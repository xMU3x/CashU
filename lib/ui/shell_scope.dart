import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/scheduler.dart' show SchedulerBinding, Priority;
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
    child: Tap(
      scale: .94,
      onTap: onTap,
      child: _fabBox(p.acc),
    ),
  );
}

/// شكل زر (+) العائم الموحّد: مستطيل بحواف دائرية (أعرض قليلًا من الارتفاع) بدل الدائرة.
Widget _fabBox(Color c) => Container(
      width: 60,
      height: 48,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: c.withValues(alpha: .3), blurRadius: 10, offset: const Offset(0, 3))]),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
    );

/// حافة ضبابية (blur) متدرجة فوق/تحت المحتوى المتحرك — تدرّج واحد متصل بدون فواصل.
/// الفكرة: شرائح BackdropFilter متجاورة (غير متراكبة) درجة blur كل واحدة أقل من اللي قبلها بفرق صغير جدًا
/// (≈ ١–٢ sigma) فمبيبانش أي حد، وفوقها لون الخلفية بتدرّج ناعم (smoothstep) يتلاشى لصفر عند آخر الحافة.
/// ملحوظة: BackdropFilter جوه ShaderMask مبيعملش blur، عشان كده التدرج بالشرائح مش بالقناع.
class BlurEdge extends StatelessWidget {
  final double height;
  final bool top;
  final Color tint;
  const BlurEdge({super.key, required this.height, required this.tint, this.top = true});

  /// قوة الـ blur عند كل شريحة (من الحافة ناحية المحتوى).
  static const List<double> _sigmas = [6.0, 4.4, 3.0, 1.9, 1.0, .4];

  /// شفافية اللون عند كل نقطة (smoothstep مقلوب): بتبدأ قوية عند الحافة وتصل لصفر بدون كسر.
  static List<double> _alphas(double a0) => [for (var i = 0; i <= 8; i++) a0 * (1 - _smooth(i / 8))];
  static double _smooth(double t) => t * t * (3 - 2 * t);

  @override
  Widget build(BuildContext context) {
    final from = top ? Alignment.topCenter : Alignment.bottomCenter;
    final to = top ? Alignment.bottomCenter : Alignment.topCenter;
    final n = _sigmas.length;
    final strip = height / n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final al = _alphas(dark ? .62 : .72);
    return RepaintBoundary(
      child: IgnorePointer(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(children: [
            for (var i = 0; i < n; i++)
              Positioned(
                left: 0,
                right: 0,
                top: top ? i * strip : null,
                bottom: top ? null : i * strip,
                height: strip + .6, // تراكب نص بكسل يمنع أي خط شعري بين الشرائح
                child: ClipRect(child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: _sigmas[i], sigmaY: _sigmas[i], tileMode: TileMode.clamp), child: const SizedBox.expand())),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: from, end: to, colors: [for (final a in al) tint.withValues(alpha: a)], stops: [for (var i = 0; i < al.length; i++) i / (al.length - 1)]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// بيعرّف الـ widgets اللي جوه تبويب إن كان التبويب ظاهر دلوقتي ولا لأ (التبويبات المخفية «حيّة» بس ساكنة).
/// [Live] بيستخدمه عشان يوقف إعادة البناء للتبويبات المخفية ويرجع يبني مرة واحدة أول ما التبويب يظهر.
class TabActivity extends InheritedWidget {
  final bool active;
  const TabActivity({super.key, required this.active, required super.child});
  static bool of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<TabActivity>()?.active ?? true;
  @override
  bool updateShouldNotify(TabActivity old) => old.active != active;
}

/// تبويبات تفضل «حيّة»: كل تبويب يتبني مرة واحدة ويفضل محفوظ (التمرير والفلاتر).
///
/// • التبويب الحالي يتبني فورًا؛ الباقي بيتسخّن (يتبني مسبقًا) واحد واحد في الخلفية بعد أول إطار وأثناء سكون الواجهة،
///   فلما المستخدم يضغط عليه يكون جاهز وبيتبدّل فورًا بدون بناء/Layout ثقيل جوه إطار الحركة (ده كان سبب إحساس «الصفحة بتحمّل»).
/// • التبديل نفسه لحظي (بدون تحريك المحتوى): تحريك الصفحة كلها فوق طبقات الضبابية (BackdropFilter) بيعيد حساب الـ blur
///   كل إطار فكان بيتقّل الرسم؛ الحركة بتظهر في الشريط السفلي نفسه (نفس حركة SegToggle).
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
  Timer? _warmTimer;
  bool _warming = false;

  static const _firstWarmDelay = Duration(milliseconds: 900);
  static const _warmGap = Duration(milliseconds: 450);

  Widget _make(String id) => KeyedSubtree(key: ValueKey('tab_$id'), child: widget.build(id));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleWarm(_firstWarmDelay));
  }

  @override
  void didUpdateWidget(KeepAliveTabs old) {
    super.didUpdateWidget(old);
    _built.removeWhere((k, _) => k != widget.current && !widget.ids.contains(k));
    _scheduleWarm(_warmGap);
  }

  @override
  void dispose() {
    _warmTimer?.cancel();
    super.dispose();
  }

  String? _nextToWarm() {
    for (final id in widget.ids) {
      if (!_built.containsKey(id)) return id;
    }
    return null;
  }

  void _scheduleWarm(Duration after) {
    if (!mounted || _warming || _nextToWarm() == null) return;
    _warming = true;
    _warmTimer?.cancel();
    _warmTimer = Timer(after, () {
      // نبني فقط وقت سكون الواجهة (Priority.idle) عشان ما نقاطعش حركة أو تمرير شغال.
      SchedulerBinding.instance.scheduleTask<void>(() {
        _warming = false;
        if (!mounted) return;
        final id = _nextToWarm();
        if (id == null) return;
        setState(() => _built[id] = _make(id));
        _scheduleWarm(_warmGap);
      }, Priority.idle);
    });
  }

  @override
  Widget build(BuildContext context) {
    _built.putIfAbsent(widget.current, () => _make(widget.current));
    return Stack(fit: StackFit.expand, children: [
      for (final e in _built.entries)
        Offstage(
          offstage: e.key != widget.current,
          child: TickerMode(
            enabled: e.key == widget.current,
            child: TabActivity(active: e.key == widget.current, child: RepaintBoundary(child: e.value)),
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
  late final AnimationController _c = AnimationController(vsync: this, duration: CashUMotion.spinner)..repeat();
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
