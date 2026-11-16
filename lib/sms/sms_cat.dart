/// تصنيف سريع محلي (من غير شبكة) لمعاملة مستخرجة من رسالة: يعتمد على اسم التاجر ونص الرسالة.
/// بيرجّع معرّف تصنيف موجود (food/shop/transport/bills/health/fun/edu/home/other أو salary/free/gift/invest/other_i).
/// بيشتغل فورًا قبل/بدل الذكاء الاصطناعي، والـ AI لو رد بسرعة بيغلبه.
const Map<String, List<String>> _kExpWords = {
  'food': ['مطعم', 'restaurant', 'cafe', 'coffee', 'كافيه', 'قهوة', 'starbucks', 'mcdonald', 'kfc', 'hardee', 'pizza', 'burger', 'talabat', 'طلبات', 'elmenus', 'بقالة', 'سوبر ماركت', 'supermarket', 'carrefour', 'كارفور', 'spinneys', 'hyper', 'هايبر', 'metro', 'خير زمان', 'مخبز', 'bakery', 'food', 'dominos', 'cilantro', 'costa', 'مأكولات'],
  'transport': ['uber', 'اوبر', 'أوبر', 'careem', 'كريم', 'inDrive', 'indrive', 'didi', 'بنزين', 'وقود', 'petrol', 'misr gas', 'total', 'mobil', 'wataniya', 'وطنية', 'chillout', 'taxi', 'تاكسي', 'مترو', 'metro ticket', 'قطار', 'egyptair', 'مصر للطيران', 'parking', 'ركن', 'toll', 'رسوم طريق'],
  'bills': ['فاتورة', 'bill', 'كهرباء', 'electric', 'مياه', 'water', 'غاز', 'gas bill', 'telecom', 'vodafone', 'فودافون', 'orange', 'اورنج', 'etisalat', 'اتصالات', 'we ', 'المصرية للاتصالات', 'internet', 'انترنت', 'fawry', 'فوري', 'aman', 'امان', 'bee', 'سداد'],
  'health': ['صيدلية', 'pharmacy', 'seif', 'سيف', 'العزبي', 'مستشفى', 'hospital', 'clinic', 'عيادة', 'دكتور', 'dr.', 'lab', 'معمل', 'تحاليل', 'مستشفي', 'اشعة', 'medical'],
  'shop': ['amazon', 'امازون', 'noon', 'نون', 'jumia', 'جوميا', 'mall', 'مول', 'zara', 'h&m', 'defacto', 'lcw', 'shop', 'store', 'متجر', 'سيتي ستارز', 'city stars', 'btech', 'بي تك', 'extra', '2b', 'shein', 'aliexpress', 'اكسترا', 'ikea', 'ايكيا', 'ملابس'],
  'fun': ['netflix', 'نتفليكس', 'spotify', 'سبوتيفاي', 'shahid', 'شاهد', 'cinema', 'سينما', 'vox', 'playstation', 'steam', 'xbox', 'game', 'العاب', 'ألعاب', 'anghami', 'youtube', 'disney', 'ملاهي', 'dream park', 'club', 'نادي'],
  'edu': ['مدرسة', 'school', 'جامعة', 'university', 'course', 'كورس', 'udemy', 'coursera', 'مصاريف دراسية', 'تعليم', 'academy', 'اكاديمية', 'كتب', 'books', 'مكتبة'],
  'home': ['ايجار', 'إيجار', 'rent', 'صيانة', 'maintenance', 'سباك', 'كهربائي', 'اثاث', 'أثاث', 'furniture', 'نظافة', 'cleaning', 'عقار', 'compound', 'كمبوند'],
};

const Map<String, List<String>> _kIncWords = {
  'salary': ['salary', 'مرتب', 'راتب', 'payroll'],
  'gift': ['هدية', 'gift', 'عيدية'],
  'invest': ['أرباح', 'ارباح', 'dividend', 'فوائد', 'interest', 'عائد', 'coupon', 'كوبون'],
  'free': ['freelance', 'فري لانس', 'upwork', 'fiverr', 'payoneer', 'paypal'],
};

/// يرجّع معرّف التصنيف المناسب، أو 'other' / 'other_i' لو مفيش تطابق.
String guessSmsCategory({required String merchant, required String body, required bool income}) {
  final text = '${merchant.toLowerCase()} ${body.toLowerCase()}';
  final m = income ? _kIncWords : _kExpWords;
  // التاجر أهم من نص الرسالة: نبدأ بيه لوحده.
  final name = merchant.toLowerCase();
  if (name.isNotEmpty) {
    for (final e in m.entries) {
      if (e.value.any((w) => name.contains(w.toLowerCase()))) return e.key;
    }
  }
  for (final e in m.entries) {
    if (e.value.any((w) => text.contains(w.toLowerCase()))) return e.key;
  }
  return income ? 'other_i' : 'other';
}

/// هل [id] تصنيف صالح للنوع المطلوب؟
bool isValidSmsCategory(String id, bool income) {
  const exp = {'bills', 'food', 'transport', 'shop', 'health', 'fun', 'edu', 'home', 'other'};
  const inc = {'salary', 'free', 'gift', 'invest', 'other_i'};
  return (income ? inc : exp).contains(id);
}
