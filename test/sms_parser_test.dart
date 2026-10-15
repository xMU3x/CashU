import 'package:budget/core/sms_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void ok(String sender, String body,
      {String? type, double? amount, String? last4, String? cat, String? cur}) {
    final r = parseSms(sender, body);
    expect(r, isNotNull, reason: body);
    if (type != null) expect(r!.type, type, reason: body);
    if (amount != null) expect(r!.amount, amount, reason: body);
    if (last4 != null) expect(r!.last4, last4, reason: body);
    if (cat != null) expect(r!.categoryId, cat, reason: body);
    if (cur != null) expect(r!.currency, cur, reason: body);
  }

  test('رسائل مصروف', () {
    ok('CIB',
        'CIB: Purchase of EGP 250.00 at CARREFOUR MAADI on card ending 6527. Available balance EGP 3,250.00',
        type: 'expense', amount: 250, last4: '6527', cat: 'shopping');
    ok('CIB',
        'تم خصم مبلغ 150.50 جنيه من حسابكم عن عملية شراء لدى طلبات بالبطاقة المنتهية 6527. الرصيد المتاح 1,200.00 ج.م',
        type: 'expense', amount: 150.5, last4: '6527', cat: 'food');
    ok('QNB', 'تم سحب مبلغ ١٠٠٠ ج.م من ماكينة ATM بطاقة 6527',
        type: 'expense', amount: 1000, last4: '6527');
    ok('CIB', 'Balance EGP 500.00. Purchase EGP 100.00 at UBER',
        type: 'expense', amount: 100, cat: 'transport');
    ok('CIB', 'Purchase USD 12.99 at NETFLIX.COM card ending 6527',
        type: 'expense', amount: 12.99, cur: 'USD', cat: 'fun');
  });

  test('رسائل دخل', () {
    ok('NBE',
        'تم إيداع مبلغ 8,500.00 ج.م في حسابكم رقم ****1234 - مرتب. الرصيد 12,000.00 ج.م',
        type: 'income', amount: 8500, last4: '1234', cat: 'salary');
    ok('VF-Cash', 'تم استلام 300 جنيه من 01012345678 . رصيد محفظتك الحالي 450.75 جنيه',
        type: 'income', amount: 300);
    ok('NBE', 'عزيزي العميل، تم تحويل مبلغ 2,000.00 جنيه الى حسابكم',
        type: 'income', amount: 2000);
  });

  test('تحويل صادر', () {
    ok('VF-Cash', 'تم تحويل 200.00 جنيه الى 01099999999 بنجاح. رصيدك الحالي 250.75 جنيه',
        type: 'expense', amount: 200);
    ok('InstaPay', 'تم تحويل مبلغ 500 جنيه من حسابك الى احمد محمد عبر انستا باي',
        type: 'expense', amount: 500);
  });

  test('لازم تتجاهل', () {
    expect(parseSms('CIB', 'رمز التحقق OTP الخاص بك هو 483921 لعملية شراء بمبلغ 250 جنيه. لا تشاركه'), isNull);
    expect(parseSms('Promo', 'عرض خاص! خصم 50% على جميع المنتجات'), isNull);
    expect(parseSms('Promo', 'عرض خاص! احصل على خصم 50 جنيه على اول طلب'), isNull);
    expect(parseSms('+201012345678', 'حولت لك 200 جنيه'), isNull);
    expect(parseSms('NBE', 'Dear customer your account balance is EGP 5,000'), isNull);
  });

  test('نص حر بالعامية', () {
    ok('me', 'صرفت 200 جنيه على بنزين امبارح',
        type: 'expense', amount: 200, cat: 'transport');
  });
}
