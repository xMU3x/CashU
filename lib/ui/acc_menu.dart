import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Text;
import 'loc_text.dart';
import '../core/models.dart';
import '../core/util.dart' show tick;
import 'anim.dart';
import 'theme.dart';

/// إجراء داخل قائمة الحساب (الضغطة المطولة أو زر «...»).
class AccMenuAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger, dividerBefore;
  const AccMenuAction(this.icon, this.label, this.onTap, {this.danger = false, this.dividerBefore = false});
}

/// بانل منبثقة في منتصف الشاشة: كل الخيارات كأزرار كبسولة (شكل الصورة المطلوبة).
Future<void> showAccountMenu(BuildContext context, Account a, List<AccMenuAction> actions) {
  tick();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'account-menu',
    barrierColor: Colors.black.withValues(alpha: .5),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (c, _, __) => _AccMenu(acc: a, actions: actions),
    transitionBuilder: (c, anim, _, child) {
      final cv = CurvedAnimation(parent: anim, curve: Motion.emphasized, reverseCurve: Curves.easeIn);
      return FadeTransition(opacity: cv, child: ScaleTransition(scale: Tween<double>(begin: .92, end: 1).animate(cv), child: child));
    },
  );
}

class _AccMenu extends StatelessWidget {
  final Account acc;
  final List<AccMenuAction> actions;
  const _AccMenu({required this.acc, required this.actions});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final mq = MediaQuery.of(context);
    final panel = p.dark == const Color(0xFF000000) ? const Color(0xFF1B1F2A) : p.card;
    final rows = <Widget>[];
    for (final x in actions) {
      final c = x.danger ? kRed : p.ink;
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Tap(
          scale: .97,
          onTap: () {
            Navigator.of(context).pop();
            // نؤخر التنفيذ لحد ما تخلص حركة الإغلاق عشان الانتقال يبقى ناعم.
            Future.delayed(const Duration(milliseconds: 180), x.onTap);
          },
          child: Container(
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.field.withValues(alpha: .9), borderRadius: BorderRadius.circular(27)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(x.icon, size: 22, color: c),
              const SizedBox(width: 10),
              Flexible(child: Text(x.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: c))),
            ]),
          ),
        ),
      ));
    }
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(), // الضغط بره البانل يقفلها
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                child: GestureDetector(
                  onTap: () {},
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 360, maxHeight: mq.size.height),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(34), border: Border.all(color: p.line.withValues(alpha: .5))),
                      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
