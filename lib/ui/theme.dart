import 'package:flutter/material.dart' hide Text;
import '../core/settings.dart';

const Color kInc = Color(0xFF2E7568);

// ألوان واجهة iOS (MoneyWiz). اللون الأساسي والأخضر والأحمر بيتغيروا حسب المظهر (عصري = برتقالي/أخضر زمردي/أحمر مطفي).
Color _accent = const Color(0xFF0A84FF), _pos = const Color(0xFF30D158), _neg = const Color(0xFFFF453A);
Color get kBlue => _accent;
Color get kGreen => _pos;
Color get kRed => _neg;
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

  /// المظهر الحالي: light | dark | modern (القديم 'dark' bool بيتحوّل تلقائيًا).
  static String mode() {
    final m = S.str('themeMode', '');
    if (m == 'light' || m == 'dark' || m == 'modern') return m;
    return S.flag('dark', true) ? 'dark' : 'light';
  }

  /// ثيم «عصري»: الخلفية #0F131A · الكروت #1A202C · الأساسي #FF522B · النص #FFFFFF · الخافت #8D9AA8 · مصروف #D94141 · دخل #10B981.
  static Pal modern() => const Pal(bg: Color(0xFF0F131A), card: Color(0xFF1A202C), field: Color(0xFF252D3B), ink: Color(0xFFFFFFFF), ink2: Color(0xFF8D9AA8), line: Color(0xFF2B3444), acc: Color(0xFFFF522B), dark: Color(0xFF0F131A));

  /// يبني اللوحة للمظهر المطلوب ويضبط ألوان الأساسي/الدخل/المصروف العامة.
  static Pal forMode(String m) {
    final modern = m == 'modern';
    _accent = modern ? const Color(0xFFFF522B) : const Color(0xFF0A84FF);
    _pos = modern ? const Color(0xFF10B981) : const Color(0xFF30D158);
    _neg = modern ? const Color(0xFFD94141) : const Color(0xFFFF453A);
    return modern ? Pal.modern() : Pal.make(m == 'dark', _accent);
  }

  static Pal make(bool d, Color acc) => d
      ? Pal(bg: const Color(0xFF000000), card: const Color(0xFF1C1C1E), field: const Color(0xFF2C2C2E), ink: Colors.white, ink2: const Color(0xFF8E8E93), line: const Color(0xFF38383A), acc: acc, dark: const Color(0xFF000000))
      : Pal(bg: const Color(0xFFF2F2F7), card: Colors.white, field: const Color(0xFFE5E5EA), ink: Colors.black, ink2: const Color(0xFF6C6C70), line: const Color(0xFFD1D1D6), acc: acc, dark: const Color(0xFF1C1C1E));

  @override
  bool operator ==(Object o) => o is Pal && o.bg == bg && o.card == card && o.field == field && o.ink == ink && o.ink2 == ink2 && o.line == line && o.acc == acc && o.dark == dark;
  @override
  int get hashCode => Object.hash(bg, card, field, ink, ink2, line, acc, dark);

  @override
  Pal copyWith() => this;
  @override
  Pal lerp(ThemeExtension<Pal>? other, double t) => other is Pal ? (t < .5 ? this : other) : this;
}

/// الخط الأساسي للإنجليزي والأرقام (Inter ≈ SF Pro Text، ترخيص OFL) والاحتياطي للعربي (Noto Sans Arabic).
String get kFontLatin => switch (S.str('font', 'plex')) { 'ping' => 'PingARLT', 'classic' => 'Inter', 'spartan' => 'LeagueSpartan', _ => 'SFProDisplay' };
/// الخط العربي: IBM Plex Sans Arabic (افتراضي) أو Noto Sans Arabic (كلاسيك). الإنجليزي والأرقام: SF Pro Display (افتراضي) أو Inter (كلاسيك).
String get kFontChoice => S.str('font', 'plex');
List<String> get kFontFallback => kFontChoice == 'ping' ? const ['PingARLT', 'NotoSansArabic'] : kFontChoice == 'classic' ? const ['NotoSansArabic'] : const ['IBMPlexSansArabic', 'NotoSansArabic'];

