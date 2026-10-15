import 'dart:math' as math;

/// نتيجة تحليل رسالة (بالقواعد أو بالذكاء الاصطناعي).
class Parsed {
  final String? type; // 'expense' | 'income' | null (غير معروف)
  final double? amount;
  final String currency;
  final double? balance;
  final String? merchant, categoryId, last4, note;
  final double confidence;
  final String source; // 'rules' | 'ai'
  final DateTime? date;

  const Parsed({
    this.type,
    this.amount,
    this.currency = 'EGP',
    this.balance,
    this.merchant,
    this.categoryId,
    this.last4,
    this.note,
    this.confidence = 0,
    this.source = 'rules',
    this.date,
  });

  Map<String, dynamic> toMap() => {
        'type': type,
        'amount': amount,
        'currency': currency,
        'balance': balance,
        'merchant': merchant,
        'categoryId': categoryId,
        'last4': last4,
        'note': note,
        'confidence': confidence,
        'source': source,
        'date': date?.millisecondsSinceEpoch,
      };

  factory Parsed.fromMap(Map<String, dynamic> m) => Parsed(
        type: m['type'],
        amount: (m['amount'] as num?)?.toDouble(),
        currency: m['currency'] ?? 'EGP',
        balance: (m['balance'] as num?)?.toDouble(),
        merchant: m['merchant'],
        categoryId: m['categoryId'],
        last4: m['last4'],
        note: m['note'],
        confidence: (m['confidence'] as num?)?.toDouble() ?? 0,
        source: m['source'] ?? 'rules',
        date: m['date'] is num
            ? DateTime.fromMillisecondsSinceEpoch((m['date'] as num).toInt())
            : null,
      );

  /// يكمّل الحقول الناقصة من [o] (المحلل بالقواعد) بعد رد الذكاء الاصطناعي.
  Parsed fill(Parsed o) => Parsed(
        type: type ?? o.type,
        amount: amount ?? o.amount,
        currency: currency,
        balance: balance ?? o.balance,
        merchant: merchant ?? o.merchant,
        categoryId: categoryId ?? o.categoryId,
        last4: last4 ?? o.last4,
        note: note,
        confidence: confidence,
        source: source,
        date: date,
      );
}

const _ar = '٠١٢٣٤٥٦٧٨٩', _fa = '۰۱۲۳۴۵۶۷۸۹';

/// أرقام عربية/فارسية → إنجليزية (نفس الطول تقريبًا).
String toAsciiDigits(String s) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    var i = _ar.indexOf(ch);
    if (i < 0) i = _fa.indexOf(ch);
    b.write(i >= 0
        ? '$i'
        : ch == '٫'
            ? '.'
            : ch == '٬'
                ? ','
                : ch);
  }
  return b.toString();
}

/// تطبيع حرف بحرف (نفس الطول) عشان مقارنة الكلمات.
String fold(String s) {
  const m = {'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ى': 'ي', 'ة': 'ه', 'ـ': ' '};
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    b.write(m[ch] ?? ch);
  }
  return b.toString();
}

const _num = r'(\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)';
const _cur =
    r'(EGP|L\.?E\.?|USD|EUR|SAR|AED|GBP|KWD|QAR|جنيه|ج\.م|جم|دولار|\$|€|£)(?![A-Za-z\u0621-\u064A])';
final _reA = RegExp('(?<![A-Za-z])$_cur\\s*:?\\s*$_num', caseSensitive: false);
final _reB = RegExp('$_num\\s*$_cur', caseSensitive: false);
final _reC = RegExp('(?:مبلغ|بمبلغ|بقيمه|بقيمة)\\s*$_num');

String _curCode(String tok) {
  final t = tok.toUpperCase().replaceAll('.', '');
  if (t == 'EGP' || t == 'LE' || tok == 'جنيه' || tok == 'جم' || tok == 'ج.م') {
    return 'EGP';
  }
  if (t == 'USD' || tok == r'$' || tok == 'دولار') return 'USD';
  if (tok == '€' || t == 'EUR') return 'EUR';
  if (tok == '£' || t == 'GBP') return 'GBP';
  return t;
}

final _bal = RegExp(r'(رصيد|balance|avail|متاح|المتاح)');

String _ctxBefore(String k, int i) {
  final c = k.substring(math.max(0, i - 32), i);
  final cut = math.max(c.lastIndexOf('. '), c.lastIndexOf('\n'));
  return cut >= 0 ? c.substring(cut + 1) : c;
}

