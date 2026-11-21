import 'package:flutter/widgets.dart';
import 'package:lottie/lottie.dart';
import 'motion.dart';

/// رسوم Lottie الأصلية للتطبيق (assets/lottie). كل المدد/المنحنيات من [CashUMotion]؛
/// الـ controller هو اللي بيحدد السرعة، فالمدة اللي جوه ملف JSON مش بتفرق.
enum CashULottieKind {
  success('assets/lottie/success_check.json'),
  empty('assets/lottie/empty_state.json'),
  loading('assets/lottie/loading_dots.json');

  final String asset;
  const CashULottieKind(this.asset);

  /// مدة دورة واحدة من [CashUMotion].
  Duration get duration => switch (this) {
        CashULottieKind.success => CashUMotion.celebrate,
        CashULottieKind.empty => CashUMotion.ambient,
        CashULottieKind.loading => CashUMotion.spinner,
      };

  /// النجاح مرة واحدة، والباقي حلقة.
  bool get loops => this != CashULottieKind.success;
}

class CashULottie extends StatefulWidget {
  final CashULottieKind kind;
  final double size;

  /// يلوّن كل الرسمة (للفاضي واللودينج حسب الثيم). النجاح بيحتفظ بألوانه (الأخضر + الأبيض).
  final Color? color;
  final VoidCallback? onDone;
  const CashULottie(this.kind, {super.key, this.size = 120, this.color, this.onDone});

  @override
  State<CashULottie> createState() => _CashULottieState();
}

class _CashULottieState extends State<CashULottie> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.kind.duration);
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && !widget.kind.loops) widget.onDone?.call();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (CashUMotion.reduced(context)) {
      // تقليل الحركة: إطار ثابت (آخر إطار للنجاح، نص الدورة للباقي) + نبلّغ بالانتهاء عشان الـ overlay يتشال.
      _c.value = widget.kind.loops ? .5 : 1;
      if (!widget.kind.loops) WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone?.call());
    } else if (widget.kind.loops) {
      _c.repeat();
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final col = widget.color;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: Lottie.asset(
          widget.kind.asset,
          controller: _c,
          fit: BoxFit.contain,
          delegates: col == null ? null : LottieDelegates(values: [ValueDelegate.color(const ['**'], value: col)]),
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// شيك نجاح بعد تسجيل معاملة (مرة واحدة).
class LottieSuccess extends CashULottie {
  const LottieSuccess({super.key, super.size = 112, super.onDone}) : super(CashULottieKind.success);
}

/// حالة فاضية للقوائم (حلقة هادية حوالين مكان الأيقونة).
class LottieEmpty extends CashULottie {
  const LottieEmpty({super.key, super.size = 120, super.color}) : super(CashULottieKind.empty);
}

/// لودينج خفيف (٣ نقط).
class LottieLoading extends CashULottie {
  const LottieLoading({super.key, super.size = 56, super.color}) : super(CashULottieKind.loading);
}
