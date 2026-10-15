import 'package:budget/core/merge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mergeRecords: الأحدث يكسب والاتحاد بيحافظ على الاتنين', () {
    final a = {
      'x': {'id': 'x', 'name': 'قديم', 'u': 1},
      'y': {'id': 'y', 'u': 5},
    };
    final b = {
      'x': {'id': 'x', 'name': 'جديد', 'u': 2},
      'z': {'id': 'z', 'u': 3},
    };
    final m = mergeRecords(a, b);
    expect(m['x']['name'], 'جديد');
    expect(m.keys.toSet(), {'x', 'y', 'z'});
  });

  test('الحذف (d) الأحدث بيكسب', () {
    final a = {'x': {'id': 'x', 'u': 1}};
    final b = {'x': {'id': 'x', 'd': true, 'u': 2}};
    expect(mergeRecords(a, b)['x']['d'], true);
  });
}
