import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../core/currency.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/store.dart';
import '../core/sync.dart';
import '../core/util.dart';
import 'groq_ai.dart';
import 'sms_parser.dart';
import 'sms_rules.dart';
import 'sms_text.dart';
import 'sms_cat.dart';

// مفاتيح محلية فقط: غير موجودة في kSyncKeys فلا تُرفع للسيرفر أبدًا.
const _kCfg = 'tyr_sms_cfg';
const _kReview = 'tyr_sms_review';
const _kLog = 'tyr_sms_log';
const _kDone = 'tyr_sms_done'; // بصمة الرسالة -> id المعاملة المسجّلة
const _kIgn = 'tyr_sms_ign'; // رسائل تجاهلها المستخدم (للاستقبال اللحظي فقط)
const _kRefs = 'tyr_sms_refs'; // أرقام مرجعية اتسجّلت قبل كده (bank|ref → وقت) — دائم، عشان إعادة الفحص ما تسجّلهاش تاني
const _kLed = 'tyr_sms_led'; // دفتر العمليات الأخيرة (٣ أيام) لكشف التكرار بين القنوات (رسالة/إشعار/نسخة عربي-إنجليزي)

/// حالة رسالة مالية بعد الفحص.
enum SmsStatus { registered, pending, fresh, ignored }

class ScanItem {
  final String sender, body, reviewId, txId;
  final int ts;
  final SmsStatus status;
  final ParsedSms parsed;
  const ScanItem({required this.sender, required this.body, required this.ts, required this.status, required this.parsed, this.reviewId = '', this.txId = ''});
}

/// نتيجة فحص الصندوق: كل الرسائل المالية بحالتها + عدد المستبعد (رموز تحقق/إعلانات).
class ScanReport {
  final int days, scanned, excluded;
  final DateTime at;
  final String? error;
  final List<ScanItem> items;
  const ScanReport({required this.days, required this.scanned, required this.excluded, required this.at, required this.items, this.error});
  int count(SmsStatus s) => items.where((e) => e.status == s).length;
}

/// خدمة تتبع رسائل البنك: تعمل بالكامل على الجهاز، بلا أي إرسال للرسائل خارجه.
class SmsTracker extends ChangeNotifier {
  static const _ch = MethodChannel('cashu/sms');
  bool busy = false;
  ScanReport? lastScan; // في الذاكرة فقط (فيه نص رسائل) — لا يُحفظ

  Map<String, dynamic> get _cfg => store.peekMap(_kCfg);
  void _saveCfg(Map<String, dynamic> m) {
    store.set(_kCfg, m);
    notifyListeners();
  }

  bool get enabled => _cfg['on'] == true;
  /// تسجيل تلقائي: أي رسالة مالية تحتوي الكلمات المفتاحية تُسجَّل فور وصولها بدون مراجعة.
  bool get autoReg => _cfg['auto'] == true && (autoAll || autoAccounts.isNotEmpty);
  /// تسجيل كل المعاملات الواضحة تلقائيًا (مش محصور في حسابات بعينها): أي رسالة تتطابق مع حساب (برقم الكارت/الحساب أو البنك) تتسجل في قسم الحساب ده. غير المتطابق يروح للمراجعة.
  bool get autoAll => _cfg['autoAll'] == true;
  void setAutoAll(bool v) => _saveCfg(_mut()..['autoAll'] = v..['auto'] = v || autoAccounts.isNotEmpty);
  /// الحسابات اللي فعّلت لها التسجيل التلقائي (لكل حساب على حدة).
  Set<String> get autoAccounts => _cfg['autoAccs'] is List ? (_cfg['autoAccs'] as List).map((e) => '$e').toSet() : <String>{};
  bool autoFor(String acc) => acc.isNotEmpty && (autoAll || autoAccounts.contains(acc));
  void setAutoFor(String acc, bool v) {
    final set = autoAccounts..remove(acc);
    if (v) set.add(acc);
    _saveCfg(_mut()..['autoAccs'] = set.toList()..['auto'] = set.isNotEmpty || autoAll);
  }
  // تحليل بالذكاء الاصطناعي: اختياري وبموافقة المستخدم، عبر Edge Function (المفتاح على السيرفر). النص يُرسل مُنقَّحًا من الأرقام الطويلة.
  bool get aiOn => _cfg['ai'] == true && sync.ready && sync.user != null;
  bool get aiEnabledFlag => _cfg['ai'] == true;
  void setAi(bool v) => _saveCfg(_mut()..['ai'] = v);
  /// إشعار عند كل معاملة تُسجَّل تلقائيًا.
  bool get notifyOn => _cfg['notify'] == true;

  void setAuto(bool v) => _saveCfg(_mut()..['auto'] = v);
  Future<void> setNotify(bool v) async {
    if (v) await _invoke<bool>('requestNotifyPermission');
    _saveCfg(_mut()..['notify'] = v);
  }

  Map<String, List<String>> get words {
    final w = _cfg['words'];
    final out = <String, List<String>>{};
    for (final k in kSmsKinds) {
      out[k] = w is Map && w[k] is List ? List<String>.from((w[k] as List).map((e) => '$e')) : List<String>.from(kDefaultWords[k]!);
    }
    return out;
  }

