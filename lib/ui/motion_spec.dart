// Pure-Dart motion constants and math (no Flutter import) so they can be unit-tested
// with a plain Dart VM. Values are ported from Kosh 2.6.1; the source reference
// (file:line in the Kosh repo) is given next to each constant.
import 'dart:math' as math;

abstract final class MotionSpec {
  // ---- durations (ms) ----
  static const int press = 120; // Keypad.kt:164-167  key press scale
  static const int exitQuick = 120; // KoshRoot.kt:357 FAB fade-out, InsightsScreen.kt:283 expand fade-out
  static const int shrink = 160; // InsightsScreen.kt:283 shrinkVertically; KoshRoot.kt:203 stage fade-out
  static const int enterQuick = 180; // KoshRoot.kt:356 FAB fade-in; :430 covered-page fade-out
  static const int state = 200; // Controls.kt:96 segment; InsightsScreen.kt:256/283 animateContentSize/expand
  static const int fade = 220; // KoshRoot.kt:427/431 tab + pop-enter fade; Transactions.kt:271 stagger item
  static const int pageExit = 260; // KoshRoot.kt:433-434 pop-exit slide+fade
  static const int pageEnter = 300; // KoshRoot.kt:428 enter slide+fade
  static const int step = 320; // OnboardingScreen.kt:132 step slide
  static const int section = 400; // Transactions.kt:284 Modifier.fadeIn
  static const int count = 650; // Amount.kt:117 animated amount
  static const int bar = 800; // Badges.kt:137 utilisation bar
  static const int chart = 900; // Charts.kt:78 rememberEntrance default

  // ---- geometry ----
  static const double pressScale = .97; // Keypad.kt:165
  static const double pageSlideFraction = .25; // KoshRoot.kt:428/433  { it / 4 }
  static const double stepSlideFraction = 1 / 3; // OnboardingScreen.kt:132 { it / 3 }
  static const double staggerOffsetDp = 24; // Transactions.kt:277
  static const int staggerStepMs = 35; // Transactions.kt:270
  static const int staggerMaxItems = 10; // Transactions.kt:265 maxDelayItems

  // ---- springs (Compose spring(dampingRatio, stiffness)) ----
  static const double progressStiffness = 50; // Progress.kt:60 StiffnessVeryLow
  static const double progressDamping = 1.0; // Progress.kt:60 DampingRatioNoBouncy
  // Compose library default for AnimatedVisibility slide (StiffnessMediumLow). NOT visible in the Kosh
  // source and not verifiable from the R8-obfuscated APK: treat as an assumption.
  static const double slideStiffness = 400;

  /// Delay before list item [index] starts entering (Kosh `staggeredEntrance`).
  static int staggerDelayMs(int index) => math.min(math.max(index, 0), staggerMaxItems) * staggerStepMs;

  /// Compose FastOutSlowInEasing == CubicBezierEasing(0.4, 0, 0.2, 1).
  static double fastOutSlowIn(double x) => cubic(.4, 0, .2, 1, x);

  /// Cubic bezier easing y(x) solved by bisection (x is the time axis).
  static double cubic(double a, double b, double c, double d, double x) {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    double lo = 0, hi = 1, t = x;
    double bx(double t) => 3 * a * t * (1 - t) * (1 - t) + 3 * c * t * t * (1 - t) + t * t * t;
    double by(double t) => 3 * b * t * (1 - t) * (1 - t) + 3 * d * t * t * (1 - t) + t * t * t;
    for (var i = 0; i < 40; i++) {
      t = (lo + hi) / 2;
      if (bx(t) < x) {
        lo = t;
      } else {
        hi = t;
      }
    }
    return by(t);
  }

  /// Opacity of the page *under* a [KoshRoute] while it is covered / uncovered.
  /// [s] is the covering route's animation value (0..1), [pushing] true while it runs forward.
  /// Push: fade-out over [enterQuick] ms of the [pageEnter]-ms push. Pop: fade-in over [fade] ms of the
  /// [pageExit]-ms pop (Kosh exitTransition / popEnterTransition).
  static double coveredOpacity(double s, {required bool pushing}) {
    s = s.clamp(0.0, 1.0);
    if (pushing) {
      final p = (s * pageEnter / enterQuick).clamp(0.0, 1.0);
      return 1 - fastOutSlowIn(p);
    }
    final p = ((1 - s) * pageExit / fade).clamp(0.0, 1.0);
    return fastOutSlowIn(p);
  }

  /// Tab cross-fade: incoming fades in over [fade] ms, outgoing out over [enterQuick] ms; [t] = 0..1 of [fade] ms.
  static double tabIn(double t) => fastOutSlowIn(t.clamp(0.0, 1.0));
  static double tabOut(double t) => 1 - fastOutSlowIn((t * fade / enterQuick).clamp(0.0, 1.0));

  /// Closed-form critically/under-damped spring displacement fraction (0 → 1) for tests/docs.
  static double springProgress(double t, {double stiffness = progressStiffness, double damping = progressDamping}) {
    final w = math.sqrt(stiffness);
    if ((damping - 1.0).abs() < 1e-9) return 1 - (1 + w * t) * math.exp(-w * t);
    final wd = w * math.sqrt(1 - damping * damping);
    final z = damping * w;
    return 1 - math.exp(-z * t) * (math.cos(wd * t) + (z / wd) * math.sin(wd * t));
  }
}
