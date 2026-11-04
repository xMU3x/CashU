package com.werd.cashu.ui.motion

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.ui.unit.IntOffset

/**
 * مواصفات الحركة المركزية — كل أنيميشن في التطبيق لازم يمر من هنا (مدد حسب مواصفات المشروع).
 * ملاحظة: easing ماتريال 3: Emphasized للدخول، Accelerate للخروج.
 */
object Motion {
    const val BUTTON = 100        // 80–120
    const val ICON = 130          // 100–150
    const val SMALL = 140         // 120–160
    const val TAB = 170           // 150–180
    const val SCREEN = 200        // 180–220
    const val DIALOG = 165        // 150–180
    const val SHEET = 200         // 180–220
    const val EXPAND = 180        // 150–200

    val Standard: Easing = CubicBezierEasing(0.2f, 0f, 0f, 1f)
    val Decelerate: Easing = CubicBezierEasing(0.05f, 0.7f, 0.1f, 1f)
    val Accelerate: Easing = CubicBezierEasing(0.3f, 0f, 0.8f, 0.15f)

    fun <T> tween(ms: Int, easing: Easing = Standard) = androidx.compose.animation.core.tween<T>(ms, easing = easing)

    /** حركة نابضة خفيفة بدون ارتداد مبالغ (للضغط/التحجيم). */
    fun <T> press() = spring<T>(dampingRatio = Spring.DampingRatioNoBouncy, stiffness = Spring.StiffnessMedium)

    // انتقال الشاشات/التبويبات الموحّد (RTL-aware: الدخول من اليمين بالعربي)
    val screenEnter: EnterTransition =
        fadeIn(tween(SCREEN, Decelerate)) + slideInHorizontally(tween(SCREEN, Decelerate)) { -it / 12 }
    val screenExit: ExitTransition = fadeOut(tween(SCREEN / 2, Accelerate))
    val screenPopEnter: EnterTransition = fadeIn(tween(SCREEN, Decelerate)) + slideInHorizontally(tween(SCREEN, Decelerate)) { it / 12 }
    val screenPopExit: ExitTransition = fadeOut(tween(SCREEN / 2, Accelerate))

    val tabEnter: EnterTransition = fadeIn(tween(TAB, Decelerate))
    val tabExit: ExitTransition = fadeOut(tween(TAB / 2, Accelerate))

    fun offsetSpec() = tween<IntOffset>(SCREEN)
}
