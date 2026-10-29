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

// مفاتيح محلية فقط: غير موجودة في kSyncKeys فلا تُرفع للسيرفر أبدًا.
const _kCfg = 'tyr_sms_cfg';
const _kReview = 'tyr_sms_review';
const _kLog = 'tyr_sms_log';
const _kDone = 'tyr_sms_done'; // بصمة الرسالة -> id المعاملة المسجّلة
const _kIgn = 'tyr_sms_ign'; // رسائل تجاهلها المستخدم (للاستقبال اللحظي فقط)

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

  SmsConfig get config => SmsConfig(words: words, excluded: excluded, trustedSenders: {...trusted, for (final w in _walletPatterns) w.$1}, cardAcc: cards, bankAcc: _bankAccAll);

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

  /// يسحب الرسائل الجديدة التي التقطها المستقبِل النيتف، ويعالجها، ثم يؤكد الاستلام (ack).
  Future<int> drainNative() async {
    if (!enabled || busy) return 0;
    busy = true;
    var n = 0;
    try {
      final raw = await _ch.invokeMethod<List<dynamic>>('drain') ?? const [];
      final ids = <String>[];
      for (final e in raw) {
        if (e is! Map) continue;
        await ingest('${e['sender'] ?? ''}', '${e['body'] ?? ''}', (e['ts'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch);
        ids.add('${e['id']}');
        n++;
      }
      if (ids.isNotEmpty) await _ch.invokeMethod<void>('ack', ids);
    } on PlatformException catch (e) {
      debugPrint('sms drain: $e');
    } on MissingPluginException {
      // ليس على أندرويد (مثلًا في الاختبارات)
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
  Map<String, int> _ign() {
    final v = store.peek(_kIgn);
    final out = <String, int>{};
    if (v is Map) v.forEach((a, b) => out['$a'] = (b as num).toInt());
    return out;
  }

  /// معاملة مسجّلة (غير محذوفة) تقابل الرسالة، أو null.
  Tx? _registeredTx(String bk, String sk, ParsedSms p, String body) {
    final done = _done();
    final byBody = repo.tx(done[bk] ?? '');
    if (byBody != null && !byBody.del) return byBody;
    final bySem = repo.tx(done[sk] ?? '');
    if (bySem != null && !bySem.del && (p.ref.isNotEmpty || _near(bySem.ts, p.ts))) return bySem;
    for (final t in repo.allTx) {
      if (t.src == 'sms' && t.note == body) return t;
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
    // 1) مسجّلة فعلًا كمعاملة؟
    final tx = _registeredTx(bk, sk, p, body);
    if (tx != null) {
      if (!manual) _log(p, 'dup');
      return ScanItem(sender: sender, body: body, ts: p.ts, status: SmsStatus.registered, parsed: p, txId: tx.id);
    }
    // 2) موجودة بالفعل في المراجعة؟
    for (final e in review) {
      final same = e['bk'] == bk || (e['bk'] == null && e['body'] == body) || (e['sk'] == sk && (p.ref.isNotEmpty || _near((e['ts'] as num?)?.toInt(), p.ts)));
      if (same) {
        if (!manual) _log(p, 'dup');
        return ScanItem(sender: sender, body: body, ts: p.ts, status: SmsStatus.pending, parsed: p, reviewId: '${e['id']}');
      }
    }
    // 3) تجاهلها المستخدم قبل كده: لا تظهر تاني أبدًا (استقبال لحظي أو فحص أو تحديث).
    if (_ign().containsKey(bk)) {
      if (!manual) _log(p, 'dup');
      return null;
    }
    var acc = p.accId;
    if (acc.isEmpty) acc = resolveAccount(p.last4, p.bankKey, sender: sender, body: body);
    // تحليل AI اختياري قبل التسجيل: لو اختلف عن المحلل المحلي أو استبعدها نحوّلها للمراجعة اليدوية (مفيش تسجيل تلقائي).
    var aiDisagree = false;
    var merchant = p.merchant;
    if (aiOn) {
      final v = await aiAnalyze(sync.client, sender, body);
      if (v != null) {
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
      'last4': p.last4, 'merchant': merchant, 'reason': p.reason, 'bank': p.bankKey, 'acc': acc, 'ref': p.ref, 'bk': bk, 'sk': sk,
      'verdict': p.verdict == SmsVerdict.accept ? 'accept' : 'review',
    });
    store.set(_kReview, l.take(1000).toList());
    _log(p, 'review');
    // تسجيل تلقائي: حساب مفعّل له + الرسالة واضحة (accept) + AI مختلفش معاها → تتسجل فورًا من غير مراجعة.
    if (!manual && autoReg && p.verdict == SmsVerdict.accept && !aiDisagree && autoFor(acc) && repo.account(acc) != null) {
      final txId = approve(id, acc);
      if (notifyOn) _invoke<void>('notify', {'title': 'تم تسجيل معاملة تلقائيًا', 'body': '${p.amount.toStringAsFixed(2)} ${p.currency}${merchant.isNotEmpty ? ' · $merchant' : ''}', 'id': (p.ts ^ p.minor) & 0x7fffffff, 'route': txId == null ? 'tx' : 'tx:$txId'});
      return ScanItem(sender: sender, body: body, ts: p.ts, status: SmsStatus.registered, parsed: p);
    }
    if (!manual && notifyOn) _notifyReview(p, id);
    notifyListeners();
    return ScanItem(sender: sender, body: body, ts: p.ts, status: SmsStatus.fresh, parsed: p, reviewId: id);
  }

  bool _near(int? a, int b) => a != null && (a - b).abs() < 10 * 60 * 1000;

  Tx _toTx(ParsedSms p, String acc, String kind, String body) {
    final inc = kSmsDir[kind] == 'in';
    return Tx(
      id: uid(), type: inc ? 'inc' : 'exp', amt: p.amount, cur: p.currency, rate: rates.rate(p.currency, S.cur), acc: acc,
      cat: inc ? 'other_i' : 'other', note: cleanBankMessage(body), pay: p.merchant, ts: p.ts, src: 'sms',
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
    final tx = _toTx(p, accId, k, '${e['body'] ?? ''}');
    repo.saveTx(tx);
    final done = _done();
    done['${e['bk'] ?? 'b|${bodyFingerprint('${e['sender'] ?? ''}', '${e['body'] ?? ''}')}'}'] = tx.id;
    if (e['sk'] != null) done['${e['sk']}'] = tx.id;
    store.set(_kDone, done, quiet: true);
    if (rememberCard && p.last4.isNotEmpty && !_cardDel.contains(p.last4)) linkCard(p.last4, accId);
    _rememberBank('${e['bank'] ?? ''}', accId);
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
    return _toTx(p, accId, kind, '${e['body'] ?? ''}');
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
      ign['${e['bk'] ?? 'b|${bodyFingerprint('${e['sender'] ?? ''}', '${e['body'] ?? ''}')}'}'] = now;
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
