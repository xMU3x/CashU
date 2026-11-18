import '../ui/motion.dart';
import 'package:material_ui/material_ui.dart' hide Text;
import '../ui/loc_text.dart';
import '../core/currency.dart';
import 'acc_tx.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/util.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/pickers.dart';
import '../ui/pay_widgets.dart';
import '../ui/sheets.dart';
import '../ui/sort_btn.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

// ======================= السلف والديون (تصميم جديد) =======================
String _money(Loan l, double v) => '${fmt(v)} ${curOf(l.cur).sym}';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// وصف الاستحقاق: مستحقة اليوم / بعد ٣ أيام / متأخرة ٢ يوم / بدون موعد.
String _dueText(Loan l) {
  if (l.settled) return 'مسدد بالكامل';
  if (l.due <= 0) return 'بدون موعد سداد';
  final d = _day(DateTime.fromMillisecondsSinceEpoch(l.due)).difference(_day(DateTime.now())).inDays;
  if (d == 0) return 'مستحقة اليوم';
  if (d > 0) return d == 1 ? 'مستحقة بكرة' : 'مستحقة خلال $d أيام';
  return 'متأخرة ${-d} ${-d == 1 ? 'يوم' : 'يوم'}';
}

Color _dueColor(Loan l, Pal p) {
  if (l.settled || l.due <= 0) return p.ink2;
  final d = _day(DateTime.fromMillisecondsSinceEpoch(l.due)).difference(_day(DateTime.now())).inDays;
  return d < 0 ? kRed : (d == 0 ? kOrange : p.ink2);
}

Widget _chip(Pal p, String t, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: c.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)),
      child: Text(t, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c)),
    );

String _status(Loan l) => l.settled ? 'مسدد' : (l.partial ? 'مسدد جزئيًا' : 'غير مسدد');
Color _statusColor(Loan l, Pal p) => l.settled ? kGreen : (l.partial ? kOrange : p.ink2);

class LoansPage extends StatefulWidget {
  const LoansPage({super.key});
  @override
  State<LoansPage> createState() => _LoansState();
}

class _LoansState extends State<LoansPage> {
  int gen = 0;

  static void _applyRemove(Loan l, RemoveChoice r) {
    switch (r) {
      case RemoveChoice.everything:
        repo.delLoan(l);
      case RemoveChoice.serviceOnly:
        repo.delLoan(l, withTx: false);
      case RemoveChoice.finish:
        repo.finishLoan(l);
    }
  }

  Future<void> _delete(Loan l) async {
    final r = await askRemove(context, l.person, canFinish: l.settled || l.left < 0.005);
    if (r != null) _applyRemove(l, r);
    if (mounted) setState(() => gen++);
  }

