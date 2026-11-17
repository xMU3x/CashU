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
import 'insta_fee.dart';
import 'sms_parser.dart';
import 'sms_rules.dart';
import 'sms_text.dart';
import 'sms_cat.dart';

// مفاتيح محلية فقط: غير موجودة في kSyncKeys فلا تُرفع للسيرفر أبدًا.
const _kCfg = 'tyr_sms_cfg';
const _kReview = 'tyr_sms_review';
const _kDone = 'tyr_sms_done'; // بصمة الرسالة -> id المعاملة المسجّلة
const _kIgn = 'tyr_sms_ign'; // رسائل تجاهلها المستخدم (للاستقبال اللحظي فقط)
const _kRefs = 'tyr_sms_refs'; // أرقام مرجعية اتسجّلت قبل كده (bank|ref → وقت) — دائم، عشان إعادة الفحص ما تسجّلهاش تاني
const _kUnk = 'tyr_sms_unk'; // أرقام ظهرت في رسائل ومش مربوطة بحساب: رقم → {عينة رسالة، معاملات اتسجّلت مؤقتًا}
const _kLed = 'tyr_sms_led'; // دفتر العمليات الأخيرة (٣ أيام) لكشف التكرار بين القنوات (رسالة/إشعار/نسخة عربي-إنجليزي)

/// حالة رسالة مالية بعد الفحص.
enum SmsStatus { registered, pending, fresh, ignored }

class ScanItem {
  final String sender, body, reviewId, txId;
  final int ts;
  final SmsStatus status;
  final ParsedSms parsed;
  /// اتسجّلت دلوقتي كمعاملة جديدة (مش مكررة).
  final bool added;
  const ScanItem({required this.sender, required this.body, required this.ts, required this.status, required this.parsed, this.reviewId = '', this.txId = '', this.added = false});
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


/// الرسائل اللي لقيناها في الصندوق قبل الاستيراد.
class ImportPreview {
  final int days;
  final List<Map<String, dynamic>> messages;
  final String? error;
  const ImportPreview({required this.days, required this.messages, this.error});

  /// المرسل ← عدد رسائله (الأكتر الأول).
  List<MapEntry<String, int>> get bySender {
    final m = <String, int>{};
    for (final e in messages) {
      m['${e['sender']}'] = (m['${e['sender']}'] ?? 0) + 1;
    }
    return m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }
}

class ImportResult {
  final int added, skipped, already, review, total, unlinked;
  final bool cancelled;
  const ImportResult({required this.added, required this.skipped, required this.already, required this.review, required this.total, required this.unlinked, this.cancelled = false});
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


  // ---------- تتبع إشعارات تطبيقات البنوك (بتطبيقات يختارها المستخدم بس) ----------
  /// تتبّع الإشعارات شغال؟ (منفصل عن تتبع الـSMS). مفيش أي إشعار بيتلقط غير من التطبيقات المختارة.
  bool get trackNotifs => _cfg['tn'] == true;

  /// حزمة التطبيق ← {name, acc}. acc فاضي = الحساب الافتراضي.
  Map<String, Map<String, String>> get notifApps {
    final v = _cfg['napps'];
    final out = <String, Map<String, String>>{};
    if (v is Map) {
      v.forEach((k, e) {
        final m = e is Map ? e : const {};
        out['$k'] = {'name': '${m['name'] ?? k}', 'acc': '${m['acc'] ?? ''}'};
      });
    }
    return out;
  }

  Future<void> _pushNotifApps() => _invoke<bool>('setNotifApps', trackNotifs ? notifApps.keys.toList() : <String>[]);

  Future<void> setTrackNotifs(bool v) async {
    _saveCfg(_mut()..['tn'] = v);
    await _pushNotifApps();
    if (v) {
      if (!await notifAccess()) await openNotifAccess();
      unawaited(drainNative());
    }
  }

