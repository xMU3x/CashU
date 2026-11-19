import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:material_ui/material_ui.dart' hide Text;
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;
import 'loc_text.dart';
import '../core/extras.dart' show extras;
import '../core/i18n.dart' show applyDigits;
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/store.dart';
import '../core/sync.dart';
import '../core/util.dart';
import '../pages/acc_tx.dart' show AccountTxPage;
import '../pages/assets_page.dart';
import '../pages/goals_page.dart';
import '../pages/loans_page.dart';
import '../pages/subs_page.dart';
import 'anim.dart';
import 'ios.dart';
import 'motion.dart';
import 'sheets.dart';
import 'theme.dart';
import 'widgets.dart';

// ======================= حسّاب — مساعد CashU الذكي (صفحة كاملة) =======================
// • الزر العائم (AiFab) بيفتح صفحة كاملة: شاشة بداية (أسئلة مقترحة + آخر المحادثات) ثم المحادثة.
// • الرد من Supabase Edge Function `ai-chat` (مفاتيح المزودين على السيرفر فقط — supabase/functions/ai-chat).
//   الرد: {reply, actions[], panel?, suggestions?} — panel وsuggestions اختياريين (لو الدالة قديمة بيشتغل عادي).
// • كل الأرقام اللي في البطاقات (panel) بتتحسب من بيانات التطبيق المبعوتة في context (PANELS_JSON) — مش من الموديل.
// • المحادثات متخزنة على الجهاز فقط (مفتاح محلي مش في kSyncKeys → ما بيترفعش للسيرفر).
// • أي أمر بيتنفّذ بس بعد ما تضغط «نفّذ واحفظ». مفيش حذف بيانات ولا إعدادات ولا نسخ احتياطي من المساعد.
// • «تراجع» بيعكس آخر دفعة اتنفذت (معاملات/هدف/سلفة) — الحذف هنا بيروح لسلة المحذوفات زي أي معاملة.

const int _kCtxMax = 6800; // الحد الأقصى لحجم context (السيرفر بيقص عند 7000)
const String _kStoreKey = 'ai_chats';

// ---------------------------------------------------------------------------------------------
// نماذج البيانات (قابلة للحفظ كـ JSON)
// ---------------------------------------------------------------------------------------------
double _dbl(dynamic v) => v is num ? v.toDouble() : (double.tryParse(normDigits('$v').replaceAll(',', '.')) ?? 0);
Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

class _Act {
  final String name;
  final Map<String, dynamic> args;
  String state = 'pending'; // pending | done | skipped | failed | undone
  String result = '';
  String accId = ''; // الحساب المختار للتسجيل (فاضي = الافتراضي) — قابل للتغيير قبل التنفيذ
  List<String> ids = []; // معرّفات اللي اتعمل (للتراجع)
  int entryTs = 0;
  double entryAmt = 0;
  _Act(this.name, this.args);

  bool get isNav => name == 'open_page';
  bool get isTx => name == 'add_expense' || name == 'add_income';

  Map<String, dynamic> toJson() => {'n': name, 'a': args, 's': state, 'r': result, 'acc': accId, 'ids': ids, 'ets': entryTs, 'eamt': entryAmt};
  factory _Act.fromJson(Map<String, dynamic> j) {
    final a = _Act('${j['n']}', _map(j['a']));
    a.state = '${j['s'] ?? 'pending'}';
    a.result = '${j['r'] ?? ''}';
    a.accId = '${j['acc'] ?? ''}';
    a.ids = [for (final x in (j['ids'] is List ? j['ids'] as List : const [])) '$x'];
    a.entryTs = j['ets'] is num ? (j['ets'] as num).toInt() : 0;
    a.entryAmt = _dbl(j['eamt']);
    return a;
  }
}

class _Msg {
  final String id;
  final bool user;
  final String text;
  final int ts;
  final List<_Act> acts;
  final Map<String, dynamic>? panel;
  final List<String> suggestions;
  int rating = 0; // 1 = 👍 · -1 = 👎
  bool err = false; // رسالة خطأ (عليها زر «حاول تاني»)
  _Msg(this.user, this.text, {List<_Act>? acts, this.panel, List<String>? suggestions, int? ts, String? id})
      : id = id ?? uid(),
        ts = ts ?? DateTime.now().millisecondsSinceEpoch,
        acts = acts ?? [],
        suggestions = suggestions ?? [];

  Map<String, dynamic> toJson() => {
        'id': id, 'u': user, 't': text, 'ts': ts, 'rt': rating, if (err) 'e': true,
        if (acts.isNotEmpty) 'acts': [for (final a in acts) a.toJson()],
        if (panel != null) 'panel': panel,
        if (suggestions.isNotEmpty) 'sg': suggestions,
      };
  factory _Msg.fromJson(Map<String, dynamic> j) {
    final m = _Msg(
      j['u'] == true, '${j['t'] ?? ''}',
      id: '${j['id'] ?? uid()}', ts: j['ts'] is num ? (j['ts'] as num).toInt() : null,
      acts: [for (final x in (j['acts'] is List ? j['acts'] as List : const [])) if (x is Map) _Act.fromJson(Map<String, dynamic>.from(x))],
      panel: j['panel'] is Map ? Map<String, dynamic>.from(j['panel'] as Map) : null,
      suggestions: [for (final x in (j['sg'] is List ? j['sg'] as List : const [])) '$x'],
    );
    m.rating = j['rt'] is num ? (j['rt'] as num).toInt() : 0;
    m.err = j['e'] == true;
    return m;
  }
}

class _Chat {
  final String id;
  String title;
  int ts;
  final List<_Msg> msgs;
  _Chat(this.id, this.title, {int? ts, List<_Msg>? msgs})
      : ts = ts ?? DateTime.now().millisecondsSinceEpoch,
        msgs = msgs ?? [];
  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'ts': ts,
        'msgs': [for (final m in msgs.skip(math.max(0, msgs.length - 80))) m.toJson()],
      };
  factory _Chat.fromJson(Map<String, dynamic> j) => _Chat(
        '${j['id'] ?? uid()}', '${j['title'] ?? ''}',
        ts: j['ts'] is num ? (j['ts'] as num).toInt() : null,
        msgs: [for (final x in (j['msgs'] is List ? j['msgs'] as List : const [])) if (x is Map) _Msg.fromJson(Map<String, dynamic>.from(x))],
      );
}

// ---------------------------------------------------------------------------------------------
// تخزين المحادثات على الجهاز
// ---------------------------------------------------------------------------------------------
final List<_Chat> _chats = [];
bool _chatsLoaded = false;

void _loadChats() {
  if (_chatsLoaded) return;
  _chatsLoaded = true;
  try {
    final raw = store.get(_kStoreKey);
    if (raw is! List) return;
    for (final x in raw) {
      if (x is Map) {
        try {
          _chats.add(_Chat.fromJson(Map<String, dynamic>.from(x)));
        } catch (_) {/* محادثة تالفة: نتخطّاها */}
      }
    }
    _chats.sort((a, b) => b.ts.compareTo(a.ts));
  } catch (_) {/* التخزين مش جاهز: نبدأ فاضي */}
}

void _saveChats() {
  _chats.sort((a, b) => b.ts.compareTo(a.ts));
  while (_chats.length > 40) {
    _chats.removeLast();
  }
  try {
    store.set(_kStoreKey, [for (final c in _chats) c.toJson()], quiet: true);
  } catch (_) {/* best effort */}
}

// ---------------------------------------------------------------------------------------------
// فتح الصفحة + الزر العائم
// ---------------------------------------------------------------------------------------------
bool _chatOpen = false;
final ValueNotifier<bool> _aiPageOpen = ValueNotifier<bool>(false);

