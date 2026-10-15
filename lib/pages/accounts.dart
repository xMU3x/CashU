import 'package:flutter/material.dart';
import '../core/currency.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/util.dart';
import '../ui/anim.dart';
import '../ui/sheets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'more_pages.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});
  @override
  State<AccountsPage> createState() => _AccountsState();
}

class _AccountsState extends State<AccountsPage> {
  final pc = PageController(viewportFraction: .84);
  int idx = 0;
  static const tints = [Color(0xFFE4EAF4), Color(0xFFF1E6DD), Color(0xFFDDEFE6), Color(0xFFEBDDF1)];

  @override
  void dispose() {
    pc.dispose();
    super.dispose();
  }

  Widget _accCard(Pal p, Account a, int i, double d) {
    final tint = tints[i % tints.length];
    return Transform.translate(
      offset: Offset(0, d.abs() * 26),
      child: Transform.rotate(
        angle: d * .06,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(34)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1B1B1B))),
                Text(a.kind == 'cash' ? 'نقدي' : a.kind == 'wallet' ? 'محفظة' : 'حساب بنكي', style: const TextStyle(color: Color(0xFF6E6E73), fontSize: 15)),
              ]),
              const Spacer(),
              bankIcon(a.kind, size: 56),
            ]),
            const SizedBox(height: 26),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              CountText(repo.bal(a.id), dec: 0, style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w800, color: Color(0xFF1B1B1B), height: 1)),
              const SizedBox(width: 8),
              Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(curOf(S.cur).sym, style: const TextStyle(fontSize: 18, color: Color(0xFF6E6E73)))),
            ]),
            const Spacer(),
            Row(children: [
              if (a.last4.isNotEmpty) Text('•••• ${a.last4}', style: const TextStyle(color: Color(0xFF6E6E73), fontSize: 17)),
              const Spacer(),
              if (a.showBud) const Text('معروض على البطاقة', style: TextStyle(color: Color(0xFF3B6FD4), fontSize: 15, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _wallet(Pal p, List<Account> accs) => SizedBox(
        height: 420,
        child: Stack(children: [
          Positioned(left: 8, right: 8, bottom: 0, height: 300, child: Container(decoration: BoxDecoration(color: p.dark, borderRadius: BorderRadius.circular(40)))),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 270,
            child: PageView.builder(
              controller: pc,
              itemCount: accs.length,
              onPageChanged: (i) {
                setState(() => idx = i);
                tick();
              },
              itemBuilder: (c, i) => CardTilt(pc: pc, i: i, builder: (d) => _accCard(p, accs[i], i, d)),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 0,
            height: 200,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(color: p.dark, borderRadius: BorderRadius.circular(40)),
                child: Padding(padding: const EdgeInsets.all(14), child: CustomPaint(painter: DashPainter(Colors.white24, 30), child: const SizedBox.expand())),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                CountText(repo.totalBal, dec: 0, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(curOf(S.cur).sym, style: const TextStyle(color: Colors.white70, fontSize: 18))),
              ]),
              const Text('إجمالي أموالك', style: TextStyle(color: Colors.white60, fontSize: 17)),
              const SizedBox(height: 8),
              Tap(onTap: () => S.put('hide', !S.flag('hide')), child: Padding(padding: const EdgeInsets.all(8), child: Icon(S.flag('hide') ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white54))),
            ]),
          ),
        ]),
      );

  Widget _stat(Pal p, String l, double v, {String? sub}) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: p.field.withValues(alpha: .7), borderRadius: BorderRadius.circular(26)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l, style: TextStyle(color: p.ink2, fontSize: 16)),
            CountText(v, dec: 0, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
            if (sub != null) Text(sub, style: TextStyle(color: p.ink2, fontSize: 15)),
          ]),
        ),
      );

  Widget _row(Pal p, IconData i, String t, String? s, VoidCallback f) => Column(children: [
        Tap(
          onTap: f,
          scale: .98,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
            child: Row(children: [
              Icon(i, color: p.ink2),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)), if (s != null) Text(s, style: TextStyle(color: p.ink2, fontSize: 15))])),
              Icon(Icons.chevron_left_rounded, color: p.ink2),
            ]),
          ),
        ),
        Divider(color: p.line, height: 1),
      ]);

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: 'حساباتي',
      icon: Icons.account_balance_wallet_rounded,
      iconColor: const Color(0xFF5B8DEF),
      trailing: RoundBtn(Icons.add_rounded, () => showAccountSheet(context)),
      child: Live(b: (c) {
        final accs = repo.accList;
        if (idx >= accs.length) idx = accs.length - 1;
        final a = accs[idx];
        final b = repo.budgetFor(a);
        final now = DateTime.now();
        final spent = repo.spent(now.year, now.month, acc: a.id);
        final bs = repo.budgetSpent(b.id, now.year, now.month);
        return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), physics: const BouncingScrollPhysics(), children: [
          Reveal(i: 0, child: _wallet(p, accs)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (var i = 0; i < accs.length; i++) AnimatedContainer(duration: const Duration(milliseconds: 300), margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 12), width: i == idx ? 24 : 8, height: 8, decoration: BoxDecoration(color: i == idx ? p.ink : p.line, borderRadius: BorderRadius.circular(5)))]),
          Reveal(i: 2, child: Row(children: [_stat(p, 'الميزانية', b.limit - bs < 0 ? 0 : b.limit - bs, sub: 'متبقٍ من ${fmt(b.limit, dec: 0)}'), const SizedBox(width: 12), _stat(p, 'مصروف الشهر', spent)])),
          const SizedBox(height: 16),
          Reveal(i: 3, child: _row(p, Icons.speed_rounded, 'ميزانيات الحساب', b.name, () => showBudgetSheet(context, b))),
          Reveal(i: 4, child: _row(p, Icons.info_rounded, 'كشف الشهر', null, () => Navigator.of(context).push(flowRoute(TxListPage(accId: a.id, title: a.name))))),
          Reveal(i: 5, child: _row(p, Icons.edit_rounded, 'تعديل الحساب', null, () => showAccountSheet(context, edit: a))),
          Reveal(
            i: 6,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('اعرض الميزانية على البطاقة', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)), Text('بطاقة الشاشة الرئيسية تعرض المصروف والمتبقي بدل الرصيد الحالي.', style: TextStyle(color: p.ink2, fontSize: 15, height: 1.5))])),
                Switch(value: a.showBud, activeTrackColor: const Color(0xFFD94F8B), activeThumbColor: Colors.white, onChanged: (v) {
                  a.showBud = v;
                  repo.saveAccount(a);
                }),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Tap(
              onTap: () async {
                final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('حذف الحساب'), content: Text('سيُحذف حساب «${a.name}». المعاملات تبقى في السجل.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف', style: TextStyle(color: Color(0xFFC0392B))))]));
                if (ok == true) {
                  if (!repo.deleteAccount(a.id)) toast(context, 'لا يمكن حذف آخر حساب');
                }
              },
              child: const Padding(padding: EdgeInsets.all(14), child: Text('حذف الحساب', style: TextStyle(color: Color(0xFFC0392B), fontSize: 19, fontWeight: FontWeight.w600))),
            ),
          ),
        ]);
      }),
    );
  }
}
