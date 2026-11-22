import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// قبول: مفيش مدة أو منحنى مكتوب يدويًا في واجهة التطبيق (lib/ui, lib/pages) خارج lib/ui/motion.dart.
/// المستثنى: مهل الشبكة `.timeout(...)` (مش حركة) وحسابات التواريخ (days/hours).
void main() {
  final dirs = [Directory('lib/ui'), Directory('lib/pages')];
  final files = [
    for (final d in dirs)
      if (d.existsSync())
        for (final f in d.listSync(recursive: true))
          if (f is File && f.path.endsWith('.dart') && !f.path.replaceAll('\\', '/').endsWith('lib/ui/motion.dart')) f,
  ];

  List<String> hits(RegExp re) {
    final out = <String>[];
    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        final t = l.trimLeft();
        if (t.startsWith('//') || t.startsWith('///')) continue;
        if (l.contains('.timeout(')) continue;
        if (re.hasMatch(l)) out.add('${f.path}:${i + 1}: ${t.length > 110 ? t.substring(0, 110) : t}');
      }
    }
    return out;
  }

  test('scans a meaningful number of UI files', () {
    expect(files.length, greaterThan(20));
  });

  test('no hand-written Duration(milliseconds/seconds/...) outside motion.dart', () {
    expect(hits(RegExp(r'Duration\(\s*(milliseconds|seconds|microseconds|minutes)\s*:')), isEmpty);
  });

  test('no hand-written curves outside motion.dart (Curves.*, Cubic(...), Interval(...))', () {
    expect(hits(RegExp(r'\bCurves\.\w+|\bCubic\(|\bInterval\(|\bElasticOutCurve|\bSpringCurve')), isEmpty);
  });
}
