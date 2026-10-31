import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import '../core/currency.dart';
import '../core/extras.dart';
import '../core/fixed_icons.dart';
import '../ui/icon_library.dart';
import '../ui/pay_widgets.dart';
import '../core/icon_pick.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/util.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/pickers.dart';
import '../ui/sheets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'acc_tx.dart';

// ======================= أقساطي (تصميم جديد) =======================
const Color _kTeal = Color(0xFF5FBFB2);

String _n(double v) {
  final s = fmt(v);
  return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
}

String _m(double v) => '${_n(v)} ${curOf('EGP').sym}';
DateTime _d0(DateTime d) => DateTime(d.year, d.month, d.day);
String _monthYear(DateTime d) => '${kMonths[d.month - 1]} ${toAr('${d.year}')}';
int _daysTo(DateTime d) => _d0(d).difference(_d0(DateTime.now())).inDays;
String _initial(String s) => s.trim().isEmpty ? '؟' : s.trim().substring(0, 1);

Widget _avatar(Pal p, String name, {double size = 52, String img = ''}) {
  final fb = Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: _kTeal.withValues(alpha: .18), shape: BoxShape.circle),
    child: Text(_initial(name), style: TextStyle(fontSize: size * .42, fontWeight: FontWeight.w600, color: _kTeal)),
  );
  final fx = fixedIconOf(img);
  if (fx != null) {
    return Container(width: size, height: size, alignment: Alignment.center, decoration: BoxDecoration(color: fx.color.withValues(alpha: .18), shape: BoxShape.circle), child: Icon(fx.icon, size: size * .52, color: fx.color));
  }
  if (img.startsWith('data:image')) {
    try {
      return ClipOval(child: Image.memory(base64Decode(img.substring(img.indexOf(',') + 1)), width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (c, e, s) => fb));
    } catch (_) {
      return fb;
    }
  }
  if (img.startsWith('http')) return ClipOval(child: Image.network(img, width: size, height: size, fit: BoxFit.cover, errorBuilder: (c, e, s) => fb));
  return fb;
}

class InstPage extends StatefulWidget {
  const InstPage({super.key});
  @override
  State<InstPage> createState() => _InstPageState();
}

class _InstPageState extends State<InstPage> {
  Future<void> _quickPay(Inst a) async {
    final amt = a.nextAmt;
    final ok = await confirmDialog(context, 'تسجيل قسط', '${_m(amt)} ل${a.name}، بتاريخ النهارده.', ok: 'سجّل قسط', cancel: 'إلغاء');
    if (ok) {
      extras.payInst(a);
      if (mounted) toast(context, 'اتسجّل قسط ${a.name}');
    }
  }

  Future<void> _delete(Inst a) async {
    final r = await askRemove(context, a.name, canFinish: a.done);
    if (r == null) return;
    switch (r) {
      case RemoveChoice.everything:
        extras.delInst(a, withTx: true);
      case RemoveChoice.serviceOnly:
        extras.delInst(a);
      case RemoveChoice.finish:
        extras.finishInst(a);
    }
  }