  List<String> get excluded => _cfg['excl'] is List ? List<String>.from((_cfg['excl'] as List).map((e) => '$e')) : List<String>.from(kDefaultExcluded);
  List<String> get trusted => _cfg['trust'] is List ? List<String>.from((_cfg['trust'] as List).map((e) => '$e')) : <String>[];
  static final _l4Re = RegExp(r'^\d{4}$');
  Set<String> get _cardDel => _cfg['cardDel'] is List ? Set<String>.from((_cfg['cardDel'] as List).map((e) => '$e')) : <String>{};

  /// last4 -> accountId: الروابط اليدوية + رقم الحساب المكتوب في إعدادات كل حساب.
  /// بطاقة واحدة = حساب واحد (المفتاح فريد)، والمحذوفة نهائيًا لا ترجع.
  Map<String, String> get cards {
    final del = _cardDel;
    final m = <String, String>{};
    _strMap(_cfg['cards']).forEach((k, v) {
      final key = normDigits(k);
      final a = repo.account(v);
      if (_l4Re.hasMatch(key) && !del.contains(key) && a != null && !a.del) m[key] = v;
    });
    for (final a in repo.accList) {
      final l4 = normDigits(a.last4);
      if (_l4Re.hasMatch(l4) && !del.contains(l4)) m[l4] = a.id;
    }
    return m;
  }

  Map<String, String> get bankAcc => _strMap(_cfg['bankAcc']);
  /// بنك -> حساب: الروابط المحفوظة + حساب اسمه يطابق اسم البنك.
  Map<String, String> get _bankAccAll {
    final m = Map<String, String>.from(bankAcc);
    return m;
  }

  /// يختار حسابًا لرسالة: ربط البطاقة/البنك، ثم حساب يطابق اسم البنك. فارغ = غير معروف.
  /// كلمات/مرسلين المحافظ المكتوبة في إعدادات الحساب (محلية بالكامل).
  List<(String, String)> get _walletPatterns => [
        for (final a in repo.accList)
          if (!a.del && a.sms.trim().isNotEmpty)
            for (final w in a.sms.split(RegExp(r'[\n,،;]')))
              if (w.trim().isNotEmpty) (normalizeForMatch(w.trim()), a.id)
      ];

  /// حساب محفظة مطابق للمرسل/نص الرسالة، أو فارغ.
  String walletFor(String sender, String body) {
    final s = normalizeForMatch(sender), t = normalizeForMatch(body);
    for (final w in _walletPatterns) {
      if (s.contains(w.$1) || t.contains(w.$1)) return w.$2;
    }
    return '';
  }

  String resolveAccount(String last4, String bankKey, {String sender = '', String body = ''}) {
    final w = walletFor(sender, body);
    if (w.isNotEmpty) return w;
    final c = cards;
    if (last4.isNotEmpty && c[last4] != null && repo.account(c[last4]!) != null) { return c[last4]!; }
    final b = bankAcc[bankKey];
    if (b != null && repo.account(b) != null) return b;
    final k = bankKey.toLowerCase();
    if (k.isNotEmpty) {
      for (final a in repo.accList) {
        final n = a.name.toLowerCase();
        if (n.contains(k) || k.contains(n)) return a.id;
      }
    }
    return '';
  }

  int get wordCount => words.values.fold(0, (s, l) => s + l.length);

  static Map<String, String> _strMap(dynamic v) => v is Map ? v.map((a, b) => MapEntry('$a', '$b')) : <String, String>{};

  SmsConfig get config => SmsConfig(
        words: words,
        excluded: excluded,
        trustedSenders: {...trusted, for (final w in _walletPatterns) w.$1},
        cardAcc: cards,
        bankAcc: _bankAccAll,
        resolver: (l4, bank, sender, body) => resolveAccount(l4, bank, sender: sender, body: body),
      );

  List<Map<String, dynamic>> get review => _list(_kReview);
  List<Map<String, dynamic>> get log => _list(_kLog);
  List<Map<String, dynamic>> _list(String k) {
    final v = store.peek(k);
    return v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
  }

  // ---------- تعديل الإعدادات ----------
  Map<String, dynamic> _mut() => Map<String, dynamic>.from(_cfg);

  void addWord(String kind, String w) {
    final t = w.trim();
    if (t.isEmpty) return;
    final m = _mut();
    final all = words;
    if (!all[kind]!.map(normalizeForMatch).contains(normalizeForMatch(t))) { all[kind]!.add(t); }
    m['words'] = all;
    _saveCfg(m);
  }

  void removeWord(String kind, String w) {
    final m = _mut();
    final all = words;
    all[kind]!.remove(w);
    m['words'] = all;
    _saveCfg(m);
  }

  void resetWords() {
    final m = _mut()..remove('words')..remove('excl');
    _saveCfg(m);
  }

  void addExcluded(String w) {
    final t = w.trim();
    if (t.isEmpty) return;
    final m = _mut();
    final l = excluded;
    if (!l.map(normalizeForMatch).contains(normalizeForMatch(t))) l.add(t);
    m['excl'] = l;
    _saveCfg(m);
  }

