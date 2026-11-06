import 'package:flutter_test/flutter_test.dart';
import 'package:cashu/sms/sms_cat.dart';

void main() {
  test('تصنيف سريع للمصروفات حسب التاجر', () {
    expect(guessSmsCategory(merchant: 'Starbucks', body: '', income: false), 'food');
    expect(guessSmsCategory(merchant: 'UBER *TRIP', body: '', income: false), 'transport');
    expect(guessSmsCategory(merchant: 'Amazon', body: '', income: false), 'shop');
    expect(guessSmsCategory(merchant: 'Netflix', body: '', income: false), 'fun');
    expect(guessSmsCategory(merchant: '', body: 'xyz', income: false), 'other');
  });

  test('تصنيف الدخل', () {
    expect(guessSmsCategory(merchant: '', body: 'تم إيداع راتب', income: true), 'salary');
    expect(guessSmsCategory(merchant: '', body: 'تحويل', income: true), 'other_i');
  });

  test('صلاحية التصنيف حسب النوع', () {
    expect(isValidSmsCategory('food', false), isTrue);
    expect(isValidSmsCategory('food', true), false);
    expect(isValidSmsCategory('salary', true), isTrue);
  });
}
