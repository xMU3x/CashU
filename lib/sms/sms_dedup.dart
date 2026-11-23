import 'insta_fee.dart';
import 'sms_text.dart';

/// منطق كشف التكرار بين قناتي التتبع (رسالة SMS ↔ إشعار تطبيق «N:») — دوال نقية بلا تخزين/شبكة عشان تتختبر.
///
/// القواعد:
/// · «مرجعين مختلفين = عمليتين» بتتطبّق جوه **نفس القناة** بس. بين قناتين مختلفتين المرجع المختلف ميلغيش المطابقة
///   (مرجع رسالة البنك غالبًا غير مرجع إشعار التطبيق لنفس العملية).
/// · نافذة التكرار بين القنوات = [kCrossChannelWindow] (نفس المبلغ والعملة والاتجاه). جوه نفس القناة النوافذ القديمة زي ما هي.
/// · الإشعار بيستنى [kNotifHold] قبل التسجيل عشان رسالة البنك (الأدق) تاخد الأولوية.
/// · (اختياري) سماحية رسوم إنستاباي في المبلغ للتحويلات الصادرة بالجنيه بين قناتين مختلفتين بس.
/// · مطابقة بين قناتين على مستويين ([DupLevel]): «متأكد» (مرجع متطابق / اسم متشابه / آخر ٤ أرقام متطابقة) = تكرار يتشال بدون أثر،
///   و«مش متأكد» (نفس المبلغ/العملة/الاتجاه خلال [kCrossChannelWindow] بدون اسم ولا مرجع يأكّدوا) = ما يتمسحش بصمت، يروح للمراجعة.

/// نافذة التكرار بين قناتين مختلفتين.
const Duration kCrossChannelWindow = Duration(minutes: 10);

/// نافذة التكرار بنفس القناة (نسخة بنفس الاسم / بدون مرجع) — زي ما كانت.
const Duration kSameChannelWindow = Duration(minutes: 3);

/// نافذة «بدون اسم» بنفس القناة — زي ما كانت.
const Duration kSameChannelNoNameWindow = Duration(minutes: 5);

/// نسخة بلغة تانية من نفس الرسالة (بدون اسم) بنفس القناة.
const Duration kLangTwinWindow = Duration(seconds: 90);

/// مدة انتظار الإشعار قبل التسجيل (٦٠–٩٠ ثانية) — لو وصلت رسالة SMS لنفس العملية خلالها الإشعار بيتحذف من الانتظار.
const Duration kNotifHold = Duration(seconds: 75);
const int kNotifHoldMinSeconds = 60;
const int kNotifHoldMaxSeconds = 90;

/// فاصل تحديث العدّاد التنازلي في كارت «إشعارات في الانتظار» (واجهة فقط، مالوش تأثير على الاحتجاز نفسه).
const Duration kHeldUiTick = Duration(seconds: 1);

/// أسباب المراجعة لـ«محتمل تكرار» (بتترجم لنص في صفحة المراجعة): إشعار جه بعد معاملة اتسجّلت من رسالة / رسالة جت بعد معاملة اتسجّلت من إشعار.
const String kReasonMaybeDupFromSms = 'maybe_dup';
const String kReasonMaybeDupFromNotif = 'maybe_dup_n';

/// مستوى التطابق بين عمليتين: [none] عمليتين مختلفتين · [maybe] نفس المبلغ/العملة/الاتجاه في النافذة بس بدون تأكيد (مراجعة) · [sure] نفس العملية.
enum DupLevel { none, maybe, sure }

/// اسم مطبَّع للمقارنة (حروف وأرقام عربية/لاتينية فقط).
String smsNm(String s) => normalizeForMatch(s).replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]'), '');

/// اسمين متشابهين (نفس قاعدة [smsNm]: ٣ حروف على الأقل وواحد يحتوي التاني).
bool namesSimilar(String x, String y) {
  final a = smsNm(x), b = smsNm(y);
  return a.length >= 3 && b.length >= 3 && (a == b || a.contains(b) || b.contains(a));
}

/// قناة الاستقبال من اسم المرسل: إشعار تطبيق = `n`، رسالة = `s`.
String channelOf(String sender) => sender.startsWith('N:') ? 'n' : 's';

