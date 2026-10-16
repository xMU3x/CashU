import 'i18n_data.dart';
import 'settings.dart';

bool _isAr(String s) => RegExp(r'[\u0600-\u06FF]').hasMatch(s);

/// طبقة الترجمة: قاموس + قواعد للنصوص التي تحتوي قيمًا متغيرة.
class L {
  static Map<String, String>? _en2ar, _ar2en;

  static void _build() {
    final a = <String, String>{}, b = <String, String>{};
    for (final line in kI18nRaw.split('\n')) {
      final i = line.indexOf('|');
      if (i <= 0) continue;
      final x = line.substring(0, i).replaceAll(r'\n', '\n');
      final y = line.substring(i + 1).replaceAll(r'\n', '\n');
      final xa = _isAr(x), ya = _isAr(y);
      if (xa && !ya) {
        b[x] = y;
      } else if (!xa && ya) {
        a[x] = y;
      } else if (xa && ya) {
        // عربي ↔ عربي (بدون ترجمة)
      } else {
        a[x] = y;
      }
    }
    _en2ar = a;
    _ar2en = b;
  }

  static String get lang => S.str('lang', 'ar');
  static bool get ar => lang == 'ar';
  static bool get rtl => ar;

  /// ترجمة نص واجهة حسب لغة التطبيق الحالية.
  static String t(String s) {
    if (s.isEmpty) return s;
    if (_en2ar == null) _build();
    final map = ar ? _en2ar! : _ar2en!;
    final hit = map[s];
    if (hit != null) return hit;
    final tr = s.trim();
    if (tr.isNotEmpty && tr != s) {
      final h2 = map[tr];
      if (h2 != null) return s.replaceFirst(tr, h2);
    }
    return _rule(s) ?? s;
  }

  static String _x(String g) => t(g);

  static String? _rule(String s) {
    final rules = ar ? _enRules : _arRules;
    for (final r in rules) {
      final m = r.$1.firstMatch(s);
      if (m != null) {
        var out = r.$2;
        for (var i = 1; i <= m.groupCount; i++) {
          out = out.replaceAll('\$$i', _x(m.group(i) ?? ''));
        }
        return out;
      }
    }
    return null;
  }

  // إنجليزي ← عربي
  static final List<(RegExp, String)> _enRules = [
    (RegExp(r'^Spent (.+?) of (.+)$'), r'أُنفق $1 من $2'),
    (RegExp(r'^Spent (.+?) · tap to set a monthly limit$'), r'أُنفق $1 · اضغط لتحديد حد شهري'),
    (RegExp(r'^(\d+) repeating transactions?$'), r'$1 معاملة متكررة'),
    (RegExp(r'^Balance: (.+)$'), r'الرصيد: $1'),
    (RegExp(r'^Transfer (.+) ▶ (.+)$'), r'تحويل $1 ▶ $2'),
    (RegExp(r'^Transfer from (.+)$'), r'تحويل من $1'),
    (RegExp(r'^Transfer to (.+)$'), r'تحويل إلى $1'),
    (RegExp(r'^"(.+)" archived$'), r'تمت أرشفة «$1»'),
    (RegExp(r'^Delete "(.+)" and its (\d+) account\(s\)\?$'), r'حذف «$1» وحساباته ($2)؟'),
    (RegExp(r'^"(.+)" will be deleted\. Its transactions stay in the history\.$'), r'سيتم حذف «$1». تبقى معاملاته في السجل.'),
    (RegExp(r'^Refund: (.+)$'), r'استرداد: $1'),
    (RegExp(r'^Edit (.+)$'), r'تعديل $1'),
    (RegExp(r'^New sub-category for (.+)$'), r'تصنيف فرعي جديد لـ $1'),
    (RegExp(r'^Difference: (.+)$'), r'الفرق: $1'),
    (RegExp(r'^Repeat: (.+)$'), r'تكرار: $1'),
    (RegExp(r'^Opening balance \((.+)\)$'), r'الرصيد الافتتاحي ($1)'),
    (RegExp(r'^(.+) · Next (.+)$'), r'$1 · التالي $2'),
    (RegExp(r'^(.+) — قريباً ✨$'), r'$1 — قريباً ✨'),
    (RegExp(r'^(.+) transactions?$'), r'$1 معاملة'),
  ];

