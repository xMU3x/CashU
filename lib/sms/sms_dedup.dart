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

/// اسم مطبَّع للمقارنة (حروف وأرقام عربية/لاتينية فقط).
String smsNm(String s) => normalizeForMatch(s).replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]'), '');

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

/// قاعدة مطابقة الاسم/الوقت/المرجع لمعاملة مسجّلة أو عنصر مراجعة (بدون لغة/آخر ٤ أرقام).
/// · مرجعين موجودين: متطابقين = نفس العملية (خلال ١٠ دقايق)؛ مختلفين = عمليتين **بنفس القناة بس**.
/// · قناتين مختلفتين (بعد مطابقة المبلغ): نفس العملية خلال [kCrossChannelWindow] مهما كان الاسم.
/// · نفس القناة: نفس الاسم خلال ٣ دقايق، أو أحد الاسمين فاضي خلال ٥ دقايق (زي ما كان).
bool crossMatch({required int ts, required int otherTs, required String name, required String otherName, required bool crossChannel, String ref = '', String otherRef = ''}) {
  final dt = (ts - otherTs).abs();
  final cross = kCrossChannelWindow.inMilliseconds;
  if (ref.isNotEmpty && otherRef.isNotEmpty) {
    if (ref == otherRef) return dt <= cross;
    if (!crossChannel) return false; // نفس القناة: مرجعين مختلفين = عمليتين حقيقيتين
    // قناتين مختلفتين: المرجع المختلف ميلغيش المطابقة ← نكمل بالوقت.
  }
  if (crossChannel) return dt <= cross;
  final a = smsNm(name), b = smsNm(otherName);
  if (a.length >= 3 && b.length >= 3 && (a == b || a.contains(b) || b.contains(a))) return dt <= kSameChannelWindow.inMilliseconds;
  if (a.isEmpty || b.isEmpty) return dt <= kSameChannelNoNameWindow.inMilliseconds;
  return false;
}

/// مطابقة عملية [a] (الجديدة) مع [b] (مسجّلة قبل كده في الدفتر/الانتظار): هل هما نفس العملية؟
/// المبلغ/العملة/الاتجاه لازم يتطابقوا (مع سماحية الرسوم بين قناتين مختلفتين).
bool isDuplicateOp(DedupKey a, DedupKey b, {int Function(int smallerMinor)? feeMinorOf}) {
  if (a.cur != b.cur || a.income != b.income) return false;
  final cross = a.crossTo(b);
  if (!sameAmount(a.minor, b.minor, cur: a.cur, income: a.income, crossChannel: cross, feeMinorOf: feeMinorOf)) return false;
  final dt = (a.ts - b.ts).abs();
  if (dt > kCrossChannelWindow.inMilliseconds) return false;
  if (a.ref.isNotEmpty && b.ref.isNotEmpty) {
    if (a.ref == b.ref) return true;
    if (!cross) return false; // نفس القناة: مرجعين مختلفين = عمليتين
  }
  if (a.last4.isNotEmpty && b.last4.isNotEmpty && a.last4 != b.last4) return false; // بطاقتين مختلفتين = عمليتين
  if (cross) return true; // قناتين مختلفتين خلال ١٠ دقايق = نفس العملية
  if (dt > kSameChannelWindow.inMilliseconds) return false;
  final x = smsNm(a.name), y = smsNm(b.name);
  if (x.length >= 3 && y.length >= 3 && (x == y || x.contains(y) || y.contains(x))) return true;
  return dt <= kLangTwinWindow.inMilliseconds && x.isEmpty && y.isEmpty && a.lang != b.lang;
}

/// دفتر العمليات الأخيرة: هل [k] تكرار لأي إدخال؟
bool ledgerDup(DedupKey k, Iterable<Map<String, dynamic>> ledger, {int Function(int smallerMinor)? feeMinorOf}) {
  for (final e in ledger) {
    if (isDuplicateOp(k, DedupKey.fromLedger(e), feeMinorOf: feeMinorOf)) return true;
  }
  return false;
}

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

/// طابور احتجاز الإشعارات: الإشعار مايتسجلش فورًا؛ بيستنى [kNotifHold]. رسالة SMS لنفس العملية خلال الانتظار = الإشعار مكرر ويتحذف.
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

  /// وصلت رسالة [sms]: يشيل من الانتظار (ويرجّع) الإشعارات اللي هي نفس العملية — المرجع المختلف ميلغيش المطابقة بين القناتين.
  List<HeldNotif> takeDuplicatesOf(DedupKey sms, {int Function(int smallerMinor)? feeMinorOf}) {
    final out = _items.where((h) => isDuplicateOp(sms, h.key, feeMinorOf: feeMinorOf)).toList();
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