class _Amt {
  final int i;
  final double v;
  final String cur;
  final bool bal;
  const _Amt(this.i, this.v, this.cur, this.bal);
}

List<_Amt> _findAmounts(String t, String k) {
  final seen = <int, _Amt>{};
  void add(int numStart, int startIdx, String num, String cur) {
    if (seen.containsKey(numStart)) return;
    final v = double.tryParse(num.replaceAll(',', ''));
    if (v == null) return;
    seen[numStart] =
        _Amt(startIdx, v, cur, _bal.hasMatch(_ctxBefore(k, startIdx)));
  }

  for (final m in _reA.allMatches(t)) {
    add(m.end - m.group(2)!.length, m.start, m.group(2)!, _curCode(m.group(1)!));
  }
  for (final m in _reB.allMatches(t)) {
    add(m.start, m.start, m.group(1)!, _curCode(m.group(2)!));
  }
  for (final m in _reC.allMatches(t)) {
    add(m.end - m.group(1)!.length, m.start, m.group(1)!, 'EGP');
  }
  final l = seen.values.toList()..sort((a, b) => a.i.compareTo(b.i));
  return l;
}

final _otp = RegExp(
    r'(otp|one.?time|رمز (التحقق|الدخول|سري|تفعيل)|كود (التحقق|التفعيل)|verification code|your code|رمز المرور|passcode|cvv|pin\b|الرقم السري)');
final _promo =
    RegExp(r'(عرض|احصل|وفر|سارع|تخفيضات|للاشتراك|اشترك|offer|promo|win |free|http|www\.|bit\.ly)');
final _anchor = RegExp(
    r'(حساب|بطاق|محفظ|رصيد|كارت|account|card|a/c|wallet|balance|atm|instapay|انستا)');
final _debit = RegExp(
    r'(خصم|سحب|شراء|مشتريات|دفع|مدفوع|صرف|سداد|تسديد|اشتريت|حولت|purchase|debit|withdraw|payment|paid|spent|charged|\bpos\b|\batm\b)');
final _credit = RegExp(
    r'(ايداع|استلام|استلمت|اضاف|credited|credit alert|received|deposit|salary|مرتب|راتب|refund|استرداد|ارجاع|وارد|cashback)');
final _toYou = RegExp(
    r'((الي|في|الى) (حسابك|حسابكم|محفظتك|محفظتكم))|to your (account|wallet)|into your');
final _fromYou =
    RegExp(r'(من (حسابك|حسابكم|محفظتك|محفظتكم))|from your (account|wallet)');
final _xfer = RegExp(r'(تم تحويل|حولت|تحويل مبلغ|transfer|\bsent\b)');

final List<(String, RegExp)> _cats = [
  ('food', RegExp(r'(مطعم|restaurant|talabat|طلبات|elmenus|المنيوس|kfc|mcdonald|ماكدونالدز|cafe|كافيه|كوفي|coffee|starbucks|ستاربكس|بيتزا|pizza|burger|برجر|حلواني|بيك|bake)')),
  ('transport', RegExp(r'(uber|اوبر|careem|كريم|indrive|بنزين|fuel|petrol|total|mobil|wataniya|وطنيه|chillout|مترو|metro|parking|جراج|سويفل|swvl|مواصلات)')),
  ('bills', RegExp(r'(فاتوره|فاتورة|bill|vodafone|فودافون|orange|اورنج|etisalat|اتصالات|\bwe\b|كهرباء|electric|غاز|مياه|fawry|فوري|انترنت|internet|سداد)')),
  ('shopping', RegExp(r'(carrefour|كارفور|spinneys|سبينس|سوق|mall|مول|amazon|امازون|noon|نون|jumia|جوميا|seoudi|سعودي|hyper|هايبر|اسواق|متجر|store|shop|ikea)')),
  ('health', RegExp(r'(صيدليه|pharmacy|عياده|مستشفي|vezeeta|فيزيتا|دكتور|clinic|hospital|سيف|العزبي|رشدي|مختبر|معمل)')),
  ('fun', RegExp(r'(netflix|spotify|cinema|سينما|shahid|شاهد|playstation|steam|xbox|vox|فوكس|game|العاب|youtube|anghami|انغامي)')),
  ('edu', RegExp(r'(school|مدرسه|جامعه|university|course|udemy|كورس|تعليم|مصاريف دراسيه|academy|اكاديميه)')),
  ('home', RegExp(r'(ايجار|rent|furniture|اثاث|home|صيانه|سباك|كهربائي)')),
];
final List<(String, RegExp)> _incomeCats = [
  ('salary', RegExp(r'(مرتب|salary|راتب|payroll)')),
  ('freelance', RegExp(r'(freelance|عمل حر|invoice|payoneer)')),
  ('gift', RegExp(r'(هديه|gift|عيديه)')),
];

