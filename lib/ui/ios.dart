import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Text;
import 'loc_text.dart';
import '../core/currency.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/i18n.dart';
import '../core/util.dart' show kMonths, toAr, tick;
import 'dart:convert' show base64Decode;
import 'anim.dart';
import 'theme.dart';
import 'widgets.dart' show confirmSheet;

// ---------- تنسيق ----------
String fixed2(double v) {
  final s = v.abs().toStringAsFixed(2);
  final parts = s.split('.');
  final ip = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '${v < 0 ? '-' : ''}$ip.${parts[1]}';
}

/// "1,234.00 ج.م" / "-33,299.87 ج.م" (العملة في آخر السطر)
String egp(double v, {String? cur}) {
  if (S.flag('hide')) return '••••';
  return '${v < 0 ? '-' : ''}${fixed2(v.abs())} ${curOf(cur ?? S.cur).sym}';
}

/// مبلغ بوزنين: الرقم medium (w500) ورمز العملة light (w300). يحافظ على نفس شكل [egp] (وضع الإخفاء والسالب).
class MoneyText extends StatelessWidget {
  final double v;
  final String? cur;
  final TextStyle style;
  const MoneyText(this.v, {super.key, this.cur, required this.style});
  @override
  Widget build(BuildContext context) {
    if (S.flag('hide')) return RichText(text: TextSpan(text: '••••', style: style.copyWith(fontWeight: FontWeight.w500)));
    final base = DefaultTextStyle.of(context).style.merge(style);
    return RichText(
      textScaler: MediaQuery.textScalerOf(context),
      text: TextSpan(style: base, children: [
        TextSpan(text: '${v < 0 ? '-' : ''}${fixed2(v.abs())}', style: const TextStyle(fontWeight: FontWeight.w500)),
        TextSpan(text: ' ${curOf(cur ?? S.cur).sym}', style: const TextStyle(fontWeight: FontWeight.w300)),
      ]),
    );
  }
}

const _mEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _mFull = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
String monthEn(int m) => isAr ? kMonths[m - 1] : _mFull[m - 1];
String enDate(DateTime d) => isAr ? toAr('${d.day} ${kMonths[d.month - 1]} ${d.year}') : '${d.day} ${_mEn[d.month - 1]} ${d.year}';
String enTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final t = '$h:${d.minute.toString().padLeft(2, '0')}';
  return isAr ? '${toAr(t)} ${d.hour >= 12 ? 'م' : 'ص'}' : '$t ${d.hour >= 12 ? 'PM' : 'AM'}';
}

String enDateTime(DateTime d) => '${enDate(d)} ${isAr ? 'الساعة' : 'at'} ${enTime(d)}';

// ---------- مسار الورقة (sheet) ----------
Route<T> sheetRoute<T>(Widget page) => PageRouteBuilder<T>(
      opaque: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => RepaintBoundary(child: page),
      // انزلاق ناعم من تحت + تلاشي خفيف (الصفحة نفسها بتتبني مرة واحدة تحت RepaintBoundary).
      transitionsBuilder: (ctx, a, sa, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(opacity: Tween<double>(begin: .0, end: 1).animate(CurvedAnimation(parent: a, curve: const Interval(0, .6))), child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, .08), end: Offset.zero).animate(c), child: child));
      },
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
            color: dark ? Color.lerp(p.card, p.field, .35)!.withValues(alpha: .68) : p.card.withValues(alpha: .72),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: dark ? p.line.withValues(alpha: .7) : Colors.white.withValues(alpha: .5), width: 1),
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
Widget hair(Pal p, {double indent = 0}) => Container(height: .6, margin: EdgeInsetsDirectional.only(start: indent), color: p.line.withValues(alpha: .7));

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
          if (chevron) Padding(padding: const EdgeInsetsDirectional.only(start: 4), child: Icon(Icons.chevron_right_rounded, color: p.ink2.withValues(alpha: .7), size: 22)),
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

  if (a.icon.startsWith('data:image')) {
    try {
      return ClipRRect(borderRadius: r, child: Image.memory(base64Decode(a.icon.substring(a.icon.indexOf(',') + 1)), width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (c, e, s) => fallback()));
    } catch (_) {
      return fallback();
    }
  }
  if (a.icon.startsWith('http')) {
    return ClipRRect(borderRadius: r, child: Image.network(a.icon, width: size, height: size, fit: BoxFit.cover, errorBuilder: (c, e, s) => fallback()));
  }
  return fallback();
}