  void _menu(Inst a) => showSheet<void>(context, (c) {
        final p = Pal.of(c);
        Widget row(IconData ic, String t, Color col, VoidCallback f) => Tap(
              onTap: () {
                Navigator.of(c).pop();
                f();
              },
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16), child: Row(children: [Icon(ic, color: col), const SizedBox(width: 18), Text(t, style: TextStyle(fontSize: 18, color: col))])),
            );
        return SheetFrame(child: Column(mainAxisSize: MainAxisSize.min, children: [
          row(Icons.edit_note_rounded, 'تعديل', p.ink, () => Navigator.of(context).push(flowRoute(InstFormPage(edit: a)))),
          row(Icons.delete_outline_rounded, 'حذف', kRed, () => _delete(a)),
          const SizedBox(height: 10),
        ]));
      });

  Widget _summary(Pal p, List<Inst> list) {
    final open = list.where((x) => !x.done).toList();
    final left = open.fold(0.0, (s, x) => s + x.left);
    DateTime? last;
    for (final x in open) {
      final e = x.endDate;
      if (e != null && (last == null || e.isAfter(last))) last = e;
    }
    final months = last == null ? 0 : math.max(1, (last.year - DateTime.now().year) * 12 + last.month - DateTime.now().month + 1);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _kTeal.withValues(alpha: .14), borderRadius: BorderRadius.circular(30)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (open.isEmpty)
          const Text('كل أقساطك اتسددت 🎉', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700))
        else ...[
          Text('هتخلص من كل الأقساط في', style: TextStyle(fontSize: 15, color: _kTeal)),
          const SizedBox(height: 4),
          Text(_monthYear(last!), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('فاضل ${_m(left)} · $months شهر', style: TextStyle(fontSize: 15, color: _kTeal)),
          const SizedBox(height: 16),
          Text('الخطط على الشهور', style: TextStyle(fontSize: 14, color: p.ink2)),
          const SizedBox(height: 10),
          for (final x in open.take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(x.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(x.endDate == null ? '' : _monthYear(x.endDate!), style: TextStyle(fontSize: 13, color: p.ink2)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: x.total <= 0 ? 0 : (x.paid / x.total).clamp(0.0, 1.0), minHeight: 8, backgroundColor: p.ink.withValues(alpha: .08), valueColor: const AlwaysStoppedAnimation(_kTeal))),
              ]),
            ),
        ],
      ]),
    );
  }

  Widget _item(Pal p, Inst a, {required bool dueNow}) {
    final nd = a.nextDue;
    String sub;
    Color subCol = p.ink2;
    if (a.done) {
      sub = 'اتسدد بالكامل';
    } else if (dueNow && nd != null) {
      final d = _daysTo(nd);
      sub = d < 0 ? '${_m(a.nextAmt)} · متأخر ${-d} يوم' : (d == 0 ? '${_m(a.nextAmt)} · مستحق النهارده' : '${_m(a.nextAmt)} · مستحق بعد $d يوم');
      if (d < 0) subCol = kRed;
    } else {
      sub = 'فاضل ${a.monthsLeft} شهر · اتدفع ${a.pays.length}/${a.count}';
    }
    return Tap(
      scale: .99,
      onTap: () => _detail(a.id),
      onLongPress: () => _menu(a),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(24)),
        child: Row(children: [
          _avatar(p, a.name, img: a.img),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(fontSize: 13.5, color: subCol)),
            ]),
          ),
          if (dueNow && !a.done)
            Tap(onTap: () => _quickPay(a), child: Container(width: 46, height: 46, decoration: BoxDecoration(color: _kTeal.withValues(alpha: .2), shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: _kTeal)))
          else
            Text(_m(a.left), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _intro(Pal p) => ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), physics: const BouncingScrollPhysics(), children: [
        Container(
          height: 150,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(color: _kTeal.withValues(alpha: .14), borderRadius: BorderRadius.circular(30)),
          child: Row(children: [
            Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _kTeal, width: 4)), child: const Icon(Icons.check_rounded, color: _kTeal, size: 30)),
            const SizedBox(width: 20),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final f in const [.55, .8, 1.0])
                Container(height: 12, margin: const EdgeInsets.symmetric(vertical: 6), alignment: AlignmentDirectional.centerStart, decoration: BoxDecoration(color: p.ink.withValues(alpha: .07), borderRadius: BorderRadius.circular(8)), child: FractionallySizedBox(widthFactor: f, child: Container(decoration: BoxDecoration(color: _kTeal, borderRadius: BorderRadius.circular(8))))),
            ])),
          ]),
        ),
        const SizedBox(height: 26),
        const Text('اعرف هتخلص إمتى', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('ضيف أقساطك وهنقولك آخر قسط هيبقى إمتى، وهنفكرك بكل واحد قبلها.', style: TextStyle(fontSize: 16.5, color: p.ink2, height: 1.6)),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(child: _optCard(p, Icons.schedule_rounded, 'قسط شغال من زمان', 'نكمّل من اللي دفعته', kOrange, () => Navigator.of(context).push(flowRoute(const InstFormPage(existing: true))))),
          const SizedBox(width: 12),
          Expanded(child: _optCard(p, Icons.shopping_bag_outlined, 'اشتريت بالتقسيط', 'قسط جديد من النهارده', _kTeal, () => Navigator.of(context).push(flowRoute(const InstFormPage())))),
        ]),
      ]);

  Widget _optCard(Pal p, IconData ic, String t, String sub, Color col, VoidCallback f) => Tap(
        onTap: f,
        child: Container(
          height: 150,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: col.withValues(alpha: .16), borderRadius: BorderRadius.circular(26)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: col.withValues(alpha: .35), shape: BoxShape.circle), child: Icon(ic, color: col, size: 22)),
            const Spacer(),
            Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            Text(sub, style: TextStyle(fontSize: 13.5, color: col)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 10), child: TopBar(title: 'أقساطي', icon: Icons.more_horiz_rounded, iconColor: kOrange, trailing: Tap(onTap: () => Navigator.of(context).push(flowRoute(const InstFormPage())), child: Container(width: 40, height: 40, decoration: BoxDecoration(color: p.acc, shape: BoxShape.circle), child: const Icon(Icons.add_rounded, color: Colors.white, size: 24))))),
          Expanded(
            child: Live(b: (c) {
              final list = extras.insts;
              if (list.isEmpty) return _intro(p);
              final now = DateTime.now();
              bool dueThisMonth(Inst x) {
                final d = x.nextDue;
                return !x.done && d != null && (d.year < now.year || (d.year == now.year && d.month <= now.month));
              }

              final due = list.where(dueThisMonth).toList();
              final rest = list.where((x) => !dueThisMonth(x)).toList();
              final dueSum = due.fold(0.0, (s, x) => s + x.nextAmt);
              return Stack(children: [
                ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 130), physics: const BouncingScrollPhysics(), children: [
                  _summary(p, list),
                  if (due.isNotEmpty) ...[
                    Padding(padding: const EdgeInsets.fromLTRB(6, 22, 6, 10), child: Row(children: [const Text('مستحق الشهر ده', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)), const Spacer(), Text(_m(dueSum), style: TextStyle(fontSize: 16, color: p.ink2))])),
                    for (final x in due) _item(p, x, dueNow: true),
                  ],
                  if (rest.isNotEmpty) ...[
                    const Padding(padding: EdgeInsets.fromLTRB(6, 22, 6, 10), child: Text('باقي الأقساط', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                    for (final x in rest) _item(p, x, dueNow: false),
                  ],
                ]),
              ]);
            }),
          ),
        ]),
      ),
    );
  }

  // ---- تفاصيل خطة القسط ----
  void _detail(String id) => Navigator.of(context).push(flowRoute(_InstDetail(id: id, onEdit: (a) => Navigator.of(context).push(flowRoute(InstFormPage(edit: a))), onDelete: _delete)));
}

