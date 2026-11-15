/// قواعد المحرك المحلي. الكلمات الافتراضية مأخوذة من شاشة "الكلمات المتتبَّعة" التي أرسلتها
/// (لقطة Moneyloop) مع إضافات شائعة، وكلها قابلة للتعديل من المستخدم.
library;

const List<String> kSmsKinds = ['purchase', 'debit', 'atm', 'xferOut', 'xferIn', 'refund'];

const Map<String, String> kSmsKindTitle = {
  'purchase': 'شراء',
  'debit': 'خصم',
  'atm': 'سحب نقدي',
  'xferOut': 'تحويل صادر',
  'xferIn': 'تحويل وارد',
  'refund': 'استرداد',
};

/// اتجاه كل نوع: out = مصروف، in = دخل.
const Map<String, String> kSmsDir = {
  'purchase': 'out',
  'debit': 'out',
  'atm': 'out',
  'xferOut': 'out',
  'xferIn': 'in',
  'refund': 'in',
};

/// أولوية الأنواع داخل نفس الاتجاه (الأخص أولًا).
const List<String> kSmsPriority = ['refund', 'atm', 'xferOut', 'xferIn', 'purchase', 'debit'];

const Map<String, List<String>> kDefaultWords = {
  'purchase': ['pos', 'purchased', 'purchase', 'charged', 'spent', 'payment', 'paid', 'شراء', 'مشتريات', 'عملية شراء', 'دفع', 'سداد', 'مدفوعات'],
  'debit': ['deducted', 'debit', 'debited', 'خصم', 'مدين', 'تم خصم'],
  'atm': ['withdrawal', 'cash withdrawal', 'atm', 'withdrawn', 'سحب', 'سحب نقدي', 'صراف'],
  'xferOut': ['sent to', 'transfer to', 'transferred', 'you sent', 'تحويل', 'تم تحويل', 'إرسال', 'أرسلت', 'حولت'],
  'xferIn': ['credited', 'received', 'deposit', 'deposited', 'incoming transfer', 'إلى حسابك', 'استلمت', 'استلام', 'وارد', 'تحويل وارد', 'إضافة', 'إيداع', 'تم إضافة'],
  'refund': ['reversal', 'refunded', 'refund', 'canceled', 'cancelled', 'reversed', 'استرداد', 'استرجاع', 'مرتجع', 'إلغاء', 'رد مبلغ'],
};

/// تُستبعد دائمًا ولا تُحفظ نهائيًا (رموز تحقق + عمليات فاشلة).
const List<String> kDefaultExcluded = [
  'otp', 'one time password', 'one-time password', 'verification code', 'activation code', 'security code', 'passcode',
  'رمز التحقق', 'رمز التأكيد', 'رمز التفعيل', 'كود التحقق', 'كود التفعيل',
  'كلمة المرور لمرة واحدة', 'كلمة السر المؤقتة',
  'declined', 'rejected', 'unsuccessful', 'not successful', 'insufficient', 'could not be completed', 'was not completed', 'failed',
  'تم رفض', 'مرفوض', 'مرفوضة', 'فشلت', 'فشل', 'غير ناجحة', 'لم تتم', 'رصيد غير كاف', 'تعذر',
];

/// عبارات تحذيرية تظهر في ذيل رسائل المعاملات الحقيقية أيضًا؛ لا تُسقط الرسالة وحدها،
/// وتُستعمل فقط إذا لم يوجد نوع عملية + مبلغ (فتكون رسالة تحقق).
const List<String> kWeakExcluded = ['do not share', "don't share", 'never share', 'لا تشارك', 'لا تفصح', 'الرقم السري'];

/// كلمات دعائية: تُرفض فقط إذا اقترنت برابط أو نسبة مئوية.
const List<String> kPromoWords = [
  'offer', 'promo', 'promotion', 'congratulations', 'win ', 'apply now', 'عرض', 'عروض', 'تهانينا', 'اشترك', 'سجل الان', 'قرض', 'تمويل شخصي',
];

/// بدايات معرّفات مرسلين مصرية شائعة (تخمين مبدئي قابل للإضافة من المستخدم، وليست قائمة رسمية مؤكدة).
const Map<String, String> kSenderHints = {
  'cib': 'CIB', 'nbe': 'NBE', 'banquemisr': 'BanqueMisr', 'qnb': 'QNB', 'aaib': 'AAIB', 'hsbc': 'HSBC', 'alexbank': 'AlexBank',
  'adib': 'ADIB', 'fabmisr': 'FABMisr', 'bdc': 'BDC', 'telda': 'Telda', 'vodafone': 'VodafoneCash', 'vf-cash': 'VodafoneCash',
  'instapay': 'InstaPay', 'fawry': 'Fawry', 'meeza': 'Meeza', 'valu': 'valU', 'enbd': 'ENBD', 'saib': 'SAIB', 'kfh': 'KFH',
  'midbank': 'MIDBANK', 'abk': 'ABK', 'cae': 'CAE', 'ubank': 'UB', 'nbk': 'NBK', 'orange cash': 'OrangeCash', 'etisalat cash': 'eCash',
};

const String kCurPattern = r'(?:egp|usd|eur|sar|aed|kwd|qar|gbp|l\.?e\.?|ج\.?م\.?|جنيه|دولار|يورو|\$|€|£)';
const String kNumPattern = r'(\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d+(?:[.,]\d{1,2})?)';

String curCodeOf(String token) {
  final t = token.toLowerCase().replaceAll('.', '');
  switch (t) {
    case 'egp':
    case 'le':
    case 'جم':
    case 'جنيه':
      return 'EGP';
    case 'usd':
    case r'$':
    case 'دولار':
      return 'USD';
    case 'eur':
    case '€':
    case 'يورو':
      return 'EUR';
    case 'gbp':
    case '£':
      return 'GBP';
    default:
      return t.toUpperCase();
  }
}