  Widget _card(Pal p, Loan l) {
    final inn = l.dir == 'owed';
    final col = inn ? kGreen : kRed;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Row(children: [
        iconBubble(p, inn ? Icons.south_west_rounded : Icons.north_east_rounded, color: col, size: 40),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.person, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(_dueText(l), style: TextStyle(fontSize: 12.5, color: _dueColor(l, p))),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_money(l, l.settled ? l.total : l.left), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: l.settled ? p.ink2 : p.ink)),
          const SizedBox(height: 4),
          _chip(p, _status(l), _statusColor(l, p)),
        ]),
      ]),
      ]),
    );
  }

  Widget _row(Pal p, Loan l) => Reveal(
        i: 1,
        child: SwipeRow(
          key: ValueKey('${l.id}_$gen'),
          bg: p.bg,
          rightW: 96,
          rightActions: swipeCircle(Icons.check_rounded, 'سداد', kGreen, () {
            setState(() => gen++);
            showLoanPaySheet(context, l);
          }),
          leftW: 96,
          leftActions: swipeCircle(Icons.delete_outline_rounded, 'حذف', kRed, () => _delete(l)),
          // سحب لآخر السطر ينفّذ الأمر علطول: سداد / حذف.
          onFullRight: () {
            setState(() => gen++);
            showLoanPaySheet(context, l);
          },
          onFullLeft: () => _delete(l),
          child: Tap(scale: .99, onTap: () => Navigator.of(context).push(flowRoute(LoanDetailPage(id: l.id))), child: _card(p, l)),
        ),
      );

  /// لوحة علوية بنفس لغة صفحة الجمعيات/الاشتراكات: كارت بحد + عنوان وخط صغير + رقم كبير + عمودين.
  Widget _totalsPanel(Pal p, double owedToMe, double iOwe, List<Loan> all) {
    final net = owedToMe - iOwe;
    final col = net > 0.5 ? kGreen : (net < -0.5 ? kRed : p.ink2);
    final today = _day(DateTime.now());
    final late = all.where((l) => !l.settled && l.due > 0 && _day(DateTime.fromMillisecondsSinceEpoch(l.due)).isBefore(today)).length;
    final open = all.where((l) => !l.settled).length;
    String v(double x) => S.flag('hide') ? '••••' : egp(x);
    Widget cell(String label, double x, Color c) => Expanded(
          child: Column(children: [
            Text(label, style: TextStyle(fontSize: 13, color: p.ink2)),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, child: Text(v(x), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c))),
          ]),
        );
    // شريط تقدم خفيف: نسبة «ديون ليا» من إجمالي المفتوح (أخضر) مقابل «ديون عليا» (أحمر).
    final tot = owedToMe + iOwe;
    final frac = tot <= 0 ? .5 : (owedToMe / tot).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.line)),
      child: Column(children: [
        // صافي المستحقات: العنوان في النص وتحته المبلغ في النص
        Text('صافي المستحقات', style: TextStyle(fontSize: 13.5, color: p.ink2)),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, child: Text(v(net.abs()), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: net.abs() < .5 ? p.ink : col))),
        const SizedBox(height: 2),
        Text(net > 0.5 ? 'الناس مديونة لك بالصافي' : (net < -0.5 ? 'إنت مديون بالصافي' : 'حسابك متعادل'), style: TextStyle(fontSize: 12.5, color: p.ink2)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: frac),
            duration: CashUMotion.expand,
            curve: CashUMotion.curve,
            builder: (c, x, _) => LinearProgressIndicator(value: x, minHeight: 4, backgroundColor: kRed.withValues(alpha: .55), valueColor: AlwaysStoppedAnimation(kGreen.withValues(alpha: .85))),
          ),
        ),
        const SizedBox(height: 12),
        // «ديون ليا» و«ديون عليا» بنفس الأماكن والتقسيمة
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            cell('ديون ليا', owedToMe, kGreen),
            VerticalDivider(color: p.line, width: 1, thickness: 1.2),
            cell('ديون عليا', iOwe, kRed),
          ]),
        ),
        if (late > 0) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${toAr('$late')} متأخرة في السداد', style: TextStyle(fontSize: 13, color: kRed))),
        if (late == 0 && open > 0) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${toAr('$open')} مستحق مفتوح', style: TextStyle(fontSize: 13, color: p.ink2))),
      ]),
    );
  }

  /// عنوان مجموعة (ديون ليا / ديون عليا) بخط فاصل وإجماليها.
  Widget _groupHeader(Pal p, String t, Color c, double total) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 20, 6, 8),
        child: Row(children: [
          Container(width: 5, height: 22, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 10),
          Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Spacer(),
          Text(S.flag('hide') ? '••••' : egp(total), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c)),
        ]),
      );

  /// الترتيب الافتراضي: غير المسدد أولًا ثم الأقرب استحقاقًا. لو اخترت ترتيب (محفوظ) بيتطبّق جوه كل مجموعة والمسدد يفضل آخرها.
  List<Loan> _group(String d) {
    // المسدّد بالكامل بيختفي من القائمة (ويرجع لو حذفت معاملة السداد أو تراجعت عنه).
    final l = repo.loanList.where((x) => x.dir == d && !x.hidden && !x.settled).toList();
    final key = savedSort('sortLoans');
    if (key == 'none') {
      return l
        ..sort((a, b) {
          if (a.settled != b.settled) return a.settled ? 1 : -1;
          final ad = a.due <= 0 ? 1 << 60 : a.due, bd = b.due <= 0 ? 1 << 60 : b.due;
          return ad.compareTo(bd);
        });
    }
    int? dt(Loan x) => x.due > 0 ? x.due : null;
    double am(Loan x) => x.settled ? x.total : x.left;
    return [
      ...applySort<Loan>(l.where((x) => !x.settled).toList(), key, date: dt, amt: am),
      ...applySort<Loan>(l.where((x) => x.settled).toList(), key, date: dt, amt: am),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: Live(b: (c) {
          final owed = _group('owed');
          final owe = _group('owe');
          double open(List<Loan> l) => l.where((x) => !x.settled).fold(0.0, (s, x) => s + x.leftBase);
          return BlurEdges(
            top: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: TopBar(
                title: 'مستحقاتي',
                icon: Icons.handshake_rounded,
                iconColor: kBlue,
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  sortButton(context, prefKey: 'sortLoans', bg: p.field, fg: p.ink2, onChanged: () => setState(() {})),
                  const SizedBox(width: 8),
                  Tap(
                    onTap: () => Navigator.of(context).push(sheetRoute(const LoanFormPage(dir: 'owed'))),
                    child: Container(width: 40, height: 40, decoration: BoxDecoration(color: p.acc, shape: BoxShape.circle), child: const Icon(Icons.add_rounded, color: Colors.white, size: 24)),
                  ),
                ]),
              ),
            ),
            body: (c2, inset) => ListView(padding: EdgeInsets.fromLTRB(16, inset.top + 4, 16, 120), physics: const BouncingScrollPhysics(), children: [
                Reveal(i: 0, child: _totalsPanel(p, open(owed), open(owe), [...owed, ...owe])),
                // الأقسام الفاضية ما بتظهرش: القسم يظهر بس لو فيه معاملات فعلًا.
                if (owed.isNotEmpty) ...[
                  _groupHeader(p, 'ديون ليا', kGreen, open(owed)),
                  for (final l in owed) _row(p, l),
                ],
                if (owed.isNotEmpty && owe.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Divider(color: p.line, height: 28, thickness: 1.2),
                ],
                if (owe.isNotEmpty) ...[
                  _groupHeader(p, 'ديون عليا', kRed, open(owe)),
                  for (final l in owe) _row(p, l),
                ],
                if (owed.isEmpty && owe.isEmpty) emptyState(p, Icons.handshake_rounded, 'مفيش مستحقات لسه'),
                if (owed.isNotEmpty || owe.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Center(child: Text('اسحب ناحية لتسجيل السداد وناحية للحذف', style: TextStyle(color: p.ink2.withValues(alpha: .7), fontSize: 12)))),
              ]),
          );
        }),
    );
  }
}

