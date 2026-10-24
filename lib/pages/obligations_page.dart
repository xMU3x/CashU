import '../ui/motion.dart';
import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import '../core/extras.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/util.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'assoc_inst.dart';
import 'acc_tx.dart';
import 'loans_page.dart';
import 'subs_page.dart';

// ======================= الالتزامات =======================
// إجمالي كل اللي عليك في فترة (شهر/سنة): أقساط + اشتراكات + ديون عليك + جمعيات، وتحتها الالتزامات نفسها.

class _Ob {
  final String kind; // inst | sub | debt | assoc
  final String title;
  final String sub;
  final double amt;
  final DateTime? when;
  final IconData icon;
  final Color color;
  final Widget Function() page;
  const _Ob(this.kind, this.title, this.sub, this.amt, this.when, this.icon, this.color, this.page);
}

const _kKinds = <String, (String, IconData, Color)>{
  'inst': ('الأقساط', Icons.payments_rounded, Color(0xFF5FBFB2)),
  'sub': ('الاشتراكات', Icons.widgets_rounded, Color(0xFF8B5CF6)),
  'debt': ('الديون', Icons.people_alt_rounded, Color(0xFFC96A4A)),
  'assoc': ('الجمعيات', Icons.groups_rounded, Color(0xFF2E7568)),
  'rec': ('المصاريف المتكررة', Icons.repeat_rounded, Color(0xFF0A84FF)),
};

bool _in(DateTime d, DateTime from, DateTime to) => !d.isBefore(from) && d.isBefore(to);

/// يجمع الالتزامات اللي موعدها داخل [from, to). دالة نقية لسهولة الاختبار.
List<_Ob> buildObligations(DateTime from, DateTime to, {List<Inst>? insts, List<Sub>? subs, List<dynamic>? loans, List<Assoc>? assocs, List<Tx>? recurring}) {
  final out = <_Ob>[];
  for (final i in (insts ?? extras.insts)) {
    if (i.done) continue;
    for (var k = i.pays.length; k < i.count; k++) {
      final d = i.dueOf(k);
      if (d == null) continue;
      if (_in(d, from, to)) out.add(_Ob('inst', i.name, 'القسط ${toAr('${k + 1}')} من ${toAr('${i.count}')}', i.nextAmt, d, Icons.payments_rounded, const Color(0xFF5FBFB2), () => const InstPage()));
    }
  }
  for (final s in (subs ?? extras.subs)) {
    if (!s.isActive || s.cyc == 'once') {
      if (s.isActive && s.cyc == 'once') {
        final d = s.firstDate;
        if (_in(d, from, to)) out.add(_Ob('sub', s.name, 'دفعة واحدة', s.amt, d, Icons.widgets_rounded, const Color(0xFF8B5CF6), () => const SubscriptionsPage()));
      }
      continue;
    }
    // نعدّ مرات التجديد داخل الفترة بالتقريب من قيمة الدورة
    var d = s.nextDue;
    var guard = 0;
    while (d != null && d.isBefore(to) && guard++ < 60) {
      if (!d.isBefore(from)) out.add(_Ob('sub', s.name, 'تجديد اشتراك', s.amt, d, Icons.widgets_rounded, const Color(0xFF8B5CF6), () => const SubscriptionsPage()));
      d = switch (s.cyc) {
        'week' => d.add(const Duration(days: 7)),
        'q3' => addMonths(d, 3),
        'h6' => addMonths(d, 6),
        'year' => addMonths(d, 12),
        _ => addMonths(d, 1),
      };
    }
  }
  for (final l in (loans ?? repo.loanList)) {
    if (l.dir != 'owe' || l.settled || l.left <= 0) continue;
    if (l.due <= 0) continue;
    final d = DateTime.fromMillisecondsSinceEpoch(l.due);
    if (_in(d, from, to) || (d.isBefore(from) && _in(DateTime.now(), from, to))) {
      out.add(_Ob('debt', l.person, d.isBefore(DateTime.now()) ? 'متأخر' : 'دين مستحق', l.leftBase, d, Icons.people_alt_rounded, const Color(0xFFC96A4A), () => const LoansPage()));
    }
  }
  for (final a in (assocs ?? extras.assocs)) {
    if (a.closed) continue;
    for (var k = 0; k < a.rounds; k++) {
      if (a.isPaid(k)) continue;
      final d = a.dueOf(k);
      if (_in(d, from, to)) out.add(_Ob('assoc', a.name, 'الدور ${toAr('${k + 1}')} من ${toAr('${a.rounds}')}', a.myPay, d, Icons.groups_rounded, const Color(0xFF2E7568), () => const AssocPage()));
    }
  }
  // المصاريف المتكررة (معاملات مصروف rep != none): كل تكرار يقع داخل الفترة يتحسب التزام.
  for (final t in (recurring ?? repo.recurring)) {
    if (t.type != 'exp' || t.del || t.rep == 'none' || t.rep.isEmpty) continue;
    var ms = t.nx == 0 ? nextOcc(t.ts, t.rep) : t.nx;
    var guard = 0;
    while (guard++ < 400) {
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      if (!d.isBefore(to)) break;
      if (!d.isBefore(from)) {
        final title = t.pay.isNotEmpty ? t.pay : (t.note.isNotEmpty ? limitWords(t.note) : 'مصروف متكرر');
        out.add(_Ob('rec', title, 'مصروف متكرر', t.base, d, Icons.repeat_rounded, const Color(0xFF0A84FF), () => const AccountTxPage()));
      }
      final n = nextOcc(ms, t.rep);
      if (n <= ms) break;
      ms = n;
    }
  }
  out.sort((x, y) => (x.when ?? DateTime(2100)).compareTo(y.when ?? DateTime(2100)));
  return out;
}

