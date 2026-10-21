import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Text;
import 'theme.dart';

/// بيتحط حوالين الصفحات اللي بتتعرض جوه الـ Shell (تبويبات الشريط السفلي):
/// الصفحة تعرف إنها مدمجة (من غير زر رجوع) وتعرف ارتفاع الشريط السفلي عشان تبعد عنه.
class EmbeddedScope extends InheritedWidget {
  final double bottomInset;
  const EmbeddedScope({super.key, required this.bottomInset, required super.child});
  static EmbeddedScope? maybeOf(BuildContext c) => c.dependOnInheritedWidgetOfExactType<EmbeddedScope>();
  @override
  bool updateShouldNotify(EmbeddedScope o) => o.bottomInset != bottomInset;
}

/// تنقّل عام جوه الـ Shell: ShellNav.go('tx') يفتح تبويب المعاملات (مع بقاء الشريط السفلي).
class ShellNav {
  static void Function(String id)? _go;
  static void bind(void Function(String id)? f) => _go = f;
  static bool go(String id) {
    final f = _go;
    if (f == null) return false;
    f(id);
    return true;
  }
}

/// زر (+) عائم موحّد لكل الصفحات (نفس زر صفحة السلف/الدين)، مرفوع فوق الشريط السفلي لما الصفحة جوه الـ Shell.
/// لازم يتحط كابن مباشر لـ Stack.
Widget addFab(BuildContext context, VoidCallback onTap) {
  final p = Pal.of(context);
  final sc = EmbeddedScope.maybeOf(context);
  final safe = MediaQuery.of(context).padding.bottom;
  return PositionedDirectional(
    end: 20,
    bottom: sc != null ? sc.bottomInset + 16 : 24 + safe,
    child: FloatingActionButton(
      heroTag: null,
      backgroundColor: p.acc,
      foregroundColor: Colors.white,
      onPressed: onTap,
      child: const Icon(Icons.add_rounded),
    ),
  );
}

/// حافة ضبابية (blur) متدرجة: بتظهر بدل اللون الأسود فوق/تحت المحتوى المتحرك.
/// ٣ طبقات بأطوال مختلفة فالضبابية بتزيد ناحية الحافة بدون تدرج لوني ظاهر.
class BlurEdge extends StatelessWidget {
  final double height;
  final bool top;
  final Color tint;
  const BlurEdge({super.key, required this.height, required this.tint, this.top = true});
  @override
  Widget build(BuildContext context) {
    Widget layer(double f) => PositionedDirectional(
          start: 0,
          end: 0,
          top: top ? 0 : null,
          bottom: top ? null : 0,
          height: height * f,
          child: ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6, tileMode: TileMode.clamp),
              child: ColoredBox(color: tint.withValues(alpha: .10)),
            ),
          ),
        );
    return IgnorePointer(child: SizedBox(height: height, child: Stack(children: [layer(1), layer(.66), layer(.33)])));
  }
}

/// تبويبات تفضل «حيّة»: كل تبويب يتبني مرة واحدة ويفضل محفوظ (التمرير والفلاتر)، والتنقل بتلاشي سريع.
class KeepAliveTabs extends StatefulWidget {
  final String current;
  final List<String> ids;
  final Widget Function(String id) build;
  const KeepAliveTabs({super.key, required this.current, required this.ids, required this.build});
  @override
  State<KeepAliveTabs> createState() => _KeepAliveTabsState();
}

class _KeepAliveTabsState extends State<KeepAliveTabs> with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 200), value: 1);
  late final Animation<double> _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
  final Map<String, Widget> _built = {};

  @override
  void didUpdateWidget(KeepAliveTabs old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current) _ac.forward(from: .0);
    _built.removeWhere((k, _) => k != widget.current && !widget.ids.contains(k));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _built.putIfAbsent(widget.current, () => KeyedSubtree(key: ValueKey('tab_${widget.current}'), child: widget.build(widget.current)));
    return Stack(fit: StackFit.expand, children: [
      for (final e in _built.entries)
        Offstage(
          offstage: e.key != widget.current,
          child: TickerMode(
            enabled: e.key == widget.current,
            child: e.key == widget.current ? FadeTransition(opacity: _fade, child: e.value) : e.value,
          ),
        ),
    ]);
  }
}

/// دايرة نقط بتلف (loader) — بتتبيّن مع السحب للتحديث.
class DotsSpinner extends StatefulWidget {
  final double size;
  final Color color;
  final bool spinning;
  final double progress; // 0..1 أثناء السحب
  const DotsSpinner({super.key, this.size = 30, required this.color, this.spinning = true, this.progress = 1});
  @override
  State<DotsSpinner> createState() => _DotsSpinnerState();
}

class _DotsSpinnerState extends State<DotsSpinner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(size: Size.square(widget.size), painter: _DotsPainter(widget.color, widget.spinning ? _c.value : widget.progress * .5, widget.progress.clamp(0.0, 1.0))),
      );
}

class _DotsPainter extends CustomPainter {
  final Color color;
  final double t, k;
  _DotsPainter(this.color, this.t, this.k);
  @override
  void paint(Canvas canvas, Size s) {
    const n = 8;
    final c = s.center(Offset.zero);
    final r = s.width / 2 - s.width * .09;
    for (var i = 0; i < n; i++) {
      final a = 2 * math.pi * i / n - math.pi / 2;
      final lead = ((t * n) - i) % n;
      final fade = .25 + .75 * (1 - lead / n);
      final paint = Paint()..color = color.withValues(alpha: (fade * k).clamp(0.0, 1.0));
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r, s.width * (.07 + .03 * (1 - lead / n)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter o) => o.t != t || o.k != k || o.color != color;
}
