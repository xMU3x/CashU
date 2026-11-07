import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
import 'loc_text.dart';
import '../core/settings.dart';
import '../core/util.dart';
import 'motion.dart';

/// ضغطة بارتداد + اهتزاز خفيف.
class Tap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap, onLongPress;
  final double scale;
  const Tap({super.key, required this.child, this.onTap, this.onLongPress, this.scale = .94});
  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap == null
            ? null
            : () {
                tick();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress,
        child: AnimatedScale(scale: _down ? widget.scale : 1, duration: _down ? CashUMotion.press : CashUMotion.release, curve: CashUMotion.curve, child: widget.child),
      );
}

/// ظهور متتابع (تلاشي + انزلاق).
class Reveal extends StatefulWidget {
  final int i;
  final Widget child;
  const Reveal({super.key, required this.i, required this.child});
  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> {
  bool on = false;
  @override
  void initState() {
    super.initState();
    // التأخير المتتابع بحد أقصى ٨ عناصر عشان القوائم الطويلة ما تتأخرش.
    Future.delayed(CashUMotion.stagger(widget.i), () {
      if (mounted) setState(() => on = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return widget.child;
    // انزلاق فقط (بدون طبقة شفافية): مفيش saveLayer على كل عنصر.
    return AnimatedSlide(offset: on ? Offset.zero : const Offset(0, .03), duration: CashUMotion.reveal, curve: CashUMotion.curve, child: widget.child);
  }
}

/// عدّاد أرقام متحرّك.
class CountText extends StatelessWidget {
  final double v;
  final TextStyle? style;
  final int dec;
  final String prefix, suffix;
  const CountText(this.v, {super.key, this.style, this.dec = 2, this.prefix = '', this.suffix = ''});
  @override
  Widget build(BuildContext context) {
    if (S.flag('hide')) return Text('••••', style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: v),
      duration: CashUMotion.counter,
      curve: CashUMotion.curve,
      builder: (c, x, _) => Text('$prefix${fmt(x, dec: dec)}$suffix', style: style),
    );
  }
}

/// موجة سائلة + شرارات: ارتفاعها = المتبقي من الميزانية.
class WaveFill extends StatefulWidget {
  final double level, sway;
  final Color color;
  const WaveFill({super.key, required this.level, required this.color, this.sway = 0});
  @override
  State<WaveFill> createState() => _WaveFillState();
}

class _WaveFillState extends State<WaveFill> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: CashUMotion.wave)..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: widget.level.clamp(0.0, 1.0)),
        duration: CashUMotion.fill,
        curve: CashUMotion.curve,
        builder: (ctx, lv, _) => RepaintBoundary(
          child: AnimatedBuilder(
            animation: c,
            builder: (_, __) => CustomPaint(painter: _WavePainter(lv, c.value, widget.color, widget.sway), size: Size.infinite),
          ),
        ),
      );
}

class _WavePainter extends CustomPainter {
  final double level, t, sway;
  final Color color;
  _WavePainter(this.level, this.t, this.color, this.sway);
  static final List<List<double>> _dots = List.generate(22, (i) {
    final r = math.Random(i * 7 + 3);
    return [r.nextDouble(), r.nextDouble(), .4 + r.nextDouble() * 1.6, .3 + r.nextDouble() * .7];
  });
  @override
  void paint(Canvas canvas, Size s) {
    final base = s.height * (1 - level);
    for (var k = 0; k < 2; k++) {
      final path = Path()..moveTo(0, s.height);
      final amp = (7 + 12 * sway.abs().clamp(0.0, 1.0)) * (k == 0 ? 1 : .7);
      for (double x = 0; x <= s.width; x += 6) {
        final y = base + math.sin((x / s.width) * math.pi * (k == 0 ? 2.2 : 3.1) + t * math.pi * 2 * (k == 0 ? 1 : -1) + k) * amp;
        path.lineTo(x, y);
      }
      path.lineTo(s.width, s.height);
      path.close();
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: k == 0 ? .34 : .2));
    }
    final dp = Paint();
    for (final d in _dots) {
      final y = ((d[1] - t * d[3] * .6) % 1.0) * s.height;
      final tw = .35 + .65 * (.5 + .5 * math.sin(t * math.pi * 2 * (1 + d[3]) + d[0] * 6));
      dp.color = Colors.white.withValues(alpha: .35 * tw);
      canvas.drawCircle(Offset(d[0] * s.width, y), d[2], dp);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter o) => o.t != t || o.level != level || o.color != color || o.sway != sway;
}