class ObligationsPage extends StatefulWidget {
  const ObligationsPage({super.key});
  @override
  State<ObligationsPage> createState() => _ObligationsState();
}

class _ObligationsState extends State<ObligationsPage> {
  bool year = false;
  DateTime cur = DateTime(DateTime.now().year, DateTime.now().month);
  String filter = 'all';

  DateTime get _from => year ? DateTime(cur.year) : DateTime(cur.year, cur.month);
  DateTime get _to => year ? DateTime(cur.year + 1) : DateTime(cur.year, cur.month + 1);
  String get _label => year ? toAr('${cur.year}') : '${kMonths[cur.month - 1]} ${toAr('${cur.year}')}';
  void _step(int d) => setState(() => cur = year ? DateTime(cur.year + d, cur.month) : DateTime(cur.year, cur.month + d));

  Widget _seg(Pal p) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          for (final e in [(false, 'شهر'), (true, 'سنة')])
            Expanded(
              child: Tap(
                onTap: () => setState(() => year = e.$1),
                child: AnimatedContainer(
                  duration: Motion.fade,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: year == e.$1 ? p.card : Colors.transparent, borderRadius: BorderRadius.circular(14)),
                  child: Text(e.$2, style: TextStyle(fontWeight: FontWeight.w700, color: year == e.$1 ? p.ink : p.ink2)),
                ),
              ),
            ),
        ]),
      );

  Widget _row(Pal p, _Ob o) => Tap(
        scale: .985,
        onTap: () => Navigator.of(context).push(flowRoute(o.page())),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: iosCard(p, r: 20),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: o.color.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)), child: Icon(o.icon, color: o.color, size: 23)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
              Text('${o.sub}${o.when == null ? '' : ' · ${enDate(o.when!)}'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: o.sub == 'متأخر' ? kRed : p.ink2)),
            ])),
            Text(egp(o.amt), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: 'الالتزامات',
      sub: 'كل اللي عليك في الفترة',
      icon: Icons.event_repeat_rounded,
      iconColor: kBlue,
      child: Live(b: (c) {
        final all = buildObligations(_from, _to);
        final list = filter == 'all' ? all : all.where((o) => o.kind == filter).toList();
        final total = all.fold(0.0, (s, o) => s + o.amt);
        final byKind = <String, double>{for (final k in _kKinds.keys) k: all.where((o) => o.kind == k).fold(0.0, (s, o) => s + o.amt)};
        return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), physics: const BouncingScrollPhysics(), children: [
          Reveal(
            i: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: kBlue.withValues(alpha: .13), borderRadius: BorderRadius.circular(28)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('إجمالي الالتزامات', style: TextStyle(fontSize: 15, color: p.ink2)),
                const SizedBox(height: 4),
                Text(egp(total), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                if (total > 0)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 8,
                      child: Row(children: [
                        for (final e in _kKinds.entries)
                          if (byKind[e.key]! > 0) Expanded(flex: (byKind[e.key]! * 100 / total).round().clamp(1, 100), child: Container(color: e.value.$3)),
                      ]),
                    ),
                  ),
                const SizedBox(height: 10),
                Wrap(spacing: 14, runSpacing: 6, children: [
                  for (final e in _kKinds.entries)
                    if (byKind[e.key]! > 0) Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 9, height: 9, decoration: BoxDecoration(color: e.value.$3, shape: BoxShape.circle)), const SizedBox(width: 6), Text('${e.value.$1} ${egp(byKind[e.key]!)}', style: TextStyle(fontSize: 12.5, color: p.ink2))]),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          _seg(p),
          const SizedBox(height: 10),
          Row(children: [
            Tap(onTap: () => _step(-1), child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.chevron_left_rounded, color: p.ink2))),
            Expanded(child: Center(child: Text(_label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)))),
            Tap(onTap: () => _step(1), child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.chevron_right_rounded, color: p.ink2))),
          ]),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final e in [('all', 'الكل'), for (final k in _kKinds.entries) (k.key, k.value.$1)])
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Tap(
                    onTap: () => setState(() => filter = e.$1),
                    child: AnimatedContainer(
                      duration: Motion.state,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(color: filter == e.$1 ? kBlue.withValues(alpha: .18) : p.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: filter == e.$1 ? kBlue : Colors.transparent)),
                      child: Text(e.$2, style: TextStyle(fontWeight: FontWeight.w600, color: filter == e.$1 ? kBlue : p.ink2)),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty) emptyState(p, Icons.event_available_rounded, 'مفيش التزامات في الفترة دي.') else for (final o in list) _row(p, o),
        ]);
      }),
    );
  }
}
