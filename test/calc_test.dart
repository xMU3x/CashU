import 'package:flutter_test/flutter_test.dart';
import 'package:tayyar/core/calc.dart';
import 'package:tayyar/core/merge.dart';

void main() {
  test('calc', () {
    expect(evalExpr('2+3×4'), 14);
    expect(evalExpr('10÷4'), 2.5);
    expect(evalExpr('50%'), .5);
    expect(evalExpr('5+'), 5);
  });
  test('merge by record time', () {
    final a = {'x': {'u': 1, 'v': 'old'}};
    final b = {'x': {'u': 2, 'v': 'new'}, 'y': {'u': 1}};
    final m = mergeFlow(a, b) as Map;
    expect((m['x'] as Map)['v'], 'new');
    expect(m.containsKey('y'), true);
  });
}