  // عربي ← إنجليزي
  static final List<(RegExp, String)> _arRules = [
    (RegExp(r'^متبقٍ من (.+)$'), r'Left of $1'),
    (RegExp(r'^سيُحذف حساب «(.+)». المعاملات تبقى في السجل.$'), r'"$1" will be deleted. Its transactions stay in the history.'),
    (RegExp(r'^ميزانية شهرية \((.+)\)$'), r'Monthly budget ($1)'),
    (RegExp(r'^كشف (.+) — (.+)$'), r'Statement: $1 — $2'),
    (RegExp(r'^المصروف: (.+)  الدخل: (.+)$'), r'Expenses: $1  Income: $2'),
    (RegExp(r'^الاستحقاق: (.+)$'), r'Due: $1'),
    (RegExp(r'^(.+) · التالي (.+)$'), r'$1 · Next $2'),
    (RegExp(r'^مقابل (.+)$'), r'Against $1'),
    (RegExp(r'^آخر تحديث: (.+)$'), r'Last updated: $1'),
    (RegExp(r'^إضافة مبلغ إلى «(.+)»$'), r'Add an amount to “$1”'),
    (RegExp(r'^([\d,\.]+) من ([\d,\.]+)$'), r'$1 of $2'),
    (RegExp(r'^بمعدلك الحالي سينتهي الشهر بإنفاق ≈ (.+)\.$'), r'At your current pace the month ends with spending of ≈ $1.'),
    (RegExp(r'^أكبر بند عندك: (.+) بنسبة (.+)٪ من مصروفك\.$'), r'Your biggest item: $1 at $2% of your spending.'),
    (RegExp(r'^أنفقت أكثر من الشهر الماضي بنسبة (.+)٪ 📈$'), r'You spent $1% more than last month 📈'),
    (RegExp(r'^أنفقت أقل من الشهر الماضي بنسبة (.+)٪ 👏$'), r'You spent $1% less than last month 👏'),
    (RegExp(r'^عدد الأيام بلا إنفاق: (.+) من (.+)$'), r'No-spend days: $1 of $2'),
    (RegExp(r'^تقدر تصرف (.+) يومياً حتى آخر الشهر بدون تجاوز الميزانية\.$'), r'You can spend $1 a day until month-end without exceeding the budget.'),
    (RegExp(r'^تحتاج (.+) عملة إضافية$'), r'You need $1 more coins'),
    (RegExp(r'^متوسط (.+) في اليوم$'), r'Average $1 per day'),
    (RegExp(r'^(.+) يوم متتالي$'), r'$1 days in a row'),
    (RegExp(r'^أي عملة غير (.+) تُحوَّل بسعر اليوم عند الحفظ\.$'), r"Any currency other than $1 is converted at today's rate when saving."),
    (RegExp(r'^تسوية: (.+)$'), r'Settlement: $1'),
    (RegExp(r'^(\d+) عمليات$'), r'$1 transactions'),
    (RegExp(r'^تمت إضافة (\d+) عملية للسجل/المراجعة$'), r'Added $1 transactions to history/review'),
    (RegExp(r'^بطاقة (•••• \d+)$'), r'Card $1'),
    (RegExp(r'^(\d+) كلمة — أضف كلماتك أو عدّل كلماتنا$'), r'$1 words — add yours or edit ours'),
    (RegExp(r'^(تلقائي|بمراجعة) · (.+)$'), r'$1 · $2'),
    (RegExp(r'^(.+) — قريباً ✨$'), r'$1 — soon ✨'),
  ];
}

/// اختصار: ترجمة نص.
String tr(String s) => L.t(s);

const _monthsAr = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
const _monthsEn = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _monthsEnShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _daysAr = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
const _daysEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// اسم الشهر (1..12) حسب اللغة.
String monthName(int m) => (L.ar ? _monthsAr : _monthsEn)[(m - 1) % 12];
String monthShort(int m) => L.ar ? _monthsAr[(m - 1) % 12] : _monthsEnShort[(m - 1) % 12];

/// اسم اليوم من DateTime.weekday (1=الاثنين).
String weekdayName(int wd) => (L.ar ? _daysAr : _daysEn)[(wd - 1) % 7];
