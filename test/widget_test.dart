import 'package:budget/core/util.dart';
import 'package:budget/data/models.dart';
import 'package:budget/data/providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseAmount يقبل الأرقام العربية', () {
    expect(parseAmount('١٢٣٫٥'), 123.5);
    expect(parseAmount('1,500'), 1500);
    expect(parseAmount('abc'), isNull);
  });

  test('أرصدة الحسابات: مصروف + تحويل + سلفة', () {
    const a = Account(id: 'a', name: 'A', initialBalance: 1000);
    const b = Account(id: 'b', name: 'B');
    final d = DateTime(2026, 10, 1);
    final r = computeBalances([a, b], [
      Tx(id: '1', type: TxType.expense, amount: 100, accountId: 'a', date: d),
      Tx(id: '2', type: TxType.transfer, amount: 300, accountId: 'a', toAccountId: 'b', date: d),
      Tx(id: '3', type: TxType.loan, amount: 50, accountId: 'a', date: d, iOwe: true),
    ]);
    expect(r['a'], 650);
    expect(r['b'], 300);
  });
}
