import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import 'ui/loc_text.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/repo.dart';
import 'core/settings.dart';
import 'core/store.dart';
import 'core/i18n.dart';
import 'sms/sms_tracker.dart';
import 'core/sync.dart';
import 'core/util.dart';
import 'pages/accounts_home.dart';
import 'pages/extra_tabs.dart';
import 'pages/settings_page.dart';
import 'pages/stats.dart';
import 'ui/anim.dart';
import 'ui/ios.dart';
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
            title: 'CashU',
            locale: Locale(isAr ? 'ar' : 'en'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
            theme: buildTheme(pal, dark),
            builder: (context, child) => Directionality(textDirection: isAr ? TextDirection.rtl : TextDirection.ltr, child: UiScale(child: child ?? const SizedBox.shrink())),
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
  int tab = 0;
  Timer? _smsTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      smsTracker.drainNative();
    }
  }

  void _go(int i) {
    if (i == tab) return;
    tick();
    setState(() => tab = i);
  }

  Widget _item(int i, IconData ic, String label, {int badge = 0}) {
    final on = tab == i;
    final p = Pal.of(context);
    final c = on ? kBlue : p.ink2;
    return Expanded(
      child: Tap(
        scale: .93,
        onTap: () => _go(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          decoration: BoxDecoration(color: on ? p.ink.withValues(alpha: .08) : Colors.transparent, borderRadius: BorderRadius.circular(26)),
          child: Stack(alignment: Alignment.center, children: [
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(ic, color: c, size: 26),
              const SizedBox(height: 2),
              Text(label, maxLines: 1, style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w500)),
            ]),
            if (badge > 0)
              Positioned(
                top: 2,
                right: 10,
                child: Container(constraints: const BoxConstraints(minWidth: 20), height: 20, padding: const EdgeInsets.symmetric(horizontal: 5), alignment: Alignment.center, decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(10)), child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
              ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (w, a) => FadeTransition(opacity: a, child: w),
          child: KeyedSubtree(key: ValueKey(tab), child: const [AccountsHome(), ScheduledTab(), StatsPage()][tab]),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 10 + bottom,
          child: AnimatedBuilder(
            animation: repo,
            builder: (c, _) => Glass(
              radius: 34,
              height: 68,
              child: Row(children: [
                _item(0, Icons.credit_card_rounded, 'Accounts'),
                _item(1, Icons.autorenew_rounded, 'Subscriptions', badge: repo.recurring.length),
                _item(2, Icons.pie_chart_rounded, 'Reports'),
              ]),
            ),
          ),
        ),
      ]),
    );
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
