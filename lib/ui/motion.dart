// Unified motion system for CashU. One source of truth for durations, curves, springs,
// page transitions and reusable motion widgets. Behaviour ported from Kosh 2.6.1
// (see docs/MOTION.md for the evidence table). Numbers live in motion_spec.dart.
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'motion_spec.dart';

/// Kill-switch: set false to stop fading the page underneath a pushed page (Kosh does fade it).
const bool kFadeCoveredPage = true;

abstract final class Motion {
  // Easing: Compose `tween()` default == FastOutSlowInEasing == Cubic(.4, 0, .2, 1).
  static const Curve standard = Curves.fastOutSlowIn;
  static const Curve linear = Curves.linear;

  static const Duration press = Duration(milliseconds: MotionSpec.press);
  static const Duration quick = Duration(milliseconds: MotionSpec.shrink);
  static const Duration short = Duration(milliseconds: MotionSpec.enterQuick);
  static const Duration state = Duration(milliseconds: MotionSpec.state); // selection / size / expand
  static const Duration fade = Duration(milliseconds: MotionSpec.fade);
  static const Duration pageExit = Duration(milliseconds: MotionSpec.pageExit);
  static const Duration pageEnter = Duration(milliseconds: MotionSpec.pageEnter);
  static const Duration step = Duration(milliseconds: MotionSpec.step);
  static const Duration section = Duration(milliseconds: MotionSpec.section);
  static const Duration count = Duration(milliseconds: MotionSpec.count);
  static const Duration chart = Duration(milliseconds: MotionSpec.chart);

  // CashU-specific surfaces that Kosh has no equivalent for (kept, but named here).
  static const Duration sheetEnter = Duration(milliseconds: 340);
  static const Duration sheetExit = Duration(milliseconds: 260);
  static const Duration circleEnter = Duration(milliseconds: 560);
  static const Duration circleExit = Duration(milliseconds: 380);

  static const double pressScale = MotionSpec.pressScale;

  /// Progress spring: Compose spring(NoBouncy, StiffnessVeryLow).
  static final SpringDescription progressSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: MotionSpec.progressStiffness, ratio: MotionSpec.progressDamping);

  /// Visibility slide spring (assumed Compose AnimatedVisibility default, stiffness 400, critically damped).
  static final SpringDescription slideSpring = SpringDescription.withDampingRatio(mass: 1, stiffness: MotionSpec.slideStiffness, ratio: 1);

  /// Stagger delay for list item [i] (Kosh staggeredEntrance).
  static Duration stagger(int i) => Duration(milliseconds: MotionSpec.staggerDelayMs(i));

  /// Crossfade for AnimatedSwitcher (Kosh stage: fadeIn 220 / fadeOut 160).
  static const Duration crossfadeOut = quick;
}

/// Page route with Kosh's NavHost transitions: enter = slide 1/4 width + fade (300ms),
/// exit = slide + fade (260ms), covered page fades out in 180ms / back in 220ms.
class KoshRoute<T> extends PageRouteBuilder<T> {
  KoshRoute(Widget page, {super.settings, bool fadeOnly = false, bool root = false})
      : super(
          opaque: true,
          transitionDuration: root ? Duration.zero : Motion.pageEnter,
          reverseTransitionDuration: root ? Duration.zero : Motion.pageExit,
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (ctx, a, sa, child) => KoshTransition(animation: a, secondary: sa, fadeOnly: fadeOnly, entering: !root, child: child),
        );

  /// The first route (Shell): no entrance animation, but it still fades while covered.
  KoshRoute.root(Widget page, {RouteSettings? settings}) : this(page, settings: settings, root: true);

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) => kFadeCoveredPage && nextRoute is KoshRoute;
}

class KoshTransition extends StatefulWidget {
  final Animation<double> animation, secondary;
  final bool fadeOnly, entering;
  final Widget child;
  const KoshTransition({super.key, required this.animation, required this.secondary, required this.child, this.fadeOnly = false, this.entering = true});
  @override
  State<KoshTransition> createState() => _KoshTransitionState();
}