/// تراجع عن سداد [index] (بعد تأكيد): يلغي الدفعة وتتحذف معاملتها من المعاملات (لو التطبيق سجّلها) ويرجع المبلغ على المتبقي.
Future<void> undoLoanPay(BuildContext context, Loan l, int index) async {
  if (index < 0 || index >= l.pays.length) return;
  final pay = l.pays[index];
  final own = pay.tx.startsWith('lp_');
  final ok = await confirmDialog(
    context,
    'تراجع عن السداد',
    'هيتلغي السداد (${_money(l, pay.amt)}) ويرجع المبلغ على المتبقي${own ? '، وتتحذف معاملته من المعاملات' : ''}.',
    ok: 'تراجع',
    cancel: 'إلغاء',
    danger: false,
  );
  if (!ok) return;
  repo.removeLoanPay(l, index);
  if (context.mounted) toast(context, 'تم التراجع عن السداد');
}

// ======================= نافذة تسجيل سداد =======================
Future<void> showLoanPaySheet(BuildContext context, Loan l) async {
  Widget tile(Pal p, IconData ic, Color col, String t, String sub, VoidCallback f) => Tap(
        scale: .98,
        onTap: f,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(26)),
          child: Row(children: [
            Icon(Icons.chevron_left_rounded, color: p.ink2),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(fontSize: 13.5, color: p.ink2)),
            ])),
            const SizedBox(width: 10),
            iconBubble(p, ic, color: col, size: 48),
          ]),
        ),
      );

  await showSheet<void>(context, (c) {
    final p = Pal.of(c);
    return SheetFrame(
      title: 'تسجيل سداد',
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 18), children: [
        tile(p, Icons.check_rounded, kGreen, 'سداد كامل', 'يسدد المتبقي بالكامل: ${_money(l, l.left)}', () async {
          Navigator.of(c).pop();
          final acc = await _pickPayAcc(context, l, l.left);
          if (acc == null || !context.mounted) return;
          repo.settleLoan(l, acc: acc);
          toast(context, 'تم تسجيل السداد');
        }),
        tile(p, Icons.payments_outlined, kOrange, 'سداد جزئي', 'سجّل ما تم دفعه الآن، ويبقى الباقي على الدين', () async {
          Navigator.of(c).pop();
          final r = await _askLoanAmt(context, l, title: l.dir == 'owed' ? 'استلام دفعة' : 'سداد دفعة', cta: 'تسجيل', color: kGreen, max: l.left);
          if (r == null || !context.mounted) return;
          repo.payLoan(l, r.amt, acc: r.acc, when: r.when, noTx: r.acc.isEmpty, note: r.note);
          if (context.mounted) toast(context, 'تم تسجيل ${_money(l, r.amt > l.total ? l.total : r.amt)}');
        }),
        tile(p, Icons.receipt_long_rounded, kBlue, 'ربط معاملة', 'استخدم معاملة مسجلة بالفعل', () async {
          Navigator.of(c).pop();
          final t = await _pickTx(context, l);
          if (t == null) return;
          repo.payLoan(l, t.amt, txId: t.id, when: t.date);
          if (context.mounted) toast(context, 'تم ربط المعاملة');
        }),
      ]),
    );
  });
}

/// بانل اختيار الحساب اللي هيتسجل عليه مبلغ السداد (كامل أو جزئي).
Future<String?> _pickPayAcc(BuildContext context, Loan l, double amt) => showPickAccount(
      context,
      l.acc.isEmpty ? repo.defaultAcc : l.acc,
      title: '${l.dir == 'owed' ? 'استلام' : 'دفع'} ${_money(l, amt)} — على أي حساب؟',
    );

/// ربط معاملة: بيفتح صفحة المعاملات الكاملة (بحث + شهور) والضغط على معاملة بيختارها.
Future<Tx?> _pickTx(BuildContext context, Loan l) {
  final want = l.dir == 'owed' ? 'inc' : 'exp'; // سداد دين لك = دخل · سداد دين عليك = مصروف
  return Navigator.of(context).push<Tx>(flowRoute(AccountTxPage(pick: true, pickWhere: (t) => t.type == want && t.loan.isEmpty && !t.pend)));
}

// ======================= تفاصيل الدين =======================
class LoanDetailPage extends StatefulWidget {
  final String id;
  const LoanDetailPage({super.key, required this.id});
  @override
  State<LoanDetailPage> createState() => _LoanDetailState();
}

