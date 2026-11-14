import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashu/ui/scroll_visibility.dart';

ScrollMetrics _m(double px) => FixedScrollMetrics(minScrollExtent: 0, maxScrollExtent: 2000, pixels: px, viewportDimension: 600, axisDirection: AxisDirection.down, devicePixelRatio: 1);

Future<BuildContext> _ctx(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  return t.element(find.byType(SizedBox));
}

void main() {
  testWidgets('search bar hides on scroll in both directions and shows at top', (t) async {
    final c = await _ctx(t);
    final sv = ScrollVisibility();
    addTearDown(sv.dispose);
    expect(sv.bar.value, true);

    sv.onNotification(ScrollUpdateNotification(metrics: _m(120), context: c, scrollDelta: 30));
    expect(sv.bar.value, false);

    sv.onNotification(ScrollUpdateNotification(metrics: _m(90), context: c, scrollDelta: -30)); // لفوق برضه يفضل مخفي
    expect(sv.bar.value, false);

    sv.onNotification(ScrollUpdateNotification(metrics: _m(0), context: c, scrollDelta: -90));
    expect(sv.bar.value, true);
  });

  testWidgets('quick tap reveals the bar', (t) async {
    final c = await _ctx(t);
    final sv = ScrollVisibility();
    addTearDown(sv.dispose);
    sv.onNotification(ScrollUpdateNotification(metrics: _m(300), context: c, scrollDelta: 40));
    expect(sv.bar.value, false);
    await t.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: sv.tapToReveal(child: const SizedBox.expand())));
    await t.tapAt(const Offset(100, 100));
    expect(sv.bar.value, true);
  });
}