/// أرقام جدولية (متساوية العرض) لمحاذاة الأرقام المالية.
const List<FontFeature> kTabular = [FontFeature.tabularFigures()];

TextTheme _fontTheme(TextTheme t, Color ink, List<String> fb) {
  TextStyle? f(TextStyle? s) => s?.copyWith(fontFamily: kFontLatin, fontFamilyFallback: fb, fontFeatures: kTabular, color: s.color ?? ink);
  return TextTheme(
    displayLarge: f(t.displayLarge), displayMedium: f(t.displayMedium), displaySmall: f(t.displaySmall),
    headlineLarge: f(t.headlineLarge), headlineMedium: f(t.headlineMedium), headlineSmall: f(t.headlineSmall),
    titleLarge: f(t.titleLarge), titleMedium: f(t.titleMedium), titleSmall: f(t.titleSmall),
    bodyLarge: f(t.bodyLarge), bodyMedium: f(t.bodyMedium), bodySmall: f(t.bodySmall),
    labelLarge: f(t.labelLarge), labelMedium: f(t.labelMedium), labelSmall: f(t.labelSmall),
  );
}

/// حركات MD3 Expressive: منحنيات emphasized + مدد قصيرة.
class Motion {
  static const Curve emphasized = Cubic(.2, 0, 0, 1);
  static const Curve emphasizedAccel = Cubic(.3, 0, .8, .15);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 260);
}

/// انتقال خفيف: تلاشي + انزلاق أفقي صغير باتجاه اللغة (RTL/LTR). بدون blur ولا طبقات إضافية.
Widget expressiveTransition(BuildContext ctx, Animation<double> a, Animation<double> sa, Widget child) {
  if (MediaQuery.maybeDisableAnimationsOf(ctx) ?? false) return child;
  final rtl = Directionality.of(ctx) == TextDirection.rtl;
  final dx = rtl ? -.06 : .06;
  final curved = CurvedAnimation(parent: a, curve: Motion.emphasized, reverseCurve: Motion.emphasizedAccel);
  return FadeTransition(
    opacity: CurvedAnimation(parent: a, curve: const Interval(0, .7, curve: Curves.easeOut)),
    child: SlideTransition(position: Tween<Offset>(begin: Offset(dx, 0), end: Offset.zero).animate(curved), child: child),
  );
}

class _ExpressiveTransitions extends PageTransitionsBuilder {
  const _ExpressiveTransitions();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) =>
      expressiveTransition(context, animation, secondaryAnimation, child);
}

// الثيم يتبني مرة واحدة لكل (مظهر + خط)؛ نفس الكائن = مفيش إعادة بناء للتطبيق كله مع كل تغيير في الـ store.
String? _themeKey;
ThemeData? _themeCache;

ThemeData buildTheme(Pal p, bool dark) {
  final key = '${p.acc.toARGB32()}|$dark|${p.bg.toARGB32()}|$kFontChoice';
  if (_themeKey == key && _themeCache != null) return _themeCache!;
  final t = _buildTheme(p, dark);
  _themeKey = key;
  return _themeCache = t;
}

ThemeData _buildTheme(Pal p, bool dark) {
  final b = dark ? Brightness.dark : Brightness.light;
  final fb = kFontFallback;
  return ThemeData(
    useMaterial3: true,
    fontFamily: kFontLatin,
    fontFamilyFallback: fb,
    brightness: b,
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: p.acc, brightness: b, dynamicSchemeVariant: DynamicSchemeVariant.expressive).copyWith(primary: p.acc, surface: p.card),
    extensions: [p],
    pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: _ExpressiveTransitions(), TargetPlatform.iOS: _ExpressiveTransitions()}),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textTheme: _fontTheme(ThemeData(brightness: b).textTheme.apply(bodyColor: p.ink, displayColor: p.ink), p.ink, fb),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(fontFamily: kFontLatin, fontFamilyFallback: fb, fontFeatures: kTabular, color: p.bg, fontSize: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
  );
}
