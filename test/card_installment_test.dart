import 'package:flutter_test/flutter_test.dart';
import 'package:cashu/core/extras.dart';
import 'package:cashu/core/models.dart';

Inst _plan({double total = 21500, int count = 12, String card = 'c', bool del = false}) =>
    Inst(id: 'p', name: 'Laptop', total: total, count: count, first: DateTime(2026, 11, 1).millisecondsSinceEpoch, card: card, acc: 'bank', del: del);

void _pay(Inst i, [double? a]) {
  final amt = a ?? i.nextAmt;
  i.pays.add(DateTime(2026, 11, 1).millisecondsSinceEpoch + i.pays.length);
  i.amts.add(amt);
}

void main() {
  test('الشهر 0: الحجز بينقص المتاح ومش مصروف', () {
    final s = summarizeCard(limit: 25000, balance: 0, plans: [_plan()]);
    expect(s.available, closeTo(3500, 0.001));
    expect(s.reserved, 21500);
    expect(s.totalDue, 21500);
    expect(s.posted, 0);
    expect(s.planPaid, 0);
    expect(s.planLeft, 21500);
    expect(s.monthly, closeTo(21500 / 12, 1e-9));
    expect(s.nextDue, DateTime(2026, 11, 1));
    expect(s.overLimit, false);
  });

  test('بعد أول قسط: المتبقي ينقص والمتاح يزيد بنفس القيمة (من غير حساب مرتين)', () {
    final p = _plan();
    final each = p.nextAmt;
    _pay(p);
    final s = summarizeCard(limit: 25000, balance: 0, plans: [p]);
    expect(s.planPaid, closeTo(each, 1e-9));
    expect(s.planLeft, closeTo(21500 - each, 1e-9));
    expect(s.available, closeTo(3500 + each, 1e-9));
    expect(s.totalDue, closeTo(21500 - each, 1e-9));
    expect(s.nextDue, DateTime(2026, 12, 1));
  });

  test('ثابت محاسبي: المدفوع + المتبقي = الإجمالي، والمتاح = الحد - المستحق', () {
    final p = _plan();
    for (var k = 0; k < 5; k++) {
      _pay(p);
    }
    final s = summarizeCard(limit: 25000, balance: 0, plans: [p]);
    expect(s.planPaid + s.planLeft, closeTo(21500, 1e-9));
    expect(s.available, closeTo(25000 - s.totalDue, 1e-9));
  });

  test('سداد مبكر للمتبقي: الخطة تخلص ويرجع الحد كامل', () {
    final p = _plan();
    _pay(p);
    _pay(p, p.left); // السداد المبكر = دفعة واحدة بالمتبقي
    expect(p.done, true);
    final s = summarizeCard(limit: 25000, balance: 0, plans: [p]);
    expect(s.planLeft, 0);
    expect(s.available, closeTo(25000, 1e-9));
    expect(s.monthly, 0);
    expect(s.nextDue, isNull);
  });

  test('المديونية الفعلية منفصلة عن المحجوز', () {
    final s = summarizeCard(limit: 25000, balance: -2000, plans: [_plan()]);
    expect(s.posted, 2000);
    expect(s.reserved, 21500);
    expect(s.totalDue, 23500);
    expect(s.available, closeTo(1500, 1e-9));
  });

  test('تخطّي الحد يظهر كـ overLimit', () {
    final s = summarizeCard(limit: 25000, balance: -5000, plans: [_plan()]);
    expect(s.available, closeTo(-1500, 1e-9));
    expect(s.overLimit, true);
  });

  test('الإلغاء (del) يحرر الحجز، وخطط البطاقات التانية والعادية لا تُحسب', () {
    final s = summarizeCard(limit: 25000, balance: 0, plans: [_plan(del: true), _plan(card: 'other'), _plan(card: '')].where((i) => i.card == 'c' || i.del));
    expect(s.reserved, 0);
    expect(s.available, 25000);
    // حتى لو اتمرّرت كلها: الدالة نفسها تتجاهل المحذوف وغير التابع للبطاقة عبر onCard/del
    final s2 = summarizeCard(limit: 25000, balance: 0, plans: [_plan(del: true), _plan(card: '')]);
    expect(s2.reserved, 0);
  });

  test('الحفظ والمزامنة: card و limit بيتسجّلوا في JSON', () {
    expect(Inst.fromJson(_plan().toJson()).card, 'c');
    final a = Account(id: 'c', name: 'Visa', kind: 'credit', limit: 25000);
    expect(Account.fromJson(a.toJson()).limit, 25000);
    expect(Account.fromJson({'id': 'x', 'name': 'old'}).limit, 0); // بيانات قديمة بدون limit
  });

  test('رصيد دائن نزل لسداد قسط متحسبش مرتين في المتاح', () {
    final p = _plan(total: 21799, count: 6);
    _pay(p, 3643);
    final s = summarizeCard(limit: 25000, balance: 3643.01, plans: [p]);
    // المتاح = الحد − المتبقي (18156) + (الدائن − المدفوع = 0.01)
    expect(s.available, closeTo(25000 - 18156 + 0.01, 0.001));
  });

  test('وضع الرصيد = المتاح − الحد (المديونية الكاملة بالأقساط)', () {
    final p = _plan(total: 21799, count: 6);
    _pay(p, 3643);
    final s = summarizeCard(limit: 25000, balance: 3643.01, plans: [p]);
    expect(s.available - s.limit, closeTo(-(18156 - 0.01), 0.001));
  });
}
