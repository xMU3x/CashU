import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/settings.dart';
import 'anim.dart';
import 'theme.dart';

// ---------- تنسيق ----------
String fixed2(double v) {
  final s = v.abs().toStringAsFixed(2);
  final parts = s.split('.');
  final ip = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '${v < 0 ? '-' : ''}$ip.${parts[1]}';
}

/// "EGP 1,234.00" / "-EGP 33,299.87"
String egp(double v, {String? cur}) {
  if (S.flag('hide')) return '••••';
  return '${v < 0 ? '-' : ''}${cur ?? S.cur} ${fixed2(v.abs())}';
}

const _mEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _mFull = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
String monthEn(int m) => _mFull[m - 1];
String enDate(DateTime d) => '${d.day} ${_mEn[d.month - 1]} ${d.year}';
String enTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
}

String enDateTime(DateTime d) => '${enDate(d)} at ${enTime(d)}';

// ---------- مسار الورقة (sheet) ----------
Route<T> sheetRoute<T>(Widget page) => PageRouteBuilder<T>(
      opaque: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (ctx, a, sa, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic)),
        child: child,
      ),
    );

/// هيكل الورقة: حواف علوية دائرية وخلفية داكنة (مثل شاشات الإضافة/التعديل).
class SheetPage extends StatelessWidget {
  final Widget child;
  const SheetPage({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.only(top: top + 8),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        child: Material(color: Pal.of(context).dark == const Color(0xFF000000) ? const Color(0xFF0B0B0C) : Pal.of(context).bg, child: child),
      ),
    );
  }
}

// ---------- زجاج ----------
class Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final double? width, height;
  const Glass({super.key, required this.child, this.radius = 30, this.padding, this.width, this.height});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final dark = p.bg.computeLuminance() < .3;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF2C2C2E).withValues(alpha: .62) : Colors.white.withValues(alpha: .7),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: dark ? .12 : .5), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

class GlassBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? bg, fg;
  const GlassBtn(this.icon, this.onTap, {super.key, this.size = 44, this.bg, this.fg});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Tap(
      onTap: onTap,
      child: bg != null
          ? Container(width: size, height: size, decoration: BoxDecoration(color: bg, shape: BoxShape.circle), child: Icon(icon, color: fg ?? Colors.white, size: size * .5))
          : Glass(radius: size / 2, width: size, height: size, child: Icon(icon, color: fg ?? p.ink, size: size * .5)),
    );
  }
}

// ---------- قائمة أزرار منبثقة (Edit / Delete ...) ----------
Future<void> showPillMenu(BuildContext context, List<(String, VoidCallback)> items, {Set<String> danger = const {}}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'menu',
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (c, a, b) => const SizedBox.shrink(),
    transitionBuilder: (c, a, b, _) {
      final cv = CurvedAnimation(parent: a, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween<double>(begin: .85, end: 1).animate(cv),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Glass(
                radius: 34,
                width: 300,
                padding: const EdgeInsets.all(12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  for (final it in items)
                    Tap(
                      scale: .97,
                      onTap: () {
                        Navigator.of(c).pop();
                        it.$2();
                      },
                      child: Container(
                        height: 48,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .1), borderRadius: BorderRadius.circular(24)),
                        child: Text(it.$1, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: danger.contains(it.$1) ? kRed : Colors.white)),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ),
      );
    },
  );
}

// ---------- بطاقة / فاصل ----------
BoxDecoration iosCard(Pal p, {double r = 22}) => BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(r));
Widget hair(Pal p, {double indent = 0}) => Container(height: .6, margin: EdgeInsets.only(left: indent), color: p.line.withValues(alpha: .7));

/// صف نموذج: أيقونة + عنوان رمادي + قيمة + سهم.
class FormRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final bool chevron;
  final VoidCallback? onTap;
  final Color? valueColor;
  const FormRow({super.key, required this.icon, required this.label, this.value, this.trailing, this.chevron = true, this.onTap, this.valueColor});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Tap(
      onTap: onTap,
      scale: .99,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          Icon(icon, color: p.ink2, size: 22),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 15, color: p.ink2)),
          const Spacer(),
          if (value != null) Flexible(child: Text(value!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15.5, color: valueColor ?? p.ink))),
          if (trailing != null) trailing!,
          if (chevron) Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.chevron_right_rounded, color: p.ink2.withValues(alpha: .7), size: 22)),
        ]),
      ),
    );
  }
}

Widget iosSwitch(bool v, ValueChanged<bool> f) => Switch(value: v, onChanged: f, activeTrackColor: kGreen, activeThumbColor: Colors.white, inactiveTrackColor: const Color(0xFF48484A), inactiveThumbColor: Colors.white, trackOutlineColor: WidgetStateProperty.all(Colors.transparent));

Widget smallChip(String t, bool on, VoidCallback f) => Tap(
      onTap: f,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: on ? kBlue : const Color(0xFF48484A), borderRadius: BorderRadius.circular(18)),
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 15)),
      ),
    );

