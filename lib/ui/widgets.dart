import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
import '../core/i18n.dart';
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

void toast(BuildContext c, String m) {
  final s = ScaffoldMessenger.of(c);
  s.hideCurrentSnackBar();
  s.showSnackBar(SnackBar(content: Text(m, textAlign: TextAlign.center), duration: const Duration(seconds: 2)));
}

void soon(BuildContext c, String name) => toast(c, '$name — قريباً');

// ---------- مسارات ----------
Route<T> flowRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => page,
      // Material 3 shared-axis (X): انزلاق قصير + تلاشي. الاتجاه يتبع RTL/LTR.
      transitionsBuilder: (ctx, a, sa, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutQuart, reverseCurve: Curves.easeInCubic);
        final dx = isAr ? -.08 : .08;
        return FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: a, curve: const Interval(0, .65, curve: Curves.easeOut))),
          child: SlideTransition(position: Tween<Offset>(begin: Offset(dx, 0), end: Offset.zero).animate(c), child: child),
        );
      },
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
class SwipeBack extends StatelessWidget {
  final Widget child;
  const SwipeBack({super.key, required this.child});
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (d) {
          if (EmbeddedScope.maybeOf(context) != null) return; // تبويب جوه الـ Shell: مفيش رجوع
          if ((d.primaryVelocity ?? 0).abs() > 900) { Navigator.of(context).maybePop(); }
        },
        child: child,
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
    final msg = ScaffoldMessenger.of(context);
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
        msg.hideCurrentSnackBar();
        msg.showSnackBar(SnackBar(content: const Text('تم الحذف'), action: SnackBarAction(label: 'تراجع', onPressed: () => repo.restoreTx(t.id))));
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
