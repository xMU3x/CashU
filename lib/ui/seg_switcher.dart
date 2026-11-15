import 'package:flutter/widgets.dart';
import 'motion.dart';

/// تبديل محتوى (تبويب/عرض) بنفس حركة SegToggle: المحتوى الجديد ينزلق بخفة، والقديم يختفي فورًا —
/// من غير أي Fade/طبقة شفافية على المحتوى كله.
class SegSwitcher extends StatelessWidget {
  final Widget child;
  const SegSwitcher({super.key, required this.child});

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: CashUMotion.of(context, CashUMotion.seg),
        reverseDuration: Duration.zero,
        switchInCurve: CashUMotion.segCurve,
        transitionBuilder: (w, a) => SlideTransition(
          position: Tween<Offset>(begin: Offset(Directionality.of(context) == TextDirection.rtl ? -.04 : .04, 0), end: Offset.zero).animate(a),
          child: w,
        ),
        layoutBuilder: (cur, prev) => cur ?? const SizedBox.shrink(),
        child: child,
      );
}