class _LoanDetailState extends State<LoanDetailPage> {
  Loan? get _l {
    for (final x in repo.loanList) {
      if (x.id == widget.id) return x;
    }
    return null;
  }

  /// صف تفاصيل مصغّر وعصري: أيقونة في دايرة صغيرة + عنوان خفيف + قيمة، من غير عنوان كبير للبانل.
  Widget _detailRow(Pal p, IconData ic, String k, String v, {bool last = false}) => Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(children: [
            Container(width: 28, height: 28, decoration: BoxDecoration(color: p.field, shape: BoxShape.circle), child: Icon(ic, color: p.ink2, size: 15)),
            const SizedBox(width: 10),
            Text(k, style: TextStyle(fontSize: 13.5, color: p.ink2)),
            const SizedBox(width: 12),
            Expanded(child: Text(v, textAlign: TextAlign.end, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
          ]),
        ),
        if (!last) hair(p),
      ]);

  Widget _bigBtn(String t, IconData ic, Color c, VoidCallback f) => Tap(
        onTap: f,
        child: Container(height: 56, alignment: Alignment.center, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(28)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(ic, color: Colors.white, size: 21), const SizedBox(width: 8), Text(t, maxLines: 1, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white))])),
      );

  String _accOf(String txId) {
    final t = txId.isEmpty ? null : repo.tx(txId);
    return t == null ? '' : (repo.account(t.acc)?.name ?? '');
  }

  List<PayEntry> _entries(BuildContext context, Loan l) {
    final out = <PayEntry>[];
    for (var i = 0; i < l.pays.length; i++) {
      final x = l.pays[i];
      out.add(PayEntry(
        ts: x.ts,
        amt: x.amt,
        accName: _accOf(x.tx),
        linked: x.tx.isNotEmpty && !x.tx.startsWith('lp_'),
        note: x.note.isNotEmpty ? 'سداد · ${x.note}' : 'سداد',
        onMore: () => showPillMenu(context, [
          ('تراجع عن السداد', () => undoLoanPay(context, l, i)),
          ('حذف', () async {
            if (await confirmDialog(context, 'حذف دفعة', 'هتتحذف الدفعة وتتزود على المتبقي.')) repo.removeLoanPay(l, i);
          }),
        ], danger: {'حذف'}),
      ));
    }
    for (var i = 0; i < l.adds.length; i++) {
      final x = l.adds[i];
      out.add(PayEntry(
        ts: x.ts,
        amt: x.amt,
        plus: true,
        accName: _accOf(x.tx),
        note: (l.dir == 'owed' ? 'سلّفته تاني' : 'دين جديد') + (x.note.isNotEmpty ? ' · ${x.note}' : ''),
        onMore: () => showPillMenu(context, [
          ('حذف', () async {
            if (await confirmDialog(context, 'حذف إضافة', 'هتتشال الإضافة من إجمالي الدين${x.tx.startsWith('la_') ? ' وتتحذف معاملتها' : ''}.')) repo.removeLoanAdd(l, i);
          }),
        ], danger: {'حذف'}),
      ));
    }
    out.sort((a, b) => b.ts.compareTo(a.ts));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: Live(b: (c) {
        final l = _l;
        if (l == null) {
          return SafeArea(child: Column(children: [Padding(padding: const EdgeInsets.all(16), child: Row(children: [GlassBtn(Icons.chevron_left_rounded, () => Navigator.of(context).maybePop(), size: 46)])), Expanded(child: emptyState(p, Icons.search_off_rounded, 'الدين ده اتحذف'))]));
        }
        final inn = l.dir == 'owed';
        final col = inn ? kGreen : kRed;
        final remText = l.rem.isEmpty ? 'بدون تذكير' : (l.rem.toList()..sort()).map((d) => d == 0 ? 'يوم الاستحقاق' : (d == 1 ? 'قبل يوم واحد' : 'قبل $d أيام')).join('، ');
        return BlurEdges(
          top: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(children: [
                GlassBtn(Icons.chevron_left_rounded, () => Navigator.of(context).maybePop(), size: 46),
                const Spacer(),
                Glass(
                  radius: 26,
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Tap(onTap: () => Navigator.of(context).push(sheetRoute(LoanFormPage(edit: l, dir: l.dir))), child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.edit_outlined, color: p.ink, size: 22))),
                    Tap(
                      onTap: () async {
                        final r = await askRemove(context, l.person, canFinish: l.settled || l.left < 0.005);
                        if (r != null) {
                          _LoansState._applyRemove(l, r);
                          if (context.mounted) Navigator.of(context).maybePop();
                        }
                      },
                      child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.delete_outline_rounded, color: kRed, size: 22)),
                    ),
                  ]),
                ),
              ]),
            ),
          bottom: Padding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, 16 + MediaQuery.of(context).padding.bottom),
              child: Row(children: [
                if (!l.settled) ...[
                  Expanded(child: _bigBtn('سداد', Icons.check_rounded, kGreen, () => showLoanPaySheet(context, l))),
                  const SizedBox(width: 10),
                ],
                Expanded(child: _bigBtn(inn ? 'سلّفته تاني' : 'دين جديد', Icons.add_rounded, kBlue, () => showLoanAddSheet(context, l))),
              ]),
            ),
          body: (c2, inset) => ListView(padding: EdgeInsets.fromLTRB(16, inset.top + 10, 16, inset.bottom + 20), physics: const BouncingScrollPhysics(), children: [
                Center(child: iconBubble(p, inn ? Icons.south_west_rounded : Icons.north_east_rounded, color: col, size: 96)),
                const SizedBox(height: 14),
                Center(child: Text(l.person, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700))),
                const SizedBox(height: 4),
                Center(child: Text(_money(l, l.settled ? l.total : l.left), style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800))),
                if (l.pays.isNotEmpty || l.settled) ...[
                  const SizedBox(height: 14),
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: l.total <= 0 ? 0 : (l.paid / l.total).clamp(0.0, 1.0), minHeight: 8, backgroundColor: p.field, valueColor: AlwaysStoppedAnimation(kGreen))),
                  const SizedBox(height: 8),
                  Row(children: [
                    Text('تم سداد ${_money(l, l.paid)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('من أصل ${_money(l, l.total)}', style: TextStyle(color: p.ink2)),
                  ]),
                ],
                const SizedBox(height: 10),
                Center(child: Text(_dueText(l), style: TextStyle(fontSize: 16, color: _dueColor(l, p)))),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (l.partial || l.settled) ...[_chip(p, _status(l), _statusColor(l, p)), const SizedBox(width: 8)],
                  _chip(p, inn ? 'ديون ليا' : 'ديون عليا', p.ink2),
                ]),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22)),
                  child: Column(children: [
                    _detailRow(p, Icons.event_outlined, 'تاريخ السداد', l.due <= 0 ? '—' : enDate(DateTime.fromMillisecondsSinceEpoch(l.due))),
                    _detailRow(p, Icons.notifications_none_rounded, 'تذكير', remText),
                    _detailRow(p, Icons.pie_chart_outline_rounded, 'احتسابه في صافي الثروة', l.nw ? 'محتسب' : 'غير محتسب'),
                    if (l.note.isNotEmpty) _detailRow(p, Icons.notes_rounded, 'الوصف', l.note),
                    _detailRow(p, Icons.schedule_rounded, 'تاريخ الإضافة', enDate(DateTime.fromMillisecondsSinceEpoch(l.ts)), last: true),
                  ]),
                ),
                if (l.pays.isNotEmpty || l.adds.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                    decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22)),
                    child: PayLog(title: 'سجل الدفعات', startOpen: true, entries: _entries(context, l)),
                  ),
                ],
              ]),
        );
      }),
    );
  }
}

