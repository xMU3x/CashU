import 'package:flutter/material.dart' hide Text;
import '../core/extras.dart';
import '../core/repo.dart';
import '../core/util.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/loc_text.dart';
import '../ui/pickers.dart';
import '../ui/sheets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

String _n(double v) {
  final s = fixed2(v);
  return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
}

String _m(double v) => '${_n(v)} ج.م';

Widget _field(Pal p, IconData ic, String hint, String value, VoidCallback f) => Tap(
      onTap: f,
      scale: .99,
      child: Container(
        height: 58,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Icon(ic, color: p.ink2, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(value.isEmpty ? hint : value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16.5, color: value.isEmpty ? p.ink2 : p.ink))),
        ]),
      ),
    );

Widget _addBtn(Pal p, VoidCallback f) => PositionedDirectional(
      end: 20,
      bottom: 28,
      child: FabIn(child: Tap(onTap: f, child: Container(width: 64, height: 64, decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(22)), child: Icon(Icons.add_rounded, color: p.bg, size: 30)))),
    );

Widget _row(Pal p, IconData ic, Color c, String t, String sub, String trail, VoidCallback f) => Tap(
      scale: .985,
      onTap: f,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22)),
        child: Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: c.withValues(alpha: .16), borderRadius: BorderRadius.circular(15)), child: Icon(ic, color: c)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), Text(sub, maxLines: 2, style: TextStyle(fontSize: 13, color: p.ink2))])),
          Text(trail, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
      ),
    );

Future<double?> _num(BuildContext c, String title, double init) async {
  final r = await promptText(c, title, hint: title, initial: init == 0 ? '' : _n(init).replaceAll(',', ''), number: true);
  if (r == null) return null;
  return double.tryParse(normDigits(r));
}

// ===================== الجمعيات =====================
class AssocPage extends StatelessWidget {
  const AssocPage({super.key});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: 'الجمعيات',
      sub: 'اشتراكك الشهري وميعاد قبضك',
      icon: Icons.groups_rounded,
      iconColor: const Color(0xFF2E7568),
      child: Live(b: (c) {
        final list = extras.assocs;
        return Stack(children: [
          list.isEmpty
              ? emptyState(p, Icons.groups_rounded, 'مفيش جمعيات.\nاضغط + عشان تضيف جمعية.')
              : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 110), physics: const BouncingScrollPhysics(), children: [
                  for (var i = 0; i < list.length; i++)
                    Reveal(i: i, child: _row(p, Icons.groups_rounded, const Color(0xFF2E7568), list[i].name, 'دورك ${list[i].turn} من ${list[i].members} · القبض ${enDate(list[i].payoutDate)}', _m(list[i].amt), () => _detail(context, list[i].id))),
                ]),
          _addBtn(p, () => Navigator.of(context).push(flowRoute(const AssocFormPage()))),
        ]);
      }),
    );
  }

  void _detail(BuildContext context, String id) => showSheet<void>(context, (c) => Live(b: (cc) {
        final p = Pal.of(cc);
        final a = extras.assocs.where((x) => x.id == id).firstOrNull;
        if (a == null) return const SizedBox.shrink();
        final nav = Navigator.of(context);
        return SheetFrame(
          title: a.name,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              _info(p, 'القسط الشهري', _m(a.amt)),
              _info(p, 'عدد الأعضاء', '${a.members}'),
              _info(p, 'دورك', '${a.turn} — القبض ${enDate(a.payoutDate)}'),
              _info(p, 'قيمة القبض', _m(a.payout)),
              _info(p, 'اتدفع (${a.monthsDone} من ${a.members})', _m(a.paidTotal)),
              if (a.rules.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('القواعد: ${a.rules}', style: TextStyle(color: p.ink2, height: 1.5))),
              const SizedBox(height: 14),
              if (a.monthsDone < a.members) bigButton(p, 'ادفع قسط الشهر', kBlue, () { extras.payAssoc(a); toast(cc, 'اتسجل القسط'); }),
              const SizedBox(height: 10),
              if (!a.received) bigButton(p, 'استلمت القبض', kGreen, () { extras.receiveAssoc(a); toast(cc, 'اتسجل القبض كدخل'); }),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Tap(onTap: () { nav.pop(); nav.push(flowRoute(AssocFormPage(edit: a))); }, child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(24)), child: const Text('تعديل', style: TextStyle(fontWeight: FontWeight.w600))))),
                const SizedBox(width: 10),
                Expanded(child: Tap(onTap: () async { if (await confirmDialog(cc, 'حذف', 'هتتحذف الجمعية، والمعاملات المسجلة تفضل زي ما هي.')) { extras.delAssoc(a); nav.pop(); } }, child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: kRed.withValues(alpha: .15), borderRadius: BorderRadius.circular(24)), child: const Text('حذف', style: TextStyle(color: kRed, fontWeight: FontWeight.w600))))),
              ]),
            ]),
          ),
        );
      }));
}

