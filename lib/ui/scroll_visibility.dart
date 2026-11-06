import 'dart:async';
import 'package:flutter/widgets.dart';

/// متحكّم واحد لإخفاء/إظهار العناصر العائمة (زر الإضافة + شريط البحث) مع التمرير.
///
/// القواعد:
/// • أي حركة تمرير بعيدًا عن أعلى القائمة (في أي اتجاه) تخفي [fab] و[bar].
/// • أعلى القائمة (≤ [topSlack]) يظهر الاثنين دائمًا.
/// • [fab] يرجع بعد سكون [idle] (٤٠٠ms) من آخر حركة.
/// • لمسة سريعة (≤ ٢٢٠ms وبدون سحب) على سطح القائمة تظهر [fab] و[bar] فورًا
///   (حتى لو القائمة لسه بتتحرك، فاللمس بيوقف الحركة).
/// الـ ValueNotifier بتتغيّر بس لما القيمة تتغيّر فعلًا، فمفيش إعادة بناء مع كل إطار تمرير.
class ScrollVisibility {
  ScrollVisibility({this.idle = const Duration(milliseconds: 400), this.topSlack = 8, this.minDelta = 1});

  final Duration idle;
  final double topSlack;
  final double minDelta;

  final ValueNotifier<bool> fab = ValueNotifier<bool>(true);
  final ValueNotifier<bool> bar = ValueNotifier<bool>(true);

  Timer? _idle;

  /// حطها كـ onNotification لـ NotificationListener حوالين القائمة. دايمًا بترجع false (ما بتبلعش الإشعار).
  bool onNotification(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical || n.depth != 0) return false;
    final atTop = n.metrics.pixels <= topSlack;
    if (n is ScrollUpdateNotification) {
      if (atTop) {
        _idle?.cancel();
        _show(true, true);
      } else if ((n.scrollDelta ?? 0).abs() >= minDelta) {
        _show(false, false);
        _restartIdle();
      }
    } else if (n is ScrollEndNotification) {
      if (atTop) {
        _idle?.cancel();
        _show(true, true);
      } else {
        _restartIdle();
      }
    }
    return false;
  }

  void _show(bool f, bool b) {
    if (fab.value != f) fab.value = f;
    if (bar.value != b) bar.value = b;
  }

  void _restartIdle() {
    _idle?.cancel();
    _idle = Timer(idle, () {
      if (fab.value != true) fab.value = true;
    });
  }

  /// إظهار فوري (لمسة سريعة).
  void reveal() {
    _idle?.cancel();
    _show(true, true);
  }

  /// يلفّ القائمة ويكتشف اللمسة السريعة (Listener خام: ما بيدخلش في تنافس الإيماءات فمفيش تأثير على التمرير أو النقر).
  Widget tapToReveal({required Widget child}) => _QuickTap(onQuickTap: reveal, child: child);

  void dispose() {
    _idle?.cancel();
    fab.dispose();
    bar.dispose();
  }
}

class _QuickTap extends StatefulWidget {
  final VoidCallback onQuickTap;
  final Widget child;
  const _QuickTap({required this.onQuickTap, required this.child});
  @override
  State<_QuickTap> createState() => _QuickTapState();
}

class _QuickTapState extends State<_QuickTap> {
  Offset? _down;
  final Stopwatch _sw = Stopwatch();

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) {
          _down = e.position;
          _sw
            ..reset()
            ..start();
        },
        onPointerUp: (e) {
          final d = _down;
          _down = null;
          if (d != null && _sw.elapsedMilliseconds <= 220 && (e.position - d).distance < 12) widget.onQuickTap();
        },
        onPointerCancel: (_) => _down = null,
        child: widget.child,
      );
}

/// يطوي [child] رأسيًا (ارتفاع + شفافية) بنفس حركة SegToggle؛ الابن يفضل في الشجرة (حالة الكتابة والتركيز ما بتضيعش).
class CollapsibleBar extends StatelessWidget {
  final ValueListenable<bool> shown;
  final Duration duration;
  final Curve curve;
  final Widget child;
  const CollapsibleBar({super.key, required this.shown, required this.duration, required this.curve, required this.child});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: shown,
        child: child,
        builder: (c, on, ch) => TweenAnimationBuilder<double>(
          tween: Tween<double>(end: on ? 1 : 0),
          duration: MediaQuery.maybeDisableAnimationsOf(c) ?? false ? Duration.zero : duration,
          curve: curve,
          child: ch,
          builder: (_, v, ch2) => IgnorePointer(
            ignoring: v < .5,
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: v.clamp(0.0, 1.0),
                child: Opacity(opacity: v.clamp(0.0, 1.0), child: ch2),
              ),
            ),
          ),
        ),
      );
}
