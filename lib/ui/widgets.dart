import 'motion.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
import 'loc_text.dart';
import '../core/currency.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'anim.dart';
import 'theme.dart';
import 'ios.dart';
import 'shell_scope.dart';

/// يعيد البناء عند أي تغيير في البيانات.
class Live extends StatelessWidget {
  final Widget Function(BuildContext) b;
  const Live({super.key, required this.b});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: Listenable.merge([repo, store]), builder: (c, _) => b(c));
}

OverlayEntry? _toastEntry;
Timer? _toastTimer;

/// إشعار صغير علوي منتصف الشاشة (شكل Dynamic Island) بتصميم Material: أيقونة + نص، ينزل بحركة ويختفي لوحده.
void toast(BuildContext c, String m, {String? actionLabel, VoidCallback? onAction}) {
  final ov = Overlay.maybeOf(c, rootOverlay: true);
  if (ov == null) return;
  _toastTimer?.cancel();
  _toastEntry?.remove();
  final bad = RegExp(r'(تعذّر|تعذر|مينفعش|لا يمكن|cannot|Cannot|failed|Failed|خطأ)').hasMatch(m);
  final icon = bad ? Icons.error_outline_rounded : Icons.check_circle_rounded;
  late final OverlayEntry entry;
  void close() {
    if (_toastEntry == entry) {
      entry.remove();
      _toastEntry = null;
    }
  }

  final hasAct = actionLabel != null && onAction != null;
  entry = OverlayEntry(
      builder: (ctx) => _IslandToast(
            text: m,
            icon: icon,
            color: bad ? const Color(0xFFFF6B5E) : const Color(0xFF34C759),
            actionLabel: hasAct ? actionLabel : null,
            onAction: hasAct
                ? () {
                    onAction();
                    _toastTimer?.cancel();
                    close();
                  }
                : null,
          ));
  _toastEntry = entry;
  ov.insert(entry);
  _toastTimer = Timer(Duration(milliseconds: hasAct ? 4600 : 2400), close);
}

class _IslandToast extends StatefulWidget {
  final String text;
  final IconData icon;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _IslandToast({required this.text, required this.icon, required this.color, this.actionLabel, this.onAction});
  @override
  State<_IslandToast> createState() => _IslandToastState();
}

class _IslandToastState extends State<_IslandToast> with SingleTickerProviderStateMixin {
  late final AnimationController ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 420), reverseDuration: const Duration(milliseconds: 260))..forward();
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer(Duration(milliseconds: widget.onAction != null ? 4250 : 2050), () {
      if (mounted) ac.reverse();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final curve = CurvedAnimation(parent: ac, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
    return Positioned(
      top: top + 8,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: widget.onAction == null,
        child: Center(
          child: AnimatedBuilder(
            animation: curve,
            builder: (c, child) => Opacity(
              opacity: ac.value.clamp(0.0, 1.0),
              child: Transform.translate(offset: Offset(0, -26 * (1 - curve.value)), child: Transform.scale(scale: .82 + .18 * curve.value, alignment: Alignment.topCenter, child: child)),
            ),
            child: Material(
              color: Pal.of(context).card,
              elevation: 6,
              shadowColor: Colors.black54,
              borderRadius: BorderRadius.circular(26),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: math.min(MediaQuery.of(context).size.width - 48, 340)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 9, 18, 9),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(widget.icon, size: 20, color: widget.color),
                    const SizedBox(width: 10),
                    Flexible(child: Text(widget.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Pal.of(context).ink, fontSize: 14, fontWeight: FontWeight.w600))),
                    if (widget.actionLabel != null) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: widget.onAction,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Text(widget.actionLabel!, style: const TextStyle(color: Color(0xFF0A84FF), fontSize: 14, fontWeight: FontWeight.w700))),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void soon(BuildContext c, String name) => toast(c, '$name — قريباً');

// ---------- مسارات ----------
/// صفحات التنقل العادية: تلاشي + انزلاق خفيف (≈٢٦٠ms) بمنحنى emphasized، ومحترمة لإعداد تقليل الحركة.
Route<T> flowRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: CashUMotion.duration,
      reverseTransitionDuration: CashUMotion.duration,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: expressiveTransition,
    );

class _CircleClipper extends CustomClipper<Path> {
  final Offset c;
  final double r;
  _CircleClipper(this.c, this.r);
  @override
  Path getClip(Size s) => Path()..addOval(Rect.fromCircle(center: c, radius: r));
  @override
  bool shouldReclip(covariant _CircleClipper o) => o.r != r || o.c != c;
}

/// كشف دائري يتّسع من زر +.
Route<T> circleRoute<T>(Widget page, Offset center) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 560),
      reverseTransitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (ctx, a, sa, child) {
        final s = MediaQuery.of(ctx).size;
        final far = math.sqrt(math.pow(math.max(center.dx, s.width - center.dx), 2) + math.pow(math.max(center.dy, s.height - center.dy), 2));
        final r = far * Curves.easeInOutCubic.transform(a.value);
        return ClipPath(clipper: _CircleClipper(center, r), child: child);
      },
    );

// ---------- هياكل ----------
Future<T?> showSheet<T>(BuildContext context, Widget Function(BuildContext) b) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: b,
    );

