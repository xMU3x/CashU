import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import '../core/currency.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/util.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/pickers.dart';
import '../ui/sheets.dart';
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
  String dir = 'owed'; // owed = ديون لك · owe = ديون عليك
  int gen = 0;

  Widget _tabs(Pal p) => Container(
        height: 52,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(26)),
        child: Row(children: [
          for (final t in const [('owed', 'ديون لك'), ('owe', 'ديون عليك')])
            Expanded(
              child: Tap(
                scale: .98,
                onTap: () => setState(() => dir = t.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: dir == t.$1 ? p.field : Colors.transparent, borderRadius: BorderRadius.circular(22)),
                  child: Text(t.$2, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: dir == t.$1 ? p.ink : p.ink2)),
                ),
              ),
            ),
        ]),
      );

  Future<void> _delete(Loan l) async {
    if (await confirmDialog(context, 'حذف', 'هيتحذف "${l.person}" مع دفعاته.')) repo.delLoan(l);
    if (mounted) setState(() => gen++);
  }

  Widget _card(Pal p, Loan l) {
    final inn = l.dir == 'owed';
    final col = inn ? kGreen : kRed;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(26)),
      child: Row(children: [
        iconBubble(p, inn ? Icons.south_west_rounded : Icons.north_east_rounded, color: col, size: 52),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.person, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(_dueText(l), style: TextStyle(fontSize: 13.5, color: _dueColor(l, p))),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_money(l, l.settled ? l.amt : l.left), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: l.settled ? p.ink2 : p.ink)),
          const SizedBox(height: 6),
          _chip(p, _status(l), _statusColor(l, p)),
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
          child: Tap(scale: .99, onTap: () => Navigator.of(context).push(flowRoute(LoanDetailPage(id: l.id))), child: _card(p, l)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Live(b: (c) {
          final all = repo.loanList.where((l) => l.dir == dir).toList()
            ..sort((a, b) {
              if (a.settled != b.settled) return a.settled ? 1 : -1;
              final ad = a.due <= 0 ? 1 << 60 : a.due, bd = b.due <= 0 ? 1 << 60 : b.due;
              return ad.compareTo(bd);
            });
          final open = all.where((l) => !l.settled).fold(0.0, (s, l) => s + l.leftBase);
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(children: [
                GlassBtn(Icons.chevron_left_rounded, () => Navigator.of(context).maybePop(), size: 46),
                const SizedBox(width: 12),
                const Expanded(child: Text('الديون', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800))),
                Tap(
                  onTap: () => Navigator.of(context).push(sheetRoute(LoanFormPage(dir: dir))),
                  child: Container(width: 48, height: 48, decoration: BoxDecoration(color: p.acc, shape: BoxShape.circle), child: const Icon(Icons.add_rounded, color: Colors.white, size: 28)),
                ),
              ]),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _tabs(p)),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 120), physics: const BouncingScrollPhysics(), children: [
                if (all.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                    child: Row(children: [
                      Text(dir == 'owed' ? 'إجمالي المستحق لك' : 'إجمالي المستحق عليك', style: TextStyle(color: p.ink2, fontSize: 14)),
                      const Spacer(),
                      Text(egp(open), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: dir == 'owed' ? kGreen : kRed)),
                    ]),
                  ),
                if (all.isEmpty) emptyState(p, Icons.handshake_rounded, dir == 'owed' ? 'مفيش حد ليك عنده فلوس' : 'مفيش عليك ديون') else for (final l in all) _row(p, l),
                if (all.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Center(child: Text('اسحب ناحية لتسجيل السداد وناحية للحذف', style: TextStyle(color: p.ink2.withValues(alpha: .7), fontSize: 12)))),
              ]),
            ),
          ]);
        }),
      ),
    );
  }
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
        tile(p, Icons.check_rounded, kGreen, 'سداد كامل', 'يسدد المتبقي بالكامل: ${_money(l, l.left)}', () {
          Navigator.of(c).pop();
          repo.settleLoan(l);
          toast(context, 'تم تسجيل السداد');
        }),
        tile(p, Icons.payments_outlined, kOrange, 'سداد جزئي', 'سجّل ما تم دفعه الآن، ويبقى الباقي على الدين', () async {
          Navigator.of(c).pop();
          final v = await showCalc(context, 0, l.cur);
          if (v == null || v <= 0) return;
          repo.payLoan(l, v);
          if (context.mounted) toast(context, 'تم تسجيل ${_money(l, v > l.amt ? l.amt : v)}');
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

Future<Tx?> _pickTx(BuildContext context, Loan l) {
  final want = l.dir == 'owed' ? 'inc' : 'exp'; // سداد دين لك = دخل · سداد دين عليك = مصروف
  final list = repo.allTx.where((t) => t.type == want && t.loan.isEmpty && !t.pend).toList()..sort((a, b) => b.ts.compareTo(a.ts));
  return showSheet<Tx>(context, (c) {
    final p = Pal.of(c);
    return SheetFrame(
      title: 'اختر المعاملة',
      height: MediaQuery.of(c).size.height * .7,
      child: list.isEmpty
          ? emptyState(p, Icons.receipt_long_rounded, 'مفيش معاملات مناسبة')
          : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), children: [
              for (final t in list.take(60))
                Tap(
                  scale: .98,
                  onTap: () => Navigator.of(c).pop(t),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(22)),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(txTitle(t), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        Text(enDate(t.date), style: TextStyle(fontSize: 12.5, color: p.ink2)),
                      ])),
                      Text('${fmt(t.amt)} ${curOf(t.cur).sym}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
            ]),
    );
  });
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

  Widget _detailRow(Pal p, IconData ic, String k, String v, {bool last = false}) => Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(children: [
            Icon(ic, color: p.ink2, size: 24),
            const SizedBox(width: 14),
            Text(k, style: TextStyle(fontSize: 16, color: p.ink2)),
            const Spacer(),
            Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
        ),
        if (!last) hair(p),
      ]);

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
        return SafeArea(
          child: Column(children: [
            Padding(
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
                        if (await confirmDialog(context, 'حذف', 'هيتحذف "${l.person}" مع دفعاته.')) {
                          repo.delLoan(l);
                          if (context.mounted) Navigator.of(context).maybePop();
                        }
                      },
                      child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.delete_outline_rounded, color: kRed, size: 22)),
                    ),
                  ]),
                ),
              ]),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 20), physics: const BouncingScrollPhysics(), children: [
                Center(child: iconBubble(p, inn ? Icons.south_west_rounded : Icons.north_east_rounded, color: col, size: 96)),
                const SizedBox(height: 14),
                Center(child: Text(l.person, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700))),
                const SizedBox(height: 4),
                Center(child: Text(_money(l, l.settled ? l.amt : l.left), style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800))),
                if (l.pays.isNotEmpty || l.settled) ...[
                  const SizedBox(height: 14),
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: l.amt <= 0 ? 0 : (l.paid / l.amt).clamp(0.0, 1.0), minHeight: 8, backgroundColor: p.field, valueColor: AlwaysStoppedAnimation(kGreen))),
                  const SizedBox(height: 8),
                  Row(children: [
                    Text('تم سداد ${_money(l, l.paid)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('من أصل ${_money(l, l.amt)}', style: TextStyle(color: p.ink2)),
                  ]),
                ],
                const SizedBox(height: 10),
                Center(child: Text(_dueText(l), style: TextStyle(fontSize: 16, color: _dueColor(l, p)))),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (l.partial || l.settled) ...[_chip(p, _status(l), _statusColor(l, p)), const SizedBox(width: 8)],
                  _chip(p, inn ? 'لك' : 'عليك', p.ink2),
                ]),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
                  decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(28)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('التفاصيل', style: TextStyle(fontSize: 16, color: p.ink2)),
                    _detailRow(p, Icons.event_outlined, 'تاريخ السداد', l.due <= 0 ? '—' : enDate(DateTime.fromMillisecondsSinceEpoch(l.due))),
                    _detailRow(p, Icons.notifications_none_rounded, 'تذكير', remText),
                    _detailRow(p, Icons.pie_chart_outline_rounded, 'احتسابه في صافي الثروة', l.nw ? 'محتسب' : 'غير محتسب'),
                    if (l.note.isNotEmpty) _detailRow(p, Icons.notes_rounded, 'الوصف', l.note),
                    _detailRow(p, Icons.schedule_rounded, 'تاريخ الإضافة', enDate(DateTime.fromMillisecondsSinceEpoch(l.ts)), last: true),
                  ]),
                ),
                if (l.pays.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                    decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(28)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('المدفوعات', style: TextStyle(fontSize: 16, color: p.ink2)),
                      const SizedBox(height: 6),
                      for (var i = 0; i < l.pays.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [
                            Tap(
                              onTap: () async {
                                if (await confirmDialog(context, 'حذف دفعة', 'هتتحذف الدفعة وتتزود على المتبقي.')) repo.removeLoanPay(l, i);
                              },
                              child: Icon(Icons.delete_outline_rounded, color: p.ink2, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Text(_money(l, l.pays[i].amt), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                            const Spacer(),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text(l.pays[i].tx.startsWith('lp_') ? 'مسجل يدويًا' : 'معاملة مرتبطة', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              Text(enDate(DateTime.fromMillisecondsSinceEpoch(l.pays[i].ts)), style: TextStyle(fontSize: 13, color: p.ink2)),
                            ]),
                          ]),
                        ),
                    ]),
                  ),
                ],
              ]),
            ),
            if (!l.settled)
              Padding(
                padding: EdgeInsets.fromLTRB(16, 6, 16, 16 + MediaQuery.of(context).padding.bottom),
                child: Tap(
                  onTap: () => showLoanPaySheet(context, l),
                  child: Container(height: 60, alignment: Alignment.center, decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(30)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('سداد', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)), SizedBox(width: 8), Icon(Icons.check_rounded, color: Colors.white)])),
                ),
              ),
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
  bool remind = true, nw = true;
  final days = <int>{1};
  bool bad = false;

  @override
  void initState() {
    super.initState();
    acc = repo.defaultAcc;
    final e = widget.edit;
    if (e != null) {
      dir = e.dir;
      nameC.text = e.person;
      noteC.text = e.note;
      amt = e.amt;
      cur = e.cur;
      acc = e.acc.isEmpty ? repo.defaultAcc : e.acc;
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
    if (name.isEmpty || amt <= 0) {
      setState(() => bad = true);
      return;
    }
    final rem = (remind && due != null) ? (days.toList()..sort()) : <int>[];
    final e = widget.edit;
    if (e == null) {
      repo.addLoan(Loan(
        id: uid(), dir: dir, person: name, amt: amt, cur: cur, rate: rates.rate(cur, S.cur), acc: acc,
        due: due?.millisecondsSinceEpoch ?? 0, note: noteC.text.trim(), ts: DateTime.now().millisecondsSinceEpoch, nw: nw, rem: rem,
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
        ..nw = nw
        ..rem = rem;
      if (e.left < 0.005 && e.pays.isNotEmpty) e.settled = true;
      repo.saveLoan(e);
    }
    Navigator.of(context).pop();
  }

  Widget _label(Pal p, String t) => Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text(t, style: TextStyle(fontSize: 15, color: p.ink2)));

  Widget _field(Pal p, {required Widget child, bool err = false}) => Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(20), border: err ? Border.all(color: kRed, width: 1.5) : null),
        child: child,
      );

  Widget _toggleCard(Pal p, String title, String sub, bool v, ValueChanged<bool> f, {Widget? extra}) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(28)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Switch(value: v, onChanged: f, activeColor: Colors.white, activeTrackColor: kGreen),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(fontSize: 14, color: p.ink2, height: 1.4)),
            ])),
          ]),
          if (extra != null) extra,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final editing = widget.edit != null;
    return Scaffold(
      backgroundColor: p.bg,
      body: SheetPage(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              Tap(onTap: _save, child: Container(width: 48, height: 48, decoration: BoxDecoration(color: p.acc, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: Colors.white, size: 26))),
              Expanded(child: Text(editing ? 'تعديل دين' : 'إضافة دين', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
              GlassBtn(Icons.chevron_right_rounded, () => Navigator.of(context).pop(), size: 48),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), physics: const BouncingScrollPhysics(), children: [
              Container(
                height: 56,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(28)),
                child: Row(children: [
                  for (final t in const [('owed', 'لك'), ('owe', 'عليك')])
                    Expanded(
                      child: Tap(
                        scale: .98,
                        onTap: () => setState(() => dir = t.$1),
                        child: AnimatedContainer(duration: const Duration(milliseconds: 220), alignment: Alignment.center, decoration: BoxDecoration(color: dir == t.$1 ? p.field : Colors.transparent, borderRadius: BorderRadius.circular(23)), child: Text(t.$2, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: dir == t.$1 ? p.ink : p.ink2))),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(28)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label(p, 'الاسم'),
                  _field(p, err: bad && nameC.text.trim().isEmpty, child: TextField(controller: nameC, style: const TextStyle(fontSize: 18), decoration: const InputDecoration(border: InputBorder.none, hintText: 'اسم الشخص'))),
                  const SizedBox(height: 16),
                  _label(p, 'المبلغ'),
                  Tap(
                    onTap: () async {
                      final r = await showCalc(context, amt, cur);
                      if (r != null) setState(() => amt = r < 0 ? 0 : r);
                    },
                    child: _field(p, err: bad && amt <= 0, child: Row(children: [
                      Tap(
                        onTap: () async {
                          final r = await showCurrencySheet(context, cur);
                          if (r != null) setState(() => cur = r);
                        },
                        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.keyboard_arrow_down_rounded, color: p.ink2, size: 20), Text(curOf(cur).sym, style: TextStyle(fontSize: 16, color: p.ink2))]),
                      ),
                      const Spacer(),
                      Text(amt == 0 ? '0' : fmt(amt), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: amt == 0 ? p.ink2 : p.ink)),
                    ])),
                  ),
                  const SizedBox(height: 16),
                  _label(p, 'الحساب'),
                  Tap(
                    onTap: () async {
                      final r = await showPickAccount(context, acc, title: 'الحساب');
                      if (r != null) setState(() => acc = r);
                    },
                    child: _field(p, child: Row(children: [Icon(Icons.keyboard_arrow_down_rounded, color: p.ink2), const Spacer(), Text(repo.account(acc)?.name ?? '—', style: const TextStyle(fontSize: 17))])),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(28)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label(p, 'تاريخ السداد'),
                  Tap(
                    onTap: () async {
                      final d = await showDateSheet(context, due ?? DateTime.now());
                      if (d != null) setState(() => due = d);
                    },
                    child: _field(p, child: Row(children: [Icon(Icons.calendar_today_outlined, color: p.ink2, size: 22), const Spacer(), Text(due == null ? 'بدون موعد' : enDate(due!), style: const TextStyle(fontSize: 18))])),
                  ),
                  if (due != null) Padding(padding: const EdgeInsets.only(top: 8), child: Tap(onTap: () => setState(() => due = null), child: Text('إزالة التاريخ', style: TextStyle(color: p.acc, fontSize: 15)))),
                  const SizedBox(height: 14),
                  _label(p, 'الوصف'),
                  Container(
                    constraints: const BoxConstraints(minHeight: 96),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(20)),
                    child: TextField(controller: noteC, minLines: 3, maxLines: 5, decoration: InputDecoration(border: InputBorder.none, hintText: 'اختياري', hintStyle: TextStyle(color: p.ink2))),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              _toggleCard(
                p, 'تذكير', 'سيصلك إشعار قبل تاريخ السداد', remind && due != null, (v) => setState(() => remind = v),
                extra: (remind && due != null)
                    ? Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('اختر يومًا أو أكثر', style: TextStyle(color: p.ink2)),
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final d in const [1, 2, 3, 7])
                              Tap(
                                scale: .96,
                                onTap: () => setState(() => days.contains(d) ? (days.length > 1 ? days.remove(d) : null) : days.add(d)),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  decoration: BoxDecoration(color: days.contains(d) ? p.acc : p.field, borderRadius: BorderRadius.circular(24)),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Text(d == 1 ? 'قبل يوم واحد' : 'قبل $d أيام', style: TextStyle(fontWeight: FontWeight.w600, color: days.contains(d) ? Colors.white : p.ink2)),
                                    if (days.contains(d)) ...[const SizedBox(width: 6), const Icon(Icons.check_rounded, size: 16, color: Colors.white)],
                                  ]),
                                ),
                              ),
                          ]),
                        ]),
                      )
                    : null,
              ),
              const SizedBox(height: 14),
              _toggleCard(p, 'احتسابه في صافي الثروة', 'يُضاف المتبقي إلى صافي ثروتك أو يُخصم منه', nw, (v) => setState(() => nw = v)),
            ]),
          ),
        ]),
      ),
    );
  }
}
