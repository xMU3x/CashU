import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:material_ui/material_ui.dart' hide Text;
import 'loc_text.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/sync.dart';
import '../core/util.dart';
import '../pages/assets_page.dart';
import '../pages/goals_page.dart';
import '../pages/loans_page.dart';
import '../pages/subs_page.dart';
import 'anim.dart';
import 'ios.dart';
import 'motion.dart';
import 'theme.dart';
import 'widgets.dart';

// ======================= مساعد CashU الذكي =======================
// • زر عائم صغير (AiFab) فوق كل الصفحات يفتح شات.
// • الرد من Supabase Edge Function `ai-chat` (مفتاح Groq على السيرفر فقط — supabase/functions/ai-chat).
// • المساعد بيشوف ملخص بيانات التطبيق (حسابات/آخر معاملات/أهداف/ديون) بعد موافقتك الأولى، وبيقدر يقترح أوامر
//   (مصروف/دخل/هدف/إضافة لهدف/دين/فتح صفحة). كل أمر بيتنفّذ بعد ما تضغط «نفّذ» — مفيش حذف ولا تغيير إعدادات ولا نسخ احتياطي.

/// ملاحظة سلوك: الشات محفوظ طول ما التطبيق مفتوح (مش بيتخزّن على الجهاز ولا بيتبعت إلا مع رسالتك الجديدة).
class _Msg {
  final bool user;
  final String text;
  final List<_Act> acts;
  _Msg(this.user, this.text, [List<_Act>? acts]) : acts = acts ?? [];
}

class _Act {
  final String name;
  final Map<String, dynamic> args;
  String state = 'pending'; // pending | done | skipped | failed
  String result = '';
  _Act(this.name, this.args);
}

final List<_Msg> _history = [];
bool _chatOpen = false;

/// يفتح الشات. [prompt] لو اتبعت بيتكتب في خانة الرسالة (ما بيتبعتش لوحده).
Future<void> openAiChat(BuildContext context, {String? prompt}) async {
  if (_chatOpen) return;
  _chatOpen = true;
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (c) => _AiChatSheet(prefill: prompt),
    );
  } finally {
    _chatOpen = false;
  }
}