class _InstDetail extends StatefulWidget {
  final String id;
  final void Function(Inst) onEdit;
  final Future<void> Function(Inst) onDelete;
  const _InstDetail({required this.id, required this.onEdit, required this.onDelete});
  @override
  State<_InstDetail> createState() => _InstDetailState();
}

class _InstDetailState extends State<_InstDetail> {
  int _gen = 0; // يقفل صف السحب بعد تنفيذ الأمر
  /// بانل الدفع الموحّد (نفس اشتراكاتي): المبلغ · الحساب · التاريخ · ربط بمعاملة · Skipped.
  Future<void> _payPanel(BuildContext c, Inst inst, {DateTime? date}) => showPayPanel(
        c,
        title: 'تسجيل قسط',
        subtitle: inst.name,
        amount: inst.nextAmt,
        acc: inst.acc.isEmpty ? repo.defaultAcc : inst.acc,
        amountLabel: 'مبلغ القسط',
        date: date,
        onSave: (r) {
          final ok = extras.payInst(inst, amt: r.amt, when: r.date, acc: r.acc);
          if (!ok) return inst.onCard && r.acc == inst.card ? 'اختار حساب بنكي غير البطاقة للسداد' : 'القسط ده اتسجّل قبل كده';
          toast(c, 'اتسجّل قسط ${inst.name}');
          return null;
        },
        // Skipped: اتدفع فعلًا ويتحسب مسدد من غير ما نسجّل اتسحب من أنهي حساب (ومن غير معاملة).
        onSkip: (r) {
          if (extras.payInst(inst, amt: r.amt, when: r.date, record: false)) toast(c, 'اتسجّل القسط Skipped');
        },
        onLink: (panel) async {
          final nav = Navigator.of(panel);
          final t = await pickTxToLink(panel, (t) => !extras.isLinked(t.id) && !t.src.startsWith('inst:'));
          if (t == null) return;
          extras.linkInstTx(inst, t);
          nav.pop();
          if (c.mounted) toast(c, 'تم ربط المعاملة');
        },
      );

