import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import 'ui/loc_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/nav.dart';
import 'core/notify.dart';
import 'core/repo.dart';
import 'core/settings.dart';
import 'core/store.dart';
import 'core/i18n.dart';
import 'sms/sms_tracker.dart';
import 'core/sync.dart';
import 'core/util.dart';
import 'pages/acc_tx.dart';
import 'pages/accounts_home.dart';
import 'pages/subs_page.dart';
import 'core/extras.dart';
import 'pages/more_tab.dart';
import 'pages/assoc_inst.dart';
import 'pages/sms_pages.dart' show SmsReviewPage;
import 'ui/anim.dart';
import 'ui/ios.dart';
import 'ui/widgets.dart' show flowRoute;
import 'ui/theme.dart';

class CashUApp extends StatelessWidget {
  const CashUApp({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (c, _) {
          final dark = S.flag('dark', true);
          final pal = Pal.make(dark, kBlue);
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: navKey,
            title: 'CashU',
            locale: Locale(isAr ? 'ar' : 'en'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
            theme: buildTheme(pal, dark),
            // شريطا النظام شفافان (edge-to-edge) وألوان الأيقونات تتبع الثيم الفاتح/الداكن.
            builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarContrastEnforced: false,
                statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
                systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
              ),
              child: Directionality(textDirection: isAr ? TextDirection.rtl : TextDirection.ltr, child: UiScale(child: child ?? const SizedBox.shrink())),
            ),
            home: const Shell(),
          );
        },
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  Timer? _smsTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    notifier.onOpen = openRoute;
    _smsTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (smsTracker.enabled) smsTracker.drainNative();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => smsTracker.drainNative());
  }

  @override
  void dispose() {
    _smsTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      sync.onResume();
      repo.runRecurring();
      extras.runAuto();
      smsTracker.drainNative();
      notifier.scheduleSoon();
    }
  }

  void _go(int i) {
    if (i == tabIndex.value) return;
    tick();
    tabIndex.value = i;
    navKey.currentState?.popUntil((r) => r.isFirst);
  }

  Widget _item(int sel, int i, IconData ic, String label) => Expanded(child: _NavItem(icon: ic, label: label, selected: sel == i, onTap: () => _go(i)));

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(children: [
        const _TabHost(),
        Positioned(
          left: 14,
          right: 14,
          bottom: 10 + bottom,
          child: RepaintBoundary(
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(color: p.card.withValues(alpha: .97), borderRadius: BorderRadius.circular(35), border: Border.all(color: p.line.withValues(alpha: .8)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 18, offset: const Offset(0, 6))]),
              // ترتيب العناصر يتبع اتجاه اللغة تلقائيًا (RTL/LTR) عبر Directionality.
              child: ValueListenableBuilder<int>(
                valueListenable: tabIndex,
                builder: (_, sel, __) => Row(children: [
                  _item(sel, 0, Icons.account_balance_wallet_rounded, 'Accounts'),
                  _item(sel, 1, Icons.format_list_bulleted_rounded, 'Transactions'),
                  _item(sel, 2, Icons.widgets_rounded, 'Subscriptions'),
                  _item(sel, 3, Icons.grid_view_rounded, 'More'),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

Widget _tabPage(int i) => switch (i) {
      0 => const AccountsHome(),
      1 => const AccountTxPage(embedded: true),
      2 => const SubscriptionsPage(embedded: true),
      _ => const MoreTab(),
    };

/// كل تبويب يُبنى مرة واحدة ويبقى حيًّا (IndexedStack): التنقّل فوري وحالة الصفحة (التمرير والفلاتر) محفوظة،
/// مع تلاشي سريع للتبويب الجديد (Material fade-through). التبويبات الأخرى تُدفّأ تدريجيًا بعد الإقلاع.
class _TabHost extends StatefulWidget {
  const _TabHost();
  @override
  State<_TabHost> createState() => _TabHostState();
}

class _TabHostState extends State<_TabHost> with SingleTickerProviderStateMixin {
  final Set<int> _built = {0};
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 200), value: 1);
  late final Animation<double> _fade = CurvedAnimation(parent: _c, curve: const Cubic(.05, .7, .1, 1));
  int _idx = 0;

  @override
  void initState() {
    super.initState();
    _idx = tabIndex.value;
    _built.add(_idx);
    tabIndex.addListener(_onTab);
    for (var i = 1; i < 4; i++) {
      Future.delayed(Duration(milliseconds: 900 + i * 700), () {
        if (mounted && !_built.contains(i)) setState(() => _built.add(i));
      });
    }
  }

  @override
  void dispose() {
    tabIndex.removeListener(_onTab);
    _c.dispose();
    super.dispose();
  }

  void _onTab() {
    final i = tabIndex.value;
    if (i == _idx) return;
    setState(() {
      _idx = i;
      _built.add(i);
    });
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) => IndexedStack(
        index: _idx,
        sizing: StackFit.expand,
        children: [
          for (var i = 0; i < 4; i++)
            if (_built.contains(i))
              RepaintBoundary(child: FadeTransition(opacity: i == _idx ? _fade : const AlwaysStoppedAnimation<double>(1), child: _tabPage(i)))
            else
              const SizedBox.shrink(),
        ],
      );
}

/// عنصر الشريط السفلي: مؤشر M3 يتلوّن ويتوسّع بمنحنى emphasized، وضغطة بتصغّر العنصر قليلًا (press feedback).
class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});
  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? .92 : 1,
        duration: const Duration(milliseconds: 100),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: widget.selected ? 1 : 0),
          duration: const Duration(milliseconds: 260),
          curve: const Cubic(.05, .7, .1, 1),
          builder: (_, t, __) {
            final c = Color.lerp(p.ink, kBlue, t)!;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
              decoration: BoxDecoration(color: Color.lerp(Colors.transparent, p.field, t), borderRadius: BorderRadius.circular(28)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(widget.icon, color: c, size: 27),
                const SizedBox(height: 2),
                Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c, fontSize: 12.5, fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500)),
              ]),
            );
          },
        ),
      ),
    );
  }
}