// ======================= إضافة / تعديل دين =======================
class LoanFormPage extends StatefulWidget {
  final Loan? edit;
  final String dir;
  const LoanFormPage({super.key, this.edit, this.dir = 'owed'});
  @override
  State<LoanFormPage> createState() => _LoanFormState();
}

class _LoanFormState extends State<LoanFormPage> {
  late String dir = widget.dir;
  final nameC = TextEditingController(), noteC = TextEditingController();
  double amt = 0;
  String cur = S.cur, acc = '';
  DateTime? due;
  DateTime when = DateTime.now(); // تاريخ ووقت إنشاء السلفة/الدين
  bool remind = true, nw = true, rec = true;
  final days = <int>{1};
  bool bad = false;

  @override
  void initState() {
    super.initState();
    acc = '';
    final e = widget.edit;
    if (e != null) {
      dir = e.dir;
      nameC.text = e.person;
      noteC.text = e.note;
      amt = e.amt;
      cur = e.cur;
      acc = e.acc;
      rec = e.rec;
      when = DateTime.fromMillisecondsSinceEpoch(e.ts);
      due = e.due > 0 ? DateTime.fromMillisecondsSinceEpoch(e.due) : null;
      nw = e.nw;
      remind = e.rem.isNotEmpty;
      days
        ..clear()
        ..addAll(e.rem.isEmpty ? {1} : e.rem);
    } else {
      due = DateTime.now().add(const Duration(days: 7));
    }
  }

  @override
  void dispose() {
    nameC.dispose();
    noteC.dispose();
    super.dispose();
  }

  void _save() {
    final name = nameC.text.trim();
    if (name.isEmpty || amt <= 0 || (rec && acc.isEmpty)) {
      setState(() => bad = true);
      return;
    }
    final rem = (remind && due != null) ? (days.toList()..sort()) : <int>[];
    final e = widget.edit;
    if (e == null) {
      repo.addLoan(Loan(
        id: uid(), dir: dir, person: name, amt: amt, cur: cur, rate: rates.rate(cur, S.cur), acc: acc,
        due: due?.millisecondsSinceEpoch ?? 0, note: noteC.text.trim(), ts: when.millisecondsSinceEpoch, nw: nw, rec: rec, rem: rem,
      ));
    } else {
      e
        ..dir = dir
        ..person = name
        ..amt = amt
        ..cur = cur
        ..rate = rates.rate(cur, S.cur)
        ..acc = acc
        ..due = due?.millisecondsSinceEpoch ?? 0
        ..note = noteC.text.trim()
        ..ts = when.millisecondsSinceEpoch
        ..nw = nw
        ..rec = rec
        ..rem = rem;
      if (e.left < 0.005 && e.pays.isNotEmpty) e.settled = true;
      repo.saveLoan(e);
    }
    Navigator.of(context).pop();
  }