  Future<void> addNotifApp(String pkg, String name, String acc) async {
    final m = _mut();
    final apps = notifApps;
    apps[pkg] = {'name': name, 'acc': acc};
    m['napps'] = apps;
    _saveCfg(m);
    await _pushNotifApps();
  }

  Future<void> removeNotifApp(String pkg) async {
    final m = _mut();
    m['napps'] = notifApps..remove(pkg);
    _saveCfg(m);
    await _pushNotifApps();
  }

  Future<void> setNotifAppAcc(String pkg, String acc) async {
    final apps = notifApps;
    if (!apps.containsKey(pkg)) return;
    apps[pkg]!['acc'] = acc;
    _saveCfg(_mut()..['napps'] = apps);
  }

  /// التطبيقات القابلة للتشغيل على الجهاز (للاختيار منها).
  Future<List<({String name, String pkg})>> installedApps() async {
    final raw = await _invoke<List<dynamic>>('installedApps') ?? const [];
    return [
      for (final e in raw)
        if (e is Map) (name: '${e['name'] ?? ''}', pkg: '${e['pkg'] ?? ''}'),
    ];
  }

  /// حالة بقاء التتبع شغال في الخلفية: battery / background / revoke (true = تمام).
  Future<Map<String, bool>> powerStatus() async {
    final r = await _invoke<Map<dynamic, dynamic>>('powerStatus');
    if (r == null) return {'battery': true, 'background': true, 'revoke': true};
    return {for (final e in r.entries) '${e.key}': e.value == true};
  }

  Future<void> requestBattery() async => _invoke<bool>('requestBattery');
  Future<void> openAppPermissions() async => _invoke<bool>('openAppPermissions');
  Future<void> openAppDetails() async => _invoke<bool>('openAppDetails');

  // ---------- البطاقات/النصوص المتجاهلة ----------
  List<String> get ignoredNums => _cfg['ignNums'] is List ? List<String>.from((_cfg['ignNums'] as List).map((e) => '$e')) : <String>[];
  List<String> get ignoredTexts => _cfg['ignTexts'] is List ? List<String>.from((_cfg['ignTexts'] as List).map((e) => '$e')) : <String>[];

  /// يضيف رقم بطاقة/حساب (3 أرقام فأكتر) للتجاهل. يرجّع false لو الرقم مش صالح.
  bool addIgnoredNum(String raw) {
    final n = normDigits(raw.trim()).replaceAll(RegExp(r'[^0-9]'), '');
    if (n.length < 3) return false;
    final l = ignoredNums;
    if (!l.contains(n)) l.add(n);
    _saveCfg(_mut()..['ignNums'] = l);
    _unkRemove(n);
    return true;
  }

  void removeIgnoredNum(String n) => _saveCfg(_mut()..['ignNums'] = ignoredNums..remove(n));

  void addIgnoredText(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return;
    final l = ignoredTexts;
    if (!l.map(_nm).contains(_nm(t))) l.add(t);
    _saveCfg(_mut()..['ignTexts'] = l);
  }

  void removeIgnoredText(String t) => _saveCfg(_mut()..['ignTexts'] = ignoredTexts..remove(t));

  /// الرسالة فيها رقم بطاقة/حساب متجاهَل (تطابق تام للرقم) أو نص متجاهَل (الحروف الكبيرة والمسافات مش فارقة).
  bool _isIgnored(String body) {
    final nums = ignoredNums;
    if (nums.isNotEmpty) {
      final tokens = RegExp(r'\d+').allMatches(normDigits(body)).map((m) => m.group(0)!).toSet();
      if (nums.any(tokens.contains)) return true;
    }
    final texts = ignoredTexts;
    if (texts.isNotEmpty) {
      final b = _nm(body);
      if (texts.any((t) {
        final x = _nm(t);
        return x.isNotEmpty && b.contains(x);
      })) {
        return true;
      }
    }
    return false;
  }

