import 'package:flutter_test/flutter_test.dart';
import 'package:cashu/core/extras.dart';

int ms(DateTime d) => d.millisecondsSinceEpoch;

void main() {
  group('دورة دفع مخصّصة', () {
    test('الترميز والقراءة', () {
      expect(customCycleCode(10, 'day'), 'c:10:day');
      expect(parseCustomCycle('c:3:week'), (3, 'week'));
      expect(parseCustomCycle('c:0:bad'), (1, 'month'));
      expect(isCustomCycle('month'), false);
      expect(isCustomCycle('c:2:year'), true);
    });

    test('الأسماء', () {
      expect(customCycleName('c:1:day'), 'كل يوم');
      expect(customCycleName('c:2:week'), 'كل أسبوعين');
      expect(cycleName('c:5:month'), contains('شهور'));
    });

    test('التاريخ التالي', () {
      final d = DateTime(2026, 1, 31);
      expect(nextCycle(d, 'c:10:day'), DateTime(2026, 2, 10));
      expect(nextCycle(d, 'c:2:week'), DateTime(2026, 2, 14));
      expect(nextCycle(d, 'c:1:month'), DateTime(2026, 2, 28));
      expect(nextCycle(DateTime(2026, 3, 5), 'c:2:year'), DateTime(2028, 3, 5));
    });

    test('القيمة الشهرية', () {
      Sub s(String c) => Sub(id: 'x', name: 'n', amt: 120, cyc: c, first: 0);
      expect(s('c:2:month').monthly, 60);
      expect(s('c:1:year').monthly, 10);
      expect(s('c:1:day').monthly, closeTo(120 * 30.4375, .01));
    });

    test('JSON يحافظ على الدورة المخصصة', () {
      final r = Sub.fromJson(Sub(id: 's', name: 'n', amt: 1, cyc: 'c:3:day', first: 0).toJson());
      expect(r.cyc, 'c:3:day');
      expect(cycleDays(r.cyc), 3);
    });
  });

  group('Skipped في الاشتراكات', () {
    test('الدفعة المتخطّاة بتنقل ميعاد التجديد للدورة اللي بعدها', () {
      final now = DateTime.now();
      final first = now.subtract(const Duration(days: 10));
      final s = Sub(id: 's', name: 'n', amt: 100, first: ms(first));
      expect(s.overdue, true);
      s.pays.add(SubPay(ms(now), 100, kSkipAcc));
      expect(s.overdue, false);
      expect(s.nextDue!.isAfter(now), true);
    });

    test('الدفع المبكر بينقل nextDue كمان', () {
      final now = DateTime.now();
      final first = now.add(const Duration(days: 5));
      final s = Sub(id: 's', name: 'n', amt: 100, first: ms(first));
      expect(s.nextDue, first);
      s.pays.add(SubPay(ms(now), 100, kSkipAcc));
      expect(s.nextDue, addMonths(first, 1));
    });
  });

  group('تنبيهات الأقساط المتعددة', () {
    test('القيمة الافتراضية والتوافق مع القديم', () {
      expect(Inst(id: 'i', name: 'x', total: 100, first: 0).reminds, [1]);
      expect(Inst(id: 'i', name: 'x', total: 100, first: 0, remind: -1).reminds, isEmpty);
      final old = Inst.fromJson({'id': 'i', 'name': 'x', 'total': 100, 'first': 0, 'remind': 3});
      expect(old.reminds, [3]);
    });

    test('JSON round-trip لأكتر من تنبيه', () {
      final i = Inst(id: 'i', name: 'x', total: 100, first: 0, reminds: [0, 2, 7]);
      final r = Inst.fromJson(i.toJson());
      expect(r.reminds, [0, 2, 7]);
      expect(Inst.fromJson((Inst(id: 'i', name: 'x', total: 1, first: 0, reminds: [])).toJson()).reminds, isEmpty);
    });
  });
}
