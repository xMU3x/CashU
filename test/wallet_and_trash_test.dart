import 'package:cashu/core/extras.dart';
import 'package:cashu/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Account: حقول المحفظة والبطاقة الائتمانية تتحفظ وتتقرأ', () {
    final a = Account(id: 'a', name: 'فودافون كاش', kind: 'wallet', sms: 'Vodafone Cash\nفودافون كاش', showAvail: true, stmtDay: 25, wkend: 'after');
    final b = Account.fromJson(a.toJson());
    expect(b.sms, 'Vodafone Cash\nفودافون كاش');
    expect(b.showAvail, true);
    expect(b.stmtDay, 25);
    expect(b.wkend, 'after');
  });

  test('Account قديم من غير الحقول الجديدة يترجم لقيم افتراضية', () {
    final b = Account.fromJson({'id': 'x', 'name': 'قديم', 'kind': 'bank'});
    expect(b.sms, '');
    expect(b.showAvail, false);
    expect(b.stmtDay, 31);
    expect(b.wkend, 'none');
  });

  test('Assoc: الأيقونة img تتحفظ', () {
    final a = Assoc(id: 'as1', name: 'جمعية', amt: 100, start: 0, img: 'ic:group');
    expect(Assoc.fromJson(a.toJson()).img, 'ic:group');
    expect(Assoc.fromJson({'id': 'o', 'name': 'قديمة', 'amt': 5, 'start': 0}).img, '');
  });

  test('SubPay: Skipped بتتعرف من علامة الحساب', () {
    expect(SubPay(1, 10, kSkipAcc).skipped, true);
    expect(SubPay(1, 10, 'acc_main').skipped, false);
  });
}
