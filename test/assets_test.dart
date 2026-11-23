import 'package:flutter_test/flutter_test.dart';
import 'package:cashu/core/assets.dart';

void main() {
  test('أصل بالوحدة: القيمة = الكمية × السعر الحالي، والتكلفة = الكمية × سعر الشراء', () {
    final a = Asset(id: 'a', type: 'gold', qty: 10, buy: 3000, price: 3500);
    expect(a.value, 35000);
    expect(a.cost, 30000);
    expect(a.gain, 5000);
    expect(a.gainPct, closeTo(16.6667, 0.001));
  });

  test('أصل بقيمة يدوية: القيمة = السعر الحالي والتكلفة = قيمة الشراء', () {
    final a = Asset(id: 'c', type: 'car', qty: 1, buy: 500000, price: 450000);
    expect(a.value, 450000);
    expect(a.cost, 500000);
    expect(a.gain, -50000);
  });

  test('snapshot بيضيف نقطة لما القيمة تتغيّر بس', () {
    final a = Asset(id: 's', type: 'stock', qty: 2, buy: 10, price: 10);
    a.snapshot();
    final n = a.hist.length;
    a.snapshot();
    expect(a.hist.length, n);
    a.price = 12;
    a.snapshot();
    expect(a.hist.length, n + 1);
    expect(a.hist.last[1], 24);
  });

  test('JSON round trip', () {
    final a = Asset(id: 'j', type: 'stock', name: 'COMI', symbol: 'COMI', qty: 5, buy: 80, price: 90, nw: false);
    a.snapshot();
    final b = Asset.fromJson(a.toJson());
    expect(b.value, a.value);
    expect(b.nw, false);
    expect(b.symbol, 'COMI');
    expect(b.hist.length, a.hist.length);
  });
}