/// دوران ثلاثي الأبعاد للبطاقات داخل PageView + مرور السحب كموجة.
class CardTilt extends StatelessWidget {
  final PageController pc;
  final int i;
  final Widget Function(double d) builder;
  const CardTilt({super.key, required this.pc, required this.i, required this.builder});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: pc,
        builder: (c, _) {
          var page = 0.0;
          if (pc.hasClients && pc.position.haveDimensions) page = pc.page ?? 0;
          final d = (page - i).clamp(-1.0, 1.0);
          final m = Matrix4.identity()
            ..setEntry(3, 2, .0012)
            ..rotateY(d * .55);
          return Transform(
            alignment: Alignment.center,
            transform: m,
            child: Transform.scale(scale: 1 - d.abs() * .07, child: Opacity(opacity: 1 - d.abs() * .35, child: builder(d))),
          );
        },
      );
}

/// حركة طفو لطيفة (للحالات الفارغة).
class Bob extends StatefulWidget {
  final Widget child;
  const Bob({super.key, required this.child});
  @override
  State<Bob> createState() => _BobState();
}

class _BobState extends State<Bob> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: CashUMotion.ambient)..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, ch) => Transform.translate(offset: Offset(0, -10 * CashUMotion.loop.transform(c.value)), child: ch),
        child: widget.child,
      );
}

/// انفجار عملات عند الحفظ.
void coinBurst(BuildContext context, Offset origin) {
  final o = Overlay.of(context);
  late OverlayEntry e;
  e = OverlayEntry(builder: (_) => _Burst(origin: origin, onDone: () => e.remove()));
  o.insert(e);
}

class _Burst extends StatefulWidget {
  final Offset origin;
  final VoidCallback onDone;
  const _Burst({required this.origin, required this.onDone});
  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: CashUMotion.celebrate)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();
  final r = math.Random();
  late final List<List<double>> coins = List.generate(16, (i) => [-math.pi * (.1 + .8 * r.nextDouble()), 90 + r.nextDouble() * 150, 5 + r.nextDouble() * 5]);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(animation: c, builder: (_, __) => CustomPaint(painter: _BurstPainter(widget.origin, c.value, coins), size: Size.infinite)),
      );
}

class _BurstPainter extends CustomPainter {
  final Offset o;
  final double v;
  final List<List<double>> coins;
  _BurstPainter(this.o, this.v, this.coins);
  @override
  void paint(Canvas canvas, Size s) {
    final e = CashUMotion.curve.transform(v);
    for (final c in coins) {
      final pos = o + Offset(math.cos(c[0]) * c[1] * e, math.sin(c[0]) * c[1] * e + 140 * v * v);
      final a = (1 - v * v).clamp(0.0, 1.0);
      canvas.drawCircle(pos, c[2], Paint()..color = const Color(0xFFFFC94D).withValues(alpha: a));
      canvas.drawCircle(pos, c[2] * .62, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFFB07A12).withValues(alpha: a));
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter o) => true;
}

/// علامة صح متحرّكة (دائرة تنفتح + الصح بيترسم) عند نجاح الحفظ.
void successCheck(BuildContext context) {
  final o = Overlay.of(context);
  late OverlayEntry e;
  e = OverlayEntry(builder: (_) => _CheckPop(onDone: () => e.remove()));
  o.insert(e);
}

class _CheckPop extends StatefulWidget {
  final VoidCallback onDone;
  const _CheckPop({required this.onDone});
  @override
  State<_CheckPop> createState() => _CheckPopState();
}

class _CheckPopState extends State<_CheckPop> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: CashUMotion.celebrate)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Center(
          child: AnimatedBuilder(
            animation: c,
            builder: (_, __) {
              final v = c.value;
              final pop = CashUMotion.pop.transform((v / .35).clamp(0.0, 1.0));
              final draw = CashUMotion.curve.transform(((v - .25) / .35).clamp(0.0, 1.0));
              final fade = v > .75 ? (1 - (v - .75) / .25).clamp(0.0, 1.0) : 1.0;
              return Opacity(opacity: fade, child: Transform.scale(scale: pop, child: CustomPaint(size: const Size(88, 88), painter: _CheckPainter(draw))));
            },
          ),
        ),
      );
}

class _CheckPainter extends CustomPainter {
  final double t;
  _CheckPainter(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawCircle(s.center(Offset.zero), s.width / 2, Paint()..color = const Color(0xFF30D158));
    final path = Path()
      ..moveTo(s.width * .28, s.height * .52)
      ..lineTo(s.width * .44, s.height * .67)
      ..lineTo(s.width * .73, s.height * .36);
    final pen = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * t), pen);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckPainter o) => o.t != t;
}

/// إطار منقّط (خياطة المحفظة).
class DashPainter extends CustomPainter {
  final Color color;
  final double radius;
  DashPainter(this.color, this.radius);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 7), p);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashPainter o) => false;
}
