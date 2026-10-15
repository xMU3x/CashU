import 'package:flutter/material.dart';

const Color kInc = Color(0xFF2E7568);
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
      ? Pal(bg: const Color(0xFF101011), card: const Color(0xFF1C1C1F), field: const Color(0xFF2A2A2E), ink: const Color(0xFFF2F2F2), ink2: const Color(0xFF9A9AA0), line: const Color(0xFF2E2E32), acc: acc, dark: const Color(0xFF000000))
      : Pal(bg: const Color(0xFFF7F7F7), card: Colors.white, field: const Color(0xFFEFEFEF), ink: const Color(0xFF1B1B1B), ink2: const Color(0xFF6E6E73), line: const Color(0xFFE8E8EA), acc: acc, dark: const Color(0xFF1C1C1C));

  @override
  Pal copyWith() => this;
  @override
  Pal lerp(ThemeExtension<Pal>? other, double t) => other is Pal ? (t < .5 ? this : other) : this;
}

ThemeData buildTheme(Pal p, bool dark) {
  final b = dark ? Brightness.dark : Brightness.light;
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'PlexArabic',
    brightness: b,
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: p.acc, brightness: b).copyWith(primary: p.acc, surface: p.card),
    extensions: [p],
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textTheme: ThemeData(brightness: b).textTheme.apply(fontFamily: 'PlexArabic', bodyColor: p.ink, displayColor: p.ink),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(fontFamily: 'PlexArabic', color: p.bg, fontSize: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
  );
}