String guessCategory(bool income, String k) {
  for (final (id, re) in (income ? _incomeCats : _cats)) {
    if (re.hasMatch(k)) return id;
  }
  return income ? 'other_in' : 'other';
}

String _clean(String s) => s
    .trim()
    .replaceAll(RegExp(r'[\s\-–*]+$'), '')
    .replaceAll(RegExp(r'\s{2,}'), ' ');

const _lb = r'(?<![A-Za-z\u0621-\u064A])';
final _mAr = RegExp(
    '$_lb(?:لدى|لدي|عند|متجر)\\s+([^\\d\\n.,،:;]{2,32}?)(?=\\s+(?:بتاريخ|في تاريخ|بالبطاق|بطاق|كارت|الرصيد|رصيد|المتاح|بمبلغ|مبلغ|عبر|يوم|ب\\s*\\d)|[.\\n,،]|\$)');
final _mEn = RegExp(
    r"\bat\s+([A-Za-z0-9][A-Za-z0-9 &'*\-\.\/]{1,30}?)(?=\s+(?:on|using|with|card|ending|ref|balance|avail|date|from)\b|[,;\n]|\.\s|\.$|$)",
    caseSensitive: false);
final _mAtm = RegExp(r'(?:من ماكينه|من ماكينة)\s+([A-Za-z0-9 ]{2,20})');
final _mTo = RegExp(
    '$_lb(?:الى|إلى|الي|to)\\s+((?!حساب|محفظ|your)[^\\d\\n.,،:;]{2,30}?)(?=\\s+(?:عبر|بنجاح|via|through|في|بتاريخ)|[.\\n,،]|\$)',
    caseSensitive: false);

String? _merchant(String t) {
  for (final re in [_mAr, _mEn, _mAtm, _mTo]) {
    final m = re.firstMatch(t);
    if (m != null) return _clean(m.group(1)!);
  }
  return null;
}

final _l4 = RegExp(
    r'(?:card|بطاقه|كارت|المنتهيه|ending|\*{2,}|x{2,}|•{2,})[^\d]{0,16}(\d{4})(?!\d)');

/// يحلّل رسالة بنك/محفظة. يرجّع null لو مش رسالة مالية (OTP، دعاية، رصيد بس…).
Parsed? parseSms(String sender, String body) {
  if (RegExp(r'^\+?\d{6,}$').hasMatch(sender.replaceAll(RegExp(r'\s'), ''))) {
    return null; // رسائل من أرقام عادية مش من بنك
  }
  final t = toAsciiDigits(body), k = fold(t);
  if (_otp.hasMatch(k)) return null;
  final amts = _findAmounts(t, k);
  _Amt? main, bal;
  for (final a in amts) {
    if (!a.bal && main == null) main = a;
    if (a.bal && bal == null) bal = a;
  }
  final anchor = _anchor.hasMatch(k);
  if (_promo.hasMatch(k) && !anchor) return null;
  if (main == null && !anchor) return null;

  var d = 0, c = 0;
  if (_debit.hasMatch(k)) d += 1;
  if (_credit.hasMatch(k)) c += 1;
  if (_fromYou.hasMatch(k)) d += 3;
  if (_toYou.hasMatch(k)) c += 3;
  if (_xfer.hasMatch(k) && !_toYou.hasMatch(k)) d += 1;
  final String? dir = d == c ? null : (d > c ? 'expense' : 'income');
  if (main == null && dir == null) return null;

  final mer = _merchant(t);
  final cat =
      dir == null ? null : guessCategory(dir == 'income', '$k ${(mer ?? '').toLowerCase()}');
  var conf = 0.0;
  if (main != null) conf += 0.35;
  if (dir != null) conf += 0.35;
  if (anchor || bal != null) conf += 0.15;
  if (mer != null) conf += 0.1;
  if (cat != null && cat != 'other' && cat != 'other_in') conf += 0.05;

  return Parsed(
    type: dir,
    amount: main?.v,
    currency: main?.cur ?? 'EGP',
    balance: bal?.v,
    merchant: mer,
    categoryId: cat,
    last4: _l4.firstMatch(k)?.group(1),
    confidence: double.parse(conf.toStringAsFixed(2)),
  );
}
