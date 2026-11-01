// أدوات نصية للمحرك المحلي: توحيد الأرقام/الحروف العربية + إخفاء البيانات الحساسة.
// لا اعتماد على Flutter هنا ليسهل اختبارها.

const String _ar = '٠١٢٣٤٥٦٧٨٩';
const String _fa = '۰۱۲۳۴۵۶۷۸۹';

/// يحوّل الأرقام العربية/الفارسية إلى 0-9 ويوحّد الفاصلة العشرية والآلاف العربية.
String asciiDigits(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    var i = _ar.indexOf(ch);
    if (i < 0) i = _fa.indexOf(ch);
    if (i >= 0) {
      b.write(i);
    } else if (ch == '٫') {
      b.write('.');
    } else if (ch == '٬') {
      b.write(',');
    } else {
      b.write(ch);
    }
  }
  return b.toString();
}

final RegExp _diacritics = RegExp('[\u064B-\u0652\u0640]');
final RegExp _spaces = RegExp(r'\s+');

/// نص للمطابقة فقط (لا يُعرض): أرقام لاتينية، حروف صغيرة، بلا تشكيل/تطويل، توحيد الألف والياء.
String normalizeForMatch(String s) {
  var t = asciiDigits(s).toLowerCase();
  t = t.replaceAll(_diacritics, '');
  t = t.replaceAll(RegExp('[أإآٱ]'), 'ا').replaceAll('ى', 'ي').replaceAll('ة', 'ه');
  return t.replaceAll(_spaces, ' ').trim();
}

bool _isWordChar(String ch) => RegExp(r'[a-z0-9]').hasMatch(ch);

/// هل يظهر [needle] داخل [hay] (كلاهما بعد normalizeForMatch)؟
/// للكلمات اللاتينية نشترط حدود كلمة؛ للعربية يكفي احتواء النص.
bool containsWord(String hay, String needle) {
  if (needle.isEmpty) return false;
  final latin = _isWordChar(needle[0]) || _isWordChar(needle[needle.length - 1]);
  if (!latin) return hay.contains(needle);
  final re = RegExp('(?<![a-z0-9])${RegExp.escape(needle)}(?![a-z0-9])');
  return re.hasMatch(hay);
}

/// "1,234.50" أو "1.234,50" أو "50,25" -> 123450 (وحدات صغرى = قرش). null لو غير صالح.
int? parseMinor(String raw) {
  var s = asciiDigits(raw).replaceAll(' ', '');
  if (s.isEmpty || !RegExp(r'^[0-9][0-9.,]*$').hasMatch(s)) return null;
  final lc = s.lastIndexOf(','), ld = s.lastIndexOf('.');
  String intPart, frac = '';
  if (lc >= 0 && ld >= 0) {
    final decIdx = lc > ld ? lc : ld;
    intPart = s.substring(0, decIdx).replaceAll(RegExp(r'[.,]'), '');
    frac = s.substring(decIdx + 1);
  } else if (lc >= 0 || ld >= 0) {
    final idx = lc >= 0 ? lc : ld;
    final after = s.substring(idx + 1);
    final multi = RegExp('[.,]').allMatches(s).length > 1;
    if (multi || after.length == 3) {
      intPart = s.replaceAll(RegExp(r'[.,]'), '');
    } else {
      intPart = s.substring(0, idx);
      frac = after;
    }
  } else {
    intPart = s;
  }
  if (frac.length > 2) return null;
  final whole = int.tryParse(intPart);
  if (whole == null) return null;
  final cents = frac.isEmpty ? 0 : int.parse(frac.padRight(2, '0'));
  return whole * 100 + cents;
}

/// يخفي أي تتابع أرقام طوله 5 أو أكثر ويُبقي آخر 4 (لسجل خفيف لا يحمل بيانات حساسة).
String maskSensitive(String s) => s.replaceAllMapped(RegExp(r'\d{5,}'), (m) {
      final d = m.group(0)!;
      return '•••${d.substring(d.length - 4)}';
    });

