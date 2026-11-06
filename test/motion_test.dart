import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashu/ui/motion.dart';

void main() {
  test('durations stay within the documented M3 ranges', () {
    expect(CashUMotion.press.inMilliseconds, inInclusiveRange(80, 120));
    expect(CashUMotion.icon.inMilliseconds, inInclusiveRange(100, 150));
    expect(CashUMotion.small.inMilliseconds, inInclusiveRange(120, 160));
    expect(CashUMotion.tab.inMilliseconds, inInclusiveRange(150, 180));
    expect(CashUMotion.page.inMilliseconds, inInclusiveRange(180, 220));
    expect(CashUMotion.dialog.inMilliseconds, inInclusiveRange(150, 180));
    expect(CashUMotion.sheet.inMilliseconds, inInclusiveRange(180, 220));
    expect(CashUMotion.expand.inMilliseconds, inInclusiveRange(150, 200));
  });

  test('stagger and chart durations are capped', () {
    expect(CashUMotion.stagger(0), Duration.zero);
    expect(CashUMotion.stagger(100), CashUMotion.staggerStep * CashUMotion.staggerMax);
    expect(CashUMotion.chart(1000).inMilliseconds, CashUMotion.chart(8).inMilliseconds);
  });

  testWidgets('reduced motion returns zero duration', (t) async {
    late Duration d;
    await t.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Builder(builder: (c) {
        d = CashUMotion.of(c);
        return const SizedBox();
      }),
    ));
    expect(d, Duration.zero);
  });
}
