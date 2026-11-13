import 'dart:math' as math;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'anim.dart';
import 'loc_text.dart';
import 'motion.dart';
import 'sheets.dart';
import 'theme.dart';
import 'widgets.dart';

/// أيقونات التطبيق البديلة (من ملف cashu_10A_colors.svg).
/// المعرّفات والألوان لازم تتطابق مع tool/gen_variant_icons.py و AndroidManifest (activity-alias) و MainActivity.kt.
class AppIconVariant {
  final String id;
  final String label;
  final Color bg;
  final Color arc;
  final Color dot;
  const AppIconVariant(this.id, this.label, this.bg, this.arc, this.dot);
}

const kAppIcons = <AppIconVariant>[
  AppIconVariant('navy', 'كحلي (الأساسية)', Color(0xFF0F1B3D), Color(0xFFFFFFFF), Color(0xFF2EE6A6)),
  AppIconVariant('black', 'أسود', Color(0xFF0A0A0A), Color(0xFFFFFFFF), Color(0xFF2EE6A6)),
  AppIconVariant('blue', 'أزرق', Color(0xFF2F6BE0), Color(0xFFFFFFFF), Color(0xFF2EE6A6)),
  AppIconVariant('mint', 'نعناعي', Color(0xFF2EE6A6), Color(0xFF0F1B3D), Color(0xFFFFFFFF)),
  AppIconVariant('green', 'أخضر داكن', Color(0xFF0B3D2E), Color(0xFFFFFFFF), Color(0xFF2EE6A6)),
  AppIconVariant('gold', 'كحلي وذهبي', Color(0xFF0F1B3D), Color(0xFFFFFFFF), Color(0xFFFFC83D)),
  AppIconVariant('mintarc', 'كحلي وقوس نعناعي', Color(0xFF0F1B3D), Color(0xFF2EE6A6), Color(0xFFFFFFFF)),
  AppIconVariant('light', 'فاتح', Color(0xFFE8EFFF), Color(0xFF0F1B3D), Color(0xFF2EE6A6)),
  AppIconVariant('royal', 'أزرق ملكي', Color(0xFF1E3A8A), Color(0xFFFFFFFF), Color(0xFF2EE6A6)),
  AppIconVariant('violet', 'بنفسجي', Color(0xFF6C4CF1), Color(0xFFFFFFFF), Color(0xFF2EE6A6)),
];

AppIconVariant appIconById(String id) => kAppIcons.firstWhere((e) => e.id == id, orElse: () => kAppIcons.first);

/// رسم الأيقونة بنفس هندسة الـ SVG (مربع مدوّر ٩٦ + قوس + نقطة) — من غير أي ملفات صور.
class AppIconPainter extends CustomPainter {
  final AppIconVariant v;
  const AppIconPainter(this.v);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 96;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(26 * k)), Paint()..color = v.bg);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(48 * k, 64 * k), radius: 26 * k),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = v.arc
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12 * k
        ..strokeCap = StrokeCap.butt
        ..isAntiAlias = true,
    );
    canvas.drawCircle(Offset(48 * k, 66 * k), 7 * k, Paint()..color = v.dot);
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
            'بعض الشاشات الرئيسية بتأخذ لحظات أو بتعيد ترتيب الأيقونة بعد التغيير.',
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
