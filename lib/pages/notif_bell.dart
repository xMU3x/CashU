import 'package:flutter/material.dart' hide Text;
import '../core/store.dart';
import '../sms/sms_tracker.dart';
import '../ui/anim.dart';
import '../ui/loc_text.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'sms_pages.dart' show SmsReviewPage;

/// جرس الإشعارات: عدّاد المعاملات اللي محتاجة مراجعة يدوية (من الرسائل). يفتح شاشة المراجعة.
class NotifBell extends StatelessWidget {
  const NotifBell({super.key});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([store, smsTracker]),
      builder: (c, _) {
        final n = smsTracker.review.length;
        return Tap(
          onTap: () => Navigator.of(context).push(flowRoute(const SmsReviewPage())),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Stack(clipBehavior: Clip.none, children: [
              Icon(n > 0 ? Icons.notifications_rounded : Icons.notifications_none_rounded, size: 26, color: n > 0 ? kBlue : p.ink2),
              if (n > 0)
                PositionedDirectional(
                  top: -5,
                  end: -6,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(9)),
                    child: Center(child: Text(n > 99 ? '99+' : '$n', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
                  ),
                ),
            ]),
          ),
        );
      },
    );
  }
}
