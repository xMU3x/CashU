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

  test('exit motion has no dead time (regression: pop felt delayed)', () {
    // نسبة الحركة المنجزة بعد الجزء [tau] من مدة الخروج، بالمنحنى الفعلي اللي Flutter بيطبّقه على القيمة النازلة ١→٠.
    double done(Curve reverse, double tau) => 1 - reverse.transform(1 - tau);
    // القديم (بدون flip): ٨٥٪+ من الحركة خلصت في أول نص المدة ونص المدة التاني الصفحة واقفة.
    const broken = Cubic(.3, 0, .8, .15);
    expect(done(broken, .5), greaterThan(.8));
    expect(done(broken, .8), greaterThan(.95)); // آخر ٢٠٪ من المدة بلا حركة تقريبًا
    // الحالي: الحركة بتبدأ فورًا وبتفضل شغالة لآخر لحظة.
    final fixed = CashUMotion.exitReverse;
    expect(done(fixed, .2), greaterThan(.05));
    expect(done(fixed, .8), lessThan(.8)); // لسه فيه حركة ظاهرة في آخر ٢٠٪
    expect(done(fixed, .8) - done(fixed, .6), greaterThan(.15));
    var prev = 0.0;
    for (var i = 1; i <= 20; i++) {
      final v = done(fixed, i / 20);
      expect(v, greaterThanOrEqualTo(prev)); // رتيب (مفيش رجوع للخلف)
      prev = v;
    }
    expect(done(fixed, 1), closeTo(1, 1e-9));
  });

  test('DirectionalCurve uses the entry curve forward and the exit curve in reverse', () {
    final c = AnimationController(vsync: const TestVSync(), duration: CashUMotion.page, value: .5);
    final d = DirectionalCurve(c);
    c.forward();
    expect(d.value, closeTo(CashUMotion.curve.transform(c.value), 1e-9));
    c.reverse();
    expect(c.status, AnimationStatus.reverse);
    expect(d.value, closeTo(CashUMotion.exitReverse.transform(c.value), 1e-9));
    c.dispose();
  });

  test('nav constants are sane', () {
    expect(CashUMotion.navActiveScale, greaterThan(1.0)); // الأيقونة النشطة بتكبر
    expect(CashUMotion.sharedAxisShift, inInclusiveRange(.05, .2));
  });

  testWidgets('sharedAxisX renders the child and respects reduced motion', (t) async {
    final c = AnimationController(vsync: const TestVSync(), duration: CashUMotion.page, value: .5);
    final s = AnimationController(vsync: const TestVSync(), duration: CashUMotion.page);
    await t.pumpWidget(Directionality(textDirection: TextDirection.rtl, child: Builder(builder: (ctx) => CashUMotion.sharedAxisX(ctx, c, s, const Text('x')))));
    expect(find.byType(SlideTransition), findsWidgets);
    expect(find.byType(FadeTransition), findsNothing); // مفيش شفافية على الصفحة كلها (أداء)
    await t.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Directionality(textDirection: TextDirection.rtl, child: Builder(builder: (ctx) => CashUMotion.sharedAxisX(ctx, c, s, const Text('x')))),
    ));
    expect(find.byType(SlideTransition), findsNothing);
    c.dispose();
    s.dispose();
  });
}
