import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'anim.dart';
import 'app_icons_data.dart';
import 'loc_text.dart';
import 'motion.dart';
import 'sheets.dart';
import 'theme.dart';
import 'widgets.dart';

export 'app_icons_data.dart';

/// أيقونات التطبيق البديلة (من tool/source/cashu_10A_colors_ios.svg). القائمة نفسها مولَّدة في app_icons_data.dart.
/// المعرّفات لازم تتطابق مع AndroidManifest (activity-alias) و MainActivity.kt.
AppIconVariant appIconById(String id) => kAppIcons.firstWhere((e) => e.id == id, orElse: () => kAppIcons.first);

/// رسم الأيقونة بنفس هندسة الـ SVG (مربع مدوّر ٩٦ بتدرّج + لمعة/ظل + قوس + خط لمعة + نقطة + بريق) — من غير أي ملفات صور.
class AppIconPainter extends CustomPainter {
  final AppIconVariant v;
  const AppIconPainter(this.v);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 96;
    canvas.save();
    canvas.scale(k);
    final rr = RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 96, 96), const Radius.circular(26));
    // الخلفية المتدرّجة
    canvas.drawRRect(rr, Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(0, 96), [v.bg0, v.bg1]));
    // لمعة علوية وظل سفلي (مقصوصين بالمربع المدوّر)
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 96, 50),
      Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(0, 50), [const Color(0xFFFFFFFF).withValues(alpha: v.gloss), const Color(0x00FFFFFF)]),
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 40, 96, 56),
      Paint()..shader = ui.Gradient.linear(const Offset(0, 40), const Offset(0, 96), [const Color(0x00000000), const Color(0xFF000000).withValues(alpha: v.shade)]),
    );
    canvas.restore();
    // القوس (تدرّج رأسي على ارتفاع القوس نفسه، أطراف دائرية)
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(48, 64), radius: 26),
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(const Offset(0, 38), const Offset(0, 64), [v.arc0, v.arc1]),
    );
    // خط اللمعة الرفيع فوق القوس
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(48, 62), radius: 29.5),
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(
          const Offset(18.5, 0),
          const Offset(77.5, 0),
          [const Color(0x00FFFFFF), const Color(0xFFFFFFFF).withValues(alpha: .7 * v.hi), const Color(0xFFFFFFFF).withValues(alpha: .7 * v.hi), const Color(0x00FFFFFF)],
          const [0, .3, .7, 1],
        ),
    );
    // النقطة (تدرّج شعاعي) + البريق
    canvas.drawCircle(
      const Offset(48, 66),
      7,
      Paint()..shader = ui.Gradient.radial(const Offset(41 + .36 * 14, 59 + .3 * 14), .85 * 14, [v.dot0, v.dot1, v.dot2], const [0, .5, 1]),
    );
    canvas.save();
    canvas.translate(45.6, 63.4);
    canvas.rotate(-25 * math.pi / 180);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 5.2, height: 3.2), Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: .55));
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(AppIconPainter old) => old.v != v;
}

class AppIconView extends StatelessWidget {
  final AppIconVariant v;
  final double size;
  const AppIconView(this.v, {super.key, this.size = 48});
  @override
  Widget build(BuildContext context) => RepaintBoundary(child: CustomPaint(size: Size.square(size), painter: AppIconPainter(v)));
}

/// الجسر مع Android (قناة cashu/icon). الحالة الحقيقية محفوظة في النظام نفسه (الـ activity-alias المفعّل)،
/// فتفضل بعد إغلاق/إعادة فتح التطبيق وإعادة تشغيل الجهاز، ومش بتتزامن بين الأجهزة (كل جهاز له أيقونته).
class AppIconService {
  static const _ch = MethodChannel('cashu/icon');

