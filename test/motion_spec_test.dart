import 'package:cashu/ui/motion_spec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('easing', () {
    test('FastOutSlowIn endpoints and monotonic', () {
      expect(MotionSpec.fastOutSlowIn(0), 0);
      expect(MotionSpec.fastOutSlowIn(1), 1);
      var prev = 0.0;
      for (var i = 1; i <= 100; i++) {
        final y = MotionSpec.fastOutSlowIn(i / 100);
        expect(y >= prev, true);
        prev = y;
      }
    });
    test('FastOutSlowIn matches the known Material curve at 0.5 (~0.80)', () {
      expect(MotionSpec.fastOutSlowIn(.5), closeTo(.80, .03));
    });
  });

  group('stagger (Kosh staggeredEntrance)', () {
    test('35ms per item, capped at item 10', () {
      expect(MotionSpec.staggerDelayMs(0), 0);
      expect(MotionSpec.staggerDelayMs(3), 105);
      expect(MotionSpec.staggerDelayMs(10), 350);
      expect(MotionSpec.staggerDelayMs(500), 350);
      expect(MotionSpec.staggerDelayMs(-4), 0);
    });
  });

  group('covered page opacity', () {
    test('push: 1 -> 0 within 180ms of the 300ms push', () {
      expect(MotionSpec.coveredOpacity(0, pushing: true), 1);
      expect(MotionSpec.coveredOpacity(1, pushing: true), 0);
      expect(MotionSpec.coveredOpacity(180 / 300, pushing: true), closeTo(0, 1e-9));
      expect(MotionSpec.coveredOpacity(.3, pushing: true), lessThan(MotionSpec.coveredOpacity(.1, pushing: true)));
    });
    test('pop: 0 -> 1 within 220ms of the 260ms pop', () {
      expect(MotionSpec.coveredOpacity(1, pushing: false), 0);
      expect(MotionSpec.coveredOpacity(0, pushing: false), 1);
      expect(MotionSpec.coveredOpacity(1 - 220 / 260, pushing: false), closeTo(1, 1e-9));
    });
  });

  group('tab cross-fade', () {
    test('incoming 220ms, outgoing finishes at 180ms', () {
      expect(MotionSpec.tabIn(0), 0);
      expect(MotionSpec.tabIn(1), 1);
      expect(MotionSpec.tabOut(0), 1);
      expect(MotionSpec.tabOut(180 / 220), closeTo(0, 1e-9));
      expect(MotionSpec.tabOut(1), closeTo(0, 1e-9));
    });
  });

  group('progress spring (stiffness 50, ratio 1)', () {
    test('monotonic, no overshoot, ~99% by 1s', () {
      var prev = 0.0;
      for (var i = 0; i <= 300; i++) {
        final x = MotionSpec.springProgress(i / 100);
        expect(x >= prev - 1e-12, true);
        expect(x <= 1.0, true);
        prev = x;
      }
      expect(MotionSpec.springProgress(1.0), greaterThan(.99));
    });
  });

  group('constants match Kosh', () {
    test('values', () {
      expect(MotionSpec.pageEnter, 300);
      expect(MotionSpec.pageExit, 260);
      expect(MotionSpec.fade, 220);
      expect(MotionSpec.enterQuick, 180);
      expect(MotionSpec.press, 120);
      expect(MotionSpec.pressScale, .97);
      expect(MotionSpec.pageSlideFraction, .25);
      expect(MotionSpec.count, 650);
      expect(MotionSpec.chart, 900);
    });
  });
}
