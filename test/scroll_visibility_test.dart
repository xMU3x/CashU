import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashu/ui/scroll_visibility.dart';

ScrollMetrics _m(double px) => FixedScrollMetrics(minScrollExtent: 0, maxScrollExtent: 2000, pixels: px, viewportDimension: 600, axisDirection: AxisDirection.down, devicePixelRatio: 1);

void main() {
  testWidgets('hides on scroll in both directions, shows at top, returns after idle', (t) async {
    final sv = ScrollVisibility();
    addTearDown(sv.dispose);
    expect(sv.fab.value, true);

    sv.onNotification(ScrollUpdateNotification(metrics: _m(120), context: null, scrollDelta: 30));
    expect(sv.fab.value, false);
    expect(sv.bar.value, false);

    sv.onNotification(ScrollUpdateNotification(metrics: _m(90), context: null, scrollDelta: -30)); // لفوق برضه يفضل مخفي
    expect(sv.bar.value, false);

    await t.pump(const Duration(milliseconds: 399));
    expect(sv.fab.value, false);
    await t.pump(const Duration(milliseconds: 2));
    expect(sv.fab.value, true); // رجع بعد ٤٠٠ms سكون
    expect(sv.bar.value, false); // الشريط يفضل مخفي لحد الوصول لأعلى أو لمسة سريعة

    sv.onNotification(ScrollUpdateNotification(metrics: _m(0), context: null, scrollDelta: -90));
    expect(sv.bar.value, true);
  });

  testWidgets('quick tap reveals both', (t) async {
    final sv = ScrollVisibility();
    addTearDown(sv.dispose);
    sv.onNotification(ScrollUpdateNotification(metrics: _m(300), context: null, scrollDelta: 40));
    await t.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: sv.tapToReveal(child: const SizedBox.expand())));
    await t.tapAt(const Offset(100, 100));
    expect(sv.fab.value, true);
    expect(sv.bar.value, true);
  });
}
