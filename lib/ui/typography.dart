import 'package:flutter/material.dart';

/// نظام الخطوط المركزي (كل الخطوط مضمّنة محليًا في assets/fonts، بدون تحميل من الإنترنت).
///
/// • Plus Jakarta Sans = الإنجليزي والأرقام (الأساسي).
/// • Readex Pro = العربية (احتياطي): Plus Jakarta Sans مفيهوش حروف عربية، فالمحرك بيختار Readex Pro
///   حرف بحرف، وده بيخلي النص المختلط (عربي + إنجليزي + أرقام) يشتغل داخل نفس العنصر.
/// • ممنوع letterSpacing غير صفر: Flutter بيكسر وصل الحروف العربية لو اتغيّر تباعد الحروف.
class AppTypography {
  AppTypography._();

  static const String latin = 'PlusJakartaSans';
  static const String arabic = 'ReadexPro';
  static const List<String> fallback = [arabic];

  /// أرقام جدولية (متساوية العرض) لمحاذاة المبالغ.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  /// نمط أساسي موحّد لأي TextStyle يُبنى خارج الـTheme (مثل منتقي الوقت).
  static TextStyle base({Color? color, double? size, FontWeight? weight}) =>
      TextStyle(fontFamily: latin, fontFamilyFallback: fallback, fontFeatures: tabular, color: color, fontSize: size, fontWeight: weight);

  /// يطبّق الخطوط على TextTheme كامل (15 نمط Material 3) ويثبّت اللون.
  static TextTheme textTheme(TextTheme t, Color ink) {
    TextStyle? f(TextStyle? s) => s?.copyWith(fontFamily: latin, fontFamilyFallback: fallback, fontFeatures: tabular, color: s.color ?? ink);
    return TextTheme(
      displayLarge: f(t.displayLarge), displayMedium: f(t.displayMedium), displaySmall: f(t.displaySmall),
      headlineLarge: f(t.headlineLarge), headlineMedium: f(t.headlineMedium), headlineSmall: f(t.headlineSmall),
      titleLarge: f(t.titleLarge), titleMedium: f(t.titleMedium), titleSmall: f(t.titleSmall),
      bodyLarge: f(t.bodyLarge), bodyMedium: f(t.bodyMedium), bodySmall: f(t.bodySmall),
      labelLarge: f(t.labelLarge), labelMedium: f(t.labelMedium), labelSmall: f(t.labelSmall),
    );
  }
}
