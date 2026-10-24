import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Text;
import 'loc_text.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/util.dart' show kMonths, tick;
import 'anim.dart';
import 'ios.dart';
import 'theme.dart';

/// قائمة الضغطة المطولة على الحساب: معاينة آخر المعاملات (مجمّعة بالشهر) + قائمة إجراءات.
class AccMenuAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger, dividerBefore;
  const AccMenuAction(this.icon, this.label, this.onTap, {this.danger = false, this.dividerBefore = false});
}

Future<void> showAccountMenu(BuildContext context, Account a, List<AccMenuAction> actions) {
  tick();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'account-menu',
    barrierColor: Colors.black.withValues(alpha: .45),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (c, _, __) => _AccMenu(acc: a, actions: actions),
    transitionBuilder: (c, anim, _, child) {
      final cv = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8 * cv.value, sigmaY: 8 * cv.value),
        child: FadeTransition(opacity: cv, child: ScaleTransition(scale: Tween<double>(begin: .94, end: 1).animate(cv), child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, .03), end: Offset.zero).animate(cv), child: child))),
      );
    },
  );
}

class _AccMenu extends StatelessWidget {
  final Account acc;
  final List<AccMenuAction> actions;
  const _AccMenu({required this.acc, required this.actions});

  double _signed(Tx t) {
    switch (t.type) {
      case 'inc':
        return t.amt;
      case 'exp':
        return -t.amt;
      case 'xfer':
        return t.to == acc.id ? t.amt : -t.amt;
      default:
        return (t.sign >= 0 ? 1 : -1) * t.amt;
    }
  }

  Widget _preview(Pal p) {
    final list = repo.txOf(acc.id).take(8).toList();
    final byMonth = <String, List<Tx>>{};
    for (final t in list) {
      byMonth.putIfAbsent('${t.date.year}-${t.date.month}', () => []).add(t);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(26)),
      child: list.isEmpty
          ? Padding(padding: const EdgeInsets.all(18), child: Center(child: Text('No transactions yet', style: TextStyle(color: p.ink2))))
          : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final e in byMonth.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 2, 6, 6),
                  child: Text(isAr ? kMonths[e.value.first.date.month - 1] : monthEn(e.value.first.date.month), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                for (final t in e.value)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                    child: Row(children: [
                      Container(width: 34, height: 34, decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(10)), child: Icon(txIcon(t, viewAcc: acc.id).$1, color: txIcon(t, viewAcc: acc.id).$2, size: 19)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(txTitle(t), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
                          Text(enDateTime(t.date), style: TextStyle(fontSize: 11.5, color: p.ink2)),
                        ]),
                      ),
                      Text(fixed2(_signed(t).abs()), style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: _signed(t) >= 0 ? kGreen : kRed)),
                    ]),
                  ),
              ],
            ]),
    );
  }

  Widget _menu(BuildContext context, Pal p) {
    final rows = <Widget>[];
    for (var i = 0; i < actions.length; i++) {
      final x = actions[i];
      if (x.dividerBefore && i > 0) rows.add(Divider(height: 10, thickness: .6, color: p.line));
      final c = x.danger ? kRed : p.ink;
      rows.add(Tap(
        scale: .98,
        onTap: () {
          Navigator.of(context).pop();
          // نؤخر التنفيذ لحد ما تخلص حركة الإغلاق عشان الانتقال يبقى ناعم.
          Future.delayed(const Duration(milliseconds: 180), x.onTap);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(children: [
            Icon(x.icon, color: c, size: 22),
            const SizedBox(width: 16),
            Expanded(child: Text(x.label, style: TextStyle(fontSize: 17, color: c))),
          ]),
        ),
      ));
    }
    return Container(width: 280, padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(28), border: Border.all(color: p.line.withValues(alpha: .6))), child: Column(mainAxisSize: MainAxisSize.min, children: rows));
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final mq = MediaQuery.of(context);
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(), // الضغط في أي مكان بره القائمة يقفلها
        child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: mq.size.width, maxHeight: mq.size.height),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                GestureDetector(onTap: () {}, child: _preview(p)),
                const SizedBox(height: 14),
                Align(alignment: AlignmentDirectional.centerStart, child: _menu(context, p)),
              ]),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