/// نافذة التأكيد/الحذف: بطاقة مركزية بنفس تصميم التطبيق (أيقونة + عنوان + نص + زرين كبسولة).
Future<bool> confirmSheet(BuildContext context, String title, String msg, {String ok = 'Delete', String cancel = 'Cancel', bool danger = true}) async {
  final r = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'confirm',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (c, _, __) {
      final p = Pal.of(c);
      final col = danger ? kRed : p.acc;
      final w = math.min(MediaQuery.of(c).size.width - 56, 380.0);
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: w,
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(32)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 54, height: 54, decoration: BoxDecoration(color: col.withValues(alpha: .15), borderRadius: BorderRadius.circular(18)), child: Icon(danger ? Icons.delete_outline_rounded : Icons.help_outline_rounded, color: col, size: 27)),
              const SizedBox(height: 14),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(msg, textAlign: TextAlign.center, style: TextStyle(color: p.ink2, fontSize: 15, height: 1.5)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: Tap(onTap: () => Navigator.of(c).pop(true), child: Container(height: 50, alignment: Alignment.center, decoration: BoxDecoration(color: col.withValues(alpha: .9), borderRadius: BorderRadius.circular(25)), child: Text(ok, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))))),
                const SizedBox(width: 10),
                Expanded(child: Tap(onTap: () => Navigator.of(c).pop(false), child: Container(height: 50, alignment: Alignment.center, decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(25)), child: Text(cancel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))))),
              ]),
            ]),
          ),
        ),
      );
    },
    transitionBuilder: (c, a, _, child) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween<double>(begin: .92, end: 1).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child)),
  );
  return r ?? false;
}

class SheetFrame extends StatelessWidget {
  final String? title;
  final Widget child;
  final Color? bg;
  final double? height;
  const SheetFrame({super.key, this.title, required this.child, this.bg, this.height});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final mq = MediaQuery.of(context);
    return Container(
      width: double.infinity, // عرض كامل دايمًا (حتى لو المحتوى فاضي) — يصلّح بانل اليوم الفاضي في التقارير
      height: height,
      constraints: BoxConstraints(maxHeight: mq.size.height * .92),
      decoration: BoxDecoration(color: bg ?? p.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: height == null ? MainAxisSize.min : MainAxisSize.max, children: [
          Container(width: 44, height: 5, margin: const EdgeInsets.only(top: 12, bottom: 14), decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(9))),
          if (title != null) Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(title!, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700))),
          Flexible(child: child),
        ]),
      ),
    );
  }
}

class RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? bg, fg;
  const RoundBtn(this.icon, this.onTap, {super.key, this.size = 44, this.bg, this.fg});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Tap(
      onTap: onTap,
      child: Container(width: size, height: size, decoration: BoxDecoration(color: bg ?? p.field, shape: BoxShape.circle), child: Icon(icon, size: size * .46, color: fg ?? p.ink)),
    );
  }
}

BoxDecoration cardDeco(Pal p, {double r = 24}) => BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(r));