Widget _info(Pal p, String a, String b) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(a, style: TextStyle(color: p.ink2, fontSize: 15)), Flexible(child: Text(b, textAlign: TextAlign.end, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))]));

class AssocFormPage extends StatefulWidget {
  final Assoc? edit;
  const AssocFormPage({super.key, this.edit});
  @override
  State<AssocFormPage> createState() => _AssocFormState();
}

class _AssocFormState extends State<AssocFormPage> {
  String name = '', acc = '', rules = '';
  double amt = 0;
  int members = 10, turn = 1;
  DateTime start = DateTime.now();
  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      name = e.name; acc = e.acc; rules = e.rules; amt = e.amt; members = e.members; turn = e.turn; start = e.startDate;
    }
  }

  void _save() {
    if (name.trim().isEmpty || amt <= 0 || members < 2 || turn < 1 || turn > members) return toast(context, 'راجع البيانات: الاسم والقسط وعدد الأعضاء ودورك');
    final a = widget.edit ?? Assoc(id: 'as_${DateTime.now().microsecondsSinceEpoch}', name: name, amt: amt, start: start.millisecondsSinceEpoch);
    a..name = name.trim()..amt = amt..members = members..turn = turn..start = start.millisecondsSinceEpoch..acc = acc..rules = rules;
    extras.saveAssoc(a);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: widget.edit == null ? 'جمعية جديدة' : 'تعديل جمعية',
      child: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 16), children: [
            _field(p, Icons.groups_rounded, 'اسم الجمعية', name, () async { final r = await promptText(context, 'اسم الجمعية', hint: 'اسم الجمعية', initial: name); if (r != null) setState(() => name = r.trim()); }),
            _field(p, Icons.payments_outlined, 'القسط الشهري (ج.م)', amt == 0 ? '' : _n(amt), () async { final r = await showCalc(context, amt, 'EGP'); if (r != null) setState(() => amt = r < 0 ? 0 : r); }),
            _field(p, Icons.people_alt_outlined, 'عدد الأعضاء', '$members', () async { final v = await _num(context, 'عدد الأعضاء', members.toDouble()); if (v != null) setState(() => members = v.toInt()); }),
            _field(p, Icons.confirmation_number_outlined, 'دورك في القبض', '$turn', () async { final v = await _num(context, 'دورك في القبض', turn.toDouble()); if (v != null) setState(() => turn = v.toInt()); }),
            _field(p, Icons.event_rounded, 'بداية الجمعية', enDate(start), () async { final d = await showDateSheet(context, start, title: 'بداية الجمعية'); if (d != null) setState(() => start = d); }),
            _field(p, Icons.credit_card_rounded, 'بتدفع من حساب', repo.account(acc)?.name ?? '', () async { final r = await showPickAccount(context, acc.isEmpty ? repo.defaultAcc : acc); if (r != null) setState(() => acc = r); }),
            _field(p, Icons.rule_rounded, 'قواعد الجمعية (اختياري)', rules, () async { final r = await promptText(context, 'قواعد الجمعية', hint: 'القواعد', initial: rules); if (r != null) setState(() => rules = r.trim()); }),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 14), child: bigButton(p, 'حفظ', kBlue, _save)),
      ]),
    );
  }
}

