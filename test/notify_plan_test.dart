import 'package:flutter_test/flutter_test.dart';
import 'package:cashu/core/extras.dart';
import 'package:cashu/core/notify_plan.dart';

void main() {
  final now = DateTime(2026, 10, 19, 8);

  test('تذكير تجديد اشتراك قبل بيومين الساعة 9', () {
    final s = Sub(id: 'a', name: 'Netflix', amt: 200, first: DateTime(2026, 9, 25).millisecondsSinceEpoch, remind: 2);
    final plans = planReminders([s], [], [], now);
    expect(plans, isNotEmpty);
    expect(plans.first.at, DateTime(2026, 10, 23, 9));
    expect(plans.first.payload, 'sub/a');
  });

  test('من غير تذكير = لا إشعارات، والمتوقف مؤقتًا لا يُذكَّر', () {
    final a = Sub(id: 'a', name: 'x', amt: 1, first: DateTime(2026, 9, 25).millisecondsSinceEpoch, remind: -1);
    final b = Sub(id: 'b', name: 'y', amt: 1, first: DateTime(2026, 9, 25).millisecondsSinceEpoch, state: 'paused');
    expect(planReminders([a, b], [], [], now), isEmpty);
  });

  test('القسط التالي وقسط الجمعية قبل يوم', () {
    final i = Inst(id: 'i', name: 'ثلاجة', total: 1200, count: 12, first: DateTime(2026, 11, 1).millisecondsSinceEpoch);
    final a = Assoc(id: 'g', name: 'جمعية', amt: 500, start: DateTime(2026, 10, 25).millisecondsSinceEpoch);
    final plans = planReminders([], [i], [a], now);
    expect(plans.map((e) => e.payload).toSet(), {'inst', 'assoc'});
    expect(plans.first.at, DateTime(2026, 10, 24, 9));
  });
}