/// يفتح صفحة حسّاب كاملة. [prompt] لو اتبعت بيتكتب في خانة الرسالة (ما بيتبعتش لوحده).
Future<void> openAiChat(BuildContext context, {String? prompt}) async {
  if (_chatOpen) return;
  _chatOpen = true;
  _aiPageOpen.value = true;
  try {
    await Navigator.of(context).push<void>(flowRoute(_AiPage(prefill: prompt)));
  } finally {
    _chatOpen = false;
    _aiPageOpen.value = false;
  }
}

/// الزر العائم الصغير. بيتحط مرة واحدة فوق كل الصفحات (app.dart) وبيختفي وصفحة حسّاب مفتوحة.
class AiFab extends StatelessWidget {
  final GlobalKey<NavigatorState> navKey;
  const AiFab({super.key, required this.navKey});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final mq = MediaQuery.of(context);
    _navKey = navKey;
    return ValueListenableBuilder<bool>(
      valueListenable: _aiPageOpen,
      builder: (c, open, _) {
        if (open || mq.viewInsets.bottom > 0) return const SizedBox.shrink(); // مخفي والكيبورد/الصفحة مفتوحين
        return PositionedDirectional(
          start: 14,
          bottom: 92 + mq.padding.bottom,
          child: Semantics(
            button: true,
            label: 'المساعد الذكي',
            child: Tap(
              scale: .92,
              onTap: () {
                final ctx = navKey.currentContext;
                if (ctx != null) openAiChat(ctx);
              },
              child: ClipOval(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: p.card.withValues(alpha: .82), shape: BoxShape.circle, border: Border.all(color: p.acc.withValues(alpha: .55)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 12, offset: const Offset(0, 4))]),
                    child: Icon(Icons.auto_awesome_rounded, color: p.acc, size: 22),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------------------------
// السياق المبعوت للمساعد (مختصر، ≤ ٦٨٠٠ حرف)
// ---------------------------------------------------------------------------------------------
double _r2(double v) => (v * 100).roundToDouble() / 100;
String _ymd(DateTime d) => d.toIso8601String().substring(0, 10);

Map<String, dynamic> _panelsJson(DateTime now) {
  final y = now.year, m = now.month;
  final py = m == 1 ? y - 1 : y, pm = m == 1 ? 12 : m - 1;
  final upto = now.day, pUpto = math.min(upto, daysIn(py, pm));
  final all = repo.allTx;
  bool isExp(Tx t) => t.type == 'exp' && t.xf.isEmpty;
  bool isInc(Tx t) => t.type == 'inc' && t.xf.isEmpty;
  Map<String, dynamic> sum(bool Function(Tx) kind, bool Function(DateTime) inRange, String label) {
    var a = 0.0;
    var n = 0;
    for (final t in all) {
      if (kind(t) && inRange(t.date)) {
        a += t.base;
        n++;
      }
    }
    return {'label': label, 'amt': _r2(a), 'n': n};
  }

  bool monthTo(DateTime d, int yy, int mm, int day) => d.year == yy && d.month == mm && d.day <= day;
  final today = DateTime(now.year, now.month, now.day);
  bool week(DateTime d, int fromDaysAgo, int toDaysAgo) {
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    return diff >= toDaysAgo && diff <= fromDaysAgo;
  }

  final curLbl = '1–$upto ${kMonths[m - 1]}', prevLbl = '1–$pUpto ${kMonths[pm - 1]}';
  Map<String, dynamic> brk(int yy, int mm, String title, String label) {
    final cats = repo.byCat(yy, mm);
    final total = cats.fold(0.0, (s, e) => s + e.value);
    final n = repo.inMonth(yy, mm).where(isExp).length;
    return {
      'title': title, 'label': label, 'total': _r2(total), 'n': n,
      'items': [for (final e in cats.take(8)) {'cat': e.key, 'name': catOf(e.key).name, 'amt': _r2(e.value)}],
    };
  }

  return {
    'cmp': {
      'spent_month': {'metric': 'spent', 'title': 'إنفاقك', 'cur': sum(isExp, (d) => monthTo(d, y, m, upto), curLbl), 'prev': sum(isExp, (d) => monthTo(d, py, pm, pUpto), prevLbl)},
      'income_month': {'metric': 'income', 'title': 'دخلك', 'cur': sum(isInc, (d) => monthTo(d, y, m, upto), curLbl), 'prev': sum(isInc, (d) => monthTo(d, py, pm, pUpto), prevLbl)},
      'spent_week': {'metric': 'spent', 'title': 'إنفاقك الأسبوعي', 'cur': sum(isExp, (d) => week(d, 6, 0), 'آخر 7 أيام'), 'prev': sum(isExp, (d) => week(d, 13, 7), 'الـ 7 أيام قبلها')},
    },
    'brk': {
      'month': brk(y, m, 'تفصيل مصروفك', kMonths[m - 1]),
      'last_month': brk(py, pm, 'تفصيل مصروف الشهر الماضي', kMonths[pm - 1]),
    },
  };
}

String _buildContext() {
  final now = DateTime.now();
  final y = now.year, m = now.month;
  final py = m == 1 ? y - 1 : y, pm = m == 1 ? 12 : m - 1;
  final head = <String>[
    'today=${_ymd(now)}; currency=${S.cur}',
    'PANELS_JSON=${jsonEncode(_panelsJson(now))}', // لازم أول السياق: السيرفر بيحسب منه أرقام البطاقات
  ];
  final body = <String>[];
  body.add('ACCOUNTS (id|name|kind|balance):');
  for (final a in repo.accList.take(30)) {
    body.add('${a.id}|${a.name}|${a.kind}|${fixed2(repo.bal(a.id))}');
  }
  body.add('SPENT_THIS_MONTH=${fixed2(repo.spent(y, m))}; SPENT_LAST_MONTH=${fixed2(repo.spent(py, pm))}; INCOME_THIS_MONTH=${fixed2(repo.income(y, m))}');
  // آخر راتب (لتقدير ميعاد الراتب القادم)
  for (final t in repo.allTx) {
    if (t.type == 'inc' && t.cat == 'salary') {
      body.add('LAST_SALARY=${_ymd(t.date)}|${fixed2(t.amt)}');
      break;
    }
  }
  // الميزانيات (كل ميزانية مرة واحدة)
  final seen = <String>{};
  final buds = <String>[];
  for (final a in repo.accList) {
    final b = repo.budgetFor(a);
    if (b.limit > 0 && seen.add(b.id)) buds.add('${b.name}|${fixed2(b.limit)}|${fixed2(repo.budgetSpent(b.id, y, m))}');
  }
  if (buds.isNotEmpty) {
    body.add('BUDGETS (name|limit|spent_this_month):');
    body.addAll(buds.take(8));
  }
  final subs = extras.subs.where((s) => s.isActive).take(15).toList();
  if (subs.isNotEmpty) {
    body.add('SUBSCRIPTIONS (name|amount|cycle|next_due|account):');
    for (final s in subs) {
      final nd = s.nextDue;
      body.add('${s.name}|${fixed2(s.amt)}|${s.cyc}|${nd == null ? '-' : _ymd(nd)}${s.overdue ? '(late)' : ''}|${repo.account(s.acc)?.name ?? ''}');
    }
  }
  final insts = extras.insts.where((i) => !i.done).take(10).toList();
  if (insts.isNotEmpty) {
    body.add('INSTALLMENTS (name|next_amount|left_total|payments_left|next_due):');
    for (final i in insts) {
      final nd = i.nextDue;
      body.add('${i.name}|${fixed2(i.nextAmt)}|${fixed2(i.left)}|${i.monthsLeft}|${nd == null ? '-' : _ymd(nd)}');
    }
  }
  final goals = repo.goalList.take(10).toList();
  if (goals.isNotEmpty) {
    body.add('GOALS (name|saved|target):');
    for (final g in goals) {
      body.add('${g.name}|${fixed2(g.saved)}|${fixed2(g.target)}');
    }
  }
  final loans = repo.loanList.where((l) => !l.settled && !l.hidden).take(10).toList();
  if (loans.isNotEmpty) {
    body.add('OPEN_DEBTS (dir owed=owed to me, owe=I owe | person | left):');
    for (final l in loans) {
      body.add('${l.dir}|${l.person}|${fixed2(l.left)}');
    }
  }
  final recent = <String>[];
  for (final t in repo.allTx.take(20)) {
    recent.add('${_ymd(t.date)}|${t.type}|${fixed2(t.amt)}|${txTitle(t)}|${repo.account(t.acc)?.name ?? ''}');
  }
  String assemble() => [...head, ...body, if (recent.isNotEmpty) 'RECENT_TX (date|type|amount|title|account):', ...recent].join('\n');
  var s = assemble();
  while (s.length > _kCtxMax && recent.isNotEmpty) {
    recent.removeLast();
    s = assemble();
  }
  if (s.length > _kCtxMax) s = s.substring(0, s.lastIndexOf('\n', _kCtxMax).clamp(0, _kCtxMax));
  return s;
}

/// سياق صغير لتحليل «اكتب اللي صرفته»: الحسابات بس.
String _accountsContext() {
  final b = StringBuffer('today=${_ymd(DateTime.now())}; currency=${S.cur}\nACCOUNTS (id|name|kind|last4):\n');
  for (final a in repo.accList.take(30)) {
    b.writeln('${a.id}|${a.name}|${a.kind}|${a.last4}');
  }
  return b.toString();
}

// ---------------------------------------------------------------------------------------------
// الموافقة الأولى + استنتاج الحساب من النص + تحليل «اكتب اللي صرفته» بالـ AI
// ---------------------------------------------------------------------------------------------
Future<bool> aiEnsureConsent(BuildContext context) async {
  if (S.flag('aiChatConsent', false)) return true;
  final ok = await confirmDialog(context, 'المساعد الذكي', 'عشان يرد ويحلّل بدقة، هيتبعت للمساعد (عن طريق السيرفر بتاعنا) ملخص من بياناتك: أسماء الحسابات وأرصدتها وآخر المعاملات والميزانيات والاشتراكات والأقساط والأهداف والديون المفتوحة — مع كل رسالة تبعتها بس. مفيش حاجة بتتنفّذ من غير ما تضغط «نفّذ».', ok: 'موافق', cancel: 'مش دلوقتي', danger: false);
  if (ok) S.put('aiChatConsent', true);
  return ok;
}

String _nz(String s) => normDigits(s).toLowerCase().replaceAll(RegExp(r'[\u064B-\u0652\u0640]'), '').replaceAll(RegExp('[أإآ]'), 'ا').replaceAll('ة', 'ه').replaceAll('ى', 'ي').trim();

String? _kindFrom(String t, List<Account> accs) {
  String? firstOf(String kind) {
    for (final a in accs) {
      if (a.kind == kind) return a.id;
    }
    return null;
  }

  if (RegExp(r'فودافون|vodafone|اتصالات|etisalat|اورنج|orange|انستا|insta|محفظ|wallet').hasMatch(t)) {
    final w = firstOf('wallet');
    if (w != null) return w;
  }
  if (RegExp(r'(^|\s)(cash|كاش|نقد|نقدي|نقدا|نقديه)(\s|$)').hasMatch(t)) {
    final c = firstOf('cash');
    if (c != null) return c;
  }
  if (RegExp(r'فيزا|visa|ماستر|master|كريدت|credit|ائتمان').hasMatch(t)) {
    final c = firstOf('credit');
    if (c != null) return c;
  }
  if (RegExp(r'ديبت|debit|مدين').hasMatch(t)) {
    final d = firstOf('debit');
    if (d != null) return d;
  }
  return null;
}

/// يرجّع id الحساب المناسب من [hint] (اللي رجّعه الـ AI: id أو اسم أو كلمة زي «كاش») أو من كلمات [line]. null = مش واضح.
/// مفيش افتراض لحساب بعينه (زي CIB): لو مفيش دليل بيرجّع null والمستخدم يختار.
String? aiResolveAccount(String hint, {String line = ''}) {
  final accs = repo.accList;
  if (accs.isEmpty) return null;
  final raw = hint.trim().toLowerCase();
  final h = _nz(hint);
  if (h.isNotEmpty) {
    for (final a in accs) {
      if (a.id.toLowerCase() == raw || _nz(a.name) == h) return a.id;
    }
    final d4 = RegExp(r'\d{4}').firstMatch(h)?.group(0);
    if (d4 != null) {
      for (final a in accs) {
        if (a.last4.isNotEmpty && a.last4 == d4) return a.id;
      }
    }
    for (final a in accs) {
      final n = _nz(a.name);
      if (n.length >= 2 && (n.contains(h) || h.contains(n))) return a.id;
    }
    final k = _kindFrom(h, accs);
    if (k != null) return k;
  }
  final l = _nz(line);
  if (l.isNotEmpty) {
    Account? best;
    for (final a in accs) {
      final n = _nz(a.name);
      if (n.length >= 2 && l.contains(n) && (best == null || n.length > _nz(best.name).length)) best = a;
    }
    if (best != null) return best.id;
    return _kindFrom(l, accs);
  }
  return null;
}

/// بند متحلّل من «اكتب اللي صرفته».
class AiEntry {
  bool inc;
  double amt;
  String cat, note, cur;
  String acc; // id الحساب ('' = لسه مش محدد)
  AiEntry({required this.inc, required this.amt, required this.cat, this.note = '', String? cur, this.acc = ''}) : cur = cur ?? S.cur;
}

/// يحلل نص حر (بند أو أكتر) بالـ AI ويرجّع البنود بحساباتها. بيرجّع null لو التحليل مش متاح (أوفلاين/مش مسجّل/دالة قديمة)
/// عشان المتصل يرجع للتحليل المحلي. لو الـ AI ما لقاش بنود بيرجّع قائمة فاضية.
Future<List<AiEntry>?> aiParseEntries(BuildContext context, String text) async {
  if (!await aiEnsureConsent(context)) return null;
  final client = sync.client;
  if (client == null || client.auth.currentSession == null) return null;
  try {
    final t = text.length > 1400 ? text.substring(0, 1400) : text;
    final res = await client.functions.invoke('ai-chat', body: {
      'mode': 'parse',
      'messages': [
        {'role': 'user', 'content': t}
      ],
      'context': _accountsContext(),
      'consent': true,
    }).timeout(const Duration(seconds: 85));
    if (res.status != 200 || res.data is! Map) return null;
    final list = (res.data as Map)['entries'];
    if (list is! List) return null; // دالة قديمة: ما بترجّعش entries
    final out = <AiEntry>[];
    for (final e in list) {
      if (e is! Map) continue;
      final amt = _dbl(e['amount']);
      if (amt <= 0) continue;
      final inc = e['type'] == 'inc';
      final note = '${e['note'] ?? ''}'.trim();
      final cat = '${e['category'] ?? ''}';
      out.add(AiEntry(
        inc: inc, amt: amt, cat: cat.isEmpty ? (inc ? 'other_i' : 'other') : cat, note: note,
        acc: aiResolveAccount('${e['account'] ?? ''}', line: note) ?? '',
      ));
    }
    return out;
  } catch (_) {
    return null;
  }
}

// ---------------------------------------------------------------------------------------------
// صفحة حسّاب
// ---------------------------------------------------------------------------------------------
const _kQuick = <(IconData, Color, String, String)>[
  (Icons.account_balance_wallet_rounded, Color(0xFFEA6A3C), 'كم أنفقت هذا الشهر؟', 'الإجمالي حتى الآن مقارنةً بالماضي.'),
  (Icons.pie_chart_rounded, Color(0xFFE59A1F), 'أين أنفق معظم أموالي؟', 'تصنيفاتك مرتبة حسب إنفاقك عليها.'),
  (Icons.event_available_rounded, Color(0xFF3FBF8A), 'هل يكفيني رصيدي حتى الراتب؟', 'رصيدك مقابل مصروفات ما تبقّى من الشهر.'),
  (Icons.autorenew_rounded, Color(0xFF6D8BFF), 'ما اشتراكاتي القادمة؟', 'مواعيد التجديد والمبالغ.'),
  (Icons.menu_book_rounded, Color(0xFF8E7CFF), 'كيف أفعّل رسائل البنك؟', 'خطوات التتبع التلقائي للرسائل.'),
];

class _AiPage extends StatefulWidget {
  final String? prefill;
  const _AiPage({this.prefill});
  @override
  State<_AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<_AiPage> {
  final input = TextEditingController();
  final scroll = ScrollController();
  _Chat? cur; // null = شاشة البداية
  String? _busyId; // id المحادثة اللي مستنية رد
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadChats();
    if (widget.prefill != null) input.text = widget.prefill!;
  }

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  bool get _busy => _busyId != null || _sending;

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: CashUMotion.small, curve: CashUMotion.curve);
      });

  // ---------------- الإرسال ----------------
  String _title(String t) {
    final s = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s.length > 40 ? '${s.substring(0, 40)}…' : s;
  }

  Future<void> _submit(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _busy) return;
    _sending = true;
    try {
      if (!await aiEnsureConsent(context)) return;
      if (!mounted) return;
      var chat = cur;
      if (chat == null) {
        chat = _Chat(uid(), _title(text));
        _chats.insert(0, chat);
        cur = chat;
      }
      chat.msgs.add(_Msg(true, text));
      chat.ts = DateTime.now().millisecondsSinceEpoch;
      input.clear();
      _saveChats();
      setState(() {});
      _toEnd();
      await _ask(chat);
    } finally {
      _sending = false;
    }
  }

  _Msg _errMsg(String t) => _Msg(false, t)..err = true;

  Future<void> _ask(_Chat chat) async {
    if (mounted) setState(() => _busyId = chat.id);
    _toEnd();
    _Msg reply;
    try {
      final client = sync.client;
      if (client == null || client.auth.currentSession == null) {
        reply = _Msg(false, 'سجّل دخولك الأول عشان أقدر أرد عليك.');
      } else {
        final hist = [
          for (final m in chat.msgs.skip(math.max(0, chat.msgs.length - 14)))
            if (!m.err && m.text.trim().isNotEmpty) {'role': m.user ? 'user' : 'assistant', 'content': m.text}
        ];
        final res = await client.functions.invoke('ai-chat', body: {'messages': hist, 'context': _buildContext(), 'consent': true}).timeout(const Duration(seconds: 85));
        reply = _parseReply(res.status, res.data);
      }
    } on FunctionException catch (e) {
      reply = switch (e.status) {
        429 => _errMsg('وصلت للحد الأقصى من الرسائل في الساعة. جرّب بعد شوية.'),
        401 => _Msg(false, 'سجّل دخولك الأول عشان أقدر أرد عليك.'),
        _ => _errMsg('المساعد مش متاح دلوقتي. جرّب تاني بعد شوية.'),
      };
    } on TimeoutException {
      reply = _errMsg('الرد اتأخر. جرّب تاني.');
    } catch (_) {
      reply = _errMsg('حصلت مشكلة في الاتصال. تأكد من الإنترنت وجرّب تاني.');
    }
    chat.msgs.add(reply);
    chat.ts = DateTime.now().millisecondsSinceEpoch;
    _saveChats(); // الرد بيتحفظ حتى لو خرجت من الصفحة
    if (!mounted) return;
    setState(() => _busyId = null);
    _toEnd();
  }

  _Msg _parseReply(int status, dynamic data) {
    if (status != 200) {
      return status == 429 ? _errMsg('وصلت للحد الأقصى من الرسائل في الساعة. جرّب بعد شوية.') : _errMsg('المساعد مش متاح دلوقتي. جرّب تاني بعد شوية.');
    }
    dynamic d = data;
    if (d is String) {
      try {
        d = jsonDecode(d);
      } catch (_) {
        return _Msg(false, d as String);
      }
    }
    if (d is! Map) return _errMsg('المساعد مش متاح دلوقتي. جرّب تاني بعد شوية.');
    var reply = '${d['reply'] ?? ''}'.trim();
    final acts = <_Act>[];
    for (final a in (d['actions'] is List ? d['actions'] as List : const [])) {
      if (a is Map && a['name'] is String && a['args'] is Map) {
        final act = _Act(a['name'] as String, Map<String, dynamic>.from(a['args'] as Map));
        if (act.isTx) act.accId = aiResolveAccount('${act.args['account'] ?? ''}', line: '${act.args['note'] ?? ''}') ?? '';
        acts.add(act);
      }
    }
    final panel = _validPanel(d['panel']);
    final sug = [for (final s in (d['suggestions'] is List ? d['suggestions'] as List : const [])) if ('$s'.trim().isNotEmpty) '$s'.trim()].take(3).toList();
    if (reply.isEmpty && acts.isEmpty && panel == null) reply = 'تمام.';
    return _Msg(false, reply, acts: acts, panel: panel, suggestions: sug);
  }

  /// يتأكد إن بطاقة الأرقام كاملة وسليمة (غير كده تتجاهل).
  Map<String, dynamic>? _validPanel(dynamic p) {
    if (p is! Map) return null;
    final m = Map<String, dynamic>.from(p);
    if (m['type'] == 'comparison') {
      final c = _map(m['current']), v = _map(m['previous']);
      return c['amount'] is num && v['amount'] is num ? m : null;
    }
    if (m['type'] == 'breakdown') {
      final items = m['items'];
      return items is List && items.isNotEmpty && m['total'] is num ? m : null;
    }
    return null;
  }

  // ---------------- تقييم 👍/👎 ----------------
  Future<void> _rate(_Msg m, int r) async {
    if (m.rating == r) return;
    setState(() => m.rating = r);
    _saveChats();
    final c = sync.client;
    final u = c?.auth.currentUser;
    if (c == null || u == null) return;
    var ex = m.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (ex.length > 200) ex = ex.substring(0, 200);
    try {
      await c.from('ai_feedback').insert({'user_id': u.id, 'rating': r, 'reply_excerpt': ex});
    } catch (_) {/* best effort: التقييم المحلي فضل محفوظ */}
  }

  // ---------------- تنفيذ الأوامر (بعد الضغط) ----------------
  String _accIdOf(_Act a) {
    if (a.accId.isNotEmpty && repo.account(a.accId) != null) return a.accId;
    return repo.defaultAcc;
  }

  static const _expCats = {'food', 'shop', 'transport', 'bills', 'health', 'fun', 'edu', 'home', 'other'};
  static const _incCats = {'salary', 'free', 'gift', 'invest', 'other_i'};

  void _run(_Act a) {
    final g = a.args;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      switch (a.name) {
        case 'add_expense':
        case 'add_income':
          {
            final inc = a.name == 'add_income';
            final amt = _dbl(g['amount']);
            if (amt <= 0) throw 'المبلغ مش واضح';
            final cat = '${g['category'] ?? ''}';
            final id = uid();
            repo.saveTx(Tx(id: id, type: inc ? 'inc' : 'exp', amt: amt, acc: _accIdOf(a), cat: (inc ? _incCats : _expCats).contains(cat) ? cat : (inc ? 'other_i' : 'other'), note: '${g['note'] ?? ''}'.trim(), ts: now));
            a.ids = [id];
            a.result = 'اتسجّل ✓';
          }
        case 'add_goal':
          {
            final name = '${g['name'] ?? ''}'.trim();
            final t = _dbl(g['target']);
            if (name.isEmpty || t <= 0) throw 'بيانات الهدف ناقصة';
            final id = uid();
            repo.saveGoal(Goal(id: id, name: name, target: t));
            a.ids = [id];
            a.result = 'اتعمل الهدف ✓';
          }
        case 'add_to_goal':
          {
            final nm = '${g['goal'] ?? ''}'.trim().toLowerCase();
            final amt = _dbl(g['amount']);
            Goal? goal;
            for (final x in repo.goalList) {
              if (x.name.toLowerCase() == nm || (nm.isNotEmpty && x.name.toLowerCase().contains(nm))) goal = x;
            }
            if (goal == null || amt <= 0) throw 'الهدف أو المبلغ مش واضح';
            goal.entries.add(GoalEntry(now, amt));
            goal.saved += amt;
            repo.saveGoal(goal);
            a.ids = [goal.id];
            a.entryTs = now;
            a.entryAmt = amt;
            a.result = 'اتضاف للهدف ✓';
          }
        case 'add_loan':
          {
            final person = '${g['person'] ?? ''}'.trim();
            final amt = _dbl(g['amount']);
            if (person.isEmpty || amt <= 0) throw 'بيانات الدين ناقصة';
            final days = g['days'] == null ? 7 : _dbl(g['days']).round().clamp(0, 3650);
            final id = uid();
            repo.addLoan(Loan(id: id, dir: g['dir'] == 'owe' ? 'owe' : 'owed', person: person, amt: amt, cur: S.cur, due: days > 0 ? DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch : 0, ts: now, rec: false, rem: days > 0 ? [1] : <int>[]));
            a.ids = [id];
            a.result = 'اتسجّل ✓';
          }
        case 'open_page':
          {
            final Widget? page = switch ('${g['page']}') {
              'goals' => const GoalsPage(),
              'subscriptions' => const SubscriptionsPage(),
              'loans' => const LoansPage(),
              'assets' => const AssetsPage(),
              _ => null,
            };
            if (page == null) throw 'صفحة غير معروفة';
            Navigator.of(context).push(flowRoute(page)); // فوق صفحة حسّاب: الرجوع بيرجّعك للمحادثة
            a.result = 'اتفتحت ✓';
          }
        default:
          throw 'أمر غير مدعوم';
      }
      a.state = 'done';
    } catch (e) {
      a.state = 'failed';
      a.result = '$e'.length > 60 ? 'مقدرتش أنفّذ' : '$e';
    }
  }

