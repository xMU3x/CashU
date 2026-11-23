import '../core/settings.dart';

/// رسوم إنستاباي (مصر): نسبة من مبلغ التحويل بحد أدنى وحد أقصى بالجنيه. القيم الافتراضية = اللي في الشاشة (٠٫١٪ · ٠٫٥ · ٢٠).
const double kInstaRateDefault = 0.1; // %
const double kInstaMinDefault = 0.5; // جنيه
const double kInstaMaxDefault = 20; // جنيه

class InstaFee {
  static bool get on => S.flag('insta_on');
  static double get rate => S.num_('insta_rate', kInstaRateDefault).toDouble();
  static double get min => S.num_('insta_min', kInstaMinDefault).toDouble();
  static double get max => S.num_('insta_max', kInstaMaxDefault).toDouble();

  /// الرسوم لمبلغ تحويل [amt] (جنيه): النسبة مقيّدة بين الأدنى والأقصى، ومقرّبة لأقرب قرش.
  static double of(double amt, {double? r, double? lo, double? hi}) {
    final rr = r ?? rate, a = lo ?? min, b = hi ?? max;
    if (amt <= 0) return 0;
    var f = amt * rr / 100;
    if (f < a) f = a;
    if (b > 0 && f > b) f = b;
    return (f * 100).round() / 100;
  }

  /// لو رسالة البنك نفسها بتذكر رسوم/عمولة ما نضيفش رسوم تانية.
  static final RegExp _mentionsFee = RegExp(r'رسوم|عمول|مصاريف|fees?\b|commission|charges?\b', caseSensitive: false);
  static bool bodyMentionsFee(String body) => _mentionsFee.hasMatch(body);
}