  /// خطوط النماذج: أبيض وبولد (في الفاتح بنستخدم لون النص الأساسي عشان يفضل مقروء).
  Color get _wc => Theme.of(context).brightness == Brightness.dark ? Colors.white : Pal.of(context).ink;
  TextStyle _ts(double size, {FontWeight w = FontWeight.w700, double a = 1}) => TextStyle(fontSize: size, fontWeight: w, color: _wc.withValues(alpha: a));




  // ---- مكوّنات الشكل الجديد (زي صفحة «إضافة سلفة»): كروت منفصلة بأيقونة في البداية ----
  Widget _sec(Pal p, String t) => Padding(padding: const EdgeInsets.fromLTRB(8, 18, 8, 10), child: Text(t, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.ink2)));

  Widget _row(Pal p, IconData ic, {required Widget child, VoidCallback? onTap, bool err = false, double minH = 60}) => Tap(
        scale: onTap == null ? 1 : .99,
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: minH),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22), border: err ? Border.all(color: kRed, width: 1.4) : null),
          child: Row(children: [Icon(ic, color: p.ink2, size: 24), const SizedBox(width: 14), Expanded(child: child)]),
        ),
      );

  Widget _two(Pal p, String small, String value, {Color? vc}) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(small, style: TextStyle(fontSize: 13, color: p.ink2)),
        const SizedBox(height: 2),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: vc)),
      ]);

  Widget _switchRow(Pal p, IconData ic, String title, String sub, bool v, ValueChanged<bool> f, {Widget? extra}) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(ic, color: p.ink2, size: 24),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              if (sub.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, style: TextStyle(fontSize: 13, color: p.ink2, height: 1.35))),
            ])),
            Switch(value: v, onChanged: f, activeThumbColor: Colors.white, activeTrackColor: kGreen),
          ]),
          if (extra != null) extra,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final editing = widget.edit != null;
    final inn = dir == 'owed';
    return Scaffold(
      backgroundColor: p.bg,
      body: SheetPage(
        child: Column(children: [
          // ترويسة: كبسولة بعنوان وزر رجوع في البداية
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Glass(
              radius: 30,
              padding: const EdgeInsets.fromLTRB(8, 8, 18, 8),
              child: Row(children: [
                GlassBtn(Icons.arrow_forward_rounded, () => Navigator.of(context).pop(), size: 44),
                const SizedBox(width: 12),
                Expanded(child: Text(editing ? (inn ? 'تعديل سلفة' : 'تعديل دين') : (inn ? 'إضافة سلفة' : 'إضافة دين'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
              ]),
            ),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 24), physics: const BouncingScrollPhysics(), children: [
              Row(children: [
                Expanded(child: _dirBtn(p, 'ليّا فلوس', Icons.south_west_rounded, inn, kGreen, () => setState(() => dir = 'owed'))),
                const SizedBox(width: 10),
                Expanded(child: _dirBtn(p, 'عليّا فلوس', Icons.north_east_rounded, !inn, kRed, () => setState(() => dir = 'owe'))),
              ]),
              _sec(p, 'التفاصيل'),
              _row(p, Icons.person_outline_rounded, err: bad && nameC.text.trim().isEmpty, child: TextField(controller: nameC, style: _ts(17), decoration: InputDecoration(border: InputBorder.none, isDense: true, hintText: 'اسم الشخص', hintStyle: TextStyle(fontSize: 17, color: p.ink2)))),
              _row(p, Icons.payments_outlined, err: bad && amt <= 0, onTap: () async {
                final r = await showCalc(context, amt, cur);
                if (r != null) setState(() => amt = r < 0 ? 0 : r);
              }, child: Row(children: [
                Expanded(child: Text(amt == 0 ? 'المبلغ (${curOf(cur).sym})' : fmt(amt), style: TextStyle(fontSize: amt == 0 ? 17 : 20, fontWeight: amt == 0 ? FontWeight.w400 : FontWeight.w800, color: amt == 0 ? p.ink2 : null))),
                Tap(
                  onTap: () async {
                    final r = await showCurrencySheet(context, cur);
                    if (r != null) setState(() => cur = r);
                  },
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Text(curOf(cur).sym, style: _ts(15)), Icon(Icons.keyboard_arrow_down_rounded, color: _wc, size: 20)]),
                ),
              ])),
              _sec(p, 'المواعيد'),
              _row(p, Icons.calendar_month_outlined, minH: 74, onTap: () async {
                final d = await showDateSheet(context, when);
                if (d != null) setState(() => when = DateTime(d.year, d.month, d.day, when.hour, when.minute));
              }, child: _two(p, inn ? 'تاريخ السلفة' : 'تاريخ الدين', enDate(when))),
              _row(p, Icons.schedule_rounded, minH: 74, onTap: () async {
                final d = await showTimeSheet(context, when);
                if (d != null) setState(() => when = DateTime(when.year, when.month, when.day, d.hour, d.minute));
              }, child: _two(p, 'الوقت', '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}')),
              _row(p, Icons.timer_outlined, minH: 74, onTap: () async {
                final d = await showDateSheet(context, due ?? DateTime.now(), title: 'تاريخ الاستحقاق');
                if (d != null) setState(() => due = d);
              }, child: Row(children: [
                Expanded(child: _two(p, 'تاريخ الاستحقاق', due == null ? 'بدون موعد' : enDate(due!))),
                if (due != null) Tap(onTap: () => setState(() => due = null), child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.close_rounded, color: p.ink2, size: 20))),
              ])),
              // خيار التذكير زي ما هو (بيظهر لما فيه تاريخ استحقاق)
              _switchRow(
                p, Icons.notifications_none_rounded, 'تذكير', 'سيصلك إشعار قبل تاريخ السداد', remind && due != null, (v) => setState(() => remind = v),
                extra: (remind && due != null)
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final d in const [1, 2, 3, 7])
                            Tap(
                              scale: .96,
                              onTap: () => setState(() => days.contains(d) ? (days.length > 1 ? days.remove(d) : null) : days.add(d)),
                              child: AnimatedContainer(
                                duration: CashUMotion.expand,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(color: days.contains(d) ? p.acc : p.field, borderRadius: BorderRadius.circular(22)),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text(d == 1 ? 'قبل يوم واحد' : 'قبل $d أيام', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: days.contains(d) ? Colors.white : _wc.withValues(alpha: .8))),
                                  if (days.contains(d)) ...[const SizedBox(width: 6), const Icon(Icons.check_rounded, size: 15, color: Colors.white)],
                                ]),
                              ),
                            ),
                        ]),
                      )
                    : null,
              ),
              _sec(p, 'خيارات زيادة'),
              _row(p, Icons.sticky_note_2_outlined, minH: 96, child: TextField(controller: noteC, minLines: 2, maxLines: 4, style: _ts(16), decoration: InputDecoration(border: InputBorder.none, isDense: true, hintText: 'ملاحظة', hintStyle: TextStyle(fontSize: 17, color: p.ink2)))),
              _row(p, Icons.account_balance_wallet_outlined, minH: 74, err: bad && rec && acc.isEmpty, onTap: () async {
                final r = await showPickAccount(context, acc, title: 'الحساب');
                if (r != null) setState(() => acc = r);
              }, child: _two(p, 'الحساب', repo.account(acc)?.name ?? 'اختر حسابًا', vc: acc.isEmpty ? p.ink2 : null)),
              _switchRow(p, Icons.receipt_long_outlined, 'إضافة عملية عند السداد', 'بتتسجل في الحركات على الحساب اللي اخترته', rec, (v) => setState(() => rec = v)),
              _switchRow(p, Icons.pie_chart_outline_rounded, 'احتسابه في صافي الثروة', 'يُضاف المتبقي إلى صافي ثروتك أو يُخصم منه', nw, (v) => setState(() => nw = v)),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Text(inn ? 'المبلغ اللي سلّفته مش بيتحسب مصروف، وبيتسجل في الحركات لما تسجّل السداد.' : 'المبلغ اللي استلفته مش بيتحسب دخل، وبيتسجل في الحركات لما تسجّل السداد.', style: TextStyle(fontSize: 13.5, color: p.ink2, height: 1.5)),
              ),
              if (bad && rec && acc.isEmpty) Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 0), child: Text('اختر الحساب الذي تمر عبره الدفعات.', style: TextStyle(color: kRed, fontSize: 14))),
            ]),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 14 + MediaQuery.of(context).padding.bottom),
            child: Tap(onTap: _save, child: Container(height: 58, alignment: Alignment.center, decoration: BoxDecoration(color: p.acc, borderRadius: BorderRadius.circular(29)), child: const Text('حفظ', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)))),
          ),
        ]),
      ),
    );
  }

  Widget _dirBtn(Pal p, String t, IconData ic, bool on, Color c, VoidCallback f) => Tap(
        onTap: f,
        child: AnimatedContainer(
          duration: CashUMotion.of(context, CashUMotion.tab),
          height: 56,
          decoration: BoxDecoration(color: on ? c.withValues(alpha: .16) : p.card, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(t, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: on ? c : p.ink2)),
            const SizedBox(width: 8),
            Icon(ic, size: 20, color: on ? c : p.ink2),
          ]),
        ),
      );
}