/// رسوم إنستاباي (قرش) لمبلغ تحويل [minor] قرش: بالقيم الافتراضية للتطبيق (٠٫١٪ · ٠٫٥ · ٢٠ جنيه).
int defaultInstaFeeMinor(int minor) => (InstaFee.of(minor / 100.0, r: kInstaRateDefault, lo: kInstaMinDefault, hi: kInstaMaxDefault) * 100).round();

/// هل المبلغين لنفس العملية؟ مطابقة بالمليم دايمًا، أو (سماحية الرسوم) لو:
/// قناتين مختلفتين + مصروف + جنيه + الفرق أكبر من صفر وأقل من/يساوي رسوم إنستاباي للمبلغ الأصغر.
bool sameAmount(int a, int b, {required String cur, required bool income, required bool crossChannel, int Function(int smallerMinor)? feeMinorOf}) {
  if (a == b) return true;
  if (!crossChannel || income || cur != 'EGP') return false;
  final lo = a < b ? a : b;
  final d = (a - b).abs();
  return d > 0 && d <= (feeMinorOf ?? defaultInstaFeeMinor)(lo);
}

/// مفتاح عملية للمقارنة (من رسالة/إشعار/دفتر/معاملة).
/// [ch] = `s` رسالة · `n` إشعار · `''` غير معروف (معاملة قديمة): بيتعامل معاه كنفس القناة (نفس سلوك الإصدارات السابقة).
class DedupKey {
  final int minor, ts;
  final String cur, ref, last4, name, lang, ch;
  final bool income;
  const DedupKey({required this.minor, required this.ts, this.cur = 'EGP', required this.income, this.ref = '', this.last4 = '', this.name = '', this.lang = '', this.ch = ''});

  /// من إدخال في دفتر العمليات (`tyr_sms_led`).
  factory DedupKey.fromLedger(Map<String, dynamic> e) => DedupKey(
        minor: (e['minor'] as num?)?.toInt() ?? 0,
        ts: (e['ts'] as num?)?.toInt() ?? 0,
        cur: '${e['cur'] ?? ''}',
        income: e['in'] == true,
        ref: '${e['ref'] ?? ''}',
        last4: '${e['l4'] ?? ''}',
        name: '${e['name'] ?? ''}',
        lang: '${e['lang'] ?? ''}',
        ch: '${e['ch'] ?? ''}',
      );

  /// هل القناتين معروفتين ومختلفتين؟
  bool crossTo(DedupKey o) => ch.isNotEmpty && o.ch.isNotEmpty && ch != o.ch;
}

/// قاعدة مطابقة الاسم/الوقت/المرجع لمعاملة مسجّلة أو عنصر مراجعة (بدون لغة/آخر ٤ أرقام) على مستويين.
/// · مرجعين موجودين: متطابقين = متأكد (خلال ١٠ دقايق)؛ مختلفين = عمليتين **بنفس القناة بس**.
/// · قناتين مختلفتين (بعد مطابقة المبلغ) خلال [kCrossChannelWindow]: اسم متشابه = متأكد، غير كده = مش متأكد (مراجعة، مش حذف صامت).
/// · نفس القناة: نفس الاسم خلال ٣ دقايق، أو أحد الاسمين فاضي خلال ٥ دقايق = متأكد (زي ما كان).
DupLevel crossMatchLevel({required int ts, required int otherTs, required String name, required String otherName, required bool crossChannel, String ref = '', String otherRef = ''}) {
  final dt = (ts - otherTs).abs();
  final cross = kCrossChannelWindow.inMilliseconds;
  if (ref.isNotEmpty && otherRef.isNotEmpty) {
    if (ref == otherRef) return dt <= cross ? DupLevel.sure : DupLevel.none;
    if (!crossChannel) return DupLevel.none; // نفس القناة: مرجعين مختلفين = عمليتين حقيقيتين
    // قناتين مختلفتين: المرجع المختلف ميلغيش المطابقة ← نكمل بالوقت.
  }
  if (crossChannel) {
    if (dt > cross) return DupLevel.none;
    return namesSimilar(name, otherName) ? DupLevel.sure : DupLevel.maybe;
  }
  if (namesSimilar(name, otherName)) return dt <= kSameChannelWindow.inMilliseconds ? DupLevel.sure : DupLevel.none;
  if (smsNm(name).isEmpty || smsNm(otherName).isEmpty) return dt <= kSameChannelNoNameWindow.inMilliseconds ? DupLevel.sure : DupLevel.none;
  return DupLevel.none;
}

