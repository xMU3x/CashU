import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../core/currency.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/store.dart';
import '../core/util.dart';

/// أنواع العمليات المتتبَّعة (بالترتيب المعتمد في التصنيف).
const kSmsKinds = <String>['purchase', 'deduct', 'atm', 'xfer_out', 'xfer_in', 'refund'];
const kSmsKindAr = {'purchase': 'شراء', 'deduct': 'خصم', 'atm': 'سحب نقدي', 'xfer_out': 'تحويل صادر', 'xfer_in': 'تحويل وارد', 'refund': 'استرداد'};

/// الكلمات الافتراضية لكل نوع.
const Map<String, List<String>> kSmsBuiltin = {
  'purchase': ['pos', 'purchased', 'purchase', 'charged', 'spent', 'payment', 'paid', 'شراء', 'عملية شراء', 'مشتريات', 'دفع', 'سداد', 'مدفوعات'],
  'deduct': ['deducted', 'debit', 'debited', 'خصم', 'تم خصم', 'مدين'],
  'atm': ['withdrawal', 'cash withdrawal', 'atm', 'withdrawn', 'سحب', 'سحب نقدي', 'صراف'],
  'xfer_out': ['sent to', 'transfer to', 'transferred', 'you sent', 'تحويل', 'تم تحويل', 'إرسال', 'أرسلت', 'حولت'],
  'xfer_in': ['credited', 'received', 'إلى حسابك', 'deposit', 'deposited', 'incoming transfer', 'استلمت', 'استلام', 'إضافة', 'إيداع', 'تحويل وارد', 'وارد', 'تم إضافة'],
  'refund': ['reversal', 'refunded', 'refund', 'canceled', 'cancelled', 'reversed', 'استرداد', 'استرجاع', 'مرتجع', 'إلغاء', 'رد مبلغ'],
};

/// كلمات تُستبعد دائمًا (للعرض فقط — التطبيق الأصلي في Kotlin).
const kSmsExcluded = ['otp', 'one time password', 'one-time password', 'verification code', 'activation code', 'security code', 'passcode', 'do not share', "don't share", 'never share', 'رمز التحقق', 'رمز التأكيد', 'رمز التفعيل', 'كود التحقق', 'كود التفعيل', 'رمز المرور', 'كلمة المرور لمرة واحدة', 'كلمة السر المؤقتة', 'الرقم السري المؤقت', 'لا تشارك', 'لا تعطي', 'لا تفصح', 'declined', 'rejected', 'failed', 'unsuccessful', 'not successful', 'insufficient', 'could not be completed', 'was not completed', 'رفض', 'مرفوضة', 'مرفوض', 'تم رفض', 'فشل', 'فشلت', 'غير ناجحة', 'لم تتم', 'لم يتم', 'رصيد غير كاف', 'الرصيد غير كافي', 'تعذر'];

/// البنوك المعروفة لقائمة الاختيار: (مفتاح المرسل، الاسم).
const kSmsBanks = <(String, String)>[
  ('cib', 'CIB'), ('nbe', 'NBE — الأهلي'), ('banquemisr', 'بنك مصر'), ('bdc', 'بنك القاهرة'), ('qnb', 'QNB'), ('alexbank', 'Alexbank'),
  ('hsbc', 'HSBC'), ('aaib', 'AAIB'), ('adib', 'ADIB'), ('faisal', 'بنك فيصل'), ('cae', 'كريدي أجريكول'), ('enbd', 'Emirates NBD'),
  ('mashreq', 'Mashreq'), ('nbk', 'NBK'), ('saib', 'SAIB'), ('aib', 'AIB'), ('abk', 'ABK'), ('vodafonecash', 'Vodafone Cash'),
  ('etisalatcash', 'e& cash'), ('orangecash', 'Orange Cash'), ('wepay', 'WE Pay'), ('instapay', 'InstaPay'), ('fawry', 'Fawry'),
  ('valu', 'valU'), ('meeza', 'Meeza'), ('telda', 'Telda'),
];

class SmsCard {
  String last4, bank, acc;
  bool auto;
  SmsCard({required this.last4, this.bank = '', required this.acc, this.auto = true});
  Map<String, dynamic> toJson() => {'last4': last4, 'bank': bank, 'acc': acc, 'auto': auto};
  factory SmsCard.fromJson(Map j) => SmsCard(last4: '${j['last4'] ?? ''}', bank: '${j['bank'] ?? ''}', acc: '${j['acc'] ?? ''}', auto: j['auto'] is bool ? j['auto'] as bool : true);
}