  void removeExcluded(String w) {
    final m = _mut();
    m['excl'] = excluded..remove(w);
    _saveCfg(m);
  }

  void trustSender(String s) {
    final t = s.trim();
    if (t.isEmpty) return;
    final m = _mut();
    final l = trusted;
    if (!l.contains(t)) l.add(t);
    m['trust'] = l;
    _saveCfg(m);
  }

  /// يربط بطاقة بحساب. لو البطاقة مربوطة بحساب تاني تتنقل (مش بتتكرر).
  void linkCard(String last4, String accId) {
    final k = normDigits(last4.trim());
    if (!_l4Re.hasMatch(k)) return;
    for (final a in repo.accList) {
      if (a.id != accId && normDigits(a.last4) == k) {
        a.last4 = '';
        repo.saveAccount(a);
      }
    }
    final m = _mut();
    final man = _strMap(m['cards']);
    man.removeWhere((x, _) => normDigits(x) == k);
    man[k] = accId;
    m['cards'] = man;
    m['cardDel'] = (_cardDel..remove(k)).toList();
    _saveCfg(m);
  }

  /// حذف نهائي: يشيل الربط اليدوي ورقم الحساب، ويمنع إعادة الربط التلقائي.
  void unlinkCard(String last4) {
    final k = normDigits(last4.trim());
    for (final a in repo.accList) {
      if (normDigits(a.last4) == k) {
        a.last4 = '';
        repo.saveAccount(a);
      }
    }
    final m = _mut();
    final man = _strMap(m['cards']);
    man.removeWhere((x, _) => normDigits(x) == k);
    m['cards'] = man;
    m['cardDel'] = (_cardDel..add(k)).toList();
    _saveCfg(m);
  }

  void linkBank(String bank, String accId) {
    final m = _mut();
    m['bankAcc'] = bankAcc..[bank] = accId;
    _saveCfg(m);
  }

  /// وصول CashU لإشعارات تطبيقات المعاملات (بيلتقط العمليات اللي مجاش عليها رسالة SMS).
  Future<bool> notifAccess() async => (await _invoke<bool>('notifAccess')) ?? false;
  Future<void> openNotifAccess() async => _invoke<bool>('openNotifAccess');

