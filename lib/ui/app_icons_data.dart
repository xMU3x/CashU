// ملف مولَّد — لا تعدّله يدويًا. المصدر: tool/source/cashu_10A_colors_ios27_flat.svg ← python3 tool/gen_variant_icons.py
import 'package:flutter/painting.dart';

/// ألوان أيقونة التطبيق (بنفس بارامترات الـ SVG الفلات): خلفية متدرّجة، فينييت علوي خفيف، قوس بلون واحد، نقطة بلون واحد.
class AppIconVariant {
  final String id;
  final String label;
  final Color bg0, bg1;
  final double vig;
  final Color arc, dot;
  const AppIconVariant(this.id, this.label, this.bg0, this.bg1, this.vig, this.arc, this.dot);
}

/// الأيقونة الأساسية (الافتراضية). لازم تتطابق مع android:enabled="true" في المانيفست ومع defaultIcon في MainActivity.kt.
const kPrimaryAppIconId = 'black';

const kAppIcons = <AppIconVariant>[
  AppIconVariant('navy', 'كحلي', Color(0xFF273250), Color(0xFF0A1228), 0.13, Color(0xFFFFFFFF), Color(0xFF2EE6A6)),
  AppIconVariant('black', 'أسود (الأساسية)', Color(0xFF1C1C1E), Color(0xFF1C1C1E), 0, Color(0xFFFFFFFF), Color(0xFF2EE6A6)),
  AppIconVariant('blue', 'أزرق', Color(0xFF2C4D98), Color(0xFF0D265C), 0.13, Color(0xFFFFFFFF), Color(0xFF2EE6A6)),
  AppIconVariant('mint', 'نعناعي', Color(0xFF245C50), Color(0xFF083128), 0.13, Color(0xFFFFFFFF), Color(0xFF2EE6A6)),
  AppIconVariant('green', 'أخضر داكن', Color(0xFF235043), Color(0xFF07281E), 0.13, Color(0xFFFFFFFF), Color(0xFF2EE6A6)),
  AppIconVariant('gold', 'كحلي وذهبي', Color(0xFF273250), Color(0xFF0A1228), 0.13, Color(0xFFFFFFFF), Color(0xFFFFC83D)),
  AppIconVariant('cream', 'كحلي وكريمي', Color(0xFF273250), Color(0xFF0A1228), 0.13, Color(0xFFFFF1D6), Color(0xFF2EE6A6)),
  AppIconVariant('graphite', 'جرافيت', Color(0xFF6E7178), Color(0xFF3E4045), 0.13, Color(0xFFFFFFFF), Color(0xFF2EE6A6)),
  AppIconVariant('royal', 'أزرق ملكي', Color(0xFF344E96), Color(0xFF14265B), 0.13, Color(0xFFFFFFFF), Color(0xFF2EE6A6)),
  AppIconVariant('violet', 'بنفسجي', Color(0xFF4F3F98), Color(0xFF271C5C), 0.13, Color(0xFFFFFFFF), Color(0xFF2EE6A6)),
];