  /// «نفّذ واحفظ»: ينفّذ كل الأوامر المعلّقة في الرسالة دفعة واحدة.
  void _runAll(_Msg m) {
    for (final a in m.acts) {
      if (!a.isNav && a.state == 'pending') _run(a);
    }
    _saveChats();
    if (mounted) setState(() {});
  }

  /// «تراجع»: يعكس الدفعة اللي اتنفذت (المعاملات بتروح سلة المحذوفات).
  void _undo(_Msg m) {
    for (final a in m.acts.reversed) {
      if (a.isNav || a.state != 'done') continue;
      try {
        switch (a.name) {
          case 'add_expense':
          case 'add_income':
            if (a.ids.isNotEmpty) repo.delTx(a.ids.first);
          case 'add_goal':
            for (final g in repo.goalList) {
              if (a.ids.isNotEmpty && g.id == a.ids.first) {
                g.del = true;
                repo.saveGoal(g);
              }
            }
          case 'add_to_goal':
            for (final g in repo.goalList) {
              if (a.ids.isNotEmpty && g.id == a.ids.first) {
                g.entries.removeWhere((e) => e.ts == a.entryTs && e.amt == a.entryAmt);
                g.saved = math.max(0, g.saved - a.entryAmt);
                repo.saveGoal(g);
              }
            }
          case 'add_loan':
            for (final l in repo.loanList) {
              if (a.ids.isNotEmpty && l.id == a.ids.first) repo.delLoan(l);
            }
        }
        a.state = 'undone';
        a.result = 'اتلغت';
      } catch (_) {
        a.result = 'مقدرتش أتراجع';
      }
    }
    _saveChats();
    if (mounted) {
      setState(() {});
      toast(context, 'تم التراجع');
    }
  }