  String _accOf(Inst inst, int k) {
    final t = inst.pays[k];
    final id = inst.links['$t'] ?? 'in_${inst.id}_$t';
    final a = repo.tx(id)?.acc;
    return a == null ? '' : (repo.account(a)?.name ?? '');
  }

  Future<void> _payAll(BuildContext c, Inst inst) async {
    final ok = await confirmDialog(c, 'سدّد المتبقي كله', 'هيتسجّل ${_m(inst.left)} كدفعة واحدة وتخلص الخطة.', ok: 'سدّد', cancel: 'إلغاء', danger: false);
    if (ok) extras.payInstAll(inst);
  }

  /// قايمة الخطة: نفس تصميم قايمة الجمعيات (سدّد المتبقي كله ← تعديل ← حذف).
  void _menu(BuildContext c, Inst inst) => showSheet<void>(c, (cc) {
        final p = Pal.of(cc);
        Widget row(IconData ic, Color col, String t, VoidCallback f) => Tap(
              onTap: () {
                Navigator.of(cc).pop();
                f();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(22)),
                child: Row(children: [
                  Container(width: 44, height: 44, decoration: BoxDecoration(color: col.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)), child: Icon(ic, color: col)),
                  const SizedBox(width: 14),
                  Expanded(child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
                ]),
              ),
            );
        return SheetFrame(
          title: inst.name,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (!inst.done) row(Icons.check_circle_outline_rounded, _kTeal, 'سدّد المتبقي كله', () => _payAll(c, inst)),
              row(Icons.edit_rounded, p.ink, 'تعديل', () => widget.onEdit(inst)),
              row(Icons.delete_outline_rounded, kRed, 'حذف', () async {
                await widget.onDelete(inst);
                if (c.mounted) Navigator.of(c).maybePop();
              }),
            ]),
          ),
        );
      });

  Widget _stat(Pal p, String l, String v, {Color? col}) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l, style: TextStyle(color: p.ink2, fontSize: 14)),
          const SizedBox(height: 2),
          Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: col)),
        ]),
      );

  /// لوحة علوية: إجمالي المتقسّط · دفعت · باقي (نفس تصميم صفحة الجمعيات).
  Widget _top(Pal p, Inst inst) {
    final nd = inst.nextDue;
    final frac = inst.total <= 0 ? 0.0 : (inst.paid / inst.total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('إجمالي المتقسّط', style: TextStyle(fontSize: 15, color: p.ink2)),
        const SizedBox(height: 4),
        Text(_m(inst.total), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
        if (inst.onCard) Padding(padding: const EdgeInsets.only(top: 4), child: Text('على بطاقة ${repo.account(inst.card)?.name ?? ''} · المتاح ${_m(extras.cardSummary(inst.card).available)}', style: TextStyle(color: p.ink2, fontSize: 13.5))),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: frac, minHeight: 8, backgroundColor: p.ink.withValues(alpha: .08), valueColor: const AlwaysStoppedAnimation(_kTeal))),
        const SizedBox(height: 14),
        Divider(color: p.line, height: 1),
        const SizedBox(height: 12),
        Row(children: [
          _stat(p, 'دفعت', _m(inst.paid), col: _kTeal),
          _stat(p, 'باقي عليك', _m(inst.left)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _stat(p, 'اتدفع', '${inst.pays.length} من ${inst.count} شهر'),
          _stat(p, 'فاضل', '${inst.monthsLeft} شهر'),
        ]),
        if (nd != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text('موعد القسط الجاي: ${enDate(nd)}', style: TextStyle(color: p.ink2))),
      ]),
    );
  }

  /// صف شهر واحد: رقم الشهر · الميعاد · المبلغ · حالة (اتدفع / سجّل السداد / لسه).
  Widget _month(BuildContext c, Pal p, Inst inst, int k) {
    final paid = k < inst.pays.length;
    final isNext = k == inst.pays.length && !inst.done;
    final due = inst.dueOf(k);
    final late = isNext && due != null && due.isBefore(DateTime.now());
    final amt = paid ? inst.amts[k] : (isNext ? inst.nextAmt : inst.each);
    final acc = paid ? _accOf(inst, k) : '';
    final row = Tap(
      scale: .985,
      onTap: () async {
        if (paid) {
          if (await confirmDialog(c, 'حذف قسط', 'هيتحذف القسط ويتشال من كشف المصاريف.', ok: 'حذف', cancel: 'إلغاء')) extras.removeInstPay(inst, k);
        } else if (isNext) {
          _payPanel(c, inst, date: due);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22)),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: paid ? _kTeal.withValues(alpha: .2) : p.field, borderRadius: BorderRadius.circular(14)),
            child: paid ? const Icon(Icons.check_rounded, color: _kTeal) : Text(toAr('${k + 1}'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_m(amt), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              Text(due == null ? '' : 'موعده ${enDate(due)}${acc.isEmpty ? '' : ' · $acc'}', style: TextStyle(fontSize: 13, color: p.ink2)),
            ]),
          ),
          Text(paid ? 'اتدفع' : (isNext ? 'سجّل السداد' : 'لسه'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: paid ? p.ink2 : (late ? kRed : (isNext ? _kTeal : p.ink2)))),
        ]),
      ),
    );
    if (!isNext) return row;
    // اسحب يمين (فيزيائيًا) → «سداد» وتفتح بانل تسجيل قسط؛ السحب لآخر السطر بيفتحها علطول.
    final rtl = Directionality.of(c) == TextDirection.rtl;
    void pay() {
      setState(() => _gen++);
      _payPanel(c, inst, date: due);
    }

    final payBtn = swipeCircle(Icons.check_rounded, 'سداد', _kTeal, pay);
    return SwipeRow(
      key: ValueKey('im_${inst.id}_${k}_$_gen'),
      bg: p.bg,
      rightW: rtl ? 0 : 96,
      rightActions: rtl ? null : payBtn,
      leftW: rtl ? 96 : 0,
      leftActions: rtl ? payBtn : null,
      onFullRight: rtl ? null : pay,
      onFullLeft: rtl ? pay : null,
      child: row,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Live(b: (c) {
      final p = Pal.of(c);
      Inst? a;
      for (final x in extras.insts) {
        if (x.id == widget.id) a = x;
      }
      if (a == null) return PageShell(title: 'القسط', icon: Icons.event_repeat_rounded, child: emptyState(p, Icons.search_off_rounded, 'الخطة دي اتحذفت'));
      final inst = a;
      return PageShell(
        title: inst.name,
        sub: 'خطة أقساط',
        icon: Icons.event_repeat_rounded,
        iconColor: _kTeal,
        trailing: Tap(onTap: () => _menu(c, inst), child: Container(width: 40, height: 40, decoration: BoxDecoration(color: p.field, shape: BoxShape.circle), child: Icon(Icons.menu_rounded, color: p.ink2))),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), physics: const BouncingScrollPhysics(), children: [
          _top(p, inst),
          const SizedBox(height: 14),
          const SizedBox(height: 14),
          for (var k = 0; k < inst.count; k++) _month(c, p, inst, k),
        ]),
      );
    });
  }
}