class TopBar extends StatelessWidget {
  final String title;
  final String? sub;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final bool back;
  const TopBar({super.key, required this.title, this.sub, this.icon, this.iconColor, this.trailing, this.back = true});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 18, offset: const Offset(0, 6))]),
      child: Row(children: [
        if (back && EmbeddedScope.maybeOf(context) == null) ...[RoundBtn(Icons.arrow_back_rounded, () => Navigator.of(context).maybePop()), const SizedBox(width: 12)],
        if (icon != null) ...[Icon(icon, color: iconColor ?? p.acc, size: 26), const SizedBox(width: 10)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            if (sub != null) Text(sub!, style: TextStyle(fontSize: 13, color: p.ink2)),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// السحب الأفقي السريع للرجوع.
class SwipeBack extends StatefulWidget {
  final Widget child;
  const SwipeBack({super.key, required this.child});
  @override
  State<SwipeBack> createState() => _SwipeBackState();
}

class _SwipeBackState extends State<SwipeBack> {
  double _startX = -1;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        // الرجوع بالسحب بيشتغل فقط لو السحب بدأ من حافة الشاشة؛ قبل كده أي سحبة سريعة في أي مكان كانت بتخرّجك من الصفحة.
        onHorizontalDragStart: (d) => _startX = d.globalPosition.dx,
        onHorizontalDragCancel: () => _startX = -1,
        onHorizontalDragEnd: (d) {
          final x = _startX;
          _startX = -1;
          if (EmbeddedScope.maybeOf(context) != null) return; // تبويب جوه الـ Shell: مفيش رجوع
          final w = MediaQueryData.fromView(View.of(context)).size.width; // العرض الحقيقي (قبل UiScale)
          final edge = x >= 0 && (x < 28 || x > w - 28);
          if (edge && (d.primaryVelocity ?? 0).abs() > 900) Navigator.of(context).maybePop();
        },
        child: widget.child,
      );
}

class PageShell extends StatelessWidget {
  final String title;
  final String? sub;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final Widget child;
  final bool swipeBack;
  const PageShell({super.key, required this.title, this.sub, this.icon, this.iconColor, this.trailing, required this.child, this.swipeBack = true});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final body = SafeArea(
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 10), child: TopBar(title: title, sub: sub, icon: icon, iconColor: iconColor, trailing: trailing)),
        Expanded(child: child),
      ]),
    );
    return Scaffold(backgroundColor: p.bg, body: swipeBack ? SwipeBack(child: body) : body);
  }
}

Widget sectionLabel(Pal p, String t) => Padding(padding: const EdgeInsets.fromLTRB(6, 14, 6, 8), child: Text(t, style: TextStyle(fontSize: 15, color: p.ink2, fontWeight: FontWeight.w500)));

/// دائرة بأيقونة مسطّحة (flat) — بديل الإيموجي.
Widget iconBubble(Pal p, IconData i, {double size = 48, Color? color, Color? bg}) =>
    Container(width: size, height: size, alignment: Alignment.center, decoration: BoxDecoration(color: bg ?? (color ?? p.ink2).withValues(alpha: .15), shape: BoxShape.circle), child: Icon(i, size: size * .5, color: color ?? p.ink2));

// ---------- عنصر معاملة ----------
class TxTile extends StatelessWidget {
  final Tx t;
  final bool showAcc;
  const TxTile(this.t, {super.key, this.showAcc = false});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final sym = curOf(t.cur).sym;
    Color col = p.ink;
    String sign = '';
    if (t.type == 'inc') {
      col = kInc;
      sign = '+';
    } else if (t.type == 'exp') {
      sign = '-';
    } else if (t.type == 'xfer') {
      col = kXfer;
    } else if (t.type == 'loan') {
      col = t.sign > 0 ? kInc : p.acc;
      sign = t.sign > 0 ? '+' : '-';
    }
    var sub = dayLabel(t.date);
    if (showAcc) sub += ' · ${repo.account(t.acc)?.name ?? ''}';
    if (t.type == 'xfer') { sub += ' · ${repo.account(t.acc)?.name ?? ''} ← ${repo.account(t.to)?.name ?? ''}'; }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        iconBubble(p, txIcon(t).$1, size: 46, color: txIcon(t).$2),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(txTitle(t), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: p.ink2)),
          ]),
        ),
        Text(S.flag('hide') ? '••••' : '$sign${fmt(t.amt)} $sym', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: col)),
      ]),
    );
  }
}