  // ---------- أرقام من الرسائل (مش مربوطة بحساب) ----------
  Map<String, Map<String, dynamic>> _unkMap() {
    final v = store.peek(_kUnk);
    final out = <String, Map<String, dynamic>>{};
    if (v is Map) {
      v.forEach((k, e) {
        if (e is Map) out['$k'] = Map<String, dynamic>.from(e);
      });
    }
    return out;
  }

  /// الأرقام اللي ظهرت في رسائل ولسه مش مربوطة بحساب (الأحدث الأول).
  List<Map<String, dynamic>> get unlinked {
    final c = cards;
    final ign = ignoredNums;
    final l = [
      for (final e in _unkMap().values)
        if (!c.containsKey('${e['l4']}') && !ign.contains('${e['l4']}')) e,
    ];
    l.sort((a, b) => ((b['ts'] as num?) ?? 0).compareTo((a['ts'] as num?) ?? 0));
    return l;
  }

  Map<String, dynamic>? unlinkedOf(String l4) {
    final e = _unkMap()[l4];
    return e == null || cards.containsKey(l4) ? null : e;
  }

  /// معاملات الرقم ده اللي اتسجّلت مؤقتًا (لسه موجودة وغير محذوفة).
  List<Tx> unlinkedTxs(String l4) {
    final e = _unkMap()[l4];
    if (e == null) return const [];
    final ids = e['txs'] is List ? (e['txs'] as List).map((x) => '$x') : const <String>[];
    return [
      for (final id in ids)
        if (repo.tx(id) != null && !repo.tx(id)!.del) repo.tx(id)!,
    ];
  }

  /// بيسجّل إن الرقم ده ظهر. بيرجّع true لو أول مرة نشوفه (عشان ننبّه المستخدم مرة واحدة).
  bool _unkAdd(String l4, {String txId = '', required String sender, required String body, required int ts, required String bank}) {
    final m = _unkMap();
    final isNew = !m.containsKey(l4);
    final Map<String, dynamic> e = m[l4] ?? <String, dynamic>{'l4': l4, 'sender': sender, 'body': body, 'ts': ts, 'bank': bank, 'txs': <String>[]};
    e['ts'] = ts > ((e['ts'] as num?) ?? 0) ? ts : e['ts'];
    final txs = e['txs'] is List ? List<String>.from((e['txs'] as List).map((x) => '$x')) : <String>[];
    if (txId.isNotEmpty && !txs.contains(txId)) txs.add(txId);
    e['txs'] = txs.length > 500 ? txs.sublist(txs.length - 500) : txs;
    if (_importKeep && txId.isNotEmpty) {
      final k = e['ktx'] is List ? List<String>.from((e['ktx'] as List).map((x) => '$x')) : <String>[];
      if (!k.contains(txId)) k.add(txId);
      e['ktx'] = k.length > 500 ? k.sublist(k.length - 500) : k;
    }
    m[l4] = e;
    store.set(_kUnk, m);
    return isNew;
  }

  void _unkRemove(String l4) {
    final m = _unkMap();
    if (m.remove(l4) != null) store.set(_kUnk, m);
  }

  /// يربط الرقم بحساب، وينقل معاملاته المسجّلة مؤقتًا لو [move]، ويسجّل رسائله اللي كانت مستنية المراجعة.
  int linkNumber(String l4, String accId, {bool move = true}) {
    final txs = move ? unlinkedTxs(l4) : const <Tx>[];
    final kept = (_unkMap()[l4]?['ktx'] is List) ? (_unkMap()[l4]!['ktx'] as List).map((x) => '$x').toSet() : <String>{};
    linkCard(l4, accId);
    var moved = 0;
    for (final t in txs) {
      if (t.acc == accId) continue;
      // معاملة اتسجّلت بالاستيراد مع «إبقاء الأرصدة»: ننقلها ونعوّض الرصيد الافتتاحي للحسابين عشان أرصدتهم ما تتغيّرش.
      if (kept.contains(t.id)) {
        final eff = (t.type == 'inc' ? 1 : -1) * t.base;
        final from = repo.account(t.acc);
        final to = repo.account(accId);
        if (from != null) {
          from.start += eff;
          repo.saveAccount(from);
        }
        if (to != null) {
          to.start -= eff;
          repo.saveAccount(to);
        }
      }
      repo.saveTx(t.clone()..acc = accId);
      moved++;
    }
    final waiting = review.where((e) => '${e['last4']}' == l4 && '${e['reason']}' == 'no_account').map((e) => '${e['id']}').toList();
    if (waiting.isNotEmpty) approveMany(waiting, accId);
    _unkRemove(l4);
    notifyListeners();
    return moved;
  }