  Future<T?> _invoke<T>(String m, [dynamic args]) async {
    try {
      return await _ch.invokeMethod<T>(m, args);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  // ---------- الصلاحيات والتشغيل ----------
  Future<bool> hasPermission() async {
    try {
      return await _ch.invokeMethod<bool>('hasPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      return await _ch.invokeMethod<bool>('requestPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// يشغّل/يوقف القراءة. التشغيل يطلب الصلاحية أولًا ولا يُفعَّل بدونها.
  Future<bool> setEnabled(bool on) async {
    if (on && !await requestPermission()) return false;
    final m = _mut()..['on'] = on;
    _saveCfg(m);
    if (on) await drainNative();
    return true;
  }

  // ---------- المعالجة ----------
  /// معاينة فقط (زر "جرّب رسالة"): لا تحفظ شيئًا.
  ParsedSms test(String sender, String text) => parseSms(sender, text, DateTime.now().millisecondsSinceEpoch, config);

  // ---------- استقبال لحظي ----------
  bool _listening = false;
  bool _again = false;
  int _busyAt = 0;
  final Map<String, int> _fails = {};

  /// بيسمع لنداء النيتف «onQueue» (بيتبعت لحظة وصول رسالة/إشعار مالي) فيسحب الطابور فورًا من غير ما يستنى المؤقت.
  void listen() {
    if (_listening) return;
    _listening = true;
    _ch.setMethodCallHandler((c) async {
      if (c.method == 'onQueue') unawaited(drainNative());
      return null;
    });
  }

  /// يسحب الرسائل الجديدة التي التقطها المستقبِل النيتف، ويعالجها، ثم يؤكد الاستلام (ack).
  /// رسالة بتفشل معالجتها بتتعاد لحد ٣ مرات (بعدها بتتشال عشان ما تعطّلش الطابور)، وأي سحب بيوصل أثناء الشغل بيتعاد بعده.
  Future<int> drainNative() async {
    if (!enabled) return 0;
    final now0 = DateTime.now().millisecondsSinceEpoch;
    if (busy && now0 - _busyAt < 60000) {
      _again = true;
      return 0;
    }
    busy = true;
    _busyAt = now0;
    var n = 0;
    try {
      do {
        _again = false;
        final raw = await _ch.invokeMethod<List<dynamic>>('drain').timeout(const Duration(seconds: 10)) ?? const [];
        final ids = <String>[];
        for (final e in raw) {
          if (e is! Map) continue;
          final id = '${e['id']}';
          try {
            await ingest('${e['sender'] ?? ''}', '${e['body'] ?? ''}', (e['ts'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch).timeout(const Duration(seconds: 25));
            ids.add(id);
            _fails.remove(id);
            n++;
          } catch (err) {
            final c = (_fails[id] ?? 0) + 1;
            _fails[id] = c;
            debugPrint('sms ingest ($c): $err');
            if (c >= 3) {
              ids.add(id);
              _fails.remove(id);
            }
          }
        }
        if (ids.isNotEmpty) await _ch.invokeMethod<void>('ack', ids);
      } while (_again);
    } on PlatformException catch (e) {
      debugPrint('sms drain: $e');
    } on MissingPluginException {
      // ليس على أندرويد (مثلًا في الاختبارات)
    } catch (e) {
      debugPrint('sms drain: $e');
    } finally {
      busy = false;
      notifyListeners();
    }
    return n;
  }

  /// مسح صندوق الوارد لآخر [days] يومًا (يحتاج READ_SMS).
  /// بيرجّع كل الرسائل المالية بحالتها: مسجّلة / في المراجعة / جديدة (اتضافت للمراجعة عشان تسجّلها).
  Future<ScanReport?> scanInbox({int days = 30}) async {
    if (!enabled) return null;
    final items = <ScanItem>[];
    var scanned = 0, excluded = 0;
    String? error;
    try {
      final since = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
      final raw = await _ch.invokeMethod<List<dynamic>>('readInbox', {'since': since, 'limit': 1500}) ?? const [];
      for (final e in raw) {
        if (e is! Map) continue;
        scanned++;
        final it = await ingest('${e['sender'] ?? ''}', '${e['body'] ?? ''}', (e['ts'] as num?)?.toInt() ?? since, manual: true);
        if (it == null) {
          excluded++;
        } else {
          items.add(it);
        }
      }
    } on PlatformException catch (e) {
      error = e.code == 'denied' ? 'لم تُمنح صلاحية قراءة الرسائل' : 'تعذّر قراءة الرسائل: ${e.message ?? e.code}';
      debugPrint('sms scan: $e');
    } on MissingPluginException {
      error = 'الفحص متاح على أندرويد فقط';
    }
    items.sort((a, b) => b.ts.compareTo(a.ts));
    lastScan = ScanReport(days: days, scanned: scanned, excluded: excluded, at: DateTime.now(), items: items, error: error);
    notifyListeners();
    return lastScan;
  }

  /// الحالة الحالية لعنصر من نتيجة الفحص (بتتحدّث لما تسجّل أو تتجاهل من نفس الشاشة).
  SmsStatus statusOf(ScanItem it) {
    if (it.status == SmsStatus.registered) return SmsStatus.registered;
    if (it.reviewId.isNotEmpty && review.any((e) => e['id'] == it.reviewId)) return it.status == SmsStatus.pending ? SmsStatus.pending : SmsStatus.fresh;
    return _ign().containsKey('b|${bodyFingerprint(it.sender, it.body)}') ? SmsStatus.ignored : SmsStatus.registered;
  }

  Map<String, String> _done() => _strMap(store.peek(_kDone));

  // ---------- الأرقام المرجعية ----------
  String _refKey(ParsedSms p) => '${p.bankKey}|${p.ref.toLowerCase()}';
  Map<String, int> _refs() {
    final v = store.peek(_kRefs);
    final out = <String, int>{};
    if (v is Map) v.forEach((a, b) => out['$a'] = (b as num).toInt());
    return out;
  }

  /// هل الرقم المرجعي ده اتشاف/اتسجّل قبل كده؟ (لازم يكون الرقم موجود في الرسالة)
  bool _refSeen(ParsedSms p) => p.ref.length >= 5 && _refs().containsKey(_refKey(p));

  void _refAdd(ParsedSms p) {
    if (p.ref.length < 5) return;
    final m = _refs();
    m[_refKey(p)] = DateTime.now().millisecondsSinceEpoch;
    if (m.length > 4000) {
      final es = m.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
      for (final e in es.take(m.length - 4000)) {
        m.remove(e.key);
      }
    }
    store.set(_kRefs, m, quiet: true);
  }
  Map<String, int> _ign() {
    final v = store.peek(_kIgn);
    final out = <String, int>{};
    if (v is Map) v.forEach((a, b) => out['$a'] = (b as num).toInt());
    return out;
  }

  /// معاملة مسجّلة (غير محذوفة) تقابل الرسالة، أو null.
  Tx? _registeredTx(String bk, String sk, ParsedSms p, String body) {
    final done = _done();
    // نفس النص بالظبط بس بعد وقت طويل = عملية جديدة (مثلًا نفس الشراء كل يوم) مش تكرار.
    final byBody = repo.tx(done[bk] ?? '');
    if (byBody != null && !byBody.del && _near(byBody.ts, p.ts)) return byBody;
    final bySem = repo.tx(done[sk] ?? '');
    if (bySem != null && !bySem.del && (p.ref.isNotEmpty || _near3(bySem.ts, p.ts))) return bySem;
    return null;
  }

  /// تكرار «عبر القنوات»: نفس العملية وصلت مرتين (إشعار إنستاباي + رسالة البنك) بنصّين مختلفين.
  /// يعتبرها مكررة لو: نفس المبلغ والعملة والاتجاه وفي نطاق دقائق، وكمان (نفس الاسم) أو (قناتين مختلفتين وفي نطاق دقيقتين).
  /// بيرجّع null لو مفيش تطابق (والتحفّظ هنا مقصود: أي شك = تدخل المراجعة، مش حذف صامت).
  static String _nm(String s) => normalizeForMatch(s).replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]'), '');

  /// الرقم المرجعي بيفصل: لو الاتنين ليهم مرجع ومختلفين = عمليتين حقيقيتين (حتى لو نفس المبلغ والاسم).
  /// من غير مرجع: نفس الاسم خلال ٣ دقايق، أو قناتين مختلفتين خلال دقيقة ونص.
  bool _crossMatch({required int ts, required int otherTs, required String name, required String otherName, required bool sameBank, String ref = '', String otherRef = ''}) {
    final dt = (ts - otherTs).abs();
    if (ref.isNotEmpty && otherRef.isNotEmpty) return ref == otherRef && dt <= 10 * 60 * 1000;
    final a = _nm(name), b = _nm(otherName);
    if (a.length >= 3 && b.length >= 3 && (a == b || a.contains(b) || b.contains(a))) return dt <= 3 * 60 * 1000;
    return !sameBank && dt <= 90 * 1000;
  }

  Tx? _crossDupTx(ParsedSms p, String merchant) {
    for (final t in repo.allTx) {
      if (t.del || t.src != 'sms') continue;
      if (t.cur != p.currency || ((t.amt * 100).round() - p.minor).abs() > 0) continue;
      if ((t.type == 'inc') != p.isIncome) continue;
      if (_crossMatch(ts: p.ts, otherTs: t.ts, name: merchant, otherName: t.pay, sameBank: true, ref: p.ref)) return t;
    }
    return null;
  }

  Map<String, dynamic>? _crossDupReview(ParsedSms p, String merchant) {
    for (final e in review) {
      if (('${e['cur'] ?? ''}') != p.currency || (e['minor'] as num?)?.toInt() != p.minor) continue;
      if ((kSmsDir['${e['kind'] ?? ''}'] == 'in') != p.isIncome) continue;
      if (_crossMatch(ts: p.ts, otherTs: (e['ts'] as num?)?.toInt() ?? 0, name: merchant, otherName: '${e['merchant'] ?? ''}', sameBank: '${e['bank'] ?? ''}' == p.bankKey, ref: p.ref, otherRef: '${e['ref'] ?? ''}')) return Map<String, dynamic>.from(e);
    }
    return null;
  }

  /// يعالج رسالة. يرجّع null لو مستبعدة (رمز تحقق/إعلان/غير مالية).
  /// [manual] = فحص يدوي: الرسالة اللي المستخدم تجاهلها قبل كده بتظهر تاني، ومفيش حاجة بتتعلّم "مكررة" إلا لو فعلًا مسجّلة أو في المراجعة.
  Future<ScanItem?> ingest(String sender, String body, int receivedMs, {bool manual = false}) async {
    final p = parseSms(sender, body, receivedMs, config);
    if (p.verdict == SmsVerdict.reject) {
      if (!manual) _log(p, 'reject'); // لا نخزن نص الرسالة المرفوضة (رموز تحقق/دعاية) إطلاقًا
      return null;
    }
    final bk = 'b|${bodyFingerprint(sender, body)}';
    final sk = semanticKey(p);
    // 0) نفس الرقم المرجعي اتسجّل/اتشاف قبل كده ← مفيش تسجيل تاني (حتى لو الفحص اتعاد أو الرسالة وصلت بصيغة تانية).
    if (_refSeen(p)) {
      if (!manual) _log(p, 'dup');
      return ScanItem(sender: sender, body: body, ts: p.ts, status: SmsStatus.registered, parsed: p);
    }
    // 1) مسجّلة فعلًا كمعاملة؟
    final tx = _registeredTx(bk, sk, p, body);
    if (tx != null) {
      if (!manual) _log(p, 'dup');
      return ScanItem(sender: sender, body: body, ts: p.ts, status: SmsStatus.registered, parsed: p, txId: tx.id);
    }
    // 2) موجودة بالفعل في المراجعة؟
    for (final e in review) {
      final ets = (e['ts'] as num?)?.toInt();
      final same = (e['bk'] == bk && _near(ets, p.ts)) || (e['bk'] == null && e['body'] == body) || (e['sk'] == sk && (p.ref.isNotEmpty || _near3(ets, p.ts)));
      if (same) {
        if (!manual) _log(p, 'dup');
        return ScanItem(sender: sender, body: body, ts: p.ts, status: SmsStatus.pending, parsed: p, reviewId: '${e['id']}');
      }
    }
    // 2.4) دفتر العمليات الأخيرة: نفس العملية من قناة تانية، أو نسخة عربي/إنجليزي من نفس الرسالة.
    if (_ledgerDup(p, sender, p.merchant, body)) {
      if (!manual) _log(p, 'dup');
      return ScanItem(sender: sender, body: body, ts: p.ts, status: SmsStatus.registered, parsed: p);
    }
    // 2.5) نفس العملية وصلت من قناة تانية (إشعار إنستاباي ↔ رسالة البنك): متتكررش.
    final xTx = _crossDupTx(p, p.merchant);
    if (xTx != null) {
      if (!manual) _log(p, 'dup');
      return ScanItem(sender: sender, body: body, ts: p.ts, status: SmsStatus.registered, parsed: p, txId: xTx.id);
    }
    final xRv = _crossDupReview(p, p.merchant);
    if (xRv != null) {
      if (!manual) _log(p, 'dup');
      return ScanItem(sender: sender, body: body, ts: p.ts, status: SmsStatus.pending, parsed: p, reviewId: '${xRv['id']}');
    }
    // 3) تجاهلها المستخدم قبل كده: لا تظهر تاني أبدًا (استقبال لحظي أو فحص أو تحديث).
    final ign = _ign();
    final igAt = ign[bk];
    if (ign.containsKey('$bk|${p.ts}') || (igAt != null && DateTime.now().millisecondsSinceEpoch - igAt < 24 * 3600 * 1000)) {
      if (!manual) _log(p, 'dup');
      return null;
    }
    var acc = p.accId;
    if (acc.isEmpty) acc = resolveAccount(p.last4, p.bankKey, sender: sender, body: body);
    // تحليل AI اختياري قبل التسجيل: لو اختلف عن المحلل المحلي أو استبعدها نحوّلها للمراجعة اليدوية (مفيش تسجيل تلقائي).
    var aiDisagree = false;
    var merchant = p.merchant;
    // التصنيف: محلي فوري، ولو الـ AI شغّال ورد بسرعة (≤ ٣ ثواني) تصنيفه يغلب.
    var cat = guessSmsCategory(merchant: merchant, body: body, income: p.isIncome);
    if (aiOn) {
      final v = await aiAnalyze(sync.client, sender, body).timeout(const Duration(seconds: 3), onTimeout: () => null);
      if (v != null) {
        if (v.confidence >= .5 && isValidSmsCategory(v.category, p.isIncome) && (v.category != 'other' && v.category != 'other_i' || cat == 'other' || cat == 'other_i')) cat = v.category;
        final localAmt = p.minor / 100.0;
        final kindOk = v.kind.isEmpty || (v.kind == 'inc') == p.isIncome;
        final amtOk = v.amount <= 0 || (v.amount - localAmt).abs() < 0.01;
        if (!v.financial || !kindOk || !amtOk) aiDisagree = true;
        if (merchant.isEmpty && v.merchant.isNotEmpty && v.confidence >= .6) merchant = v.merchant;
      }
    }
    // كل المعاملات المستخرجة من الرسائل تظهر الأول في الجرس (المراجعة)، والمستخدم يسجّلها أو يعدّلها أو يتجاهلها.
    final id = uid();
    final l = review;
    l.insert(0, {
      'id': id, 'sender': sender, 'body': body, 'ts': p.ts, 'kind': p.kind, 'minor': p.minor, 'cur': p.currency,
      'last4': p.last4, 'merchant': merchant, 'reason': p.reason, 'bank': p.bankKey, 'acc': acc, 'ref': p.ref, 'bk': bk, 'sk': sk, 'cat': cat,
      'verdict': p.verdict == SmsVerdict.accept ? 'accept' : 'review',
    });
    store.set(_kReview, l.take(1000).toList());
    _refAdd(p);
    _log(p, 'review');
    _ledAdd(p, sender, merchant, body);
    // تسجيل تلقائي: حساب مفعّل له + الرسالة واضحة (accept) + AI مختلفش معاها → تتسجل فورًا من غير مراجعة.
    // «تسجيل كل المعاملات» + حساب مش معروف: بنسجّل على الحساب الافتراضي بدل ما نسيبها في المراجعة.
    var autoAcc = acc;
    var fallback = false;
    final noAcc = p.verdict == SmsVerdict.review && p.reason == 'no_account';
    if (autoAcc.isEmpty && autoAll && (p.verdict == SmsVerdict.accept || noAcc)) {
      final d = repo.defaultAcc;
      if (d.isNotEmpty && repo.account(d) != null) {
        autoAcc = d;
        fallback = true;
      }
    }
    final autoOk = p.verdict == SmsVerdict.accept || (fallback && noAcc);
    if (!manual && autoReg && autoOk && !aiDisagree && autoFor(autoAcc) && repo.account(autoAcc) != null) {
      final txId = approve(id, autoAcc, rememberCard: !fallback);
      if (notifyOn) _invoke<void>('notify', {'title': fallback ? 'سُجّلت معاملة على الحساب الافتراضي' : 'تم تسجيل معاملة تلقائيًا', 'body': '${p.amount.toStringAsFixed(2)} ${p.currency}${merchant.isNotEmpty ? ' · $merchant' : ''}', 'id': (p.ts ^ p.minor) & 0x7fffffff, 'route': txId == null ? 'tx' : 'tx:$txId'});
      return ScanItem(sender: sender, body: body, ts: p.ts, status: SmsStatus.registered, parsed: p);
    }
    if (!manual && notifyOn) _notifyReview(p, id);
    notifyListeners();
    return ScanItem(sender: sender, body: body, ts: p.ts, status: SmsStatus.fresh, parsed: p, reviewId: id);
  }

  bool _near(int? a, int b) => a != null && (a - b).abs() < 10 * 60 * 1000;
  bool _near3(int? a, int b) => a != null && (a - b).abs() < 3 * 60 * 1000;

  // ---------- دفتر العمليات الأخيرة ----------
  static String _lang(String s) {
    final ar = RegExp(r'[\u0600-\u06FF]').allMatches(s).length;
    final en = RegExp(r'[A-Za-z]').allMatches(s).length;
    return ar > en ? 'a' : 'e';
  }

  void _ledAdd(ParsedSms p, String sender, String merchant, String body) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final l = _list(_kLed)..removeWhere((e) => ((e['at'] as num?)?.toInt() ?? 0) < now - 3 * 86400000);
    l.insert(0, {'ts': p.ts, 'at': now, 'minor': p.minor, 'cur': p.currency, 'in': p.isIncome, 'ch': sender.startsWith('N:') ? 'n' : 's', 'ref': p.ref, 'name': merchant, 'l4': p.last4, 'lang': _lang(body)});
    store.set(_kLed, l.take(200).toList(), quiet: true);
  }

  /// هل نفس العملية اتشافت قبل كده؟ (نفس المبلغ/العملة/الاتجاه)
  /// · مرجعين موجودين: متطابقين = تكرار، مختلفين = عمليتين · آخر ٤ أرقام مختلفة = عمليتين
  /// · قناتين مختلفتين (رسالة ↔ إشعار) خلال ٣ دقايق = تكرار · نفس القناة: نفس الاسم، أو نسخة بلغة تانية خلال ٩٠ ثانية.
  bool _ledgerDup(ParsedSms p, String sender, String merchant, String body) {
    final ch = sender.startsWith('N:') ? 'n' : 's';
    final lang = _lang(body);
    for (final e in _list(_kLed)) {
      if ('${e['cur']}' != p.currency || (e['minor'] as num?)?.toInt() != p.minor || (e['in'] == true) != p.isIncome) continue;
      final dt = (p.ts - ((e['ts'] as num?)?.toInt() ?? 0)).abs();
      if (dt > 10 * 60 * 1000) continue;
      final er = '${e['ref'] ?? ''}';
      if (p.ref.isNotEmpty && er.isNotEmpty) {
        if (p.ref == er) return true;
        continue;
      }
      final l4 = '${e['l4'] ?? ''}';
      if (p.last4.isNotEmpty && l4.isNotEmpty && p.last4 != l4) continue;
      if (dt > 3 * 60 * 1000) continue;
      if ('${e['ch']}' != ch) return true;
      final a = _nm(merchant), b = _nm('${e['name'] ?? ''}');
      if (a.length >= 3 && b.length >= 3 && (a == b || a.contains(b) || b.contains(a))) return true;
      if (dt <= 90 * 1000 && a.isEmpty && b.isEmpty && '${e['lang']}' != lang) return true;
    }
    return false;
  }

  /// مرسل اتوافق على رسالته يدويًا = موثوق من هنا ورايح (يتجاهل الأرقام الشخصية وإشعارات التطبيقات).
  void _learnSender(String s) {
    final t = s.trim();
    if (t.isEmpty || t.startsWith('N:') || t.startsWith('+') || RegExp(r'^\d{7,}$').hasMatch(t)) return;
    trustSender(t);
  }

  Tx _toTx(ParsedSms p, String acc, String kind, String body, {String cat = ''}) {
    final inc = kSmsDir[kind] == 'in';
    return Tx(
      id: uid(), type: inc ? 'inc' : 'exp', amt: p.amount, cur: p.currency, rate: rates.rate(p.currency, S.cur), acc: acc,
      cat: isValidSmsCategory(cat, inc) ? cat : (inc ? 'other_i' : 'other'), note: cleanBankMessage(body), pay: p.merchant, ts: p.ts, src: 'sms',
    );
  }

  void _rememberBank(String bank, String acc) {
    if (bank.isEmpty || acc.isEmpty || bankAcc.containsKey(bank)) return;
    linkBank(bank, acc);
  }

  void _notifyReview(ParsedSms p, String reviewId) {
    final title = kSmsDir[p.kind] == 'in' ? 'معاملة دخل جديدة تنتظر مراجعتك' : 'معاملة مصروف جديدة تنتظر مراجعتك';
    final msg = '${p.amount.toStringAsFixed(2)} ${p.currency}${p.merchant.isNotEmpty ? ' · ${p.merchant}' : ''}';
    _invoke<void>('notify', {'title': title, 'body': msg, 'id': (p.ts ^ p.minor) & 0x7fffffff, 'route': 'rv:$reviewId'});
  }

  /// موافقة المستخدم على عنصر المراجعة (مع إمكانية تغيير الحساب/النوع).
  /// يرجّع معرّف المعاملة اللي اتسجلت (أو null لو العنصر مش موجود).
  String? approve(String id, String accId, {String? kind, bool rememberCard = true}) {
    final l = review;
    final i = l.indexWhere((e) => e['id'] == id);
    if (i < 0) return null;
    final e = l[i];
    final k = kind ?? '${e['kind']}';
    final p = ParsedSms(
      verdict: SmsVerdict.accept, reason: 'user', kind: k, minor: (e['minor'] as num).toInt(), currency: '${e['cur']}',
      last4: '${e['last4']}', merchant: '${e['merchant']}', ts: (e['ts'] as num).toInt(),
    );
    final tx = _toTx(p, accId, k, '${e['body'] ?? ''}', cat: '${e['cat'] ?? ''}');
    repo.saveTx(tx);
    final done = _done();
    done['${e['bk'] ?? 'b|${bodyFingerprint('${e['sender'] ?? ''}', '${e['body'] ?? ''}')}'}'] = tx.id;
    if (e['sk'] != null) done['${e['sk']}'] = tx.id;
    store.set(_kDone, done, quiet: true);
    if (rememberCard && p.last4.isNotEmpty && !_cardDel.contains(p.last4)) linkCard(p.last4, accId);
    if (rememberCard) {
      _rememberBank('${e['bank'] ?? ''}', accId);
      _learnSender('${e['sender'] ?? ''}');
    }
    l.removeAt(i); // نص الرسالة يُحذف بمجرد البت فيه
    store.set(_kReview, l);
    _log(p, 'accept');
    notifyListeners();
    return tx.id;
  }

  /// مسودة معاملة من عنصر مراجعة (تُفتح في بانل المعاملة للتعديل قبل الحفظ).
  Tx draftOf(Map<String, dynamic> e, String accId, String kind) {
    final p = ParsedSms(
      verdict: SmsVerdict.accept, reason: 'user', kind: kind, minor: (e['minor'] as num).toInt(), currency: '${e['cur']}',
      last4: '${e['last4']}', merchant: '${e['merchant']}', ts: (e['ts'] as num).toInt(),
    );
    return _toTx(p, accId, kind, '${e['body'] ?? ''}', cat: '${e['cat'] ?? ''}');
  }

  /// بعد حفظ المستخدم للمعاملة من البانل: نربطها بالرسالة ونشيل الرسالة من المراجعة.
  void finalizeReview(String id, Tx tx) {
    final l = review;
    final i = l.indexWhere((e) => e['id'] == id);
    if (i < 0) return;
    final e = l[i];
    final done = _done();
    done['${e['bk'] ?? 'b|${bodyFingerprint('${e['sender'] ?? ''}', '${e['body'] ?? ''}')}'}'] = tx.id;
    if (e['sk'] != null) done['${e['sk']}'] = tx.id;
    store.set(_kDone, done, quiet: true);
    if ('${e['last4']}'.isNotEmpty && !_cardDel.contains('${e['last4']}')) linkCard('${e['last4']}', tx.acc);
    _rememberBank('${e['bank'] ?? ''}', tx.acc);
    l.removeAt(i);
    store.set(_kReview, l);
    notifyListeners();
  }

  /// تسجيل عدة رسائل دفعة واحدة على نفس الحساب.
  int approveMany(Iterable<String> ids, String accId) {
    var n = 0;
    for (final id in ids.toList()) {
      if (review.any((e) => e['id'] == id)) {
        approve(id, accId);
        n++;
      }
    }
    return n;
  }

  /// يسجّل الرسالة ويسجّل معها كل رسائل المراجعة التي لها نفس آخر ٤ أرقام أو نفس البنك على نفس الحساب.
  int approveSimilar(String id, String accId) {
    final src = review.firstWhere((e) => e['id'] == id, orElse: () => <String, dynamic>{});
    if (src.isEmpty) return 0;
    final l4 = '${src['last4']}', bank = '${src['bank']}';
    final ids = review.where((e) => e['id'] == id || (l4.isNotEmpty && '${e['last4']}' == l4) || (l4.isEmpty && bank.isNotEmpty && '${e['bank']}' == bank && '${e['last4']}'.isEmpty)).map((e) => '${e['id']}').toList();
    return approveMany(ids, accId);
  }

  void _ignore(Iterable<Map<String, dynamic>> items) {
    final ign = _ign();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final e in items) {
      final k = '${e['bk'] ?? 'b|${bodyFingerprint('${e['sender'] ?? ''}', '${e['body'] ?? ''}')}'}';
      ign[k] = now;
      ign['$k|${e['ts']}'] = now;
    }
    store.set(_kIgn, ign, quiet: true);
  }

  void rejectMany(Iterable<String> ids) {
    final set = ids.toSet();
    _ignore(review.where((e) => set.contains(e['id'])));
    store.set(_kReview, review..removeWhere((e) => set.contains(e['id'])));
    notifyListeners();
  }

  void rejectReview(String id) => rejectMany([id]);

  void clearLog() {
    store.set(_kLog, <dynamic>[]);
    notifyListeners();
  }

  void _log(ParsedSms p, String v) {
    final l = log;
    l.insert(0, {'t': DateTime.now().millisecondsSinceEpoch, 's': maskSensitive(p.sender), 'v': v, 'r': p.reason, 'k': p.kind, 'm': p.minor, 'c': p.currency});
    store.set(_kLog, l.take(300).toList(), quiet: true);
  }
}

final SmsTracker smsTracker = SmsTracker();
