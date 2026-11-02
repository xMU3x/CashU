import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import '../core/currency.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/sync.dart';
import '../core/util.dart';
import '../ui/anim.dart';
import '../ui/sheets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'add_tx.dart';
import 'accounts.dart';
import 'more_pages.dart';
import 'profile.dart';
import 'tools.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomeState();
}

class _HomeState extends State<HomePage> {
  final pc = PageController(viewportFraction: .95);
  int ci = 0;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void dispose() {
    pc.dispose();
    super.dispose();
  }

  void _add({int page = 0, String? cat}) => Navigator.of(context).push(flowRoute(AddTxPage(page: page, cat: cat)));

  String get _name {
    final u = sync.user;
    if (u == null) return 'ضيف';
    final m = u.userMetadata;
    final n = (m?['full_name'] ?? m?['name'] ?? '') as String;
    if (n.trim().isNotEmpty) return n.trim().split(' ').first;
    return (u.email ?? 'ضيف').split('@').first;
  }

  Widget _header(Pal p) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(34), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 18, offset: const Offset(0, 6))]),
        child: Row(children: [
          Tap(
            onTap: () => Navigator.of(context).push(flowRoute(const ToolsPage())),
            child: Container(width: 52, height: 52, decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(18)), child: Icon(Icons.apps_rounded, color: p.ink2)),
          ),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Text('مرحباً', style: TextStyle(color: p.ink2, fontSize: 14)),
            Text(_name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(width: 12),
          Tap(
            onTap: () => showProfileSheet(context),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.line, width: 2)),
              child: CircleAvatar(radius: 24, backgroundColor: const Color(0xFFB5295F), child: Text(_name.characters.first.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600))),
            ),
          ),
        ]),
      );

  Widget _card(Pal p, Account a, double sway) {
    final b = repo.budgetFor(a);
    final spent = repo.spent(month.year, month.month, acc: a.id);
    final inc = repo.income(month.year, month.month, acc: a.id);
    final bs = repo.budgetSpent(b.id, month.year, month.month);
    final left = b.limit - bs;
    final frac = b.limit > 0 ? (bs / b.limit).clamp(0.0, 1.0) : 0.0;
    final warn = b.limit > 0 && bs / b.limit >= .8;
    Widget stat(String l, double v, {Color? c, bool plus = false}) => Expanded(
          child: Column(children: [
            Text(l, style: const TextStyle(color: Colors.white60, fontSize: 14)),
            const SizedBox(height: 4),
            CountText(v, dec: 0, prefix: plus ? '+' : '', style: TextStyle(color: c ?? Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
          ]),
        );
    Widget sq(IconData i, VoidCallback f) => Tap(onTap: f, child: Container(width: 46, height: 46, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .06), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)), child: Icon(i, color: Colors.white70, size: 20)));
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: p.dark, borderRadius: BorderRadius.circular(36), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 24, offset: const Offset(0, 12))]),
      child: Stack(children: [
        Positioned.fill(child: WaveFill(level: b.limit > 0 ? (1 - frac) * .55 : .18, color: warn ? const Color(0xFFD4543F) : p.acc, sway: sway)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(children: [
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                Text('المصروف · ${kMonths[month.month - 1]}', style: const TextStyle(color: Colors.white60, fontSize: 14)),
              ]),
              const Spacer(),
              sq(Icons.more_horiz_rounded, () => _accMenu(a)),
              sq(S.flag('hide') ? Icons.visibility_off_rounded : Icons.visibility_rounded, () => S.put('hide', !S.flag('hide'))),
              sq(Icons.event_rounded, () async {
                final r = await showMonthSheet(context, month);
                if (r != null) setState(() => month = r);
              }),
            ]),
            const Spacer(),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              CountText(spent, dec: 0, style: const TextStyle(color: Colors.white, fontSize: 60, fontWeight: FontWeight.w700, height: 1)),
              const SizedBox(width: 8),
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(curOf(S.cur).sym, style: const TextStyle(color: Colors.white70, fontSize: 20))),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: frac),
                    duration: const Duration(milliseconds: 1100),
                    curve: Curves.easeOutCubic,
                    builder: (c, v, _) => LinearProgressIndicator(value: v, minHeight: 8, backgroundColor: Colors.white24, valueColor: AlwaysStoppedAnimation(warn ? const Color(0xFFFF8A75) : Colors.white)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (a.last4.isNotEmpty)
                Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white24)), child: Text('•••• ${a.last4}', style: const TextStyle(color: Colors.white70, fontSize: 16))),
              const SizedBox(width: 10),
              Container(width: 44, height: 34, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFDDE3EE), Color(0xFF9DA9BD)]), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.memory_rounded, color: Colors.white70, size: 22)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              stat('دخل الشهر', inc, c: const Color(0xFF7BD3A6), plus: true),
              Container(width: 1, height: 36, color: Colors.white12),
              stat('المتبقي', b.limit > 0 ? left : 0),
              Container(width: 1, height: 36, color: Colors.white12),
              Expanded(child: Tap(onTap: () => showBudgetSheet(context, b), child: Column(children: [const Text('الميزانية', style: TextStyle(color: Colors.white60, fontSize: 14)), const SizedBox(height: 4), CountText(b.limit, dec: 0, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700))]))),
            ]),
          ]),
        ),
      ]),
    );
  }

  void _accMenu(Account a) => showSheet<void>(context, (c) {
        final p = Pal.of(c);
        Widget row(IconData i, String t, VoidCallback f) => Tap(onTap: () { Navigator.of(c).pop(); f(); }, child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(22)), child: Row(children: [Icon(i, color: p.ink2), const SizedBox(width: 14), Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))])));
        return SheetFrame(title: a.name, child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Column(mainAxisSize: MainAxisSize.min, children: [
          row(Icons.edit_rounded, 'تعديل الحساب', () => showAccountSheet(context, edit: a)),
          row(Icons.flag_rounded, 'تحديد الميزانية', () => showBudgetSheet(context, repo.budgetFor(a))),
          row(Icons.account_balance_wallet_rounded, 'حساباتي', () => Navigator.of(context).push(flowRoute(const AccountsPage()))),
        ])));
      });

  Widget _allowance(Pal p, Account a) {
    final b = repo.budgetFor(a);
    final now = DateTime.now();
    final days = daysIn(now.year, now.month) - now.day + 1;
    final al = repo.allowance(a, now);
    final spentPct = b.limit > 0 ? repo.budgetSpent(b.id, now.year, now.month) / b.limit : 0.0;
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(26), border: Border.all(color: p.line)),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: kInc.withValues(alpha: .14), shape: BoxShape.circle), child: const Icon(Icons.speed_rounded, color: kInc)),
          const SizedBox(width: 12),
          Expanded(
            child: b.limit > 0
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('متاح ${fmt(al < 0 ? 0 : al)} يوميًا', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Text('باقٍ ${toAr('$days')} يومًا', style: TextStyle(color: p.ink2, fontSize: 14)),
                  ])
                : Tap(onTap: () => showBudgetSheet(context, b), child: Text('حدّد ميزانية الشهر لتعرف المتاح يوميًا', style: TextStyle(color: p.ink2, fontSize: 15))),
          ),
          Container(width: 1, height: 32, color: p.line),
          Tap(
            onTap: () => _add(page: 1),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Row(children: [const Text('دخل', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), const SizedBox(width: 8), Container(width: 26, height: 26, decoration: BoxDecoration(color: kInc.withValues(alpha: .18), shape: BoxShape.circle), child: const Icon(Icons.add_rounded, size: 18, color: kInc))])),
          ),
        ]),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        child: S.flag('budgetAlerts', true) && spentPct >= .8
            ? Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFD4543F).withValues(alpha: .12), borderRadius: BorderRadius.circular(20)), child: Row(children: [const Icon(Icons.warning_amber_rounded, color: Color(0xFFD4543F)), const SizedBox(width: 10), Expanded(child: Text(spentPct >= 1 ? 'تجاوزت ميزانية الشهر!' : 'صرفت ${toAr('${(spentPct * 100).round()}')}٪ من ميزانية الشهر', style: const TextStyle(color: Color(0xFFD4543F), fontWeight: FontWeight.w600)))]))
            : const SizedBox(width: double.infinity),
      ),
    ]);
  }

  Widget _shortcuts(Pal p) {
    Widget t(IconData i, Color c, String l, VoidCallback f) => Expanded(
          child: Tap(
            onTap: f,
            child: Column(children: [
              Container(width: 70, height: 70, decoration: BoxDecoration(color: c.withValues(alpha: .13), borderRadius: BorderRadius.circular(24)), child: Icon(i, color: c, size: 30)),
              const SizedBox(height: 8),
              Text(l, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ]),
          ),
        );
    return Column(children: [
      Row(children: [
        const Text('اختصارات سريعة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const Spacer(),
        Tap(onTap: () => Navigator.of(context).push(flowRoute(const ToolsPage())), child: Row(children: [Text('المزيد', style: TextStyle(color: p.ink2, fontSize: 16)), Icon(Icons.chevron_right_rounded, color: p.ink2)])),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        t(Icons.file_download_rounded, const Color(0xFFC0392B), 'كشف', () => Navigator.of(context).push(flowRoute(const TxListPage(title: 'كشف الحساب')))),
        t(Icons.receipt_long_rounded, const Color(0xFF3B6FD4), 'فاتورة', () => _add(cat: 'bills')),
        t(Icons.mic_rounded, const Color(0xFF2E7568), 'تحدث', () => showSmartEntry(context)),
        t(Icons.lightbulb_rounded, const Color(0xFFC2306A), 'دوّن', () => showSmartEntry(context, quick: true)),
        t(Icons.auto_awesome_rounded, const Color(0xFF6D3FD0), 'فلو', () => Navigator.of(context).push(flowRoute(const FlowAIPage()))),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Live(b: (c) {
      final accs = repo.accList;
      if (ci >= accs.length) ci = accs.length - 1;
      final list = repo.allTx.take(8).toList();
      return ListView(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 16, 130),
        physics: const BouncingScrollPhysics(),
        children: [
          Reveal(i: 0, child: _header(p)),
          const SizedBox(height: 14),
          Reveal(
            i: 1,
            child: SizedBox(
              height: 304,
              child: PageView.builder(
                controller: pc,
                itemCount: accs.length,
                onPageChanged: (i) {
                  setState(() => ci = i);
                  tick();
                },
                itemBuilder: (c, i) => CardTilt(pc: pc, i: i, builder: (d) => _card(p, accs[i], d)),
              ),
            ),
          ),
          if (accs.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (var i = 0; i < accs.length; i++) AnimatedContainer(duration: const Duration(milliseconds: 300), margin: const EdgeInsets.symmetric(horizontal: 3), width: i == ci ? 22 : 7, height: 7, decoration: BoxDecoration(color: i == ci ? p.ink : p.line, borderRadius: BorderRadius.circular(5)))]),
            ),
          const SizedBox(height: 6),
          Reveal(i: 2, child: _allowance(p, accs[ci])),
          const SizedBox(height: 26),
          Reveal(i: 3, child: _shortcuts(p)),
          const SizedBox(height: 28),
          Reveal(
            i: 4,
            child: Row(children: [
              const Text('المعاملات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const Spacer(),
              Tap(onTap: () => Navigator.of(context).push(flowRoute(const TxListPage())), child: Row(children: [Text('عرض الكل', style: TextStyle(color: p.ink2, fontSize: 16)), Icon(Icons.chevron_right_rounded, color: p.ink2)])),
            ]),
          ),
          const SizedBox(height: 6),
          if (list.isEmpty)
            emptyState(p, Icons.toll_rounded, 'لا معاملات بعد.\nاضغط + لتضيف أول مصروف وشاهد البطاقة تتفاعل.')
          else
            for (var i = 0; i < list.length; i++) Reveal(i: 5 + i, child: SwipeTx(list[i], onEdit: (t) => Navigator.of(context).push(flowRoute(AddTxPage(edit: t))))),
          if (list.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Center(child: Text('← اسحب المعاملة للتعديل أو الحذف →', style: TextStyle(color: p.ink2.withValues(alpha: .6), fontSize: 12)))),
        ],
      );
    });
  }
}