  /// تجاهل الرقم نهائيًا (بيروح لقايمة البطاقات المتجاهلة).
  void dismissNumber(String l4) {
    addIgnoredNum(l4);
    _unkRemove(l4);
  }

  // ---------- الكلمات المتتبَّعة (قايمة واحدة مسطّحة للعرض) ----------
  List<String> get allWords {
    final seen = <String>{};
    final out = <String>[];
    for (final l in words.values) {
      for (final w in l) {
        if (seen.add(normalizeForMatch(w))) out.add(w);
      }
    }
    return out;
  }

  /// يشيل الكلمة من كل الأنواع اللي فيها.
  void removeWordEverywhere(String w) {
    final all = words;
    final n = normalizeForMatch(w);
    for (final k in all.keys) {
      all[k]!.removeWhere((x) => normalizeForMatch(x) == n);
    }
    _saveCfg(_mut()..['words'] = all);
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
  /// أثناء استيراد «إبقاء الأرصدة كما هي»: المعاملات المسجّلة مؤقتًا بتتعلّم عشان نعوّض أرصدتها لو اتنقلت لحساب تاني.
  bool _importKeep = false;
  bool _again = false;
  int _busyAt = 0;
  final Map<String, int> _fails = {};

  /// بيسمع لنداء النيتف «onQueue» (بيتبعت لحظة وصول رسالة/إشعار مالي) فيسحب الطابور فورًا من غير ما يستنى المؤقت.
  void listen() {
    if (_listening) return;
    _listening = true;
    unawaited(_pushNotifApps()); // نبعت قايمة تطبيقات الإشعارات المختارة للنيتف (لو التطبيق اتقفل ورجع)
    _ch.setMethodCallHandler((c) async {
      if (c.method == 'onQueue') unawaited(drainNative());
      return null;
    });
  }

  /// يسحب الرسائل الجديدة التي التقطها المستقبِل النيتف، ويعالجها، ثم يؤكد الاستلام (ack).
  /// رسالة بتفشل معالجتها بتتعاد لحد ٣ مرات (بعدها بتتشال عشان ما تعطّلش الطابور)، وأي سحب بيوصل أثناء الشغل بيتعاد بعده.
  Future<int> drainNative() async {
    if (!enabled && !trackNotifs) return 0;
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
          // السماح بحسب القناة: رسالة SMS ← «تتبع الرسائل»، إشعار (N:حزمة) ← «تتبع الإشعارات» + تطبيق مختار. غير كده يتأكَّد ويتشال من الطابور بلا معالجة.
          final snd = '${e['sender'] ?? ''}';
          final allowed = snd.startsWith('N:') ? (trackNotifs && notifApps.containsKey(snd.substring(2))) : enabled;
          if (!allowed) {
            ids.add(id);
            continue;
          }
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


  // ---------- استيراد الرسائل السابقة ----------
  /// يقرأ الصندوق لآخر [days] يومًا ويرجّع الرسائل اللي فيها أرقام (بدون رموز التحقق) — لسه مفيش حاجة اتسجلت.
  Future<ImportPreview> previewImport({int days = 90}) async {
    String? error;
    final msgs = <Map<String, dynamic>>[];
    try {
      final since = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
      final raw = await _ch.invokeMethod<List<dynamic>>('readInbox', {'since': since, 'limit': 3000}) ?? const [];
      for (final e in raw) {
        if (e is! Map) continue;
        msgs.add({'sender': '${e['sender'] ?? ''}', 'body': '${e['body'] ?? ''}', 'ts': (e['ts'] as num?)?.toInt() ?? since});
      }
    } on PlatformException catch (e) {
      error = e.code == 'denied' ? 'لم تُمنح صلاحية قراءة الرسائل' : 'تعذّر قراءة الرسائل: ${e.message ?? e.code}';
    } on MissingPluginException {
      error = 'الاستيراد متاح على أندرويد فقط';
    }
    return ImportPreview(days: days, messages: msgs, error: error);
  }

  /// يستورد الرسائل (الأقدم أولًا) بنفس منطق التسجيل التلقائي، بدون إشعارات. [keepBalances]: يبقّي أرصدة الحسابات زي ما هي
  /// (بنعدّل الرصيد الافتتاحي بقدر أثر المعاملات المستوردة بالظبط)، وإلا الرصيد يتعاد حسابه من المعاملات.
  Future<ImportResult> runImport(
    List<Map<String, dynamic>> msgs, {
    bool keepBalances = true,
    void Function(int done, int total)? onProgress,
    bool Function()? cancelled,
  }) async {
    final before = {for (final a in repo.accList) a.id: repo.bal(a.id)};
    _importKeep = keepBalances;
    final sorted = [...msgs]..sort((a, b) => ((a['ts'] as num?) ?? 0).compareTo((b['ts'] as num?) ?? 0));
    var added = 0, skipped = 0, already = 0, review = 0, done = 0;
    for (final m in sorted) {
      if (cancelled?.call() == true) break;
      try {
        final it = await ingest('${m['sender']}', '${m['body']}', (m['ts'] as num).toInt(), autoImport: true);
        if (it == null) {
          skipped++;
        } else if (it.added) {
          added++;
        } else if (it.status == SmsStatus.registered) {
          already++;
        } else {
          review++;
        }
      } catch (e) {
        debugPrint('sms import: $e');
        skipped++;
      }
      done++;
      onProgress?.call(done, sorted.length);
      if (done % 4 == 0) await Future<void>.delayed(Duration.zero); // نسيب الواجهة تتحدّث
    }
    _importKeep = false;
    if (keepBalances && added > 0) {
      for (final a in repo.accList) {
        final b0 = before[a.id];
        if (b0 == null) continue;
        final diff = b0 - repo.bal(a.id);
        if (diff.abs() > 0.0049) {
          a.start += diff;
          repo.saveAccount(a);
        }
      }
    }
    notifyListeners();
    return ImportResult(added: added, skipped: skipped, already: already, review: review, cancelled: cancelled?.call() == true, total: sorted.length, unlinked: unlinked.length);
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
  Future<ScanItem?> ingest(String sender, String body, int receivedMs, {bool manual = false, bool autoImport = false}) async {
    // بطاقة/حساب أو نص طلب المستخدم يتجاهله: يُستبعد بصمت ولا يُحفظ منه أي شيء.
    if (_isIgnored(body)) return null;
    final p = parseSms(sender, body, receivedMs, config);
    if (p.verdict == SmsVerdict.reject) {
      return null;
    }
    final bk = 'b|${bodyFingerprint(sender, body)}';
    final sk = semanticKey(p);
    // 0) نفس الرقم المرجعي اتسجّل/اتشاف قبل كده ← مفيش تسجيل تاني (حتى لو الفحص اتعاد أو الرسالة وصلت بصيغة تانية).
    if (_refSeen(p)) {
      return ScanItem(sender: sender, body: body, ts: p.ts, status: SmsStatus.registered, parsed: p);
    }
    // 1) مسجّلة فعلًا كمعاملة؟
    final tx = _registeredTx(bk, sk, p, body);
    if (tx != null) {
      return ScanItem(sender: sender, body: body, ts: p.ts, status: SmsStatus.registered, parsed: p, txId: tx.id);
    }
    // 2) موجودة بالفعل في المراجعة؟
    for (final e in review) {
      final ets = (e['ts'] as num?)?.toInt();
      final same = (e['bk'] == bk && _near(ets, p.ts)) || (e['bk'] == null && e['body'] == body) || (e['sk'] == sk && (p.ref.isNotEmpty || _near3(ets, p.ts)));
      if (same) {
        return ScanItem(sender: sender, body: body, ts: p.ts, status: SmsStatus.pending, parsed: p, reviewId: '${e['id']}');
      }
    }
    // 2.4) دفتر العمليات الأخيرة: نفس العملية من قناة تانية، أو نسخة عربي/إنجليزي من نفس الرسالة.
    if (_ledgerDup(p, sender, p.merchant, body)) {
      return ScanItem(sender: sender, body: body, ts: p.ts, status: SmsStatus.registered, parsed: p);
    }
    // 2.5) نفس العملية وصلت من قناة تانية (إشعار إنستاباي ↔ رسالة البنك): متتكررش.
    final xTx = _crossDupTx(p, p.merchant);
    if (xTx != null) {
      return ScanItem(sender: sender, body: body, ts: p.ts, status: SmsStatus.registered, parsed: p, txId: xTx.id);
    }
    final xRv = _crossDupReview(p, p.merchant);
    if (xRv != null) {
      return ScanItem(sender: sender, body: body, ts: p.ts, status: SmsStatus.pending, parsed: p, reviewId: '${xRv['id']}');
    }
    // 3) تجاهلها المستخدم قبل كده: لا تظهر تاني أبدًا (استقبال لحظي أو فحص أو تحديث).
    final ign = _ign();
    final igAt = ign[bk];
    if (ign.containsKey('$bk|${p.ts}') || (igAt != null && DateTime.now().millisecondsSinceEpoch - igAt < 24 * 3600 * 1000)) {
      return null;
    }
    // ---------- تحديد الحساب ----------
    // الأساس رقم البطاقة/الحساب الظاهر في الرسالة: مطابق لحساب ← يتسجّل فيه. رقم غريب ← حسابك الافتراضي مؤقتًا + نطلب منك تربطه.
    final isN = sender.startsWith('N:');
    final appCfg = isN ? notifApps[sender.substring(2)] : null;
    final appAcc = (appCfg?['acc'] ?? '');
    var acc = p.accId;
    if (acc.isEmpty) acc = resolveAccount(p.last4, p.bankKey, sender: sender, body: body);
    // التطبيق المتتبَّع مربوط بحساب ومفيش رقم بطاقة غريب في الإشعار: يتسجّل مباشرة على حساب التطبيق (بدل تخمين بالاسم).
    if (acc.isEmpty && appAcc.isNotEmpty && repo.account(appAcc) != null && (p.last4.isEmpty || cards[p.last4] != null)) acc = appAcc;
    final byWallet = walletFor(sender, body).isNotEmpty;
    final unknownNum = p.last4.isNotEmpty && cards[p.last4] == null && !byWallet;
    if (unknownNum) acc = '';
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
    // كل المعاملات المستخرجة من الرسائل بتتحفظ الأول في المراجعة، وبعدها بتتسجّل تلقائيًا لو واضحة (أو بيراجعها المستخدم لو ملتبسة).
    final id = uid();
    final l = review;
    l.insert(0, {
      'id': id, 'sender': sender, 'body': body, 'ts': p.ts, 'kind': p.kind, 'minor': p.minor, 'cur': p.currency,
      'last4': p.last4, 'merchant': merchant, 'reason': p.reason, 'bank': p.bankKey, 'acc': acc, 'ref': p.ref, 'bk': bk, 'sk': sk, 'cat': cat,
      'verdict': p.verdict == SmsVerdict.accept ? 'accept' : 'review',
    });
    store.set(_kReview, l.take(1000).toList());
    _refAdd(p);
    _ledAdd(p, sender, merchant, body);
    // تسجيل تلقائي: الرسالة واضحة (accept أو الحساب بس هو الناقص) + AI مختلفش معاها.
    // حساب مش معروف: إشعار من تطبيق مختار ← حساب التطبيق (أو الافتراضي)، رقم غريب في الرسالة ← الافتراضي مؤقتًا.
    var target = acc;
    var fallback = false;
    final noAcc = p.verdict == SmsVerdict.review && p.reason == 'no_account';
    if ((p.verdict == SmsVerdict.accept || noAcc) && (unknownNum || (target.isEmpty && isN))) {
      target = appAcc.isNotEmpty && repo.account(appAcc) != null ? appAcc : repo.defaultAcc;
      fallback = true;
    }
    final autoOk = (p.verdict == SmsVerdict.accept || (fallback && noAcc)) && target.isNotEmpty && repo.account(target) != null;
    final loud = !manual && !autoImport;
    if ((!manual || autoImport) && autoOk && !aiDisagree) {
      final txId = approve(id, target, rememberCard: !fallback);
      var firstTime = false;
      if (fallback && unknownNum && txId != null) {
        firstTime = _unkAdd(p.last4, txId: txId, sender: sender, body: body, ts: p.ts, bank: p.bankKey);
      }
      if (loud) {
        if (firstTime) {
          _invoke<void>('notify', {'title': 'رقم جديد في رسائل البنك •••• ${p.last4}', 'body': 'اتسجّلت معاملته على حسابك الافتراضي — اضغط تربطه بالحساب الصح', 'id': (p.last4.hashCode ^ p.minor) & 0x7fffffff, 'route': 'num:${p.last4}'});
        } else if (notifyOn) {
          _invoke<void>('notify', {'title': fallback ? 'سُجّلت معاملة على الحساب الافتراضي' : 'تم تسجيل معاملة تلقائيًا', 'body': '${p.amount.toStringAsFixed(2)} ${p.currency}${merchant.isNotEmpty ? ' · $merchant' : ''}', 'id': (p.ts ^ p.minor) & 0x7fffffff, 'route': txId == null ? 'tx' : 'tx:$txId'});
        }
      }
      return ScanItem(sender: sender, body: body, ts: p.ts, status: SmsStatus.registered, parsed: p, txId: txId ?? '', added: true);
    }
    if (loud && notifyOn) _notifyReview(p, id);
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

  /// رسوم إنستاباي: بس للتحويل الصادر (xferOut) بالجنيه، ولو الخيار شغّال وحساب العملية مفعّل عليه، ورسالة البنك مش بتذكر رسوم.
  /// السحب العادي والخصم والشراء مالهمش رسوم إنستاباي. الرسوم بتتسجل كمصروف مستقل بنفس التاريخ (id = fee_<id المعاملة>).
  void _maybeInstaFee(Tx tx, String kind, String body) {
    if (kind != 'xferOut' || !InstaFee.on || tx.cur != 'EGP') return;
    if (InstaFee.bodyMentionsFee(body)) return;
    final a = repo.account(tx.acc);
    if (a == null || !a.insta) return;
    final fee = InstaFee.of(tx.amt);
    if (fee <= 0) return;
    if (repo.tx('fee_${tx.id}') != null) return;
    repo.saveTx(Tx(id: 'fee_${tx.id}', type: 'exp', amt: fee, cur: 'EGP', rate: 1, acc: tx.acc, cat: 'other', note: 'رسوم إنستاباي', ts: tx.ts, src: 'sms'));
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
    _maybeInstaFee(tx, k, '${e['body'] ?? ''}');
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


}

final SmsTracker smsTracker = SmsTracker();