  void _openTx() => Navigator.of(context).push(flowRoute(const AccountTxPage()));

  /// آخر رسالة فيها أوامر اتنفذت (هي الوحيدة اللي عليها زر «تراجع»).
  _Msg? get _lastDone {
    final c = cur;
    if (c == null) return null;
    for (final m in c.msgs.reversed) {
      if (m.acts.any((a) => !a.isNav && a.state == 'done')) return m;
      if (m.acts.any((a) => !a.isNav && a.state == 'undone')) return null; // آخر دفعة اتراجعت: مفيش تراجع تاني
    }
    return null;
  }

  // ---------------- مظهر ----------------
  IconData get _back => Directionality.of(context) == TextDirection.rtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded;
  IconData get _fwd => Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded;

  Widget _topBtn(Pal p, IconData i, VoidCallback f) => Tap(
        onTap: f,
        child: Container(width: 44, height: 44, decoration: BoxDecoration(color: p.card, shape: BoxShape.circle), child: Icon(i, color: p.ink, size: 22)),
      );

  Widget _topBar(Pal p) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(children: [
          _topBtn(p, _back, () {
            if (cur != null) {
              setState(() => cur = null);
            } else {
              Navigator.of(context).maybePop();
            }
          }),
          const Spacer(),
          if (cur != null) ...[
            _topBtn(p, Icons.add_rounded, () => setState(() {
                  cur = null;
                  input.clear();
                })),
            const SizedBox(width: 8),
          ],
          _topBtn(p, Icons.schedule_rounded, _showChats),
        ]),
      );

  String _dateOf(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts), n = DateTime.now();
    if (d.year == n.year && d.month == n.month && d.day == n.day) return timeLabel(d);
    return '${d.day} ${kMonths[d.month - 1]}${d.year == n.year ? '' : ' ${d.year}'}';
  }

  Widget _chatRow(Pal p, _Chat c, {VoidCallback? onTap, Widget? trailing}) => Tap(
        onTap: onTap ?? () => _openChat(c),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(16)), child: Icon(Icons.chat_bubble_outline_rounded, color: p.ink2, size: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.title.isEmpty ? 'محادثة' : c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(_dateOf(c.ts), style: TextStyle(fontSize: 13, color: p.ink2)),
              ]),
            ),
            trailing ?? Icon(_fwd, color: p.ink2, size: 20),
          ]),
        ),
      );

  void _openChat(_Chat c) {
    setState(() => cur = c);
    _toEnd();
  }

  Future<void> _deleteChat(_Chat c) async {
    final ok = await confirmDialog(context, 'حذف المحادثة', 'المحادثة دي هتتحذف من جهازك بس. بياناتك المالية ما بتتأثرش.', ok: 'حذف', cancel: 'إلغاء');
    if (!ok) return;
    _chats.remove(c);
    if (cur == c) cur = null;
    _saveChats();
    if (mounted) setState(() {});
  }

  Future<void> _showChats() async {
    await showSheet<void>(context, (c) => StatefulBuilder(builder: (c, setS) {
          final p = Pal.of(c);
          return SheetFrame(
            title: 'المحادثات',
            child: _chats.isEmpty
                ? Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), child: Text('لسه مفيش محادثات. اسأل حسّاب أي سؤال وهتتحفظ هنا.', textAlign: TextAlign.center, style: TextStyle(color: p.ink2, height: 1.6)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      for (final ch in List<_Chat>.of(_chats))
                        _chatRow(
                          p, ch,
                          onTap: () {
                            Navigator.of(c).pop();
                            _openChat(ch);
                          },
                          trailing: Tap(
                            onTap: () async {
                              await _deleteChat(ch);
                              setS(() {});
                            },
                            child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.delete_outline_rounded, color: p.ink2, size: 22)),
                          ),
                        ),
                    ]),
                  ),
          );
        }));
  }

  // ---------------- شاشة البداية ----------------
  Widget _home(Pal p) {
    final recent = _chats.take(3).toList();
    return ListView(key: const ValueKey('home'), padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), physics: const BouncingScrollPhysics(), children: [
      Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: p.acc.withValues(alpha: .16), shape: BoxShape.circle), child: Icon(Icons.auto_awesome_rounded, color: p.acc, size: 22)),
        const SizedBox(width: 10),
        Text('المساعد الذكي حسّاب', style: TextStyle(color: p.acc, fontSize: 18, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 16),
      Text.rich(
        TextSpan(children: [
          TextSpan(text: 'اسأل عن ', style: TextStyle(color: p.ink2)),
          TextSpan(text: 'مصروفاتك ودخلك وميزانياتك', style: TextStyle(color: p.ink, fontWeight: FontWeight.w800)),
          TextSpan(text: '، والإجابة من ', style: TextStyle(color: p.ink2)),
          TextSpan(text: 'أرقامك أنت', style: TextStyle(color: p.ink, fontWeight: FontWeight.w800)),
          TextSpan(text: '.', style: TextStyle(color: p.ink2)),
        ]),
        style: const TextStyle(fontSize: 27, height: 1.55, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 28),
      const Text('أسئلة مقترحة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      SizedBox(
        height: 128,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: _kQuick.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (c, i) {
            final q = _kQuick[i];
            return Tap(
              onTap: () => _submit(q.$3),
              child: Container(
                width: 262,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: p.line)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 38, height: 38, decoration: BoxDecoration(color: q.$2.withValues(alpha: .18), borderRadius: BorderRadius.circular(12)), child: Icon(q.$1, color: q.$2, size: 20)),
                  const Spacer(),
                  Text(q.$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(q.$4, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: p.ink2)),
                ]),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 22),
      Divider(color: p.line, height: 1),
      const SizedBox(height: 22),
      Row(children: [
        const Text('آخر المحادثات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const Spacer(),
        if (_chats.isNotEmpty) Tap(onTap: _showChats, child: Padding(padding: const EdgeInsets.all(4), child: Text('الكل', style: TextStyle(color: p.acc, fontSize: 15, fontWeight: FontWeight.w700)))),
      ]),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(26), border: Border.all(color: p.line)),
        child: recent.isEmpty
            ? Padding(padding: const EdgeInsets.all(22), child: Text('لسه مفيش محادثات. اختار سؤال من فوق أو اكتب سؤالك تحت.', textAlign: TextAlign.center, style: TextStyle(color: p.ink2, height: 1.6)))
            : Column(children: [
                for (var i = 0; i < recent.length; i++) ...[
                  if (i > 0) Divider(color: p.line, height: 1, indent: 72),
                  _chatRow(p, recent[i]),
                ],
              ]),
      ),
    ]);
  }

  // ---------------- المحادثة ----------------
  static final _numRe = RegExp(r'[0-9٠-٩]+(?:[,٬.٫][0-9٠-٩]+)*(?:\s?(?:ج\.م|جنيه|%|٪))?');

  TextSpan _rich(Pal p, String text) {
    final t = applyDigits(text);
    final spans = <InlineSpan>[];
    var i = 0;
    for (final m in _numRe.allMatches(t)) {
      if (m.start > i) spans.add(TextSpan(text: t.substring(i, m.start)));
      spans.add(TextSpan(text: m.group(0), style: TextStyle(color: p.acc, fontWeight: FontWeight.w700, backgroundColor: p.acc.withValues(alpha: .13))));
      i = m.end;
    }
    if (i < t.length) spans.add(TextSpan(text: t.substring(i)));
    return TextSpan(children: spans);
  }

  Widget _conversation(Pal p) {
    final c = cur!;
    final last = c.msgs.isEmpty ? null : c.msgs.last;
    final undoMsg = _lastDone;
    return ListView(key: ValueKey('chat_${c.id}'), controller: scroll, padding: const EdgeInsets.fromLTRB(16, 12, 16, 14), physics: const BouncingScrollPhysics(), children: [
      for (final m in c.msgs) _msgView(p, m, isLast: identical(m, last), undoable: identical(m, undoMsg)),
      if (_busyId == c.id) Align(alignment: AlignmentDirectional.centerStart, child: Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22)), child: _Dots(color: p.ink2))),
    ]);
  }

  Widget _msgView(Pal p, _Msg m, {required bool isLast, required bool undoable}) {
    final width = MediaQuery.of(context).size.width;
    if (m.user) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          constraints: BoxConstraints(maxWidth: width * .8),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(color: p.acc, borderRadius: const BorderRadiusDirectional.only(topStart: Radius.circular(24), topEnd: Radius.circular(24), bottomEnd: Radius.circular(24), bottomStart: Radius.circular(6))),
          child: SelectableText(applyDigits(m.text), style: const TextStyle(fontSize: 16, height: 1.45, color: Colors.white)),
        ),
      );
    }
    final saveActs = m.acts.where((a) => !a.isNav).toList();
    final navActs = m.acts.where((a) => a.isNav).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            constraints: BoxConstraints(maxWidth: width * .9),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(color: p.card, borderRadius: const BorderRadiusDirectional.only(topStart: Radius.circular(24), topEnd: Radius.circular(24), bottomEnd: Radius.circular(24), bottomStart: Radius.circular(6))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (m.text.isNotEmpty) SelectableText.rich(_rich(p, m.text), style: TextStyle(fontSize: 16, height: 1.55, color: p.ink)),
              if (m.panel != null) ...[
                const SizedBox(height: 14),
                _panelView(p, m.panel!),
              ],
              if (saveActs.isNotEmpty) ...[
                const SizedBox(height: 14),
                _actionsCard(p, m, saveActs, undoable),
              ],
              for (final a in navActs) ...[
                const SizedBox(height: 10),
                _navChip(p, a),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 6),
        if (!m.err) _feedbackRow(p, m),
        if (m.err && isLast && _busyId == null) Padding(padding: const EdgeInsets.only(top: 6), child: _chip(p, 'حاول تاني', Icons.refresh_rounded, _retry)),
        if (isLast && !m.err && m.suggestions.isNotEmpty && _busyId == null)
          Padding(padding: const EdgeInsets.only(top: 12), child: Wrap(spacing: 8, runSpacing: 8, children: [for (final s in m.suggestions) _chip(p, s, Icons.auto_awesome_rounded, () => _submit(s))])),
      ]),
    );
  }

  Future<void> _retry() async {
    final c = cur;
    if (c == null || _busy) return;
    if (c.msgs.isNotEmpty && c.msgs.last.err) c.msgs.removeLast();
    _saveChats();
    _sending = true;
    try {
      await _ask(c);
    } finally {
      _sending = false;
    }
  }

  Widget _chip(Pal p, String label, IconData icon, VoidCallback f) => Tap(
        onTap: f,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: p.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: p.acc),
            const SizedBox(width: 8),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
          ]),
        ),
      );

  Widget _feedbackRow(Pal p, _Msg m) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 4),
        child: Row(children: [
          Container(width: 30, height: 30, decoration: BoxDecoration(color: p.acc.withValues(alpha: .14), shape: BoxShape.circle), child: Icon(Icons.auto_awesome_rounded, color: p.acc, size: 16)),
          const SizedBox(width: 6),
          Tap(onTap: () => _rate(m, 1), child: Padding(padding: const EdgeInsets.all(8), child: AnimatedSwitcher(duration: CashUMotion.icon, child: Icon(m.rating == 1 ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined, key: ValueKey(m.rating == 1), size: 20, color: m.rating == 1 ? p.acc : p.ink2)))),
          Tap(onTap: () => _rate(m, -1), child: Padding(padding: const EdgeInsets.all(8), child: AnimatedSwitcher(duration: CashUMotion.icon, child: Icon(m.rating == -1 ? Icons.thumb_down_alt_rounded : Icons.thumb_down_alt_outlined, key: ValueKey(m.rating == -1), size: 20, color: m.rating == -1 ? kRed : p.ink2)))),
        ]),
      );

  // ---------------- بطاقات الأرقام (comparison / breakdown) ----------------
  Widget _panelView(Pal p, Map<String, dynamic> d) => d['type'] == 'comparison' ? _cmpPanel(p, d) : _brkPanel(p, d);

  Widget _panelBox(Pal p, String title, List<Widget> children, int count) => Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: p.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          ...children,
          const SizedBox(height: 10),
          Divider(color: p.line, height: 1),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Text('بناءً على ${count.toString()} معاملة', style: TextStyle(fontSize: 13, color: p.ink2))),
            Tap(
              onTap: _openTx,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('عرض المعاملات', style: TextStyle(color: p.acc, fontSize: 14, fontWeight: FontWeight.w700)),
                Icon(_fwd, color: p.acc, size: 18),
              ]),
            ),
          ]),
        ]),
      );

  Widget _barRow(Pal p, String label, double amt, double frac, Color color, {bool strong = false}) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.ink2, fontSize: 13.5))),
          Directionality(textDirection: TextDirection.ltr, child: Text(money(amt), style: TextStyle(fontWeight: FontWeight.w800, fontSize: strong ? 17 : 15))),
        ]),
        const SizedBox(height: 7),
        _Bar(frac: frac, color: color, track: p.field),
      ]);

  Widget _cmpPanel(Pal p, Map<String, dynamic> d) {
    final cur = _map(d['current']), prev = _map(d['previous']);
    final ca = _dbl(cur['amount']), pa = _dbl(prev['amount']);
    final mx = math.max(math.max(ca, pa), 1.0);
    final pct = d['change_pct'] is num ? (d['change_pct'] as num).toDouble() : null;
    final good = d['good'] == true;
    final n = (_dbl(cur['count']) + _dbl(prev['count'])).round();
    return _panelBox(p, '${d['title'] ?? ''}', [
      _barRow(p, '${cur['label'] ?? ''}', ca, ca / mx, p.acc, strong: true),
      const SizedBox(height: 12),
      _barRow(p, '${prev['label'] ?? ''}', pa, pa / mx, p.ink2.withValues(alpha: .4)),
      if (pct != null) ...[
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: (good ? kGreen : kRed).withValues(alpha: .15), borderRadius: BorderRadius.circular(14)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(pct > 0 ? Icons.trending_up_rounded : (pct < 0 ? Icons.trending_down_rounded : Icons.trending_flat_rounded), size: 16, color: good ? kGreen : kRed),
              const SizedBox(width: 6),
              Directionality(textDirection: TextDirection.ltr, child: Text('${pct > 0 ? '+' : (pct < 0 ? '-' : '')}${pct.abs() >= 10 ? pct.abs().round() : pct.abs().toStringAsFixed(1)}%', style: TextStyle(color: good ? kGreen : kRed, fontWeight: FontWeight.w800, fontSize: 14))),
            ]),
          ),
        ),
      ],
    ], n);
  }

  Widget _brkPanel(Pal p, Map<String, dynamic> d) {
    final items = [for (final x in (d['items'] as List)) if (x is Map) Map<String, dynamic>.from(x)];
    final total = _dbl(d['total']);
    return _panelBox(p, '${d['title'] ?? ''}${'${d['period_label'] ?? ''}'.isEmpty ? '' : ' — ${d['period_label']}'}', [
      Row(children: [
        Expanded(child: Text('الإجمالي', style: TextStyle(color: p.ink2, fontSize: 13.5))),
        Directionality(textDirection: TextDirection.ltr, child: Text(money(total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
      ]),
      const SizedBox(height: 12),
      for (final it in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              iconBubble(p, catIcon('${it['cat']}').$1, size: 32, color: catIcon('${it['cat']}').$2),
              const SizedBox(width: 10),
              Expanded(child: Text('${it['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
              Directionality(textDirection: TextDirection.ltr, child: Text('${money(_dbl(it['amount']))}  ·  ${_dbl(it['pct']) >= 10 ? _dbl(it['pct']).round() : _dbl(it['pct']).toStringAsFixed(1)}%', style: TextStyle(color: p.ink2, fontSize: 13))),
            ]),
            const SizedBox(height: 6),
            _Bar(frac: (_dbl(it['pct']) / 100).clamp(0.0, 1.0), color: catIcon('${it['cat']}').$2, track: p.field),
          ]),
        ),
    ], (d['count'] is num) ? (d['count'] as num).round() : 0);
  }

  // ---------------- بطاقة «معاملات جاهزة» + حالة الحفظ + تراجع ----------------
  String _countWord(int n) => n == 1 ? 'معاملة واحدة' : (n == 2 ? 'معاملتان' : (n <= 10 ? '$n معاملات' : '$n معاملة'));

  String _accName(_Act a) => repo.account(_accIdOf(a))?.name ?? '';

  ({IconData icon, Color color, String title, String sub, String amt, bool inc}) _rowOf(_Act a) {
    final g = a.args;
    switch (a.name) {
      case 'add_expense':
      case 'add_income':
        {
          final inc = a.name == 'add_income';
          final cat = '${g['category'] ?? ''}';
          final id = cat.isEmpty ? (inc ? 'other_i' : 'other') : cat;
          final ic = catIcon(id);
          final note = '${g['note'] ?? ''}'.trim();
          return (icon: ic.$1, color: ic.$2, title: note.isEmpty ? catOf(id).name : note, sub: '${catOf(id).name}${_accName(a).isEmpty ? '' : ' · ${_accName(a)}'}', amt: '${inc ? '+' : '-'}${money(_dbl(g['amount']))}', inc: inc);
        }
      case 'add_goal':
        return (icon: Icons.flag_rounded, color: const Color(0xFF3FBF8A), title: 'هدف «${g['name']}»', sub: 'المستهدف ${money(_dbl(g['target']))}', amt: '', inc: false);
      case 'add_to_goal':
        return (icon: Icons.savings_rounded, color: const Color(0xFF3FBF8A), title: 'إضافة لهدف «${g['goal']}»', sub: '', amt: '+${money(_dbl(g['amount']))}', inc: true);
      case 'add_loan':
        {
          final owe = g['dir'] == 'owe';
          return (icon: Icons.handshake_rounded, color: const Color(0xFF6D8BFF), title: owe ? 'دين عليك لـ ${g['person']}' : 'سلفة لـ ${g['person']}', sub: '', amt: money(_dbl(g['amount'])), inc: !owe);
        }
    }
    return (icon: Icons.bolt_rounded, color: Pal.of(context).acc, title: a.name, sub: '', amt: '', inc: false);
  }

  Widget _txRow(Pal p, _Act a, {bool pending = false, bool dim = false}) {
    final r = _rowOf(a);
    return Opacity(
      opacity: dim ? .5 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: r.color.withValues(alpha: .16), shape: BoxShape.circle), child: Icon(r.icon, color: r.color, size: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              if (r.sub.isNotEmpty) ...[
                const SizedBox(height: 2),
                if (pending && a.isTx)
                  Tap(
                    onTap: () async {
                      final id = await showPickAccount(context, _accIdOf(a));
                      if (id != null && mounted) {
                        setState(() => a.accId = id);
                        _saveChats();
                      }
                    },
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(child: Text(r.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: p.ink2))),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_rounded, size: 13, color: p.acc),
                    ]),
                  )
                else
                  Text(r.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: p.ink2)),
              ],
            ]),
          ),
          if (r.amt.isNotEmpty) Directionality(textDirection: TextDirection.ltr, child: Text(r.amt, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: r.inc ? kGreen : p.ink))),
        ]),
      ),
    );
  }

  Widget _pill(Pal p, String label, VoidCallback f, {bool primary = true, IconData? icon}) => Tap(
        onTap: f,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(color: primary ? p.acc : p.field, borderRadius: BorderRadius.circular(24)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 18, color: primary ? Colors.white : p.ink), const SizedBox(width: 6)],
            Text(label, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: primary ? Colors.white : p.ink)),
          ]),
        ),
      );

  Widget _actionsCard(Pal p, _Msg m, List<_Act> acts, bool undoable) {
    final live = acts.where((a) => a.state != 'skipped').toList();
    final pending = live.where((a) => a.state == 'pending').toList();
    final done = live.where((a) => a.state == 'done').toList();
    final failed = live.where((a) => a.state == 'failed').toList();
    final undone = live.where((a) => a.state == 'undone').toList();
    Widget header(IconData i, Color c, String small, String big) => Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: c.withValues(alpha: .16), shape: BoxShape.circle), child: Icon(i, color: c, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(small, style: TextStyle(fontSize: 13.5, color: p.ink2)), Text(big, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))])),
        ]);
    Widget box(List<Widget> kids) => AnimatedSize(
          duration: CashUMotion.expand,
          curve: CashUMotion.curve,
          alignment: Alignment.topCenter,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: p.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids),
          ),
        );

    if (live.isEmpty) return box([Text('اتجاهلت الأوامر دي.', style: TextStyle(color: p.ink2))]);

    // ① بانتظار التأكيد (أمر أو أكتر في بطاقة واحدة وزر حفظ واحد)
    if (pending.isNotEmpty) {
      return box([
        header(Icons.receipt_long_rounded, p.acc, 'معاملات جاهزة — بانتظار تأكيدك', _countWord(pending.length)),
        const SizedBox(height: 8),
        for (final a in pending)
          Row(children: [
            Expanded(child: _txRow(p, a, pending: true)),
            if (pending.length > 1)
              Tap(
                onTap: () {
                  setState(() => a.state = 'skipped');
                  _saveChats();
                },
                child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.close_rounded, size: 18, color: p.ink2)),
              ),
          ]),
        const SizedBox(height: 6),
        Text('مفيش حاجة بتتحفظ غير لما تضغط حفظ.', style: TextStyle(fontSize: 13.5, color: p.ink2, height: 1.5)),
        const SizedBox(height: 14),
        _pill(p, 'نفّذ واحفظ', () => _runAll(m)),
        if (pending.length == 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Tap(
              onTap: () {
                setState(() => pending.first.state = 'skipped');
                _saveChats();
              },
              child: Container(height: 36, alignment: Alignment.center, child: Text('تجاهل', style: TextStyle(color: p.ink2, fontWeight: FontWeight.w600))),
            ),
          ),
      ]);
    }

    // ② اتحفظت (مع «اعرض معاملاتي» و«تراجع» لآخر دفعة)
    if (done.isNotEmpty) {
      return box([
        header(Icons.check_circle_outline_rounded, kGreen, 'تم الحفظ', _countWord(done.length)),
        const SizedBox(height: 8),
        for (final a in done) _txRow(p, a),
        for (final a in failed) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${_rowOf(a).title}: ${a.result}', style: TextStyle(color: kRed, fontSize: 13.5))),
        const SizedBox(height: 6),
        Text('تمت إضافتها إلى معاملاتك.', style: TextStyle(fontSize: 14, color: p.ink2)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _pill(p, 'اعرض معاملاتي', _openTx)),
          if (undoable) ...[
            const SizedBox(width: 10),
            _pill(p, 'تراجع', () => _undo(m), primary: false, icon: Icons.undo_rounded),
          ],
        ]),
      ]);
    }

    // ③ اتلغت بالتراجع
    if (undone.isNotEmpty) {
      return box([
        header(Icons.undo_rounded, p.ink2, 'تم التراجع', _countWord(undone.length)),
        const SizedBox(height: 8),
        for (final a in undone) _txRow(p, a, dim: true),
        Text('اتشالت من معاملاتك (موجودة في سلة المحذوفات).', style: TextStyle(fontSize: 13.5, color: p.ink2)),
      ]);
    }

    // ④ فشل التنفيذ
    return box([
      header(Icons.error_outline_rounded, kRed, 'مقدرتش أنفّذ', _countWord(failed.length)),
      const SizedBox(height: 8),
      for (final a in failed) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${_rowOf(a).title}: ${a.result}', style: TextStyle(color: kRed, fontSize: 14))),
    ]);
  }

  Widget _navChip(Pal p, _Act a) {
    final label = const {'goals': 'الأهداف', 'subscriptions': 'الاشتراكات', 'loans': 'المستحقات', 'assets': 'الأصول'}['${a.args['page']}'] ?? 'الصفحة';
    return _chip(p, 'افتح $label', Icons.open_in_new_rounded, () {
      _run(a);
      _saveChats();
      if (mounted) setState(() {});
    });
  }

  // ---------------- الإدخال ----------------
  Widget _composer(Pal p) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 6, 4),
          decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(30), border: Border.all(color: p.line)),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onChanged: (_) => setState(() {}),
                onSubmitted: (v) => _submit(v),
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(border: InputBorder.none, hintText: 'اسأل عن أموالك أو عن التطبيق…', hintStyle: TextStyle(color: p.ink2)),
              ),
            ),
            const SizedBox(width: 8),
            Tap(
              onTap: () => _submit(input.text),
              child: AnimatedContainer(
                duration: CashUMotion.icon,
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: input.text.trim().isEmpty || _busy ? p.field : p.acc, shape: BoxShape.circle),
                child: Icon(Icons.arrow_upward_rounded, color: input.text.trim().isEmpty || _busy ? p.ink2 : Colors.white),
              ),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PopScope(
      canPop: cur == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => cur = null); // من المحادثة: الرجوع لشاشة البداية الأول
      },
      child: Scaffold(
        backgroundColor: p.bg,
        body: Stack(children: [
          // توهّج خفيف من أعلى (زي ستايل التطبيق)
          Positioned(top: 0, left: 0, right: 0, height: 320, child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [p.acc.withValues(alpha: .13), p.bg.withValues(alpha: 0)])))),
          SafeArea(
            child: Column(children: [
              _topBar(p),
              Expanded(child: AnimatedSwitcher(duration: CashUMotion.tab, switchInCurve: CashUMotion.curve, child: cur == null ? _home(p) : _conversation(p))),
              _composer(p),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// عناصر صغيرة
// ---------------------------------------------------------------------------------------------
class _Bar extends StatelessWidget {
  final double frac;
  final Color color, track;
  const _Bar({required this.frac, required this.color, required this.track});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: frac.clamp(0.0, 1.0).toDouble()),
        duration: CashUMotion.fill,
        curve: CashUMotion.curve,
        builder: (c, v, _) => ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(height: 8, color: track, alignment: AlignmentDirectional.centerStart, child: FractionallySizedBox(widthFactor: v, child: Container(color: color))),
        ),
      );
}

class _Dots extends StatefulWidget {
  final Color color;
  const _Dots({required this.color});
  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (c, _) => Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: widget.color.withValues(alpha: .25 + .75 * (math.sin((_c.value * 2 * math.pi) - i * .9) * .5 + .5)), shape: BoxShape.circle),
            ),
        ]),
      );
}

/// فتح صفحة من خارج الصفحة باستخدام الـ Navigator العام (محتفظ بيها للتوافق).
void navKeyPush(Widget page) => _navKey?.currentState?.push(flowRoute(page));

/// الـ Navigator العام (بيتسجّل من [AiFab]).
GlobalKey<NavigatorState>? _navKey;
