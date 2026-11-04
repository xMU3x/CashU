import 'package:flutter/widgets.dart';

/// مصدر واحد لقيم الحركة في CashU (Material 3 Motion): مدد قصيرة + منحنيات قياسية.
/// أي انتقال جديد لازم يستخدم القيم دي بدل أرقام مكتوبة يدويًا.
///
/// | الحركة                  | المدة     |
/// |--------------------------|-----------|
/// | ضغط الأزرار              | ٩٠–١٢٠ms  |
/// | الأيقونات                | ١٠٠–١٥٠ms |
/// | انتقالات صغيرة           | ١٢٠–١٦٠ms |
/// | التبديل بين التبويبات     | ١٥٠–١٨٠ms |
/// | التنقل بين الشاشات        | ١٨٠–٢٢٠ms |
/// | النوافذ (Dialogs)         | ١٥٠–١٨٠ms |
/// | الأوراق السفلية           | ١٨٠–٢٢٠ms |
/// | فتح/غلق العناصر           | ١٥٠–٢٠٠ms |
class CashUMotion {
  CashUMotion._();

  /// ضغط الأزرار وتغذية الضغط.
  static const Duration press = Duration(milliseconds: 90);
  /// تبديل الأيقونات.
  static const Duration icon = Duration(milliseconds: 130);
  /// انتقالات العناصر الصغيرة (ألوان، شفافية، شيبس).
  static const Duration small = Duration(milliseconds: 140);
  /// التبديل بين التبويبات / SegToggle / الشريط السفلي.
  static const Duration tab = Duration(milliseconds: 170);
  /// التنقل بين الشاشات (دخول وخروج بنفس المدة).
  static const Duration page = Duration(milliseconds: 200);
  /// النوافذ المنبثقة والقوائم.
  static const Duration dialog = Duration(milliseconds: 160);
  /// الأوراق السفلية (Bottom sheets).
  static const Duration sheet = Duration(milliseconds: 200);
  /// فتح/غلق العناصر القابلة للتوسيع.
  static const Duration expand = Duration(milliseconds: 180);
  /// ظهور عناصر القوائم أول مرة.
  static const Duration reveal = Duration(milliseconds: 160);

  /// المدة الافتراضية (تنقّل الصفحات) — موجودة للتوافق مع الكود القديم.
  static const Duration duration = page;

  /// المنحنى القياسي (دخول) — Material emphasized-decelerate تقريبًا.
  static const Curve curve = Curves.easeOutCubic;
  /// منحنى الخروج.
  static const Curve exitCurve = Curves.easeInCubic;
  /// منحنى الحركات المتماثلة (تبويب/تبديل).
  static const Curve standard = Curves.easeInOutCubic;

  /// هل المستخدم مفعّل «تقليل الحركة» في الجهاز؟
  static bool reduced(BuildContext c) => MediaQuery.maybeDisableAnimationsOf(c) ?? false;

  /// المدة الفعلية (صفر لو تقليل الحركة مفعّل).
  static Duration of(BuildContext c, [Duration d = page]) => reduced(c) ? Duration.zero : d;
}
