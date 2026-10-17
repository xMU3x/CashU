import 'settings.dart';

/// لغة الواجهة: 'ar' (افتراضي، RTL) أو 'en' (LTR).
bool get isAr => S.str('lang', 'ar') != 'en';

const Map<String, String> _en2ar = {
  'Transactions': 'المعاملات', 'More': 'المزيد', 'Assets': 'الأصول', 'Exchange': 'صرف عملة', 'Statistics': 'إحصائيات', 'Banks': 'بنوك', 'Cards': 'كروت', 'Other': 'أخرى',
  'Tags (comma separated)': 'وسوم (افصل بفاصلة)', 'Attachment / Link': 'مرفق / رابط',
  'Accounts': 'الحسابات', 'Account name': 'اسم الحساب', 'Additional information': 'معلومات إضافية', 'All': 'الكل',
  'All Transactions': 'كل المعاملات', 'Amount': 'المبلغ', 'Archive': 'أرشفة', 'Auto-clear transactions': 'تسوية المعاملات تلقائيًا',
  'Bank Account': 'حساب بنكي', 'Bank Accounts': 'حسابات بنكية', 'Budgets': 'الميزانيات', 'Cancel': 'إلغاء', 'Cash': 'نقدي',
  'Credit': 'ائتمان', 'eWallets': 'محافظ إلكترونية', 'Debit Cards': 'بطاقات الخصم', 'Cash/Wallet Account': 'حساب نقدي / محفظة',
  'Credit Card': 'بطاقة ائتمان', 'Debit Card': 'بطاقة خصم', 'eWallet': 'محفظة إلكترونية', 'Checkbook': 'دفتر الشيكات',
  'Checkbook Register': 'سجل الشيكات', 'Cleared': 'مُسوّاة', 'Connect to Online Banking': 'الربط مع البنك', 'Current balance': 'الرصيد الحالي',
  'Custom URL': 'رابط مخصص', 'Date & time': 'التاريخ والوقت', 'Default': 'افتراضي', 'Delete': 'حذف', 'Delete account': 'حذف الحساب',
  'Delete group': 'حذف المجموعة', 'Deleted': 'تم الحذف', 'Undo': 'تراجع', 'Description': 'الوصف', 'Done': 'تم',
  'Due date (optional)': 'تاريخ الاستحقاق (اختياري)', 'Duplicate': 'تكرار', 'Duplicated': 'تم التكرار', 'Edit': 'تعديل',
  'Edit Account': 'تعديل الحساب', 'Expense': 'مصروف', 'Income': 'دخل', 'Transfer': 'تحويل', 'Move Transaction': 'نقل المعاملة',
  'I owe them': 'عليّا لهم', 'They owe me': 'ليّا عندهم', 'Icon': 'الأيقونة', 'Icon library': 'مكتبة الأيقونات',
  'Include in Group balance': 'تضمين في رصيد المجموعة', 'Include in Net Worth': 'تضمين في صافي الثروة', 'Loan / Debt': 'سلفة / دين',
  'Make Scheduled': 'جعلها متكررة', 'Monthly': 'شهري', 'Daily': 'يومي', 'Weekly': 'أسبوعي', 'Name': 'الاسم', 'New balance': 'الرصيد الجديد',
  'No limit': 'بلا حد', 'No transactions yet': 'لا توجد معاملات بعد', 'None': 'لا شيء', 'Note': 'ملاحظة', 'Online banking': 'الخدمات البنكية',
  'Open loans': 'السلف المفتوحة', 'Opening balance': 'الرصيد الافتتاحي', 'Options': 'خيارات', 'Payee': 'المستفيد', 'Pending': 'معلّقة',
  'Person name': 'اسم الشخص', 'Put in Group': 'وضع في مجموعة', 'Receive date': 'تاريخ الاستلام', 'Refund': 'استرداد',
  'Refund added': 'تمت إضافة الاسترداد', 'Reorder': 'ترتيب', 'Repeat': 'تكرار', 'Reports': 'التقارير', 'Save': 'حفظ',
  'Save & Add Another': 'حفظ وإضافة أخرى', 'Scheduled': 'المجدولة', 'Subscriptions': 'الاشتراكات', 'Search': 'بحث',
  'Select Account': 'اختر الحساب', 'Select Category': 'اختر التصنيف', 'Select transaction': 'اختر المعاملة', 'Send date': 'تاريخ الإرسال',
  'Settings': 'الإعدادات', 'Share Transaction': 'مشاركة المعاملة', 'Show All': 'عرض الكل', 'Split': 'تقسيم', 'Stop': 'إيقاف',
  'Transfer amount': 'مبلغ التحويل', 'Upload': 'رفع', 'Upload Image': 'رفع صورة', 'Does not repeat': 'لا يتكرر', 'NET WORTH': 'صافي الثروة',
  'LIABILITIES': 'الالتزامات', 'Basic': 'أساسي', 'Advanced': 'متقدم', 'Search ': 'بحث ', 'Not signed in': 'غير مسجّل', 'Add': 'إضافة',
  'Downloading image...': 'جارٍ تحميل الصورة...', 'Could not download the image. The link will be used directly.': 'تعذّر تحميل الصورة، سيتم استخدام الرابط مباشرة.',
  'Opening Balance': 'الرصيد الافتتاحي', 'Last 4 digits': 'آخر ٤ أرقام', 'Account number': 'رقم الحساب (آخر ٤ أرقام)', 'Adjust': 'تسوية', 'Today': 'اليوم', 'Yesterday': 'أمس', 'New transaction': 'معاملة جديدة', 'Image from gallery': 'صورة من المعرض', 'Image from URL': 'صورة من رابط',
  "Icon from bank's website": 'أيقونة من موقع البنك', 'Bank icons': 'أيقونات البنوك', 'Budget monitoring': 'متابعة الميزانية',
  'You cannot delete the last account': 'لا يمكن حذف آخر حساب', 'You cannot archive the last account': 'لا يمكن أرشفة آخر حساب',
  'Enter an account name': 'اكتب اسم الحساب', 'Open an account to edit it': 'افتح حسابًا لتعديله',
  'Only expenses and income can be scheduled': 'يمكن جدولة المصروفات والدخل فقط', 'Only expenses and income can be refunded': 'يمكن استرداد المصروفات والدخل فقط',
  'Scheduled monthly': 'تمت الجدولة شهريًا', 'Editing this type is not supported yet': 'تعديل هذا النوع غير مدعوم بعد',
  'Borrowed money is not counted as income. ': 'المبالغ المقترضة لا تُحتسب دخلًا. ',
  'No scheduled transactions.\nOpen a transaction and choose Make Scheduled.': 'لا توجد اشتراكات أو معاملات متكررة.\nافتح معاملة واختر «جعلها متكررة».',
};

