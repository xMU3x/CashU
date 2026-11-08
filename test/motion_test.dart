import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashu/ui/motion.dart';

void main() {
  test('transitions share the SegToggle contract', () {
    expect(CashUMotion.seg.inMilliseconds, inInclusiveRange(150, 180));
    for (final d in [CashUMotion.tab, CashUMotion.page, CashUMotion.dialog, CashUMotion.sheet, CashUMotion.expand, CashUMotion.reveal]) {
      expect(d, CashUMotion.seg);
    }
    expect(CashUMotion.press.inMilliseconds, inInclusiveRange(80, 120));
    expect(CashUMotion.icon.inMilliseconds, inInclusiveRange(100, 150));
  });

  test('interactive motion stays within the 150-220ms budget', () {
    for (final d in [CashUMotion.counter, CashUMotion.chartBase, CashUMotion.fill, CashUMotion.shake]) {
      expect(d.inMilliseconds, inInclusiveRange(150, 220));
    }
    expect(CashUMotion.page.inMilliseconds, inInclusiveRange(150, 220));
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