/// بصمة FNV-1a 32 بت بقيمتين ابتدائيتين مختلفتين => نص سداسي 16 خانة (آمنة على Android).
String fingerprint(String s) {
  int run(int seed) {
    var h = seed;
    for (final u in s.codeUnits) {
      h ^= u;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  String hx(int v) => v.toRadixString(16).padLeft(8, '0');
  return hx(run(0x811C9DC5)) + hx(run(0x9E3779B1));
}

// ───────── تنظيف نص الرسالة قبل حفظه في وصف المعاملة ─────────
// العرض فقط: الرسالة الأصلية تبقى كما هي في المراجعة/السجل، واستخراج البيانات يعمل على الأصل.

final List<RegExp> _leadNoise = [
  RegExp(r'^\s*(?:عزيزي|عزيزتي|عميلنا|عميلتنا)\s+(?:العميل|العميلة|العزيز|العزيزة)?\s*[،,:\-]?\s*'),
  RegExp(r'^\s*يرجى\s+العلم\s+(?:بأنه|بان|أنه|انه|أن|ان)\s*'),
  RegExp(r'^\s*نود\s+(?:إعلامك|اعلامك|إبلاغك|ابلاغك)\s+(?:بأنه|بان|أنه|انه|أن|ان)\s*'),
  RegExp(r'^\s*(?:تنبيه|إشعار|اشعار)\s*[:：\-]\s*'),
];

final List<RegExp> _tailNoise = [
  RegExp(r'[\s،,.\-–]*(?:للمزيد|للاستفسار|للاستعلام|لمزيد\s+من\s+المعلومات)[^\n]{0,40}?(?:اتصل|الاتصال|اتصال|تواصل|التواصل|call)[^\n]*$', caseSensitive: false),
  RegExp(r'[\s،,.\-–]*(?:برجاء|يرجى|من\s+فضلك)\s+(?:الاتصال|الإتصال|التواصل)\s+(?:ب|على|علي)?[^\n]*$'),
  RegExp(r'[\s،,.\-–]*(?:للإبلاغ|للابلاغ)\s+عن\s+(?:أي|اي)\s+(?:معاملة|عملية)[^\n]*$'),
  RegExp(r'[\s،,.\-–]*(?:شكرا|شكراً)\s+(?:لاستخدامك|لتعاملك|لثقتك)[^\n]*$'),
  RegExp(r'[\s،,.\-–]*(?:for\s+(?:more|inquiries)[^\n]{0,30}call)[^\n]*$', caseSensitive: false),
];

/// رقم حساب/كارت مخفي جزئيًا (****7748 أو xxxx7748 أو XXXXXXXX7748 أو •••7748) → **7748
final RegExp _maskedAcc = RegExp(r'(?:[*xX•●#]{2,}[\s\-]*)+(\d{3,})(?!\d)');

/// أرقام طويلة بلا فواصل (9+) تُختصر لآخر 4 (لا تمسّ المبالغ ولا التواريخ ولا المراجع الحرفية).
final RegExp _longDigits = RegExp(r'(?<![\d.,:/\-])\d{9,}(?![\d.,:/\-])');

/// يرجّع وصفًا مختصرًا للمعاملة من نص الرسالة. لو التنظيف حذف أي رقم (مبلغ/تاريخ/مرجع) يرجّع الأصل بدون تغيير.
String cleanBankMessage(String raw) {
  final original = raw.trim();
  if (original.isEmpty) return original;
  var s = asciiDigits(original).replaceAll(RegExp(r'\s+'), ' ').trim();
  // الافتتاحيات (قد تتكرر: «عزيزي العميل، يرجى العلم أنه ...»)
  for (var round = 0; round < 3; round++) {
    final before = s;
    for (final re in _leadNoise) {
      s = s.replaceFirst(re, '');
    }
    if (s == before) break;
  }
  for (final re in _tailNoise) {
    s = s.replaceFirst(re, '');
  }
  s = s.replaceAllMapped(_maskedAcc, (m) => '**${m[1]!.length > 4 ? m[1]!.substring(m[1]!.length - 4) : m[1]!}');
  s = s.replaceAllMapped(_longDigits, (m) => '**${m[0]!.substring(m[0]!.length - 4)}');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  s = s.replaceFirst(RegExp(r'[\s،,.\-–:]+$'), '');
  if (s.isEmpty) return original;
  // حماية: كل رقم قصير/مبلغ/تاريخ كان في الأصل لازم يفضل (الأرقام الطويلة المقنّعة مستثناة).
  final keep = RegExp(r'\d+(?:[.,:\-/]\d+)*').allMatches(asciiDigits(original)).map((m) => m[0]!).where((t) => t.length < 9 && t != '19666');
  for (final t in keep) {
    if (!s.contains(t)) return original;
  }
  return s;
}
