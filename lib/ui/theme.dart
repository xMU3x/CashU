import 'package:flutter/material.dart' hide Text;

const Color kInc = Color(0xFF2E7568);

// ألوان واجهة iOS (MoneyWiz)
const Color kBlue = Color(0xFF0A84FF);
const Color kGreen = Color(0xFF30D158);
const Color kRed = Color(0xFFFF453A);
const Color kOrange = Color(0xFFFF9F0A);
const Color kXfer = Color(0xFF2A4BCF);

class Thm {
  final String id, name;
  final Color color;
  final int price;
  const Thm(this.id, this.name, this.color, this.price);
}

const kThemes = <Thm>[
  Thm('terra', 'تراكوتا', Color(0xFF9C4B38), 0),
  Thm('ocean', 'محيط', Color(0xFF2A5FA8), 120),
  Thm('emerald', 'زمرد', Color(0xFF2E7568), 120),
  Thm('plum', 'برقوق', Color(0xFF7B3F8C), 200),
  Thm('sunset', 'غروب', Color(0xFFD9722B), 200),
];
Thm themeById(String id) => kThemes.firstWhere((t) => t.id == id, orElse: () => kThemes.first);

class Pal extends ThemeExtension<Pal> {
  final Color bg, card, field, ink, ink2, line, acc, dark;
  const Pal({required this.bg, required this.card, required this.field, required this.ink, required this.ink2, required this.line, required this.acc, required this.dark});

  static Pal of(BuildContext c) => Theme.of(c).extension<Pal>()!;

  static Pal make(bool d, Color acc) => d
      ? Pal(bg: const Color(0xFF000000), card: const Color(0xFF1C1C1E), field: const Color(0xFF2C2C2E), ink: Colors.white, ink2: const Color(0xFF8E8E93), line: const Color(0xFF38383A), acc: acc, dark: const Color(0xFF000000))
      : Pal(bg: const Color(0xFFF2F2F7), card: Colors.white, field: const Color(0xFFE5E5EA), ink: Colors.black, ink2: const Color(0xFF6C6C70), line: const Color(0xFFD1D1D6), acc: acc, dark: const Color(0xFF1C1C1E));

  @override
  Pal copyWith() => this;
  @override
  Pal lerp(ThemeExtension<Pal>? other, double t) => other is Pal ? (t < .5 ? this : other) : this;
}

/// الخطوط (مضمّنة محليًا، لا تحميل من الإنترنت):
/// Inter = الإنجليزي والأرقام (الأساسي)، وCairo = العربية (احتياطي لكل حرف عربي).
/// Inter ما فيهوش حروف عربية فالمحرك بيرجع لـ Cairo تلقائيًا حرف بحرف، فالنص المختلط يشتغل داخل نفس العنصر.
const String kFontLatin = 'Inter';
const String kFontArabic = 'Cairo';
const List<String> kFontFallback = [kFontArabic];

/// أرقام جدولية (متساوية العرض) لمحاذاة الأرقام المالية.
const List<FontFeature> kTabular = [FontFeature.tabularFigures()];

TextTheme _fontTheme(TextTheme t, Color ink) {
  TextStyle? f(TextStyle? s) => s?.copyWith(fontFamily: kFontLatin, fontFamilyFallback: kFontFallback, fontFeatures: kTabular, color: s.color ?? ink);
  return TextTheme(
    displayLarge: f(t.displayLarge), displayMedium: f(t.displayMedium), displaySmall: f(t.displaySmall),
    headlineLarge: f(t.headlineLarge), headlineMedium: f(t.headlineMedium), headlineSmall: f(t.headlineSmall),
    titleLarge: f(t.titleLarge), titleMedium: f(t.titleMedium), titleSmall: f(t.titleSmall),
    bodyLarge: f(t.bodyLarge), bodyMedium: f(t.bodyMedium), bodySmall: f(t.bodySmall),
    labelLarge: f(t.labelLarge), labelMedium: f(t.labelMedium), labelSmall: f(t.labelSmall),
  );
}

ThemeData buildTheme(Pal p, bool dark) {
  final b = dark ? Brightness.dark : Brightness.light;
  return ThemeData(
    useMaterial3: true,
    fontFamily: kFontLatin,
    fontFamilyFallback: kFontFallback,
    brightness: b,
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: p.acc, brightness: b).copyWith(primary: p.acc, surface: p.card),
    extensions: [p],
    pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: ZoomPageTransitionsBuilder(), TargetPlatform.iOS: ZoomPageTransitionsBuilder()}),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textTheme: _fontTheme(ThemeData(brightness: b).textTheme.apply(bodyColor: p.ink, displayColor: p.ink), p.ink),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(fontFamily: kFontLatin, fontFamilyFallback: kFontFallback, fontFeatures: kTabular, color: p.bg, fontSize: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
  );
}