class SmsWord {
  final String text, kind;
  final bool custom;
  const SmsWord(this.text, this.kind, this.custom);
}

String _guessCat(String merchant, String kind) {
  final m = merchant.toLowerCase();
  bool has(String re) => RegExp(re).hasMatch(m);
  if (kind == 'xfer_in') return 'other_i';
  if (has(r'مطعم|restaurant|cafe|coffee|kfc|mcdonald|burger|pizza|talabat|elmenus|بقال|market|carrefour|spinneys|hyper|kazyon|seoudi|وجبه|مخبز')) return 'food';
  if (has(r'uber|careem|indrive|بنزين|petrol|fuel|total|mobil|wataniya|chillout|مترو|metro|تاكسي|garage|parking')) return 'transport';
  if (has(r'vodafone|orange|etisalat|\bwe\b|كهرباء|electric|water|gas|fawry|internet|فاتوره|bill|اتصالات')) return 'bills';
  if (has(r'pharmacy|صيدل|hospital|clinic|عياد|seif|ezaby|دكتور|مستشفى|lab')) return 'health';
  if (has(r'amazon|noon|jumia|zara|h&m|mall|store|متجر|ikea|decathlon|b\.tech|btech|2b')) return 'shop';
  if (has(r'school|university|مدرس|جامع|udemy|course|كورس')) return 'edu';
  if (has(r'netflix|spotify|cinema|vox|shahid|steam|playstation|xbox|سينما')) return 'fun';
  return 'other';
}

/// خدمة تتبع رسائل البنك: تستقبل المرشّحين من Kotlin وتقرر التسجيل/المراجعة وتحفظ السجل.
class SmsService extends ChangeNotifier {
  static const _m = MethodChannel('cashu/sms');
  static const _e = EventChannel('cashu/sms_events');
  StreamSubscription? _sub;
  bool _started = false;
  Map<String, bool> perms = {'receive': false, 'read': false, 'notif': false};

  bool get supported => !kIsWeb && Platform.isAndroid;
  bool get enabled => S.flag('smsOn');

  // ---------- إعدادات محلية (لا تُزامَن) ----------
  Map<String, dynamic> get _cfg => store.getMap('sms_cfg');
  void _saveCfg(Map<String, dynamic> m) {
    store.set('sms_cfg', m);
    pushConfig();
    notifyListeners();
  }

  List<String> get disabledWords => List<String>.from((_cfg['off'] as List?) ?? const []);
  List<SmsWord> get customWords => [
        for (final w in ((_cfg['custom'] as List?) ?? const []))
          if (w is Map) SmsWord('${w['t']}', '${w['k']}', true)
      ];

  List<SmsWord> words(String kind) {
    final off = disabledWords;
    return [
      for (final t in kSmsBuiltin[kind] ?? const <String>[])
        if (!off.contains('$kind:$t')) SmsWord(t, kind, false),
      ...customWords.where((w) => w.kind == kind),
    ];
  }

  int get wordCount => kSmsKinds.fold(0, (s, k) => s + words(k).length);

  void addWord(String text, String kind) {
    final t = text.trim();
    if (t.isEmpty) return;
    final c = _cfg;
    final l = List<dynamic>.from((c['custom'] as List?) ?? const []);
    l.removeWhere((w) => w is Map && w['t'] == t);
    l.add({'t': t, 'k': kind});
    c['custom'] = l;
    _saveCfg(c);
  }

  void removeWord(SmsWord w) {
    final c = _cfg;
    if (w.custom) {
      final l = List<dynamic>.from((c['custom'] as List?) ?? const []);
      l.removeWhere((x) => x is Map && x['t'] == w.text && x['k'] == w.kind);
      c['custom'] = l;
    } else {
      final off = List<dynamic>.from((c['off'] as List?) ?? const []);
      off.add('${w.kind}:${w.text}');
      c['off'] = off;
    }
    _saveCfg(c);
  }

  void moveWord(SmsWord w, String toKind) {
    removeWord(w);
    addWord(w.text, toKind);
  }

  List<SmsCard> get cards => [for (final j in ((_cfg['cards'] as List?) ?? const [])) if (j is Map) SmsCard.fromJson(j)];
  void saveCards(List<SmsCard> l) {
    final c = _cfg;
    c['cards'] = [for (final x in l) x.toJson()];
    _saveCfg(c);
  }

  // ---------- ذكاء اصطناعي (محلي، لا يُزامَن) ----------
  Map<String, dynamic> get ai => store.getMap('sms_ai');
  void saveAi(Map<String, dynamic> m) {
    store.set('sms_ai', m);
    notifyListeners();
  }