/// يفتح صفحة حسب مسارها النصي (يُستخدم من الإشعارات): home · tx · subs · more · sub/<id> · assoc · inst · review.
void openRoute(String go) {
  final parts = go.split('/');
  final nav = navKey.currentState;
  if (nav == null) return;
  void tabOnly(int i) {
    nav.popUntil((r) => r.isFirst);
    tabIndex.value = i;
  }

  switch (parts[0]) {
    case 'home':
      tabOnly(0);
    case 'tx':
      tabOnly(1);
    case 'subs':
      tabOnly(2);
    case 'more':
      tabOnly(3);
    case 'sub':
      tabOnly(2);
      final ctx = nav.overlay?.context;
      if (parts.length > 1 && ctx != null) showSubDetail(ctx, parts[1]);
    case 'assoc':
      nav.popUntil((r) => r.isFirst);
      nav.push(flowRoute(const AssocPage()));
    case 'inst':
      nav.popUntil((r) => r.isFirst);
      nav.push(flowRoute(const InstPage()));
    case 'review':
      nav.popUntil((r) => r.isFirst);
      nav.push(flowRoute(const SmsReviewPage()));
  }
}

/// تصغير موحّد لكل الواجهة (خطوط/أزرار/أيقونات/مسافات) بنسبة واحدة ليبقى التناسق.
/// القيمة من الإعدادات (uiScale) وافتراضيها 0.88.
class UiScale extends StatelessWidget {
  final Widget child;
  const UiScale({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final k = S.num_('uiScale', .88).toDouble().clamp(.7, 1.0);
    if (k >= .999) return child;
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(size: mq.size / k, padding: mq.padding / k, viewPadding: mq.viewPadding / k, viewInsets: mq.viewInsets / k),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          minHeight: 0,
          maxWidth: mq.size.width / k,
          maxHeight: mq.size.height / k,
          child: Transform.scale(scale: k, alignment: Alignment.topLeft, child: SizedBox(width: mq.size.width / k, height: mq.size.height / k, child: child)),
        ),
      ),
    );
  }
}