// ---------- أيقونات ----------
Widget accIcon(Account a, {double size = 40}) {
  final r = BorderRadius.circular(size * .26);
  Widget fallback() {
    final ic = a.kind == 'cash' ? Icons.payments_rounded : a.kind == 'wallet' ? Icons.account_balance_wallet_rounded : a.kind == 'credit' ? Icons.credit_card_rounded : a.kind == 'debit' ? Icons.credit_card_outlined : Icons.account_balance_rounded;
    final col = a.kind == 'cash' ? kGreen : a.kind == 'wallet' ? const Color(0xFFFF453A) : a.kind == 'credit' ? kBlue : a.kind == 'debit' ? const Color(0xFFBF5AF2) : kOrange;
    return Container(width: size, height: size, decoration: BoxDecoration(color: col.withValues(alpha: .18), borderRadius: r), child: Icon(ic, color: col, size: size * .54));
  }

  if (a.icon.startsWith('http')) {
    return ClipRRect(borderRadius: r, child: Image.network(a.icon, width: size, height: size, fit: BoxFit.cover, errorBuilder: (c, e, s) => fallback()));
  }
  return fallback();
}

/// أيقونة ولون المعاملة داخل مربع داكن.
(IconData, Color) txIcon(Tx t, {String? viewAcc}) {
  if (t.type == 'adj') return (Icons.flag_rounded, kRed);
  if (t.type == 'xfer') {
    final incoming = viewAcc != null && viewAcc.isNotEmpty && t.to == viewAcc;
    return (Icons.autorenew_rounded, incoming ? kGreen : kRed);
  }
  if (t.type == 'loan') return (Icons.handshake_rounded, kOrange);
  const m = <String, (IconData, Color)>{
    'bills': (Icons.home_rounded, Color(0xFFB08A5A)),
    'food': (Icons.room_service_rounded, Color(0xFF32ADE6)),
    'transport': (Icons.directions_bus_rounded, Color(0xFFBF5AF2)),
    'shop': (Icons.shopping_bag_rounded, Color(0xFFFF6482)),
    'health': (Icons.medical_services_rounded, Color(0xFF8E9AAF)),
    'fun': (Icons.movie_rounded, Color(0xFFFFD60A)),
    'edu': (Icons.school_rounded, Color(0xFFFF9F0A)),
    'home': (Icons.house_rounded, Color(0xFF64D2FF)),
    'salary': (Icons.work_rounded, kGreen),
    'free': (Icons.laptop_mac_rounded, Color(0xFF30D158)),
    'gift': (Icons.card_giftcard_rounded, Color(0xFFFF375F)),
    'invest': (Icons.trending_up_rounded, Color(0xFF30D158)),
    'other_i': (Icons.attach_money_rounded, kGreen),
  };
  return m[t.cat] ?? (Icons.category_rounded, const Color(0xFF8E8E93));
}

// ---------- سحب أفقي يكشف أزرارًا ----------
class SwipeRow extends StatefulWidget {
  final Widget child;
  final Widget? rightActions; // تظهر عند السحب لليمين (على الشمال)
  final double rightW;
  final Widget? leftActions; // تظهر عند السحب لليسار (على اليمين)
  final double leftW;
  final Color bg;
  const SwipeRow({super.key, required this.child, this.rightActions, this.rightW = 0, this.leftActions, this.leftW = 0, this.bg = Colors.black});
  @override
  State<SwipeRow> createState() => SwipeRowState();
}

class SwipeRowState extends State<SwipeRow> {
  double dx = 0;
  bool drag = false;

  void close() => setState(() => dx = 0);

  void _end(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    double t = 0;
    if (dx > 0 && widget.rightW > 0 && (dx > widget.rightW * .4 || v > 700)) t = widget.rightW;
    if (dx < 0 && widget.leftW > 0 && (-dx > widget.leftW * .4 || v < -700)) t = -widget.leftW;
    setState(() {
      drag = false;
      dx = t;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) => setState(() => drag = true),
        onHorizontalDragUpdate: (d) => setState(() => dx = (dx + d.delta.dx).clamp(-widget.leftW, widget.rightW).toDouble()),
        onHorizontalDragEnd: _end,
        child: Stack(children: [
          Positioned.fill(
            child: Container(
              color: widget.bg,
              child: Stack(children: [
                if (widget.rightActions != null) Positioned(left: 0, top: 0, bottom: 0, width: widget.rightW, child: Center(child: widget.rightActions)),
                if (widget.leftActions != null) Positioned(right: 0, top: 0, bottom: 0, width: widget.leftW, child: Center(child: widget.leftActions)),
              ]),
            ),
          ),
          AnimatedContainer(
            duration: Duration(milliseconds: drag ? 0 : 240),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(dx, 0, 0),
            child: widget.child,
          ),
        ]),
      ),
    );
  }
}

/// زر دائري صغير بعنوان تحته (Edit / Reorder / Archive / Delete).
Widget swipeCircle(IconData i, String label, Color c, VoidCallback f, {Color fg = Colors.white}) => Tap(
      onTap: f,
      child: SizedBox(
        width: 70,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: c, shape: BoxShape.circle), child: Icon(i, color: fg, size: 21)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
        ]),
      ),
    );

Future<bool> confirmDialog(BuildContext context, String title, String msg, {String ok = 'Delete'}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 18)),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(ok, style: const TextStyle(color: kRed))),
        ],
      ),
    ) ??
    false;