  bool get aiReady => '${ai['key'] ?? ''}'.trim().isNotEmpty;

  // ---------- السجل ----------
  List<Map<String, dynamic>> get log => [for (final j in ((store.get('sms_log') as List?) ?? const [])) if (j is Map) Map<String, dynamic>.from(j)];
  void _saveLog(List<Map<String, dynamic>> l) {
    if (l.length > 400) l.removeRange(0, l.length - 400);
    store.set('sms_log', l);
    notifyListeners();
  }

  List<Map<String, dynamic>> byStatus(String s) => log.where((e) => e['status'] == s).toList().reversed.toList();
  int get reviewCount => log.where((e) => e['status'] == 'review').length;

  void clearLog() => _saveLog([]);

  // ---------- دورة الحياة ----------
  Future<void> start() async {
    if (_started || !supported) return;
    _started = true;
    try {
      _sub = _e.receiveBroadcastStream().listen((j) => _onJson('$j'), onError: (_) {});
      await refreshPerms();
      await pushConfig();
      await drain();
    } catch (e) {
      debugPrint('sms start: $e');
    }
  }

  Future<void> refreshPerms() async {
    if (!supported) return;
    try {
      final r = await _m.invokeMethod<Map>('perms');
      if (r != null) perms = {for (final e in r.entries) '${e.key}': e.value == true};
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> requestPerms() async {
    if (!supported) return false;
    try {
      final r = await _m.invokeMethod<Map>('requestPerms');
      if (r != null) perms = {for (final e in r.entries) '${e.key}': e.value == true};
      notifyListeners();
    } catch (_) {}
    return perms['receive'] == true;
  }

  Future<void> pushConfig() async {
    if (!supported) return;
    final w = <Map<String, String>>[];
    for (final k in kSmsKinds) {
      for (final x in words(k)) {
        w.add({'t': x.text, 'k': k});
      }
    }
    final cfg = {
      'enabled': enabled,
      'auto': S.flag('smsAuto', true),
      'notify': S.flag('smsNotify', true),
      'lang': S.str('lang', 'ar'),
      'words': w,
      'cards': [for (final c in cards) c.toJson()],
    };
    try {
      await _m.invokeMethod('setConfig', jsonEncode(cfg));
    } catch (_) {}
  }

  Future<void> setEnabled(bool v) async {
    S.put('smsOn', v);
    if (v) await requestPerms();
    await pushConfig();
    if (v) await drain();
    notifyListeners();
  }

  Future<void> drain() async {
    if (!supported) return;
    try {
      final s = await _m.invokeMethod<String>('drain');
      if (s == null || s.isEmpty) return;
      final l = jsonDecode(s);
      if (l is List) {
        for (final c in l) {
          if (c is Map) await handle(Map<String, dynamic>.from(c));
        }
      }
    } catch (e) {
      debugPrint('sms drain: $e');
    }
  }

  void _onJson(String j) {
    try {
      final c = jsonDecode(j);
      if (c is Map) handle(Map<String, dynamic>.from(c));
    } catch (_) {}
  }

  /// تحليل نص يدويًا (للتجربة). null = ستُتجاهل.
  Future<Map<String, dynamic>?> parse(String sender, String body) async {
    if (!supported) return null;
    try {
      final s = await _m.invokeMethod<String>('parse', {'sender': sender, 'body': body});
      if (s == null || s.isEmpty) return null;
      return Map<String, dynamic>.from(jsonDecode(s) as Map);
    } catch (_) {
      return null;
    }
  }

  /// مسح الرسائل القديمة. يعيد عدد الرسائل الجديدة التي دخلت السجل.
  Future<int> scanInbox(int days) async {
    if (!supported) return 0;
    if (perms['read'] != true) await requestPerms();
    if (perms['read'] != true) return -1;
    try {
      final s = await _m.invokeMethod<String>('scanInbox', days);
      final l = jsonDecode(s ?? '[]');
      var n = 0;
      if (l is List) {
        for (final c in l) {
          if (c is Map) {
            await handle(Map<String, dynamic>.from(c), quiet: true);
            n++;
          }
        }
      }
      return n;
    } catch (_) {
      return 0;
    }
  }

  // ---------- المعالجة ----------
  Future<void> handle(Map<String, dynamic> c, {bool quiet = false}) async {
    final id = '${c['id']}';
    final l = log;
    if (l.any((e) => e['id'] == id)) return;
    final status = '${c['status']}';
    final e = Map<String, dynamic>.from(c);
    e.remove('body');
    e['text'] = '${c['body'] ?? ''}';
    if (status == 'auto') {
      final t = _record(e);
      e['status'] = t == null ? 'review' : 'recorded';
      if (t != null) e['tx'] = t.id;
    }
    l.add(e);
    _saveLog(l);
    if (e['status'] == 'review' && S.flag('smsAiAuto') && aiReady) {
      await aiRefine('$id');
    }
  }

  Account? _acc(String id) {
    for (final a in repo.accList) {
      if (a.id == id) return a;
    }
    return null;
  }

  Tx? _record(Map<String, dynamic> e, {String? accId}) {
    final accKey = accId ?? '${e['acc'] ?? ''}';
    final a = _acc(accKey);
    final amt = (e['amt'] is num) ? (e['amt'] as num).toDouble() : 0.0;
    if (a == null || amt <= 0) return null;
    final kind = '${e['kind']}';
    final merchant = '${e['merchant'] ?? ''}'.trim();
    final cur = '${e['cur'] ?? 'EGP'}'.isEmpty ? 'EGP' : '${e['cur']}';
    final ts = (e['ts'] is num) ? (e['ts'] as num).toInt() : DateTime.now().millisecondsSinceEpoch;
    double rate = 1;
    try {
      rate = cur == S.cur ? 1 : rates.rate(cur, S.cur);
    } catch (_) {}
    var type = 'exp', cat = _guessCat(merchant, kind), note = merchant, to = '';
    switch (kind) {
      case 'atm':
        note = merchant.isEmpty ? 'سحب نقدي' : merchant;
        cat = 'other';
        Account? cash;
        for (final x in repo.accList) {
          if (x.kind == 'cash' && x.id != a.id) {
            cash = x;
            break;
          }
        }
        if (cash != null) {
          type = 'xfer';
          to = cash.id;
          cat = '';
        }
        break;
      case 'xfer_out':
        note = merchant.isEmpty ? 'تحويل صادر' : merchant;
        cat = 'other';
        break;
      case 'xfer_in':
        type = 'inc';
        note = merchant.isEmpty ? 'تحويل وارد' : merchant;
        cat = 'other_i';
        break;
      case 'refund':
        type = 'inc';
        note = merchant.isEmpty ? 'استرداد' : 'استرداد: $merchant';
        cat = 'other_i';
        break;
      default:
        if (note.isEmpty) note = '${e['bankName'] ?? ''}'.isEmpty ? 'عملية بنكية' : '${e['bankName']}';
    }
    final t = Tx(id: uid(), type: type, amt: amt, cur: cur, rate: rate, acc: a.id, to: to, cat: cat, note: note, ts: ts, src: 'sms');
    repo.saveTx(t);
    return t;
  }

  /// تسجيل عملية من قائمة المراجعة (يمكن تحديد الحساب/النوع/المبلغ).
  bool confirm(String id, {String? accId, String? kind, double? amt}) {
    final l = log;
    final i = l.indexWhere((e) => e['id'] == id);
    if (i < 0) return false;
    final e = l[i];
    if (kind != null) e['kind'] = kind;
    if (amt != null) e['amt'] = amt;
    final t = _record(e, accId: accId);
    if (t == null) return false;
    e['status'] = 'recorded';
    e['tx'] = t.id;
    _saveLog(l);
    return true;
  }

  void dismiss(String id) {
    final l = log;
    final i = l.indexWhere((e) => e['id'] == id);
    if (i < 0) return;
    l[i]['status'] = 'ignored';
    _saveLog(l);
  }

  void undoRecorded(String id) {
    final l = log;
    final i = l.indexWhere((e) => e['id'] == id);
    if (i < 0) return;
    final tx = '${l[i]['tx'] ?? ''}';
    if (tx.isNotEmpty) repo.delTx(tx);
    l[i]['status'] = 'review';
    l[i].remove('tx');
    _saveLog(l);
  }

  // ---------- الذكاء الاصطناعي (زر التحليل) ----------
  static const _prompt = 'أنت محلّل رسائل بنكية مصرية. من نص الرسالة استخرج JSON فقط بدون أي شرح بالشكل: '
      '{"kind":"purchase|deduct|atm|xfer_out|xfer_in|refund|none","amount":number,"currency":"EGP","last4":"آخر 4 أرقام للبطاقة أو الحساب أو فارغ","merchant":"اسم التاجر أو المستلم أو فارغ"}. '
      'تجاهل الرصيد المتاح. kind=none إن لم تكن عملية مالية فعلية (OTP أو عملية فاشلة أو دعاية).';

  /// يرسل نص الرسالة فقط لمزوّد الذكاء الاصطناعي الذي ضبطه المستخدم. null عند الفشل.
  Future<Map<String, dynamic>?> aiParse(String body) async {
    final a = ai;
    final key = '${a['key'] ?? ''}'.trim();
    if (key.isEmpty) return null;
    final prov = '${a['prov'] ?? 'gemini'}';
    String? text;
    try {
      if (prov == 'gemini') {
        final model = '${a['model'] ?? ''}'.isEmpty ? 'gemini-2.0-flash' : '${a['model']}';
        final r = await http.post(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'),
          headers: {'Content-Type': 'application/json', 'x-goog-api-key': key},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': '$_prompt\n\nالرسالة:\n$body'}
                ]
              }
            ],
            'generationConfig': {'responseMimeType': 'application/json', 'temperature': 0}
          }),
        ).timeout(const Duration(seconds: 25));
        if (r.statusCode != 200) return null;
        text = jsonDecode(utf8.decode(r.bodyBytes))['candidates'][0]['content']['parts'][0]['text'] as String?;
      } else if (prov == 'claude') {
        final model = '${a['model'] ?? ''}'.isEmpty ? 'claude-haiku-4-5' : '${a['model']}';
        final r = await http.post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {'Content-Type': 'application/json', 'x-api-key': key, 'anthropic-version': '2023-06-01'},
          body: jsonEncode({
            'model': model,
            'max_tokens': 300,
            'system': _prompt,
            'messages': [
              {'role': 'user', 'content': body}
            ]
          }),
        ).timeout(const Duration(seconds: 25));
        if (r.statusCode != 200) return null;
        text = jsonDecode(utf8.decode(r.bodyBytes))['content'][0]['text'] as String?;
      } else {
        final base = '${a['url'] ?? ''}'.isEmpty ? 'https://api.openai.com/v1' : '${a['url']}'.replaceAll(RegExp(r'/+$'), '');
        final model = '${a['model'] ?? ''}'.isEmpty ? 'gpt-4o-mini' : '${a['model']}';
        final r = await http.post(
          Uri.parse('$base/chat/completions'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $key'},
          body: jsonEncode({
            'model': model,
            'temperature': 0,
            'messages': [
              {'role': 'system', 'content': _prompt},
              {'role': 'user', 'content': body}
            ]
          }),
        ).timeout(const Duration(seconds: 25));
        if (r.statusCode != 200) return null;
        text = jsonDecode(utf8.decode(r.bodyBytes))['choices'][0]['message']['content'] as String?;
      }
      if (text == null) return null;
      final m = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (m == null) return null;
      final j = jsonDecode(m.group(0)!);
      return j is Map ? Map<String, dynamic>.from(j) : null;
    } catch (e) {
      debugPrint('ai parse: $e');
      return null;
    }
  }

  /// يحسّن مرشّحًا في المراجعة بالذكاء الاصطناعي. يعيد true عند النجاح.
  Future<bool> aiRefine(String id) async {
    final l = log;
    final i = l.indexWhere((e) => e['id'] == id);
    if (i < 0) return false;
    final e = l[i];
    final r = await aiParse('${e['text'] ?? ''}');
    if (r == null) return false;
    final kind = '${r['kind'] ?? 'none'}';
    if (kind == 'none') {
      e['status'] = 'excluded';
      e['reason'] = 'ai_none';
      _saveLog(l);
      return true;
    }
    if (!kSmsKinds.contains(kind)) return false;
    e['kind'] = kind;
    final amt = r['amount'];
    if (amt is num && amt > 0) e['amt'] = amt.toDouble();
    if ('${r['currency'] ?? ''}'.isNotEmpty) e['cur'] = '${r['currency']}'.toUpperCase();
    final l4 = '${r['last4'] ?? ''}'.replaceAll(RegExp(r'\D'), '');
    if (l4.length == 4) e['last4'] = l4;
    e['merchant'] = '${r['merchant'] ?? e['merchant'] ?? ''}';
    e['ai'] = true;
    for (final c in cards) {
      if (c.last4 == '${e['last4']}') {
        e['acc'] = c.acc;
        break;
      }
    }
    final auto = S.flag('smsAiAuto') && '${e['acc'] ?? ''}'.isNotEmpty && '${e['cur']}' == 'EGP' && kind != 'refund';
    if (auto) {
      final t = _record(e);
      if (t != null) {
        e['status'] = 'recorded';
        e['tx'] = t.id;
      }
    }
    _saveLog(l);
    return true;
  }
}

final SmsService smsService = SmsService();
