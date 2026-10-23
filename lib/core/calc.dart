/// حاسبة بسيطة: + - × ÷ و % (بعد الرقم = /100).
double? evalExpr(String src) {
  final s = src.replaceAll(' ', '');
  if (s.isEmpty) return null;
  final tokens = <Object>[];
  var buf = '';
  for (final ch in s.split('')) {
    if ('0123456789.'.contains(ch)) {
      buf += ch;
    } else if (ch == '%') {
      if (buf.isNotEmpty) {
        final v = double.tryParse(buf);
        if (v == null) return null;
        tokens.add(v / 100);
        buf = '';
      } else if (tokens.isNotEmpty && tokens.last is double) {
        tokens[tokens.length - 1] = (tokens.last as double) / 100;
      }
    } else {
      if (buf.isNotEmpty) {
        final v = double.tryParse(buf);
        if (v == null) return null;
        tokens.add(v);
        buf = '';
      }
      if (tokens.isEmpty || tokens.last is String) {
        if (tokens.isEmpty && ch == '-') {
          tokens.add(0.0);
        } else if (tokens.isNotEmpty) {
          tokens[tokens.length - 1] = ch;
          continue;
        } else {
          continue;
        }
      }
      tokens.add(ch);
    }
  }
  if (buf.isNotEmpty) {
    final v = double.tryParse(buf);
    if (v == null) return null;
    tokens.add(v);
  }
  if (tokens.isNotEmpty && tokens.last is String) tokens.removeLast();
  if (tokens.isEmpty) return null;
  final t2 = <Object>[tokens[0]];
  for (var i = 1; i + 1 < tokens.length; i += 2) {
    final op = tokens[i] as String;
    final b = tokens[i + 1] as double;
    if (op == '×' || op == '÷') {
      final a = t2.removeLast() as double;
      t2.add(op == '×' ? a * b : (b == 0 ? double.nan : a / b));
    } else {
      t2.add(op);
      t2.add(b);
    }
  }
  var r = t2[0] as double;
  for (var i = 1; i + 1 < t2.length; i += 2) {
    final op = t2[i] as String;
    final b = t2[i + 1] as double;
    r = op == '+' ? r + b : r - b;
  }
  if (r.isNaN || r.isInfinite) return null;
  return r;
}