/// نفس [crossMatchLevel] لكن «متأكد» بس (الـ«مش متأكد» مش بيتعامل كتكرار).
bool crossMatch({required int ts, required int otherTs, required String name, required String otherName, required bool crossChannel, String ref = '', String otherRef = ''}) =>
    crossMatchLevel(ts: ts, otherTs: otherTs, name: name, otherName: otherName, crossChannel: crossChannel, ref: ref, otherRef: otherRef) == DupLevel.sure;

/// مطابقة عملية [a] (الجديدة) مع [b] (مسجّلة قبل كده في الدفتر/الانتظار) على مستويين.
/// المبلغ/العملة/الاتجاه لازم يتطابقوا (مع سماحية الرسوم بين قناتين مختلفتين) والفرق في الوقت ≤ [kCrossChannelWindow].
/// · [DupLevel.sure]: مرجع متطابق، أو (بين قناتين) اسم متشابه أو آخر ٤ أرقام متطابقة، أو (نفس القناة) القواعد القديمة.
/// · [DupLevel.maybe]: قناتين مختلفتين بنفس المبلغ/العملة/الاتجاه خلال النافذة بدون أي تأكيد ← مراجعة المستخدم، مش حذف صامت.
/// · آخر ٤ أرقام مختلفة = عمليتين دايمًا.
DupLevel dupLevel(DedupKey a, DedupKey b, {int Function(int smallerMinor)? feeMinorOf}) {
  if (a.cur != b.cur || a.income != b.income) return DupLevel.none;
  final cross = a.crossTo(b);
  if (!sameAmount(a.minor, b.minor, cur: a.cur, income: a.income, crossChannel: cross, feeMinorOf: feeMinorOf)) return DupLevel.none;
  final dt = (a.ts - b.ts).abs();
  if (dt > kCrossChannelWindow.inMilliseconds) return DupLevel.none;
  if (a.ref.isNotEmpty && b.ref.isNotEmpty) {
    if (a.ref == b.ref) return DupLevel.sure;
    if (!cross) return DupLevel.none; // نفس القناة: مرجعين مختلفين = عمليتين
  }
  final bothL4 = a.last4.isNotEmpty && b.last4.isNotEmpty;
  if (bothL4 && a.last4 != b.last4) return DupLevel.none; // بطاقتين مختلفتين = عمليتين
  if (cross) return bothL4 || namesSimilar(a.name, b.name) ? DupLevel.sure : DupLevel.maybe;
  if (dt > kSameChannelWindow.inMilliseconds) return DupLevel.none;
  if (namesSimilar(a.name, b.name)) return DupLevel.sure;
  final x = smsNm(a.name), y = smsNm(b.name);
  return dt <= kLangTwinWindow.inMilliseconds && x.isEmpty && y.isEmpty && a.lang != b.lang ? DupLevel.sure : DupLevel.none;
}

/// تكرار «متأكد» بس (بيتشال/بيتسجّل كمكرر). الـ«مش متأكد» اسأل عنه [dupLevel].
bool isDuplicateOp(DedupKey a, DedupKey b, {int Function(int smallerMinor)? feeMinorOf}) => dupLevel(a, b, feeMinorOf: feeMinorOf) == DupLevel.sure;

/// دفتر العمليات الأخيرة: أعلى مستوى تطابق لـ [k] مع أي إدخال (sure يغلب maybe).
DupLevel ledgerDupLevel(DedupKey k, Iterable<Map<String, dynamic>> ledger, {int Function(int smallerMinor)? feeMinorOf}) {
  var best = DupLevel.none;
  for (final e in ledger) {
    final l = dupLevel(k, DedupKey.fromLedger(e), feeMinorOf: feeMinorOf);
    if (l == DupLevel.sure) return l;
    if (l == DupLevel.maybe) best = l;
  }
  return best;
}