  /// الأيقونة المفعّلة حاليًا (للعرض في الإعدادات).
  static final ValueNotifier<String> selected = ValueNotifier<String>('navy');

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> refresh() async {
    if (!supported) return;
    try {
      final id = await _ch.invokeMethod<String>('current');
      if (id != null && kAppIcons.any((e) => e.id == id) && selected.value != id) selected.value = id;
    } catch (_) {
      // قناة غير متاحة (مثلاً أثناء الاختبار) — نفضل على القيمة الحالية.
    }
  }

  /// بيرجّع true لو التغيير تم.
  static Future<bool> set(String id) async {
    if (!supported || !kAppIcons.any((e) => e.id == id)) return false;
    try {
      final r = await _ch.invokeMethod<String>('set', {'id': id});
      if (r == id) {
        selected.value = id;
        return true;
      }
    } catch (_) {}
    return false;
  }
}

/// أيقونة صغيرة في صف الإعدادات تعرض الأيقونة الحالية.
class AppIconBadge extends StatefulWidget {
  const AppIconBadge({super.key});
  @override
  State<AppIconBadge> createState() => _AppIconBadgeState();
}

class _AppIconBadgeState extends State<AppIconBadge> {
  @override
  void initState() {
    super.initState();
    AppIconService.refresh();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
        valueListenable: AppIconService.selected,
        builder: (c, id, _) => AppIconView(appIconById(id), size: 34),
      );
}

/// يفتح شاشة اختيار الأيقونة؛ بيرجّع true لو الأيقونة اتغيّرت.
Future<bool> showChangeIconSheet(BuildContext context) async {
  if (!AppIconService.supported) {
    toast(context, 'تغيير الأيقونة متاح على أندرويد فقط');
    return false;
  }
  await AppIconService.refresh();
  if (!context.mounted) return false;
  final r = await showSheet<bool>(context, (c) => const _IconSheet());
  return r ?? false;
}

class _IconSheet extends StatefulWidget {
  const _IconSheet();
  @override
  State<_IconSheet> createState() => _IconSheetState();
}

class _IconSheetState extends State<_IconSheet> {
  late String sel = AppIconService.selected.value;
  bool busy = false;

  Future<void> _confirm() async {
    if (busy) return;
    if (sel == AppIconService.selected.value) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => busy = true);
    final ok = await AppIconService.set(sel);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => busy = false);
      toast(context, 'تعذّر تغيير الأيقونة');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final v = appIconById(sel);
    return SheetFrame(
      title: 'تغيير الأيقونة',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // معاينة كبيرة للاختيار الحالي
          AnimatedSwitcher(
            duration: CashUMotion.of(context, CashUMotion.seg),
            reverseDuration: Duration.zero,
            switchInCurve: CashUMotion.segCurve,
            transitionBuilder: (w, a) => ScaleTransition(scale: Tween<double>(begin: .92, end: 1).animate(a), child: w),
            layoutBuilder: (cur, prev) => cur ?? const SizedBox.shrink(),
            child: AppIconView(v, key: ValueKey(v.id), size: 96),
          ),
          const SizedBox(height: 10),
          Text(v.label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final e in kAppIcons)
                Tap(
                  scale: .94,
                  onTap: busy ? null : () => setState(() => sel = e.id),
                  child: AnimatedContainer(
                    duration: CashUMotion.of(context, CashUMotion.seg),
                    curve: CashUMotion.segCurve,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: sel == e.id ? p.acc : Colors.transparent, width: 2.5),
                    ),
                    child: AppIconView(e, size: 52),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'الأيقونة بتتغير في قائمة التطبيقات فورًا. لو كنت مثبّتها على الشاشة الرئيسية ممكن تحتاج تضيفها من جديد (اضغط مطولًا على الأيقونة الجديدة ← إضافة للشاشة الرئيسية).',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: p.ink2),
          ),
          const SizedBox(height: 14),
          bigButton(p, busy ? '...' : 'تأكيد', kBlue, _confirm),
        ]),
      ),
    );
  }
}
