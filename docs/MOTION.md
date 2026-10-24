# CashU motion system (ported from Kosh 2.6.1)

Code: `lib/ui/motion.dart` (tokens, `KoshRoute`, `SpringValue`, `SpringSlide`) and `lib/ui/motion_spec.dart` (pure constants + math, unit-tested).
Evidence: Kosh source (file:line) + APK 2.6.1 (versionCode 34, same build as the source; APK has no `res/anim`/Lottie, all motion is Compose code; class names are R8-obfuscated so Compose *library defaults* could not be verified from the APK).

| Kosh primitive (source) | Spec | CashU implementation |
|---|---|---|
| NavHost enter (KoshRoot.kt:426-429) | slide 1/4 width + fade, 300ms, FastOutSlowIn | `KoshRoute` via `flowRoute()` (all 44 call sites) |
| NavHost exit / popExit (:430,:432-434) | slide 1/4 + fade 260ms | `KoshRoute` reverse (260ms) |
| Covered page (:430-431) | fade-out 180ms / pop fade-in 220ms | `KoshTransition` secondary fade (`kFadeCoveredPage` kill-switch) |
| Tab switch (:427,:431) | fade-in 220 / fade-out 180 | `KeepAliveTabs` cross-fade |
| Bottom bar (:349) | slideIn/OutVertically (Compose default spring, **assumed** stiffness 400) | `SpringSlide` |
| Key press (Keypad.kt:164) | scale .97, 120ms | `Tap` default |
| Staggered list (Transactions.kt:262-278) | min(i,10)*35ms delay, 220ms, 24dp rise | `Reveal` |
| Animated amount (Amount.kt:117) | 650ms, only on change | `CountText` (`fromZero:` to keep count-up) |
| Progress (Progress.kt:58) | spring(ratio 1, stiffness 50) | `SpringValue` (home, goals ring, stats bars, wave level) |
| Chart entrance (Charts.kt:78) | 900ms FastOutSlowIn | stats charts |
| Expand/size (InsightsScreen.kt:256,283) | 200ms | all `AnimatedSize` -> `Motion.state` |
| Segment/selection (Controls.kt:96) | 200ms | `AnimatedContainer` etc. -> tokens |

## Not ported (reason)
- Shared-element transaction icon (SharedMotion.kt): CashU has no transaction detail screen (tap opens an edit sheet).
- Large collapsing title, sticky headers, M3 PullToRefresh: design-affecting; CashU has its own pull/hide-bar behaviour.
- Predictive back, `animateItem()` list placement, onboarding steps, splash, shimmer: no matching CashU surface / not testable here.
- M3 ModalBottomSheet / dialog motion: library defaults, not in Kosh source. CashU sheets keep 340/260ms (named `Motion.sheetEnter/Exit`).
- Kept as CashU-specific: circle reveal route, pop menus (easeOutBack), swipe widget in ios.dart, heat-map pop-in, bob/burst.

## Lag fixes (static analysis only, **not profiled on a device**)
1. `ThemeData`/`ColorScheme.fromSeed` rebuilt on every `store` write -> memoised on (mode, font).
2. `Reveal` delay grew `40 + i*70` ms unbounded (item 30 = 2.1s) and used 2 implicit animations -> capped at 350ms, one controller.
3. Wave/coin painters rebuilt the widget tree every frame -> `repaint:` listenable + `RepaintBoundary`.
4. Bottom bar faded an opacity layer over a `BackdropFilter` -> spring slide only.
Candidates left untouched (design-affecting, need profiling): 18 stacked `BackdropFilter`s in `BlurEdge`, whole-app `UiScale` transform, hidden tabs still rebuilding on `store` notifications.
