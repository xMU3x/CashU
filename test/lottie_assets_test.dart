import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const names = ['success_check', 'empty_state', 'loading_dots'];

  test('pubspec declares lottie package and the assets/lottie folder', () {
    final y = File('pubspec.yaml').readAsStringSync();
    expect(RegExp(r'^\s{2}lottie:\s*\^?\d', multiLine: true).hasMatch(y), isTrue);
    expect(y, contains('- assets/lottie/'));
  });

  for (final n in names) {
    test('$n.json is a structurally valid Lottie file', () {
      final f = File('assets/lottie/$n.json');
      expect(f.existsSync(), isTrue);
      final d = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      for (final k in ['v', 'fr', 'ip', 'op', 'w', 'h', 'layers']) {
        expect(d.containsKey(k), isTrue, reason: '$n missing $k');
      }
      expect((d['op'] as num) > (d['ip'] as num), isTrue);
      final layers = d['layers'] as List;
      expect(layers, isNotEmpty);
      for (final l in layers.cast<Map<String, dynamic>>()) {
        for (final k in ['ind', 'ty', 'ks', 'ip', 'op', 'shapes']) {
          expect(l.containsKey(k), isTrue, reason: '$n layer missing $k');
        }
      }
    });

    test('$n.json keyframes are strictly increasing in time', () {
      final d = jsonDecode(File('assets/lottie/$n.json').readAsStringSync());
      void walk(dynamic o) {
        if (o is Map) {
          if (o['a'] == 1 && o['k'] is List) {
            final ts = [for (final k in (o['k'] as List)) (k as Map)['t'] as num];
            for (var i = 1; i < ts.length; i++) {
              expect(ts[i] > ts[i - 1], isTrue, reason: '$n keyframes not increasing: $ts');
            }
          }
          o.values.forEach(walk);
        } else if (o is List) {
          o.forEach(walk);
        }
      }

      walk(d);
    });
  }

  test('every asset path referenced from lottie_views.dart exists', () {
    final src = File('lib/ui/lottie_views.dart').readAsStringSync();
    final paths = RegExp(r"'(assets/lottie/[\w./]+)'").allMatches(src).map((m) => m.group(1)!).toList();
    expect(paths.length, names.length);
    for (final p in paths) {
      expect(File(p).existsSync(), isTrue, reason: p);
    }
  });
}
