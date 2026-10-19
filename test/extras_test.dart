import 'package:flutter_test/flutter_test.dart';
import 'package:cashu/core/extras.dart';

void main() {
  test('addMonths يضبط آخر يوم في الشهر', () {
    expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    expect(addMonths(DateTime(2026, 11, 15), 3), DateTime(2027, 2, 15));
  });

  test('القيمة الشهرية للاشتراكات', () {
    Sub s(String c, double a) => Sub(id: 'x', name: 'n', amt: a, cyc: c, first: 0);
    expect(s('month', 500).monthly, 500);
    expect(s('q3', 100).monthly, closeTo(33.33, .01));
    expect(s('year', 200).monthly, closeTo(16.67, .01));
    expect(s('once', 90).monthly, 0);
  });

  test('الأقساط: القسط والمتبقي', () {
    final i = Inst(id: 'i', name: 'ثلاجة', total: 12000, count: 12, first: DateTime(2026, 1, 1).millisecondsSinceEpoch);
    expect(i.each, 1000);
    i.pays.addAll([1, 2, 3]);
    expect(i.left, 9000);
    expect(i.done, false);
    expect(i.nextDue, DateTime(2026, 4, 1));
  });

  test('الجمعية: ميعاد القبض وقيمته', () {
    final a = Assoc(id: 'a', name: 'ج', amt: 500, members: 10, turn: 3, start: DateTime(2026, 1, 10).millisecondsSinceEpoch);
    expect(a.payout, 5000);
    expect(a.payoutDate, DateTime(2026, 3, 10));
  });

  test('JSON round-trip للاشتراك', () {
    final s = Sub(id: 's', name: 'Netflix', amt: 200, first: 5, trial: true, trialEnd: 9)..pays.add(SubPay(7, 200));
    final r = Sub.fromJson(s.toJson());
    expect(r.name, 'Netflix');
    expect(r.trial, true);
    expect(r.pays.single.amt, 200);
  });
}