/// الزر العائم الصغير. بيتحط مرة واحدة فوق كل الصفحات (app.dart).
class AiFab extends StatelessWidget {
  final GlobalKey<NavigatorState> navKey;
  const AiFab({super.key, required this.navKey});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final mq = MediaQuery.of(context);
    _navKey = navKey;
    if (mq.viewInsets.bottom > 0) return const SizedBox.shrink(); // مخفي والكيبورد مفتوح
    return PositionedDirectional(
      start: 14,
      bottom: 92 + mq.padding.bottom,
      child: Semantics(
        button: true,
        label: 'المساعد الذكي',
        child: Tap(
          scale: .92,
          onTap: () {
            final c = navKey.currentContext;
            if (c != null) openAiChat(c);
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
  }
}

// ----------------------------------------------------------------------------------------------
class _AiChatSheet extends StatefulWidget {
  final String? prefill;
  const _AiChatSheet({this.prefill});
  @override
  State<_AiChatSheet> createState() => _AiChatState();
}

class _AiChatState extends State<_AiChatSheet> {
  final input = TextEditingController();
  final scroll = ScrollController();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefill != null) input.text = widget.prefill!;
  }

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: CashUMotion.small, curve: CashUMotion.curve);
      });

  /// ملخص صغير لحالة التطبيق (بيتبعت مع كل رسالة، حد أقصى ~٧ آلاف حرف).
  String _context() {
    final now = DateTime.now();
    final b = StringBuffer('today=${now.toIso8601String().substring(0, 10)}; currency=${S.cur}\n');
    b.writeln('ACCOUNTS (id|name|kind|balance):');
    for (final a in repo.accList) {
      if (a.del || a.arch) continue;
      b.writeln('${a.id}|${a.name}|${a.kind}|${fixed2(repo.bal(a.id))}');
    }
    b.writeln('SPENT_THIS_MONTH=${fixed2(repo.spent(now.year, now.month))}');
    final txs = repo.txOf(null).where((t) => !t.del).toList()..sort((a, c) => c.ts.compareTo(a.ts));
    b.writeln('RECENT_TX (date|type|amount|title|account):');
    for (final t in txs.take(20)) {
      b.writeln('${t.date.toIso8601String().substring(0, 10)}|${t.type}|${fixed2(t.amt)}|${txTitle(t)}|${repo.account(t.acc)?.name ?? ''}');
    }
    final goals = repo.goalList;
    if (goals.isNotEmpty) {
      b.writeln('GOALS (name|saved|target):');
      for (final g in goals) {
        b.writeln('${g.name}|${fixed2(g.saved)}|${fixed2(g.target)}');
      }
    }
    final loans = repo.loanList.where((l) => !l.settled && !l.hidden).toList();
    if (loans.isNotEmpty) {
      b.writeln('OPEN_DEBTS (dir owed=owed to me, owe=I owe | person | left):');
      for (final l in loans) {
        b.writeln('${l.dir}|${l.person}|${fixed2(l.left)}');
      }
    }
    final s = b.toString();
    return s.length > 6800 ? s.substring(0, 6800) : s;
  }

  Future<bool> _consent() async {
    if (S.flag('aiChatConsent', false)) return true;
    final ok = await confirmDialog(context, 'المساعد الذكي', 'عشان يرد بدقة، هيتبعت للمساعد (عن طريق السيرفر بتاعنا) ملخص من بياناتك: أسماء الحسابات وأرصدتها وآخر المعاملات والأهداف والديون المفتوحة — مع كل رسالة تبعتها بس. مفيش حاجة بتتنفّذ من غير ما تضغط «نفّذ».', ok: 'موافق', cancel: 'مش دلوقتي', danger: false);
    if (ok) S.put('aiChatConsent', true);
    return ok;
  }

  Future<void> _send() async {
    final text = input.text.trim();
    if (text.isEmpty || busy) return;
    if (!await _consent()) return;
    final client = sync.client;
    setState(() {
      _history.add(_Msg(true, text));
      input.clear();
      busy = true;
    });
    _toEnd();
    String reply;
    var acts = <_Act>[];
    try {
      if (client == null || client.auth.currentSession == null) {
        reply = 'سجّل دخولك الأول عشان أقدر أرد عليك.';
      } else {
        final msgs = [for (final m in _history.skip(math.max(0, _history.length - 14))) {'role': m.user ? 'user' : 'assistant', 'content': m.text}];
        final res = await client.functions.invoke('ai-chat', body: {'messages': msgs, 'context': _context(), 'consent': true}).timeout(const Duration(seconds: 40));
        if (res.status != 200 || res.data is! Map) {
          reply = res.status == 429 ? 'وصلت للحد الأقصى من الرسائل في الساعة. جرّب بعد شوية.' : 'المساعد مش متاح دلوقتي. جرّب تاني بعد شوية.';
        } else {
          final j = res.data as Map;
          reply = '${j['reply'] ?? ''}'.trim();
          if (reply.isEmpty) reply = 'تمام.';
          for (final a in (j['actions'] is List ? j['actions'] as List : const [])) {
            if (a is Map && a['name'] is String && a['args'] is Map) acts.add(_Act(a['name'] as String, Map<String, dynamic>.from(a['args'] as Map)));
          }
        }
      }
    } on TimeoutException {
      reply = 'الرد اتأخر. جرّب تاني.';
    } catch (_) {
      reply = 'حصلت مشكلة في الاتصال. تأكد من الإنترنت وجرّب تاني.';
    }
    if (!mounted) return;
    setState(() {
      _history.add(_Msg(false, reply, acts));
      busy = false;
    });
    _toEnd();
  }

  // ---- تنفيذ الأوامر (بعد الضغط على «نفّذ») ----
  static double _num(dynamic v) => v is num ? v.toDouble() : (double.tryParse(normDigits('$v').replaceAll(',', '.')) ?? 0);

  String _accId(dynamic v) {
    final s = '${v ?? ''}'.trim().toLowerCase();
    if (s.isNotEmpty) {
      for (final a in repo.accList) {
        if (a.del || a.arch) continue;
        if (a.id.toLowerCase() == s || a.name.toLowerCase() == s) return a.id;
      }
      for (final a in repo.accList) {
        if (!a.del && !a.arch && a.name.toLowerCase().contains(s)) return a.id;
      }
    }
    return repo.defaultAcc;
  }

  static const _expCats = {'food', 'shop', 'transport', 'bills', 'health', 'fun', 'edu', 'home', 'other'};
  static const _incCats = {'salary', 'free', 'gift', 'invest', 'other_i'};

  String _describe(_Act a) {
    final g = a.args;
    switch (a.name) {
      case 'add_expense':
        return 'تسجيل مصروف ${fixed2(_num(g['amount']))} ${S.cur}${'${g['note'] ?? ''}'.isEmpty ? '' : ' — ${g['note']}'}';
      case 'add_income':
        return 'تسجيل دخل ${fixed2(_num(g['amount']))} ${S.cur}${'${g['note'] ?? ''}'.isEmpty ? '' : ' — ${g['note']}'}';
      case 'add_goal':
        return 'إنشاء هدف «${g['name']}» بمبلغ ${fixed2(_num(g['target']))}';
      case 'add_to_goal':
        return 'إضافة ${fixed2(_num(g['amount']))} إلى هدف «${g['goal']}»';
      case 'add_loan':
        return g['dir'] == 'owe' ? 'تسجيل دين عليك لـ ${g['person']} بمبلغ ${fixed2(_num(g['amount']))}' : 'تسجيل سلفة لـ ${g['person']} بمبلغ ${fixed2(_num(g['amount']))}';
      case 'open_page':
        return 'فتح صفحة ${const {'goals': 'الأهداف', 'subscriptions': 'الاشتراكات', 'loans': 'المستحقات', 'assets': 'الأصول'}['${g['page']}'] ?? ''}';
    }
    return a.name;
  }

  IconData _icon(String n) => switch (n) {
        'add_expense' => Icons.north_east_rounded,
        'add_income' => Icons.south_west_rounded,
        'add_goal' || 'add_to_goal' => Icons.flag_rounded,
        'add_loan' => Icons.handshake_rounded,
        _ => Icons.open_in_new_rounded,
      };

  void _run(_Act a) {
    final g = a.args;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      switch (a.name) {
        case 'add_expense':
        case 'add_income':
          {
          final inc = a.name == 'add_income';
          final amt = _num(g['amount']);
          if (amt <= 0) throw 'المبلغ مش واضح';
          final cat = '${g['category'] ?? ''}';
          repo.saveTx(Tx(id: uid(), type: inc ? 'inc' : 'exp', amt: amt, acc: _accId(g['account']), cat: (inc ? _incCats : _expCats).contains(cat) ? cat : (inc ? 'other_i' : 'other'), note: '${g['note'] ?? ''}'.trim(), ts: now));
          a.result = 'اتسجّل ✓';
          }
        case 'add_goal':
          {
          final name = '${g['name'] ?? ''}'.trim();
          final t = _num(g['target']);
          if (name.isEmpty || t <= 0) throw 'بيانات الهدف ناقصة';
          repo.saveGoal(Goal(id: uid(), name: name, target: t));
          a.result = 'اتعمل الهدف ✓';
          }
        case 'add_to_goal':
          {
          final nm = '${g['goal'] ?? ''}'.trim().toLowerCase();
          final amt = _num(g['amount']);
          Goal? goal;
          for (final x in repo.goalList) {
            if (x.name.toLowerCase() == nm || x.name.toLowerCase().contains(nm)) goal = x;
          }
          if (goal == null || amt <= 0) throw 'الهدف أو المبلغ مش واضح';
          goal.entries.add(GoalEntry(now, amt));
          goal.saved += amt;
          repo.saveGoal(goal);
          a.result = 'اتضاف للهدف ✓';
          }
        case 'add_loan':
          {
          final person = '${g['person'] ?? ''}'.trim();
          final amt = _num(g['amount']);
          if (person.isEmpty || amt <= 0) throw 'بيانات الدين ناقصة';
          final days = g['days'] == null ? 7 : _num(g['days']).round().clamp(0, 3650);
          repo.addLoan(Loan(id: uid(), dir: g['dir'] == 'owe' ? 'owe' : 'owed', person: person, amt: amt, cur: S.cur, due: days > 0 ? DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch : 0, ts: now, rec: false, rem: days > 0 ? [1] : <int>[]));
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
          Navigator.of(context).pop(); // يقفل الشات
          navKeyPush(page);
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
    if (mounted) setState(() {});
  }

  Widget _actCard(Pal p, _Act a) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: p.acc.withValues(alpha: .16), shape: BoxShape.circle), child: Icon(_icon(a.name), size: 18, color: p.acc)),
            const SizedBox(width: 10),
            Expanded(child: Text(_describe(a), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.35))),
          ]),
          const SizedBox(height: 10),
          if (a.state == 'pending')
            Row(children: [
              Expanded(child: Tap(onTap: () => _run(a), child: Container(height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: p.acc, borderRadius: BorderRadius.circular(20)), child: const Text('نفّذ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))))),
              const SizedBox(width: 8),
              Expanded(child: Tap(onTap: () => setState(() => a.state = 'skipped'), child: Container(height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(20)), child: const Text('تجاهل', style: TextStyle(fontWeight: FontWeight.w600))))),
            ])
          else
            Text(a.state == 'done' ? a.result : (a.state == 'skipped' ? 'اتجاهل' : a.result), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: a.state == 'done' ? kGreen : (a.state == 'failed' ? kRed : p.ink2))),
        ]),
      );

  Widget _bubble(Pal p, _Msg m) => Align(
        alignment: m.user ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .82),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: m.user ? p.acc : p.field, borderRadius: BorderRadius.circular(20)),
              child: SelectableText(m.text, style: TextStyle(fontSize: 15.5, height: 1.45, color: m.user ? Colors.white : p.ink)),
            ),
            for (final a in m.acts) _actCard(p, a),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        height: mq.size.height * .86,
        decoration: BoxDecoration(color: p.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), border: Border.all(color: p.line)),
        child: Column(children: [
          Container(width: 44, height: 5, margin: const EdgeInsets.only(top: 10, bottom: 8), decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(9))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Icon(Icons.auto_awesome_rounded, color: p.acc, size: 22),
              const SizedBox(width: 8),
              const Expanded(child: Text('المساعد الذكي', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
              if (_history.isNotEmpty) Tap(onTap: () => setState(_history.clear), child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.delete_sweep_outlined, color: p.ink2, size: 22))),
              Tap(onTap: () => Navigator.of(context).pop(), child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.close_rounded, color: p.ink, size: 22))),
            ]),
          ),
          Expanded(
            child: _history.isEmpty
                ? ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 16), children: [
                    Center(child: Icon(Icons.auto_awesome_rounded, size: 46, color: p.acc)),
                    const SizedBox(height: 12),
                    const Center(child: Text('اسألني عن فلوسك أو اطلب مني أسجّل حاجة', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                    const SizedBox(height: 18),
                    for (final s in const ['صرفت كام الشهر ده؟', 'سجّل مصروف ٥٠ جنيه قهوة', 'اعمل هدف ادخار لموبايل ٢٠٠٠٠', 'مين عليه فلوس ليا؟'])
                      Tap(onTap: () => setState(() => input.text = s), child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13), decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(18)), child: Text(s, style: const TextStyle(fontSize: 15)))),
                  ])
                : ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), physics: const BouncingScrollPhysics(), children: [
                    for (final m in _history) _bubble(p, m),
                    if (busy) Align(alignment: AlignmentDirectional.centerEnd, child: Padding(padding: const EdgeInsets.all(8), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: p.acc)))),
                  ]),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 6, 12, 12 + (mq.viewInsets.bottom > 0 ? 0 : mq.padding.bottom)),
            child: Row(children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(26), border: Border.all(color: p.line)),
                  child: TextField(
                    controller: input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(border: InputBorder.none, hintText: 'اكتب رسالتك…', hintStyle: TextStyle(color: p.ink2)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tap(onTap: _send, child: Container(width: 50, height: 50, decoration: BoxDecoration(color: busy ? p.field : p.acc, shape: BoxShape.circle), child: Icon(Icons.arrow_upward_rounded, color: busy ? p.ink2 : Colors.white))),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// فتح صفحة من خارج الشات (بعد قفله) باستخدام الـ Navigator العام.
void navKeyPush(Widget page) => _navKey?.currentState?.push(flowRoute(page));

/// الـ Navigator العام (بيتسجّل من [AiFab]) عشان الشات يعرف يفتح الصفحات بعد ما يتقفل.
GlobalKey<NavigatorState>? _navKey;
