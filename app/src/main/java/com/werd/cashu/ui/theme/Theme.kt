package com.werd.cashu.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import com.werd.cashu.R

val PingAR = FontFamily(
    Font(R.font.pingarlt_thin, FontWeight.Thin),
    Font(R.font.pingarlt_extralight, FontWeight.ExtraLight),
    Font(R.font.pingarlt_light, FontWeight.Light),
    Font(R.font.pingarlt_regular, FontWeight.Normal),
    Font(R.font.pingarlt_medium, FontWeight.Medium),
    Font(R.font.pingarlt_bold, FontWeight.Bold),
    Font(R.font.pingarlt_heavy, FontWeight.ExtraBold),
    Font(R.font.pingarlt_black, FontWeight.Black),
)

private val Seed = Color(0xFF1F6FE5)
private val LightFallback = lightColorScheme(primary = Seed)
private val DarkFallback = darkColorScheme(primary = Color(0xFF9CC2FF))

@Composable
fun CashUTheme(dark: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    val ctx = LocalContext.current
    val scheme = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> if (dark) dynamicDarkColorScheme(ctx) else dynamicLightColorScheme(ctx)
        dark -> DarkFallback
        else -> LightFallback
    }
    val base = Typography()
    val typo = Typography(
        displayLarge = base.displayLarge.copy(fontFamily = PingAR), displayMedium = base.displayMedium.copy(fontFamily = PingAR),
        displaySmall = base.displaySmall.copy(fontFamily = PingAR), headlineLarge = base.headlineLarge.copy(fontFamily = PingAR),
        headlineMedium = base.headlineMedium.copy(fontFamily = PingAR), headlineSmall = base.headlineSmall.copy(fontFamily = PingAR),
        titleLarge = base.titleLarge.copy(fontFamily = PingAR), titleMedium = base.titleMedium.copy(fontFamily = PingAR),
        titleSmall = base.titleSmall.copy(fontFamily = PingAR), bodyLarge = base.bodyLarge.copy(fontFamily = PingAR),
        bodyMedium = base.bodyMedium.copy(fontFamily = PingAR), bodySmall = base.bodySmall.copy(fontFamily = PingAR),
        labelLarge = base.labelLarge.copy(fontFamily = PingAR), labelMedium = base.labelMedium.copy(fontFamily = PingAR),
        labelSmall = base.labelSmall.copy(fontFamily = PingAR),
    )
    // RTL عربي دائمًا (التطبيق عربي أساسًا).
    CompositionLocalProvider(androidx.compose.ui.platform.LocalLayoutDirection provides LayoutDirection.Rtl) {
        MaterialTheme(colorScheme = scheme, typography = typo, content = content)
    }
}