final Map<String, String> _ar2en = {
  'الإعدادات': 'Settings', 'تتبع رسائل البنك': 'Bank SMS tracking', 'قراءة رسائل البنك': 'Read bank messages', 'تحتاج مراجعة': 'Needs review',
  'مراجعة الرسائل': 'Review messages', 'السجل': 'Log', 'الكلمات المتتبَّعة': 'Tracked words', 'البطاقات والحسابات': 'Cards & accounts',
  'إضافة بطاقة': 'Add card', 'الوضع الداكن': 'Dark mode', 'اللغة': 'Language', 'الأدوات': 'Tools', 'المزيد': 'More', 'غير مسجّل': 'Not signed in',
  'إلغاء': 'Cancel', 'تأكيد': 'Confirm', 'حفظ': 'Save', 'حذف': 'Delete', 'تم': 'Done', 'المتجر والعملات': 'Store & coins',
  'إدارة البيانات': 'Data management', 'الخصوصية': 'Privacy', 'اهتزاز اللمس': 'Haptics', 'صوت الإضافة': 'Add sound',
};

final List<(RegExp, String)> _rules = [
  (RegExp(r'^"(.+)" will be deleted\. Its transactions stay in the history\.$'), r'سيتم حذف "$1". تبقى معاملاته في السجل.'),
  (RegExp(r'^Delete "(.+)" and its (\d+) account\(s\)\?$'), r'حذف "$1" وحساباته ($2)؟'),
  (RegExp(r'^(\d+) repeating transactions?$'), r'$1 معاملة متكررة'),
];

/// يترجم نصًا واجهيًا حسب اللغة الحالية. النص غير الموجود في القاموس يُعرض كما هو.
String tl(String s) {
  if (!isAr) return _ar2en[s] ?? s;
  final d = _en2ar[s];
  if (d != null) return d;
  if (s.isEmpty || !RegExp(r'[A-Za-z]').hasMatch(s)) return s;
  for (final r in _rules) {
    final m = r.$1.firstMatch(s);
    if (m != null) return r.$2.replaceAllMapped(RegExp(r'\$(\d)'), (g) => m.group(int.parse(g.group(1)!)) ?? '');
  }
  return s;
}