// ======================= خطة أقساط جديدة =======================
class InstFormPage extends StatefulWidget {
  final Inst? edit;
  final bool existing; // قسط شغال من زمان (نسجّل اللي اتدفع بدون ما يدخل الميزانية)
  const InstFormPage({super.key, this.edit, this.existing = false});
  @override
  State<InstFormPage> createState() => _InstFormState();
}

class _InstFormState extends State<InstFormPage> {
  final nameC = TextEditingController(), noteC = TextEditingController();
  double total = 0;
  int count = 12, paidBefore = 0;
  late DateTime bought = DateTime.now();
  late DateTime first = addMonths(DateTime.now(), 1);
  String acc = '', card = '';
  bool auto = false, budget = true, bad = false;
  String img = '';
  final Set<int> reminds = {1}; // تنبيهات متعددة (عدد الأيام قبل القسط)

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      nameC.text = e.name;
      noteC.text = e.note;
      total = e.total;
      count = e.count;
      first = DateTime.fromMillisecondsSinceEpoch(e.first);
      bought = first;
      acc = e.acc;
      card = e.card;
      auto = e.auto;
      budget = e.budget;
      img = e.img;
      reminds
        ..clear()
        ..addAll(e.reminds);
    }
  }

  @override
  void dispose() {
    nameC.dispose();
    noteC.dispose();
    super.dispose();
  }

  void _save() {
    if (nameC.text.trim().isEmpty || total <= 0 || count < 1) {
      setState(() => bad = true);
      return;
    }
    final cerr = extras.validateInst(card: card, total: total, edit: widget.edit);
    if (cerr != null) {
      toast(context, cerr);
      return;
    }
    if (card.isNotEmpty && (acc.isEmpty ? repo.defaultAcc : acc) == card) {
      toast(context, 'اختار حساب بنكي تدفع منه غير البطاقة نفسها');
      return;
    }
    final e = widget.edit;
    if (e != null) {
      e
        ..card = card
        ..name = nameC.text.trim()
        ..total = total
        ..count = count
        ..first = first.millisecondsSinceEpoch
        ..acc = acc
        ..note = noteC.text.trim()
        ..auto = auto
        ..budget = budget
        ..img = img
        ..reminds = (reminds.toList()..sort())
        ..remind = reminds.isEmpty ? -1 : (reminds.toList()..sort()).first;
      extras.saveInst(e);
    } else {
      final a = Inst(id: 'in_${DateTime.now().microsecondsSinceEpoch}', card: card, name: nameC.text.trim(), total: total, count: count, first: first.millisecondsSinceEpoch, acc: acc, note: noteC.text.trim(), auto: auto, budget: budget, img: img, remind: reminds.isEmpty ? -1 : (reminds.toList()..sort()).first, reminds: (reminds.toList()..sort()));
      extras.saveInst(a);
      // أقساط قديمة اتدفعت قبل كده: تتسجل على الخطة بس
      for (var i = 0; i < math.min(paidBefore, count - 1); i++) {
        final d = a.dueOf(i);
        if (d != null) extras.payInst(a, when: d, record: false);
      }
      extras.runAutoInst();
    }
    Navigator.of(context).pop();
  }

  /// سطر توضيحي للبطاقة المختارة: الحد والمتاح (مع رجوع المتبقي القديم للخطة عند التعديل).
  String _cardHint(String id) {
    final s = extras.cardSummary(id);
    final back = (widget.edit != null && widget.edit!.card == id) ? widget.edit!.left : 0.0;
    return 'الحد ${_n(s.limit)} · المتاح ${_n(s.available + back)} ج.م';
  }

  /// أيقونة الخطة: نفس مكتبة الأيقونات الموحّدة في كل التطبيق.
  Future<void> _imageSheet() async {
    final r = await showIconLibrary(context, current: img, title: 'أيقونة القسط', resetLabel: 'استخدام أول حرف من الاسم');
    if (r != null && mounted) setState(() => img = r);
  }

  /// اختيار متعدد: الضغط على الشريحة يضيفها/يشيلها، و«من غير تذكير» تمسح الكل.
  Widget _multiChips(Pal p, List<(String, String)> opts, Set<int> sel) {
    Widget chip(String label, bool on, VoidCallback f) => Tap(
          onTap: () => setState(f),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(color: on ? kBlue.withValues(alpha: .18) : p.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: on ? kBlue : Colors.transparent)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (on) ...[Icon(Icons.check_rounded, size: 16, color: kBlue), const SizedBox(width: 5)],
              Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: on ? kBlue : p.ink2)),
            ]),
          ),
        );
    return Wrap(spacing: 8, runSpacing: 8, children: [
      chip('من غير تذكير', sel.isEmpty, () => sel.clear()),
      for (final o in opts)
        chip(o.$2, sel.contains(int.parse(o.$1)), () {
          final v = int.parse(o.$1);
          sel.contains(v) ? sel.remove(v) : sel.add(v);
        }),
    ]);
  }

  Widget _chips(Pal p, List<(String, String)> opts, String sel, void Function(String) f) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in opts)
          Tap(
            onTap: () => setState(() => f(o.$1)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(color: o.$1 == sel ? kBlue.withValues(alpha: .18) : p.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: o.$1 == sel ? kBlue : Colors.transparent)),
              child: Text(o.$2, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: o.$1 == sel ? kBlue : p.ink2)),
            ),
          ),
      ]);

  Widget _label(Pal p, String t) => Padding(padding: const EdgeInsets.fromLTRB(6, 14, 6, 8), child: Text(t, style: TextStyle(fontSize: 15, color: p.ink2)));

  Widget _box(Pal p, {required Widget child, bool err = false, VoidCallback? onTap}) => Tap(
        scale: .99,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22), border: err ? Border.all(color: kRed, width: 1.5) : null),
          child: child,
        ),
      );

  Widget _switch(Pal p, String t, String sub, bool v, ValueChanged<bool> f, IconData ic) => Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(24)),
        child: Row(children: [
          Switch(value: v, onChanged: f, activeThumbColor: Colors.white, activeTrackColor: kGreen),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), const SizedBox(height: 2), Text(sub, style: TextStyle(fontSize: 13.5, color: p.ink2, height: 1.4))])),
          const SizedBox(width: 8),
          Icon(ic, color: p.ink2),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final each = (total > 0 && count > 0) ? total / count : 0.0;
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(children: [
              GlassBtn(Icons.chevron_left_rounded, () => Navigator.of(context).maybePop(), size: 46),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.edit == null ? (widget.existing ? 'قسط شغال من زمان' : 'خطة أقساط جديدة') : 'تعديل خطة الأقساط', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 30), physics: const BouncingScrollPhysics(), children: [
              _label(p, 'التفاصيل'),
              _box(p, err: bad && nameC.text.trim().isEmpty, child: Row(children: [
                Tap(onTap: _imageSheet, child: Stack(clipBehavior: Clip.none, children: [
                  _avatar(p, nameC.text, size: 44, img: img),
                  PositionedDirectional(bottom: -3, end: -3, child: Container(width: 20, height: 20, decoration: BoxDecoration(color: kBlue, shape: BoxShape.circle, border: Border.all(color: p.bg, width: 2)), child: const Icon(Icons.edit_rounded, color: Colors.white, size: 11))),
                ])),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: nameC, style: const TextStyle(fontSize: 18), decoration: InputDecoration(border: InputBorder.none, hintText: 'اسم المنتج', hintStyle: TextStyle(color: p.ink2)))),
              ])),
              const SizedBox(height: 10),
              _box(p, err: bad && total <= 0, onTap: () async {
                final r = await showCalc(context, total, 'EGP');
                if (r != null) setState(() => total = r < 0 ? 0 : r);
              }, child: Row(children: [Icon(Icons.payments_outlined, color: p.ink2), const SizedBox(width: 12), Text(total == 0 ? 'الإجمالي (ج.م)' : _n(total), style: TextStyle(fontSize: 18, color: total == 0 ? p.ink2 : p.ink))])),
              _label(p, 'الخطة'),
              _box(p, err: bad && count < 1, onTap: () async {
                final r = await showCalc(context, count.toDouble(), 'EGP');
                if (r != null && r >= 1) setState(() => count = r.toInt());
              }, child: Row(children: [Icon(Icons.calendar_month_outlined, color: p.ink2), const SizedBox(width: 12), Text('عدد شهور السداد: ', style: TextStyle(color: p.ink2)), Text('$count', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))])),
              if (each > 0) Padding(padding: const EdgeInsets.fromLTRB(6, 8, 6, 0), child: Text('${_n(total)} ج.م ÷ $count شهر = ${_n(each)} ج.م في الشهر', style: TextStyle(color: _kTeal, fontSize: 15))),
              const SizedBox(height: 10),
              _box(p, onTap: () async {
                final d = await showDateSheet(context, bought, title: 'تاريخ الشراء');
                if (d != null) setState(() => bought = d);
              }, child: Row(children: [Icon(Icons.event_note_outlined, color: p.ink2), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('تاريخ الشراء', style: TextStyle(fontSize: 13, color: p.ink2)), Text(enDate(bought), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))])])),
              const SizedBox(height: 10),
              _box(p, onTap: () async {
                final d = await showDateSheet(context, first, title: 'ميعاد أول قسط');
                if (d != null) setState(() => first = d);
              }, child: Row(children: [Icon(Icons.event_available_outlined, color: p.ink2), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ميعاد أول قسط', style: TextStyle(fontSize: 13, color: p.ink2)), Text(enDate(first), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)), Text('وبعده كل شهر يوم ${first.day}', style: TextStyle(fontSize: 13, color: _kTeal))])])),
              if (widget.existing && widget.edit == null) ...[
                const SizedBox(height: 10),
                _box(p, onTap: () async {
                  final r = await showCalc(context, paidBefore.toDouble(), 'EGP');
                  if (r != null && r >= 0) setState(() => paidBefore = math.min(r.toInt(), math.max(count - 1, 0)));
                }, child: Row(children: [Icon(Icons.task_alt_rounded, color: p.ink2), const SizedBox(width: 12), Text('اتدفع كام قسط لحد دلوقتي؟ ', style: TextStyle(color: p.ink2)), Text('$paidBefore', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))])),
                Padding(padding: const EdgeInsets.fromLTRB(6, 6, 6, 0), child: Text('الأقساط اللي اتدفعت قبل كده بتتسجل على الخطة بس، ومش بتدخل الميزانية ولا رصيد الحساب.', style: TextStyle(fontSize: 13, color: p.ink2, height: 1.5))),
              ],
              const SizedBox(height: 10),
              // قسط على بطاقة ائتمانية: بيتحجز من الحد الائتماني (مش مصروف). كل قسط بيتدفع من الحساب البنكي تحت.
              if (repo.accList.any((x) => x.kind == 'credit')) ...[
                _box(p, onTap: () async {
                  final cards = repo.accList.where((x) => x.kind == 'credit').toList();
                  final r = await showSelect(context, 'قسط على بطاقة ائتمانية', [('', 'قسط عادي (من غير بطاقة)'), for (final x in cards) (x.id, x.name)], card);
                  if (r != null) setState(() => card = r);
                }, child: Row(children: [
                  Icon(Icons.credit_score_rounded, color: p.ink2),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('على بطاقة ائتمانية', style: TextStyle(fontSize: 13, color: p.ink2)),
                    Text(card.isEmpty ? 'قسط عادي' : (repo.account(card)?.name ?? '—'), style: const TextStyle(fontSize: 17)),
                    if (card.isNotEmpty) Text(_cardHint(card), style: TextStyle(fontSize: 12.5, color: p.ink2)),
                  ])),
                ])),
                const SizedBox(height: 10),
              ],
              _box(p, onTap: () async {
                final r = await showPickAccount(context, acc.isEmpty ? repo.defaultAcc : acc, title: 'بتدفع من حساب');
                if (r != null) setState(() => acc = r);
              }, child: Row(children: [Icon(Icons.credit_card_rounded, color: p.ink2), const SizedBox(width: 12), Text(repo.account(acc.isEmpty ? repo.defaultAcc : acc)?.name ?? '—', style: const TextStyle(fontSize: 17))])),
              _switch(p, 'تسجيل القسط لوحده', 'هتسجّل كل قسط بنفسك، وهيوصلك تذكير قبل الموعد بيوم.', auto, (v) => setState(() => auto = v), Icons.repeat_rounded),
              _label(p, 'الإشعارات'),
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('تقدر تختار أكتر من تنبيه', style: TextStyle(fontSize: 13, color: p.ink2))),
              _multiChips(p, const [('0', 'يوم القسط'), ('1', 'قبلها بيوم'), ('2', 'بيومين'), ('3', 'بـ 3 أيام'), ('7', 'بأسبوع')], reminds),
              _label(p, 'خيارات زيادة'),
              _box(p, child: Row(children: [Icon(Icons.sticky_note_2_outlined, color: p.ink2), const SizedBox(width: 12), Expanded(child: TextField(controller: noteC, decoration: InputDecoration(border: InputBorder.none, hintText: 'ملاحظة', hintStyle: TextStyle(color: p.ink2))))])),
              _switch(p, 'احسبها من الميزانية', 'بتتسجل في الحركات وبتتحسب في المصاريف.', budget, (v) => setState(() => budget = v), Icons.account_balance_wallet_outlined),
              const SizedBox(height: 18),
              Tap(onTap: _save, child: Container(height: 60, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFF8BE6D6), borderRadius: BorderRadius.circular(30)), child: const Text('حفظ', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF0B3D36))))),
            ]),
          ),
        ]),
      ),
    );
  }
}