// ======================= سلّفته تاني / دين جديد =======================
/// زيادة مبلغ على نفس الدين بتاريخ ووقت محدّدين (بتتجمع في الإجمالي).
Future<void> showLoanAddSheet(BuildContext context, Loan l) async {
  final owed = l.dir == 'owed';
  final r = await _askLoanAmt(context, l, title: owed ? 'سلّفته تاني' : 'دين جديد', cta: owed ? 'إضافة السلفة' : 'إضافة الدين', color: kBlue);
  if (r == null || !context.mounted) return;
  repo.addToLoan(l, r.amt, when: r.when, acc: r.acc, note: r.note);
  if (context.mounted) toast(context, owed ? 'اتزادت ${_money(l, r.amt)} على ${l.person}' : 'اتزاد عليك ${_money(l, r.amt)} لـ ${l.person}');
}

class _LoanAmtResult {
  final double amt;
  final String acc;
  final DateTime when;
  final String note;
  const _LoanAmtResult(this.amt, this.acc, this.when, [this.note = '']);
}

/// بانل مبلغ + حساب (تحت بعض) + تاريخ ووقت. [max] = أقصى مبلغ مسموح (للسداد الجزئي).
Future<_LoanAmtResult?> _askLoanAmt(BuildContext context, Loan l, {required String title, required String cta, required Color color, double? max}) =>
    showSheet<_LoanAmtResult>(context, (c) => _LoanAmtSheet(loan: l, title: title, cta: cta, color: color, max: max));