/// معاملة قابلة للسحب: يسارًا تعديل / يمينًا حذف مع تراجع.
class SwipeTx extends StatelessWidget {
  final Tx t;
  final bool showAcc;
  final void Function(Tx)? onEdit;
  const SwipeTx(this.t, {super.key, this.showAcc = false, this.onEdit});
  Widget _bg(Color c, IconData i, AlignmentGeometry a) => Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: a,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(22)),
        child: Icon(i, color: Colors.white),
      );
  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(t.id),
      background: _bg(kXfer, Icons.edit_rounded, AlignmentDirectional.centerStart),
      secondaryBackground: _bg(const Color(0xFFC0392B), Icons.delete_rounded, AlignmentDirectional.centerEnd),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          if (t.type == 'exp' || t.type == 'inc') {
            onEdit?.call(t);
          } else {
            toast(context, 'هذا النوع يُحذف فقط');
          }
          return false;
        }
        return true;
      },
      onDismissed: (_) {
        repo.delTx(t.id);
        toast(context, 'تم الحذف', actionLabel: 'تراجع', onAction: () => repo.restoreTx(t.id));
      },
      child: TxTile(t, showAcc: showAcc),
    );
  }
}

Widget emptyState(Pal p, IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(children: [
        Bob(child: Icon(icon, size: 54, color: p.ink2)),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center, style: TextStyle(color: p.ink2, fontSize: 15, height: 1.6)),
      ]),
    );

/// شريحة اختيار (مصفوفة صغيرة).
Widget pill(Pal p, String label, bool on, VoidCallback f, {Color? color}) => Tap(
      onTap: f,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(color: on ? (color ?? p.ink) : p.field, borderRadius: BorderRadius.circular(22)),
        child: Text(label, style: TextStyle(color: on ? Colors.white : p.ink, fontWeight: FontWeight.w600)),
      ),
    );

// ---------- خيارات الحذف / الإنهاء الموحّدة (أقساط · اشتراكات · جمعيات · ديون) ----------
enum RemoveChoice { everything, serviceOnly, finish }

/// بانل موحّد: حذف كل شيء (الخدمة + معاملاتها)، أو حذف الخدمة فقط مع بقاء معاملاتها، أو (اختياري) إنهاءها وإخفاءها مع بقاء المعاملات.
Future<RemoveChoice?> askRemove(BuildContext context, String name, {bool canFinish = true}) {
  final p = Pal.of(context);
  Widget opt(BuildContext c, IconData ic, Color col, String t, String sub, RemoveChoice v) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: p.field,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.of(c).pop(v),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(width: 42, height: 42, decoration: BoxDecoration(color: col.withValues(alpha: .15), shape: BoxShape.circle), child: Icon(ic, color: col, size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(sub, style: TextStyle(fontSize: 12.5, color: p.ink2, height: 1.35)),
                ])),
              ]),
            ),
          ),
        ),
      );
  return showModalBottomSheet<RemoveChoice>(
    context: context,
    backgroundColor: p.card,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('«$name»', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          opt(c, Icons.delete_forever_rounded, kRed, 'حذف بالكامل', 'يتحذف من الخدمة ومن الحسابات والمعاملات كمان', RemoveChoice.everything),
          opt(c, Icons.link_off_rounded, kOrange, 'حذف الخدمة فقط', 'تتحذف الخدمة نفسها وتفضل معاملاتها محفوظة', RemoveChoice.serviceOnly),
          if (canFinish) opt(c, Icons.check_circle_outline_rounded, kGreen, 'خلصت (إنهاء وإخفاء)', 'تختفي من الصفحة وتفضل معاملاتها مسجّلة', RemoveChoice.finish),
          TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('إلغاء')),
        ]),
      ),
    ),
  );
}
