import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../core/currency.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'sms_parser.dart';
import 'sms_rules.dart';
import 'sms_text.dart';

// مفاتيح محلية فقط: غير موجودة في kSyncKeys فلا تُرفع للسيرفر أبدًا.
const _kCfg = 'tyr_sms_cfg';
const _kReview = 'tyr_sms_review';
const _kLog = 'tyr_sms_log';
const _kSeen = 'tyr_sms_seen';

/// خدمة تتبع رسائل البنك: تعمل بالكامل على الجهاز، بلا أي إرسال للرسائل خارجه.
class SmsTracker extends ChangeNotifier {
  static const _ch = MethodChannel('cashu/sms');
  bool busy = false;

  Map<String, dynamic> get _cfg => store.peekMap(_kCfg);
  void _saveCfg(Map<String, dynamic> m) {
    store.set(_kCfg, m);
    notifyListeners();
  }

  bool get enabled => _cfg['on'] == true;
  /// تسجيل تلقائي: أي رسالة مالية تحتوي الكلمات المفتاحية تُسجَّل فور وصولها بدون مراجعة.
  bool get autoReg => _cfg['auto'] == true;
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
  /// last4 -> accountId: الروابط اليدوية + رقم الحساب المكتوب في إعدادات كل حساب.
  Map<String, String> get cards {
    final m = _strMap(_cfg['cards']);
    for (final a in repo.accList) {
      if (a.last4.length == 4) m[a.last4] = a.id;
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
  String resolveAccount(String last4, String bankKey) {
    final c = cards;
    if (last4.isNotEmpty && c[last4] != null && repo.account(c[last4]!) != null) return c[last4]!;
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

  SmsConfig get config => SmsConfig(words: words, excluded: excluded, trustedSenders: trusted.toSet(), cardAcc: cards, bankAcc: _bankAccAll);

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
    if (!all[kind]!.map(normalizeForMatch).contains(normalizeForMatch(t))) all[kind]!.add(t);
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

  void linkCard(String last4, String accId) {
    final m = _mut();
    m['cards'] = cards..[last4] = accId;
    _saveCfg(m);
  }

  void unlinkCard(String last4) {
    final m = _mut();
    m['cards'] = cards..remove(last4);
    _saveCfg(m);
  }

  void linkBank(String bank, String accId) {
    final m = _mut();
    m['bankAcc'] = bankAcc..[bank] = accId;
    _saveCfg(m);
  }

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

  /// مسح صندوق الوارد لآخر [days] يومًا (يحتاج READ_SMS). التكرار يُمنع تلقائيًا.
  Future<int> scanInbox({int days = 30}) async {
    if (!enabled) return 0;
    var n = 0;
    try {
      final since = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
      final raw = await _ch.invokeMethod<List<dynamic>>('readInbox', {'since': since, 'limit': 800}) ?? const [];
      for (final e in raw.reversed) {
        if (e is! Map) continue;
        await ingest('${e['sender'] ?? ''}', '${e['body'] ?? ''}', (e['ts'] as num?)?.toInt() ?? since);
        n++;
      }
    } on PlatformException catch (e) {
      debugPrint('sms scan: $e');
    } on MissingPluginException {
      // تجاهل خارج أندرويد
    }
    notifyListeners();
    return n;
  }

  Future<void> ingest(String sender, String body, int receivedMs) async {
    final p = parseSms(sender, body, receivedMs, config);
    if (p.verdict == SmsVerdict.reject) {
      _log(p, 'reject'); // لا نخزن نص الرسالة المرفوضة (رموز تحقق/دعاية) إطلاقًا
      return;
    }
    final seen = _seen();
    final bk = 'b|${bodyFingerprint(sender, body)}';
    final sk = semanticKey(p);
    final dup = seen.containsKey(bk) || (p.ref.isNotEmpty ? seen.containsKey(sk) : _near(seen[sk], p.ts));
    if (dup) {
      _log(p, 'dup');
      return;
    }
    seen[bk] = p.ts;
    seen[sk] = p.ts;
    _saveSeen(seen);
    var acc = p.accId;
    if (acc.isEmpty) acc = resolveAccount(p.last4, p.bankKey);
    // التسجيل التلقائي يغطي حالات المراجعة القابلة للحسم فقط؛ الرسائل الملتبسة فعلًا تبقى للمراجعة.
    const autoOk = {'unknown_sender', 'no_account', 'multiple_amounts'};
    final canAuto = p.verdict == SmsVerdict.review && autoReg && p.kind.isNotEmpty && p.minor > 0 && autoOk.contains(p.reason);
    if (p.verdict == SmsVerdict.accept || (canAuto && acc.isNotEmpty)) {
      final tx = _toTx(p, acc, p.kind, body);
      repo.saveTx(tx);
      _rememberBank(p.bankKey, acc);
      _log(p, 'accept');
      if (notifyOn) _notify(p, tx);
    } else {
      final l = review;
      l.insert(0, {
        'id': uid(), 'sender': sender, 'body': body, 'ts': p.ts, 'kind': p.kind, 'minor': p.minor, 'cur': p.currency,
        'last4': p.last4, 'merchant': p.merchant, 'reason': p.reason, 'bank': p.bankKey,
      });
      store.set(_kReview, l.take(200).toList());
      _log(p, 'review');
    }
    notifyListeners();
  }

  bool _near(int? a, int b) => a != null && (a - b).abs() < 10 * 60 * 1000;

  Tx _toTx(ParsedSms p, String acc, String kind, String body) {
    final inc = kSmsDir[kind] == 'in';
    return Tx(
      id: uid(), type: inc ? 'inc' : 'exp', amt: p.amount, cur: p.currency, rate: rates.rate(p.currency, S.cur), acc: acc,
      cat: inc ? 'other_i' : 'other', note: body, pay: p.merchant, ts: p.ts, src: 'sms',
    );
  }

  void _rememberBank(String bank, String acc) {
    if (bank.isEmpty || acc.isEmpty || bankAcc.containsKey(bank)) return;
    linkBank(bank, acc);
  }

  void _notify(ParsedSms p, Tx tx) {
    final inc = tx.type == 'inc';
    final acc = repo.account(tx.acc)?.name ?? '';
    final title = inc ? 'تم تسجيل دخل' : 'تم تسجيل مصروف';
    final msg = '${tx.amt.toStringAsFixed(2)} ${p.currency}${p.merchant.isNotEmpty ? ' · ${p.merchant}' : ''}${acc.isNotEmpty ? ' · $acc' : ''}';
    _invoke<void>('notify', {'title': title, 'body': msg, 'id': tx.id.hashCode & 0x7fffffff});
  }

  /// موافقة المستخدم على عنصر المراجعة (مع إمكانية تغيير الحساب/النوع).
  void approve(String id, String accId, {String? kind, bool rememberCard = true}) {
    final l = review;
    final i = l.indexWhere((e) => e['id'] == id);
    if (i < 0) return;
    final e = l[i];
    final k = kind ?? '${e['kind']}';
    final p = ParsedSms(
      verdict: SmsVerdict.accept, reason: 'user', kind: k, minor: (e['minor'] as num).toInt(), currency: '${e['cur']}',
      last4: '${e['last4']}', merchant: '${e['merchant']}', ts: (e['ts'] as num).toInt(),
    );
    repo.saveTx(_toTx(p, accId, k, '${e['body'] ?? ''}'));
    if (rememberCard && p.last4.isNotEmpty) linkCard(p.last4, accId);
    _rememberBank('${e['bank'] ?? ''}', accId);
    l.removeAt(i); // نص الرسالة يُحذف بمجرد البت فيه
    store.set(_kReview, l);
    _log(p, 'accept');
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

  void rejectMany(Iterable<String> ids) {
    final set = ids.toSet();
    store.set(_kReview, review..removeWhere((e) => set.contains(e['id'])));
    notifyListeners();
  }

  void rejectReview(String id) {
    final l = review..removeWhere((e) => e['id'] == id);
    store.set(_kReview, l);
    notifyListeners();
  }

  void clearLog() {
    store.set(_kLog, <dynamic>[]);
    notifyListeners();
  }

  // ---------- مساعدات التخزين ----------
  Map<String, int> _seen() {
    final v = store.peek(_kSeen);
    final out = <String, int>{};
    if (v is Map) v.forEach((a, b) => out['$a'] = (b as num).toInt());
    return out;
  }

  void _saveSeen(Map<String, int> m) {
    final cut = DateTime.now().subtract(const Duration(days: 60)).millisecondsSinceEpoch;
    m.removeWhere((_, t) => t < cut);
    if (m.length > 4000) {
      final keys = m.keys.toList()..sort((a, b) => m[a]!.compareTo(m[b]!));
      for (final k in keys.take(m.length - 4000)) {
        m.remove(k);
      }
    }
    store.set(_kSeen, m, quiet: true);
  }

  void _log(ParsedSms p, String v) {
    final l = log;
    l.insert(0, {'t': DateTime.now().millisecondsSinceEpoch, 's': maskSensitive(p.sender), 'v': v, 'r': p.reason, 'k': p.kind, 'm': p.minor, 'c': p.currency});
    store.set(_kLog, l.take(300).toList(), quiet: true);
  }
}

final SmsTracker smsTracker = SmsTracker();
