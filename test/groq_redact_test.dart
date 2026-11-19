import 'package:flutter_test/flutter_test.dart';
import 'package:cashu/sms/groq_ai.dart';

void main() {
  test('redactForAi يخفي الأرقام الطويلة والروابط ويُبقي المبلغ', () {
    final r = redactForAi('تم خصم 1,250.50 جنيه من حساب 1234567890123 لدى Carrefour https://x.co/abc');
    expect(r.contains('1234567890123'), isFalse);
    expect(r.contains('****0123'), isTrue);
    expect(r.contains('1,250.50'), isTrue);
    expect(r.contains('https'), isFalse);
  });
  test('أرقام عربية-هندية تتحوّل', () {
    expect(redactForAi('٠١٢٣٤٥٦٧٨٩٠١'), contains('****'));
  });
}
