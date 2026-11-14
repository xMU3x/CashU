// ملف مولَّد — لا تعدّله يدويًا. المصدر: tool/source/cashu_10A_colors_ios.svg ← python3 tool/gen_variant_icons.py
import 'package:flutter/painting.dart';

/// ألوان أيقونة التطبيق (بنفس بارامترات الـ SVG): خلفية متدرّجة، لمعة/ظل، قوس متدرّج، خط لمعة، نقطة متدرّجة.
class AppIconVariant {
  final String id;
  final String label;
  final Color bg0, bg1;
  final double gloss, shade;
  final Color arc0, arc1;
  final double hi;
  final Color dot0, dot1, dot2;
  const AppIconVariant(this.id, this.label, this.bg0, this.bg1, this.gloss, this.shade, this.arc0, this.arc1, this.hi, this.dot0, this.dot1, this.dot2);
}

const kAppIcons = <AppIconVariant>[
  AppIconVariant('navy', 'كحلي (الأساسية)', Color(0xFF293452), Color(0xFF0A1127), 0.1, 0.28, Color(0xFFFFFFFF), Color(0xFFBCC9EA), 0.9, Color(0xFFA1F4D7), Color(0xFF2EE6A6), Color(0xFF21A678)),
  AppIconVariant('black', 'أسود', Color(0xFF252525), Color(0xFF060606), 0.1, 0.28, Color(0xFFFFFFFF), Color(0xFFBCC9EA), 0.9, Color(0xFFA1F4D7), Color(0xFF2EE6A6), Color(0xFF21A678)),
  AppIconVariant('blue', 'أزرق', Color(0xFF467BE3), Color(0xFF1E448F), 0.1, 0.28, Color(0xFFFFFFFF), Color(0xFFBCC9EA), 0.9, Color(0xFFA1F4D7), Color(0xFF2EE6A6), Color(0xFF21A678)),
  AppIconVariant('mint', 'نعناعي', Color(0xFF71EEC2), Color(0xFF25B885), 0.22, 0.16, Color(0xFF22357A), Color(0xFF0A1330), 0.5, Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFBCC9EA)),
  AppIconVariant('green', 'أخضر داكن', Color(0xFF265245), Color(0xFF07271D), 0.1, 0.28, Color(0xFFFFFFFF), Color(0xFFBCC9EA), 0.9, Color(0xFFA1F4D7), Color(0xFF2EE6A6), Color(0xFF21A678)),
  AppIconVariant('gold', 'كحلي وذهبي', Color(0xFF293452), Color(0xFF0A1127), 0.1, 0.28, Color(0xFFFFFFFF), Color(0xFFBCC9EA), 0.9, Color(0xFFFFE6A8), Color(0xFFFFC83D), Color(0xFFB8902C)),
  AppIconVariant('mintarc', 'كحلي وقوس نعناعي', Color(0xFF293452), Color(0xFF0A1127), 0.1, 0.28, Color(0xFF8CF8D8), Color(0xFF14BF86), 0.5, Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFBCC9EA)),
  AppIconVariant('light', 'فاتح', Color(0xFFFFFFFF), Color(0xFFB7C5E8), 0.3, 0.1, Color(0xFF22357A), Color(0xFF0A1330), 0.5, Color(0xFFA1F4D7), Color(0xFF2EE6A6), Color(0xFF21A678)),
  AppIconVariant('royal', 'أزرق ملكي', Color(0xFF375097), Color(0xFF132558), 0.1, 0.28, Color(0xFFFFFFFF), Color(0xFFBCC9EA), 0.9, Color(0xFFA1F4D7), Color(0xFF2EE6A6), Color(0xFF21A678)),
  AppIconVariant('violet', 'بنفسجي', Color(0xFF7C60F3), Color(0xFF45319A), 0.1, 0.28, Color(0xFFFFFFFF), Color(0xFFBCC9EA), 0.9, Color(0xFFA1F4D7), Color(0xFF2EE6A6), Color(0xFF21A678)),
];
