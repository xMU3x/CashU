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
