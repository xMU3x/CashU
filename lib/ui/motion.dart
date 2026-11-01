import 'package:flutter/widgets.dart';

/// مصدر واحد لقيم الحركة في CashU (نفس حركة SegToggle): ٣٢٠ms + easeOutCubic.
/// أي انتقال جديد لازم يستخدم القيم دي بدل أرقام مكتوبة يدويًا.
class CashUMotion {
  CashUMotion._();

  static const Duration duration = Duration(milliseconds: 320);
  static const Curve curve = Curves.easeOutCubic;

  /// هل المستخدم مفعّل «تقليل الحركة» في الجهاز؟
  static bool reduced(BuildContext c) => MediaQuery.maybeDisableAnimationsOf(c) ?? false;

  /// المدة الفعلية: صفر لو تقليل الحركة مفعّل.
  static Duration of(BuildContext c) => reduced(c) ? Duration.zero : duration;
}
