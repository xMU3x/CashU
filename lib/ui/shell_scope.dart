import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Text;
import 'anim.dart';
import 'theme.dart';
import 'motion.dart';

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
Widget addFab(BuildContext context, VoidCallback onTap, {bool consumed = false}) {
  final p = Pal.of(context);
  final sc = EmbeddedScope.maybeOf(context);
  final safe = MediaQuery.of(context).padding.bottom;
  return PositionedDirectional(
    end: 20,
    // consumed = الصفحة جوه PageShell/SafeArea فالمسافة السفلية اتخصمت بالفعل (متتحسبش مرتين).
    bottom: consumed ? 20 : (sc != null ? sc.bottomInset + 16 : 24 + safe),
    child: FloatingActionButton(
      heroTag: null,
      backgroundColor: p.acc,
      foregroundColor: Colors.white,
      onPressed: onTap,
      child: const Icon(Icons.add_rounded),
    ),
  );
}

/// زر (+) عائم بنفس شكل زر الصفحة الرئيسية (دايرة زرقاء ٤٤ مع ظل خفيف) — لازم يتحط كابن مباشر لـ Stack.
Widget homeFab(BuildContext context, VoidCallback onTap) => PositionedDirectional(
      end: 28,
      bottom: (EmbeddedScope.maybeOf(context)?.bottomInset ?? (96 + MediaQuery.of(context).padding.bottom)) + 16,
      child: Tap(
        scale: .92,
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: kBlue, shape: BoxShape.circle, boxShadow: [BoxShadow(color: kBlue.withValues(alpha: .3), blurRadius: 10, offset: const Offset(0, 3))]),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
        ),
      ),
    );

/// حافة ضبابية (blur) متدرجة فوق/تحت المحتوى المتحرك.
/// ملحوظة: BackdropFilter جوه ShaderMask مبيعملش blur (الخلفية بتبقى فاضية)، فالتدرج بيتعمل بطبقات
/// blur متتالية بأطوال مختلفة — الأقوى ناحية الحافة والأخف ناحية المحتوى — من غير ShaderMask.
class BlurEdge extends StatelessWidget {
  final double height;
  final bool top;
  final Color tint;
  const BlurEdge({super.key, required this.height, required this.tint, this.top = true});
  @override
  Widget build(BuildContext context) {
    final from = top ? Alignment.topCenter : Alignment.bottomCenter;
    final to = top ? Alignment.bottomCenter : Alignment.topCenter;
    // ملحوظة: BackdropFilter جوه ShaderMask مبيعملش blur، فالتدرج بيتعمل بطبقات blur كتير ورفيعة الفرق بينها
    // (٩ طبقات بدل ٥) عشان الانتقال يبان قطعة واحدة من غير خطوط، واللون بيتلاشى فوقها بتدرج ناعم.
    const steps = [(1.0, 3.0), (.5, 9.0)]; // طبقتين بس: أخف بكتير على الـ GPU أثناء التمرير
    Widget layer(double frac, double sigma) => Align(
          alignment: from,
          child: SizedBox(
            height: height * frac,
            width: double.infinity,
            child: ClipRect(child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp), child: const SizedBox.expand())),
          ),
        );
    return RepaintBoundary(
      child: IgnorePointer(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(children: [
            for (final s in steps) layer(s.$1, s.$2),
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: from, end: to, colors: [tint.withValues(alpha: .72), tint.withValues(alpha: .38), tint.withValues(alpha: .12), tint.withValues(alpha: 0)], stops: const [0, .4, .75, 1])))),
          ]),
        ),
      ),
    );
  }
}

/// تبويبات تفضل «حيّة»: كل تبويب يتبني مرة واحدة ويفضل محفوظ (التمرير والفلاتر)، والتنقل فوري بدون تلاشي.
class KeepAliveTabs extends StatefulWidget {
  final String current;
  final List<String> ids;
  final Widget Function(String id) build;
  const KeepAliveTabs({super.key, required this.current, required this.ids, required this.build});
  @override
  State<KeepAliveTabs> createState() => _KeepAliveTabsState();
}

class _KeepAliveTabsState extends State<KeepAliveTabs> {
  final Map<String, Widget> _built = {};

  @override
  void didUpdateWidget(KeepAliveTabs old) {
    super.didUpdateWidget(old);
    _built.removeWhere((k, _) => k != widget.current && !widget.ids.contains(k));
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
            child: _TabFade(active: e.key == widget.current, child: e.value),
          ),
        ),
    ]);
  }
}

/// تلاشي عند تفعيل التبويب (CashUMotion: ٣٢٠ms) عند تفعيل التبويب؛ الحالة والتمرير محفوظين لأن التبويب نفسه KeepAlive.
class _TabFade extends StatefulWidget {
  final bool active;
  final Widget child;
  const _TabFade({required this.active, required this.child});
  @override
  State<_TabFade> createState() => _TabFadeState();
}

class _TabFadeState extends State<_TabFade> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: CashUMotion.duration, value: 1);

  @override
  void didUpdateWidget(_TabFade old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      if (CashUMotion.reduced(context)) {
        _c.value = 1; // تقليل الحركة: بدون تلاشي
      } else {
        _c.forward(from: 0); // نفس الحركة لكل التبويبات (بما فيها الحسابات)
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: _c, curve: CashUMotion.curve);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, .02), end: Offset.zero).animate(a), child: widget.child),
    );
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
