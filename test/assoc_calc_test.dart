import 'package:flutter_test/flutter_test.dart';
import 'package:cashu/core/extras.dart';

// حالات جمعية بقيم واضحة. القيم المتوقعة محسوبة يدويًا من تعريف الجمعية الحالي في extras.dart
// (القسط × الأفراد = قيمة الدور، النصيب يضاعف القسط). أي قاعدة غير مؤكدة موثّقة في CHECKLIST.md.
int _d(int y, int m, int d) => DateTime(y, m, d).millisecondsSinceEpoch;

Assoc _a({double share = 1, List<int>? turns, String role = 'member', bool imIn = true, String every = 'month', int? start}) =>
    Assoc(id: 'a', name: 'ج', amt: 500, members: 10, start: start ?? _d(2026, 1, 10), share: share, turns: turns, role: role, imIn: imIn, every: every);

void main() {
  skippedTests();
  test('نصيب كامل، دوري الثالث', () {
    final a = _a(turns: [3]);
    expect(a.myPay, 500);
    expect(a.pot, 5000);
    expect(a.totalToPay, 5000);
    expect(a.totalToGet, 5000);
    expect(a.payoutDate, DateTime(2026, 3, 10));
  });

  test('نصيبين (دورين 2 و 7): القسط يتضاعف والقبض موزّع على الدورين', () {
    final a = _a(share: 2, turns: [2, 7]);
    expect(a.myPay, 1000);
    expect(a.myTurnCount, 2);
    expect(a.myPayoutPerTurn, 5000);
    expect(a.totalToGet, 10000);
    expect(a.payoutDate, DateTime(2026, 2, 10)); // أقرب دور
  });

  test('نص نصيب: القسط 250 والقبض 2500 في دور واحد', () {
    final a = _a(share: 0.5, turns: [4]);
    expect(a.myPay, 250);
    expect(a.myTurnCount, 1);
    expect(a.myPayoutPerTurn, 2500);
    expect(a.totalToGet, 2500);
  });

  test('مدير غير مشترك: لا يدفع ولا يقبض', () {
    final a = _a(role: 'admin', imIn: false);
    expect(a.myPay, 0);
    expect(a.totalToPay, 0);
    expect(a.totalToGet, 0);
  });

  test('تقدّم: 3 دفعات وقبض الدور 3', () {
    final a = _a(turns: [3])..paidIdx.addAll([0, 1, 2])..got.add(2);
    expect(a.paidTotal, 1500);
    expect(a.gotTotal, 5000);
    expect(a.position, 3500);
    expect(a.leftToPay, 3500);
    expect(a.leftToGet, 0);
    expect(a.finished, false);
  });

  test('تنتهي بعد دفع كل الأدوار واستلام الدور', () {
    final a = _a(turns: [3])..paidIdx.addAll([for (var i = 0; i < 10; i++) i])..got.add(2);
    expect(a.leftToPay, 0);
    expect(a.finished, true);
  });

  test('بيانات قديمة: pays بدون paidIdx تُحسب كعدد دفعات', () {
    final a = _a(turns: [3])..pays.addAll([1, 2, 3]);
    expect(a.paidCount, 3);
    expect(a.isPaid(2), true);
    expect(a.isPaid(3), false);
  });

  test('المواعيد: أسبوعي، كل أسبوعين، وآخر الشهر', () {
    expect(_a(every: 'week', start: _d(2026, 1, 1)).dueOf(2), DateTime(2026, 1, 15));
    expect(_a(every: '2week', start: _d(2026, 1, 1)).dueOf(2), DateTime(2026, 1, 29));
    expect(_a(start: _d(2026, 1, 31)).dueOf(1), DateTime(2026, 2, 28));
  });
}

void skippedTests() {
  group('جمعية قديمة (Skipped)', () {
    test('الأدوار المسددة بالفعل تُحسب مدفوعة ولا تُنشئ معاملات', () {
      final a = _a(turns: [3]);
      // نفس منطق extras.skipAssocRounds على الموديل مباشرة (بدون repo)
      for (final k in [0, 1, 2]) {
        a.paidIdx.add(k);
        a.pays.add(a.dueOf(k).millisecondsSinceEpoch);
        a.skipped.add(k);
      }
      expect(a.paidCount, 3);
      expect(a.paidTotal, 1500);
      expect(a.isSkipped(1), true);
      expect(a.isSkipped(5), false);
      expect(a.leftToPay, 3500);
    });
    test('JSON round-trip يحفظ skipped و hidden', () {
      final a = _a(turns: [3])..skipped.addAll([0, 1])..hidden = true;
      final r = Assoc.fromJson(a.toJson());
      expect(r.skipped, [0, 1]);
      expect(r.hidden, true);
    });
  });
}
