import 'package:flutter/material.dart' hide Text;
import 'loc_text.dart';
import '../core/currency.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/util.dart';
import '../pages/acc_tx.dart';
import 'anim.dart';
import 'ios.dart' show fixed2, enDate;
import 'pickers.dart';
import 'sheets.dart';
import 'theme.dart';
import 'widgets.dart';

/// عناصر الدفع الموحّدة: سجل الدفعات + بانل الدفع + زر «ربط بمعاملة» — نفس الشكل في الاشتراكات والأقساط (وأي صفحة دفع).

String _fmt(double v) {
  final s = fixed2(v);
  return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
}

/// زر صغير «ربط بمعاملة».
/// أزرار الدفع الموحّدة: [top] (اختياري، مثل «سدّد المتبقي») ثم زر «ربط بمعاملة» صغير ثم زر «سجّل الدفع» بحجم متوسط.
Widget payActions(Pal p, {required String payLabel, required VoidCallback onPay, required VoidCallback onLink, Widget? top}) => Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (top != null) ...[top, const SizedBox(height: 10)],
        linkPill(p, onLink),
        const SizedBox(height: 10),
        Tap(
          scale: .97,
          onTap: onPay,
          child: Container(
            height: 50,
            width: double.infinity, // عرض الشاشة كامل
            alignment: Alignment.center,
            decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: kBlue.withValues(alpha: .3), blurRadius: 12, offset: const Offset(0, 4))]),
            child: Text(payLabel, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );

Widget linkPill(Pal p, VoidCallback onTap, {String label = 'ربط بمعاملة'}) => Tap(
      scale: .95,
      onTap: onTap,
      child: Container(
        width: 190, // صغير الارتفاع وعريض نسبيًا
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: kBlue.withValues(alpha: .14), borderRadius: BorderRadius.circular(17)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.link_rounded, color: kBlue, size: 17),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 13.5, color: kBlue, fontWeight: FontWeight.w600)),
        ]),
      ),
    );

/// يفتح قائمة المعاملات لاختيار مصروف قديم يتربط (لا يعرض المعلّق ولا اللي اتربط قبل كده).
Future<Tx?> pickTxToLink(BuildContext context, bool Function(Tx) allowed) =>
    Navigator.of(context).push<Tx>(flowRoute(AccountTxPage(pick: true, pickWhere: (t) => t.type == 'exp' && !t.pend && allowed(t))));

/// صف في سجل الدفعات.
class PayEntry {
  final int ts;
  final double amt;
  final String accName; // فاضي = مفيش حساب
  final bool linked, skipped, due; // due = قسط/دفعة جاية (لسه ما اتدفعتش)
  final VoidCallback? onTap, onMore;
  const PayEntry({required this.ts, required this.amt, this.accName = '', this.linked = false, this.skipped = false, this.due = false, this.onTap, this.onMore});
}

/// «سجل الدفعات» القابل للطي — نفس الشكل في كل الصفحات.
class PayLog extends StatefulWidget {
  final List<PayEntry> entries;
  final String title;
  final bool startOpen;
  const PayLog({super.key, required this.entries, this.title = 'سجل الدفعات', this.startOpen = false});
  @override
  State<PayLog> createState() => _PayLogState();
}

class _PayLogState extends State<PayLog> {
  late bool open = widget.startOpen;

  Widget _row(Pal p, PayEntry e) {
    final date = enDate(DateTime.fromMillisecondsSinceEpoch(e.ts));
    final sub = e.skipped ? 'Skipped' : (e.accName.isEmpty ? '' : e.accName);
    final ic = e.due ? Icons.schedule_rounded : (e.skipped ? Icons.skip_next_rounded : (e.linked ? Icons.link_rounded : Icons.check_circle_outline_rounded));
    final col = e.due ? kOrange : (e.skipped ? p.ink2 : kGreen);
    return Tap(
      scale: .99,
      onTap: e.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(color: e.due ? kOrange.withValues(alpha: .10) : p.field.withValues(alpha: .6), borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Icon(ic, color: col, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.due ? 'القسط الجاي · $date' : date, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: p.ink2)),
          ])),
          Text(_fmt(e.amt), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: e.due ? kOrange : p.ink)),
          if (e.onMore != null) Tap(onTap: e.onMore, child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.more_horiz_rounded, color: p.ink2, size: 20))) else const SizedBox(width: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final paid = widget.entries.where((e) => !e.due).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Tap(
        scale: .99,
        onTap: () => setState(() => open = !open),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            Text('$paid', style: TextStyle(color: p.ink2)),
            const SizedBox(width: 4),
            AnimatedRotation(turns: open ? .5 : 0, duration: const Duration(milliseconds: 220), child: Icon(Icons.expand_more_rounded, color: p.ink2)),
          ]),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: open
            ? Padding(
                padding: const EdgeInsets.only(top: 6),
                child: widget.entries.isEmpty ? Padding(padding: const EdgeInsets.all(14), child: Text('لسه مفيش دفعات.', style: TextStyle(color: p.ink2))) : Column(children: [for (final e in widget.entries) _row(p, e)]),
              )
            : const SizedBox(width: double.infinity),
      ),
    ]);
  }
}