final Map<String, (IconData, Color)> _kCatIcons = {
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

(IconData, Color) catIcon(String id) {
  final base = _kCatIcons[id] ?? (Icons.category_rounded, const Color(0xFF8E8E93));
  final st = repo.catStyle(id); // تخصيص المستخدم (أيقونة/لون) يغلب الافتراضي
  return (st.$1 ?? base.$1, st.$2 ?? base.$2);
}

/// أيقونة ولون المعاملة داخل مربع داكن.
(IconData, Color) txIcon(Tx t, {String? viewAcc}) {
  if (t.type == 'adj') return (Icons.flag_rounded, kRed);
  if (t.type == 'xfer') {
    final incoming = viewAcc != null && viewAcc.isNotEmpty && t.to == viewAcc;
    return (Icons.autorenew_rounded, incoming ? kGreen : kRed);
  }
  if (t.type == 'loan') return (Icons.handshake_rounded, kBlue);
  return catIcon(t.cat);
}


// ---------- سحب أفقي يكشف أزرارًا ----------
/// الاتجاه منطقي (يتبع RTL/LTR): [rightActions] = أزرار جهة البداية، تظهر بسحب الصف ناحية النهاية.
/// [leftActions] = أزرار جهة النهاية، تظهر بسحب الصف ناحية البداية.
/// عند السحب لآخر مدى تتباعد الأيقونات (stretch) وتتدور زوايا الصف بدل الحواف الحادة.
class SwipeRow extends StatefulWidget {
  final Widget child;
  final Widget? rightActions; // جهة البداية
  final double rightW;
  final Widget? leftActions; // جهة النهاية
  final double leftW;
  final Color bg;
  const SwipeRow({super.key, required this.child, this.rightActions, this.rightW = 0, this.leftActions, this.leftW = 0, this.bg = Colors.black});
  @override
  State<SwipeRow> createState() => SwipeRowState();
}

class SwipeRowState extends State<SwipeRow> {
  double dx = 0; // منطقي: > 0 = الصف مسحوب ناحية النهاية (يكشف أزرار البداية)
  bool drag = false;
  bool _armed = false;

  void close() => setState(() => dx = 0);

  double get _maxR => widget.rightW;
  double get _maxL => widget.leftW;
  double get _s => Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;

  /// مقاومة مطاطية بعد نهاية الأزرار بدل التوقف الحاد.
  double _resist(double raw) {
    if (raw > _maxR) return _maxR + (raw - _maxR) * .6;
    if (raw < -_maxL) return -_maxL + (raw + _maxL) * .6;
    return raw;
  }

  void _end(DragEndDetails d) {
    final v = (d.primaryVelocity ?? 0) * _s;
    double t = 0;
    if (dx > 0 && _maxR > 0 && (dx > _maxR * .4 || v > 700)) t = _maxR;
    if (dx < 0 && _maxL > 0 && (-dx > _maxL * .4 || v < -700)) t = -_maxL;
    setState(() {
      drag = false;
      _armed = false;
      dx = t;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pr = _maxR > 0 ? (dx / _maxR).clamp(0.0, 1.0) : 0.0;
    final pl = _maxL > 0 ? (-dx / _maxL).clamp(0.0, 1.0) : 0.0;
    Widget reveal(double t, Widget w) => Opacity(opacity: Curves.easeOut.transform(t), child: Transform.scale(scale: .82 + .18 * Curves.easeOutBack.transform(t), child: w));
    final stretchR = dx > _maxR ? dx : _maxR;
    final stretchL = -dx > _maxL ? -dx : _maxL;
    // زوايا مدوّرة طالما الصف مسحوب (بدل الحواف الحادة)
    final rad = (dx.abs() / 24).clamp(0.0, 1.0) * 22;
    return ClipRect(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) => setState(() => drag = true),
        onHorizontalDragUpdate: (d) {
          final step = d.delta.dx * _s;
          final nx = _resist(dx + step * (dx.abs() > (dx > 0 ? _maxR : _maxL) ? .7 : 1));
          final armed = (nx > 0 && _maxR > 0 && nx > _maxR * .4) || (nx < 0 && _maxL > 0 && -nx > _maxL * .4);
          if (armed && !_armed) tick();
          setState(() {
            dx = nx;
            _armed = armed;
          });
        },
        onHorizontalDragEnd: _end,
        child: Stack(children: [
          Positioned.fill(
            child: Container(
              color: widget.bg,
              child: Stack(children: [
                if (widget.rightActions != null) PositionedDirectional(start: 0, top: 0, bottom: 0, width: stretchR, child: Center(child: reveal(pr, widget.rightActions!))),
                if (widget.leftActions != null) PositionedDirectional(end: 0, top: 0, bottom: 0, width: stretchL, child: Center(child: reveal(pl, widget.leftActions!))),
              ]),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: dx),
            duration: Duration(milliseconds: drag ? 0 : 380),
            curve: const Cubic(.2, .9, .25, 1),
            builder: (c, v, ch) => Transform.translate(offset: Offset(v * _s, 0), child: ClipRRect(borderRadius: BorderRadius.circular(v.abs() > 0.5 ? rad : 0), child: ch)),
            child: widget.child,
          ),
        ]),
      ),
    );
  }
}

/// زر بحواف دائرية (كبسولة) بعنوان تحته (Edit / Reorder / Archive / Delete / Income / Expense).
Widget swipeCircle(IconData i, String label, Color c, VoidCallback f, {Color fg = Colors.white}) => Tap(
      onTap: f,
      child: SizedBox(
        width: 72,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 62, height: 36, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(18)), child: Icon(i, color: fg, size: 20)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
        ]),
      ),
    );