class _KoshTransitionState extends State<KoshTransition> {
  late CurvedAnimation _in;

  void _bind() => _in = CurvedAnimation(parent: widget.animation, curve: Motion.standard, reverseCurve: Motion.standard.flipped);

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(KoshTransition old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation) {
      _in.dispose();
      _bind();
    }
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  double _covered() {
    final sa = widget.secondary;
    final s = sa.status;
    if (s == AnimationStatus.dismissed) return 1;
    return MotionSpec.coveredOpacity(sa.value, pushing: s != AnimationStatus.reverse);
  }

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    Widget c = RepaintBoundary(child: widget.child);
    if (widget.entering) {
      final inner = c;
      c = FadeTransition(
        opacity: _in,
        child: widget.fadeOnly
            ? inner
            : AnimatedBuilder(
                animation: _in,
                child: inner,
                builder: (_, ch) => FractionalTranslation(translation: Offset(dir * MotionSpec.pageSlideFraction * (1 - _in.value), 0), child: ch),
              ),
      );
    }
    if (!kFadeCoveredPage) return c;
    return AnimatedBuilder(
      animation: widget.secondary,
      child: c,
      builder: (_, ch) {
        final o = _covered();
        return o >= 1 ? ch! : Opacity(opacity: o, child: ch);
      },
    );
  }
}

/// Used by ThemeData.pageTransitionsTheme so any stray MaterialPageRoute matches too.
class KoshTransitionsBuilder extends PageTransitionsBuilder {
  const KoshTransitionsBuilder();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) =>
      KoshTransition(animation: animation, secondary: secondaryAnimation, child: child);
}

/// Animates a double toward [value] with a spring (retargets from the current value and velocity, like Compose).
class SpringValue extends StatefulWidget {
  final double value, initial;
  final SpringDescription? spring;
  final Widget Function(BuildContext context, double v) builder;
  const SpringValue({super.key, required this.value, required this.builder, this.initial = 0, this.spring});
  @override
  State<SpringValue> createState() => _SpringValueState();
}

class _SpringValueState extends State<SpringValue> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(vsync: this, value: widget.initial);
  SpringDescription get _sp => widget.spring ?? Motion.progressSpring;

  void _go() {
    if (_c.value == widget.value && !_c.isAnimating) return;
    _c.animateWith(SpringSimulation(_sp, _c.value, widget.value, _c.velocity, snapToEnd: true, tolerance: const Tolerance(distance: .0005, velocity: .005)));
  }

  @override
  void initState() {
    super.initState();
    _go();
  }

  @override
  void didUpdateWidget(SpringValue old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _go();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c, builder: (ctx, _) => widget.builder(ctx, _c.value));
}

/// Slides [child] off/on with a critically-damped spring (Kosh bottom bar: AnimatedVisibility slide).
/// [hidden] is the offset (as a fraction of the child's size) when not shown.
class SpringSlide extends StatefulWidget {
  final bool shown;
  final Offset hidden;
  final Widget child;
  const SpringSlide({super.key, required this.shown, required this.child, this.hidden = const Offset(0, 1)});
  @override
  State<SpringSlide> createState() => _SpringSlideState();
}

class _SpringSlideState extends State<SpringSlide> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(vsync: this, value: widget.shown ? 1 : 0);

  void _go() => _c.animateWith(SpringSimulation(Motion.slideSpring, _c.value, widget.shown ? 1 : 0, _c.velocity, snapToEnd: true, tolerance: const Tolerance(distance: .001, velocity: .01)));

  @override
  void didUpdateWidget(SpringSlide old) {
    super.didUpdateWidget(old);
    if (old.shown != widget.shown) _go();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (_, ch) => FractionalTranslation(translation: widget.hidden * (1 - _c.value.clamp(0.0, 1.0)), child: ch),
      );
}