class _LoanAmtSheet extends StatefulWidget {
  final Loan loan;
  final String title, cta;
  final Color color;
  final double? max;
  const _LoanAmtSheet({required this.loan, required this.title, required this.cta, required this.color, this.max});
  @override
  State<_LoanAmtSheet> createState() => _LoanAmtSheetState();
}

class _LoanAmtSheetState extends State<_LoanAmtSheet> {
  final amtC = TextEditingController();
  late String acc = widget.loan.acc;
  final noteC = TextEditingController();
  DateTime when = DateTime.now();
  bool bad = false;

  @override
  void dispose() {
    amtC.dispose();
    noteC.dispose();
    super.dispose();
  }

  double get _amt {
    const ar = '٠١٢٣٤٥٦٧٨٩';
    var t = amtC.text.trim().replaceAll(',', '').replaceAll('٫', '.');
    for (var i = 0; i < 10; i++) {
      t = t.replaceAll(ar[i], '$i');
    }
    return double.tryParse(t) ?? 0;
  }

  Widget _card(Pal p, {required IconData icon, required Widget child, VoidCallback? onTap, bool err = false}) => Tap(
        scale: onTap == null ? 1 : .99,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(20), border: err ? Border.all(color: kRed, width: 1.4) : null),
          child: Row(children: [Icon(icon, color: p.ink2, size: 24), const SizedBox(width: 14), Expanded(child: child)]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final sym = curOf(widget.loan.cur).sym;
    return SheetFrame(
      title: widget.title,
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
        // المبلغ ثم الحساب تحت بعض
        _card(p, icon: Icons.payments_outlined, err: bad && _amt <= 0, child: TextField(
          controller: amtC,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          decoration: InputDecoration(border: InputBorder.none, isDense: true, hintText: 'مبلغ الدفعة ($sym)', hintStyle: TextStyle(fontSize: 16, color: p.ink2)),
        )),
        _card(p, icon: Icons.account_balance_wallet_outlined, onTap: () async {
          final r = await showPickAccount(context, acc, title: 'الحساب');
          if (r != null) setState(() => acc = r);
        }, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('الحساب', style: TextStyle(fontSize: 12.5, color: p.ink2)),
          Row(children: [
            Expanded(child: Text(acc.isEmpty ? 'بدون حساب (اختياري)' : (repo.account(acc)?.name ?? 'اختر حسابًا'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: acc.isEmpty ? p.ink2 : null))),
            if (acc.isNotEmpty) Tap(onTap: () => setState(() => acc = ''), child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.close_rounded, size: 20, color: p.ink2))),
          ]),
        ])),
        Row(children: [
          Expanded(
            child: _card(p, icon: Icons.calendar_today_outlined, onTap: () async {
              final d = await showDateSheet(context, when);
              if (d != null) setState(() => when = DateTime(d.year, d.month, d.day, when.hour, when.minute));
            }, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('التاريخ', style: TextStyle(fontSize: 12.5, color: p.ink2)),
              Text(enDate(when), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ])),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _card(p, icon: Icons.schedule_rounded, onTap: () async {
              final d = await showTimeSheet(context, when);
              if (d != null) setState(() => when = DateTime(when.year, when.month, when.day, d.hour, d.minute));
            }, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('الوقت', style: TextStyle(fontSize: 12.5, color: p.ink2)),
              Text('${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ])),
          ),
        ]),
        _card(p, icon: Icons.sticky_note_2_outlined, child: TextField(
          controller: noteC,
          minLines: 1,
          maxLines: 3,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(border: InputBorder.none, isDense: true, hintText: 'الملاحظة (اختياري)', hintStyle: TextStyle(fontSize: 16, color: p.ink2)),
        )),
        const SizedBox(height: 4),
        Tap(
          onTap: () {
            final a = _amt;
            if (a <= 0) {
              setState(() => bad = true);
              return;
            }
            Navigator.of(context).pop(_LoanAmtResult(widget.max != null && a > widget.max! ? widget.max! : a, acc, when, noteC.text.trim()));
          },
          child: Container(height: 56, alignment: Alignment.center, decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(28)), child: Text(widget.cta, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white))),
        ),
      ]),
    );
  }
}