/// نتيجة بانل الدفع.
class PayResult {
  final double amt;
  final DateTime date;
  final String acc;

  /// تقسيم الدفع على أكتر من حساب (حساب، مبلغ)؛ فاضية = دفع من حساب واحد.
  final List<(String, double)> parts;
  const PayResult(this.amt, this.date, this.acc, [this.parts = const []]);
}

/// بانل الدفع الموحّد: المبلغ · اتسحبت من أنهي حساب · التاريخ · «ربط بمعاملة» · وزر Skipped (اتدفعت ومش لازم حساب).
/// [onSave] يرجّع رسالة خطأ لو الدفع اترفض (فتفضل البانل مفتوحة)، أو null لو نجح.
/// [onSkip] اختياري: لو اتبعت يظهر زر Skipped. [onLink] اختياري: لو اتبعت يظهر «ربط بمعاملة».
Future<void> showPayPanel(
  BuildContext context, {
  required String title,
  String subtitle = '',
  required double amount,
  required String acc,
  required String amountLabel,
  String saveLabel = 'حفظ',
  DateTime? date,
  required String? Function(PayResult r) onSave,
  void Function(PayResult r)? onSkip,
  Future<void> Function(BuildContext panel)? onLink,
  bool allowSplit = false,
}) {
  var amt = amount;
  var when = date ?? DateTime.now();
  var from = acc;
  var splits = <(String, double)>[];
  return showSheet<void>(context, (c) => StatefulBuilder(builder: (c, set) {
        final p = Pal.of(c);
        Widget field(IconData ic, String label, String value, Future<void> Function() f) => Tap(
              onTap: () => f(),
              scale: .99,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(22)),
                child: Row(children: [
                  Icon(ic, color: p.ink2, size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 12.5, color: p.ink2)), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))])),
                ]),
              ),
            );
        final a = repo.account(from);
        PayResult res() {
          final now = DateTime.now();
          final sp = splits.length > 1 && (splits.fold(0.0, (s, x) => s + x.$2) - amt).abs() < 0.01 ? splits : <(String, double)>[];
          return PayResult(amt, DateTime(when.year, when.month, when.day, now.hour, now.minute, now.second), sp.isNotEmpty ? sp.first.$1 : from, sp);
        }

        return SheetFrame(
          title: title,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (subtitle.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(subtitle, style: TextStyle(fontSize: 15, color: p.ink2))),
              field(Icons.payments_outlined, '$amountLabel (${curOf('EGP').sym})', _fmt(amt), () async {
                final r = await showCalc(c, amt, 'EGP');
                if (r != null && r > 0) set(() => amt = r);
              }),
              if (splits.length > 1)
                field(Icons.call_split_rounded, 'اتسحبت من حسابات', splits.map((x) => '${repo.account(x.$1)?.name ?? ''} (${_fmt(x.$2)})').join(' + '), () async {
                  final r = await showSplitSheet(c, amt, 'EGP', from, splits);
                  if (r != null) set(() => splits = r.length > 1 ? r : []);
                })
              else
                field(Icons.credit_card_rounded, 'اتسحبت من حساب', a == null ? 'اختر الحساب' : a.name, () async {
                  final r = await showPickAccount(c, from);
                  if (r != null) set(() => from = r);
                }),
              if (allowSplit && splits.length < 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Tap(
                      scale: .95,
                      onTap: () async {
                        final r = await showSplitSheet(c, amt, 'EGP', from, splits);
                        if (r != null) set(() => splits = r.length > 1 ? r : []);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(color: kBlue.withValues(alpha: .14), borderRadius: BorderRadius.circular(16)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.call_split_rounded, color: kBlue, size: 18), const SizedBox(width: 5), Text('تقسيم على أكتر من حساب', style: TextStyle(fontSize: 13.5, color: kBlue, fontWeight: FontWeight.w600))]),
                      ),
                    ),
                  ),
                ),
              field(Icons.event_rounded, 'التاريخ', enDate(when), () async {
                final d = await showDateSheet(c, when, title: 'التاريخ');
                if (d != null) set(() => when = d);
              }),
              if (onLink != null || onSkip != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    if (onLink != null) linkPill(p, () => onLink(c)),
                    const Spacer(),
                    if (onSkip != null)
                      Tap(
                        scale: .95,
                        onTap: () {
                          onSkip(res());
                          Navigator.of(c).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(16)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.skip_next_rounded, color: p.ink2, size: 18), const SizedBox(width: 5), Text('Skipped', style: TextStyle(fontSize: 13.5, color: p.ink2, fontWeight: FontWeight.w600))]),
                        ),
                      ),
                  ]),
                ),
              const SizedBox(height: 4),
              bigButton(p, saveLabel, kBlue, () {
                final err = onSave(res());
                if (err != null) {
                  toast(c, err);
                  return;
                }
                Navigator.of(c).pop();
              }),
            ]),
          ),
        );
      }));
}