/// دفتر العمليات الأخيرة: هل [k] تكرار «متأكد» لأي إدخال؟
bool ledgerDup(DedupKey k, Iterable<Map<String, dynamic>> ledger, {int Function(int smallerMinor)? feeMinorOf}) => ledgerDupLevel(k, ledger, feeMinorOf: feeMinorOf) == DupLevel.sure;

/// إشعار محتجز في الانتظار.
class HeldNotif {
  final String id, sender, body;
  final int recvMs, dueAt;
  final DedupKey key;
  const HeldNotif({required this.id, required this.sender, required this.body, required this.recvMs, required this.dueAt, required this.key});

  Map<String, dynamic> toJson() => {
        'id': id, 'sender': sender, 'body': body, 'recv': recvMs, 'due': dueAt,
        'minor': key.minor, 'ts': key.ts, 'cur': key.cur, 'in': key.income, 'ref': key.ref, 'l4': key.last4, 'name': key.name, 'lang': key.lang, 'ch': key.ch,
      };

  factory HeldNotif.fromJson(Map<String, dynamic> j) => HeldNotif(
        id: '${j['id'] ?? ''}',
        sender: '${j['sender'] ?? ''}',
        body: '${j['body'] ?? ''}',
        recvMs: (j['recv'] as num?)?.toInt() ?? 0,
        dueAt: (j['due'] as num?)?.toInt() ?? 0,
        key: DedupKey.fromLedger(j),
      );
}

/// طابور احتجاز الإشعارات: الإشعار مايتسجلش فورًا؛ بيستنى [kNotifHold]. رسالة SMS لنفس العملية (بتأكيد) خلال الانتظار = الإشعار مكرر ويتحذف؛ بدون تأكيد = يروح للمراجعة.
class NotifHold {
  final List<HeldNotif> _items;
  NotifHold([Iterable<HeldNotif> items = const []]) : _items = [...items];

  factory NotifHold.fromJson(dynamic v) => NotifHold(v is List ? v.whereType<Map>().map((e) => HeldNotif.fromJson(Map<String, dynamic>.from(e))) : const <HeldNotif>[]);

  List<Map<String, dynamic>> toJson() => [for (final h in _items) h.toJson()];

  List<HeldNotif> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  int get length => _items.length;

  void add(HeldNotif h) => _items.add(h);

  /// أقرب موعد استحقاق (أو null لو الطابور فاضي).
  int? get nextDue => _items.isEmpty ? null : _items.map((h) => h.dueAt).reduce((a, b) => a < b ? a : b);

  /// وصلت رسالة [sms]: يشيل من الانتظار (ويرجّع) الإشعارات اللي هي نفس العملية **بتأكيد** (مرجع/اسم/آخر ٤ أرقام) — المرجع المختلف ميلغيش المطابقة بين القناتين.
  List<HeldNotif> takeDuplicatesOf(DedupKey sms, {int Function(int smallerMinor)? feeMinorOf}) {
    final out = _items.where((h) => isDuplicateOp(sms, h.key, feeMinorOf: feeMinorOf)).toList();
    _items.removeWhere(out.contains);
    return out;
  }

  /// نفس العملية «احتمال» بس (نفس المبلغ/العملة/الاتجاه خلال النافذة بدون اسم ولا مرجع يأكّدوا): يشيلهم من الانتظار ويرجّعهم
  /// عشان يتسجّلوا في المراجعة (مش حذف صامت). نادِها بعد [takeDuplicatesOf].
  List<HeldNotif> takeMaybeDuplicatesOf(DedupKey sms, {int Function(int smallerMinor)? feeMinorOf}) {
    final out = _items.where((h) => dupLevel(sms, h.key, feeMinorOf: feeMinorOf) == DupLevel.maybe).toList();
    _items.removeWhere(out.contains);
    return out;
  }

  /// الإشعارات اللي انتهت مدة انتظارها (يشيلها ويرجّعها بترتيب الوصول).
  List<HeldNotif> takeDue(int nowMs) {
    final out = _items.where((h) => h.dueAt <= nowMs).toList()..sort((a, b) => a.recvMs.compareTo(b.recvMs));
    _items.removeWhere(out.contains);
    return out;
  }
}