/// عنصر في [showPopMenu]: أيقونة + عنوان. [divider] يرسم خطًا فاصلًا قبله.
class PopItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool divider, danger;
  const PopItem(this.icon, this.label, this.onTap, {this.divider = false, this.danger = false});
}

/// قائمة منبثقة زجاجية أعلى اليمين (مثل قائمة (...) في صورة All Transactions).
Future<void> showPopMenu(BuildContext context, List<PopItem> items) {
  final top = MediaQuery.of(context).padding.top + 58;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'menu',
    barrierColor: Colors.black38,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (c, a, b) => const SizedBox.shrink(),
    transitionBuilder: (c, a, b, _) {
      final cv = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: a,
        child: Stack(children: [
          PositionedDirectional(
            top: top,
            end: 16,
            child: ScaleTransition(
              scale: Tween<double>(begin: .88, end: 1).animate(cv),
              // ScaleTransition.alignment نوعه Alignment (مش AlignmentDirectional)؛ نحلّه يدويًا حسب الاتجاه عشان RTL يفضل سليم.
              alignment: Directionality.of(c) == TextDirection.rtl ? Alignment.topLeft : Alignment.topRight,
              child: Material(
                color: Colors.transparent,
                child: Glass(
                  radius: 30,
                  width: 270,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (final it in items) ...[
                      if (it.divider) Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 22, vertical: 6), color: Colors.white.withValues(alpha: .14)),
                      Tap(
                        scale: .98,
                        onTap: () {
                          Navigator.of(c).pop();
                          it.onTap();
                        },
                        child: Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: Row(children: [
                            Icon(it.icon, size: 22, color: it.danger ? kRed : Pal.of(c).ink),
                            const SizedBox(width: 16),
                            Expanded(child: Text(it.label, style: TextStyle(fontSize: 17, color: it.danger ? kRed : Pal.of(c).ink))),
                          ]),
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ]),
      );
    },
  );
}

Future<bool> confirmDialog(BuildContext context, String title, String msg, {String ok = 'Delete', String cancel = 'Cancel', bool danger = true}) => confirmSheet(context, title, msg, ok: ok, cancel: cancel, danger: danger);