// ===================== الأقساط =====================
class InstPage extends StatelessWidget {
  const InstPage({super.key});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: 'أقساطي',
      sub: 'المتبقي ومواعيد الدفع',
      icon: Icons.more_horiz_rounded,
      iconColor: kBlue,
      child: Live(b: (c) {
        final list = extras.insts;
        final left = list.fold(0.0, (a, x) => a + x.left);
        return Stack(children: [
          list.isEmpty
              ? emptyState(p, Icons.more_horiz_rounded, 'مفيش أقساط.\nاضغط + عشان تضيف قسط.')
              : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 110), physics: const BouncingScrollPhysics(), children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('إجمالي المتبقي', style: TextStyle(color: p.ink2, fontSize: 15)), Text(_m(left), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))]),
                  ),
                  for (var i = 0; i < list.length; i++)
                    Reveal(i: i, child: _row(p, Icons.more_horiz_rounded, kBlue, list[i].name, list[i].done ? 'اتسدد بالكامل' : 'القسط الجاي ${list[i].nextDue == null ? '' : enDate(list[i].nextDue!)} · ${list[i].pays.length}/${list[i].count}', _m(list[i].each), () => _detail(context, list[i].id))),
                ]),
          _addBtn(p, () => Navigator.of(context).push(flowRoute(const InstFormPage()))),
        ]);
      }),
    );
  }

  void _detail(BuildContext context, String id) => showSheet<void>(context, (c) => Live(b: (cc) {
        final p = Pal.of(cc);
        final a = extras.insts.where((x) => x.id == id).firstOrNull;
        if (a == null) return const SizedBox.shrink();
        final nav = Navigator.of(context);
        return SheetFrame(
          title: a.name,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              _info(p, 'الإجمالي', _m(a.total)),
              _info(p, 'القسط', '${_m(a.each)} × ${a.count}'),
              _info(p, 'اتدفع', _m(a.paid)),
              _info(p, 'المتبقي', _m(a.left)),
              const SizedBox(height: 8),
              for (var i = 0; i < a.count; i++)
                Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Icon(i < a.pays.length ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 20, color: i < a.pays.length ? kGreen : p.ink2), const SizedBox(width: 10), Text('القسط ${i + 1}', style: const TextStyle(fontSize: 15)), const Spacer(), Text(enDate(a.dueOf(i)!), style: TextStyle(color: p.ink2, fontSize: 14))])),
              const SizedBox(height: 14),
              if (!a.done) bigButton(p, 'ادفع القسط الجاي', kBlue, () { extras.payInst(a); toast(cc, 'اتسجل القسط كمصروف'); }),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Tap(onTap: () { nav.pop(); nav.push(flowRoute(InstFormPage(edit: a))); }, child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(24)), child: const Text('تعديل', style: TextStyle(fontWeight: FontWeight.w600))))),
                const SizedBox(width: 10),
                Expanded(child: Tap(onTap: () async { if (await confirmDialog(cc, 'حذف', 'هتتحذف خطة القسط، والمعاملات المسجلة تفضل زي ما هي.')) { extras.delInst(a); nav.pop(); } }, child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: kRed.withValues(alpha: .15), borderRadius: BorderRadius.circular(24)), child: const Text('حذف', style: TextStyle(color: kRed, fontWeight: FontWeight.w600))))),
              ]),
            ]),
          ),
        );
      }));
}

class InstFormPage extends StatefulWidget {
  final Inst? edit;
  const InstFormPage({super.key, this.edit});
  @override
  State<InstFormPage> createState() => _InstFormState();
}

class _InstFormState extends State<InstFormPage> {
  String name = '', acc = '', note = '';
  double total = 0;
  int count = 12;
  DateTime first = DateTime.now();
  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      name = e.name; acc = e.acc; note = e.note; total = e.total; count = e.count; first = DateTime.fromMillisecondsSinceEpoch(e.first);
    }
  }

  void _save() {
    if (name.trim().isEmpty || total <= 0 || count < 1) return toast(context, 'راجع البيانات: الاسم والإجمالي وعدد الأقساط');
    final a = widget.edit ?? Inst(id: 'in_${DateTime.now().microsecondsSinceEpoch}', name: name, total: total, first: first.millisecondsSinceEpoch);
    a..name = name.trim()..total = total..count = count..first = first.millisecondsSinceEpoch..acc = acc..note = note;
    extras.saveInst(a);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: widget.edit == null ? 'قسط جديد' : 'تعديل قسط',
      child: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 16), children: [
            _field(p, Icons.shopping_bag_outlined, 'اسم القسط', name, () async { final r = await promptText(context, 'اسم القسط', hint: 'اسم القسط', initial: name); if (r != null) setState(() => name = r.trim()); }),
            _field(p, Icons.payments_outlined, 'إجمالي المبلغ (ج.م)', total == 0 ? '' : _n(total), () async { final r = await showCalc(context, total, 'EGP'); if (r != null) setState(() => total = r < 0 ? 0 : r); }),
            _field(p, Icons.format_list_numbered_rounded, 'عدد الأقساط', '$count', () async { final v = await _num(context, 'عدد الأقساط', count.toDouble()); if (v != null && v >= 1) setState(() => count = v.toInt()); }),
            if (total > 0 && count > 0) Padding(padding: const EdgeInsets.fromLTRB(6, 0, 6, 10), child: Text('القسط الشهري: ${_m(total / count)}', style: TextStyle(color: p.ink2))),
            _field(p, Icons.event_rounded, 'أول قسط يوم', enDate(first), () async { final d = await showDateSheet(context, first, title: 'أول قسط يوم'); if (d != null) setState(() => first = d); }),
            _field(p, Icons.credit_card_rounded, 'بتدفع من حساب', repo.account(acc)?.name ?? '', () async { final r = await showPickAccount(context, acc.isEmpty ? repo.defaultAcc : acc); if (r != null) setState(() => acc = r); }),
            _field(p, Icons.sticky_note_2_outlined, 'ملاحظة (اختياري)', note, () async { final r = await promptText(context, 'ملاحظة', hint: 'ملاحظة', initial: note); if (r != null) setState(() => note = r.trim()); }),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 14), child: bigButton(p, 'حفظ', kBlue, _save)),
      ]),
    );
  }
}
