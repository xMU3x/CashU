import 'package:flutter/material.dart' hide Text;
import 'ui/tr.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/repo.dart';
import 'core/settings.dart';
import 'core/store.dart';
import 'core/sync.dart';
import 'core/util.dart';
import 'pages/accounts_home.dart';
import 'pages/extra_tabs.dart';
import 'pages/stats.dart';
import 'ui/anim.dart';
import 'ui/ios.dart';
import 'ui/scale.dart';
import 'ui/theme.dart';
import 'sms/sms_service.dart';

class CashUApp extends StatelessWidget {
  const CashUApp({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (c, _) {
          final dark = S.flag('dark', true);
          final pal = Pal.make(dark, themeById(S.str('theme', 'terra')).color);
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'CashU',
            locale: Locale(L.lang),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
            theme: buildTheme(pal, dark),
            builder: (context, child) => Directionality(
              textDirection: L.rtl ? TextDirection.rtl : TextDirection.ltr,
              child: UiScale(scale: S.num_('uiScale', .88).toDouble(), child: child ?? const SizedBox.shrink()),
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
  int tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    smsService.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      sync.onResume();
      repo.runRecurring();
      smsService.drain();
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
          decoration: BoxDecoration(color: on ? p.ink.withValues(alpha: .09) : Colors.transparent, borderRadius: BorderRadius.circular(26)),
          child: Stack(alignment: Alignment.center, children: [
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(ic, color: c, size: 26),
              const SizedBox(height: 2),
              Text(label, maxLines: 1, style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w500)),
            ]),
            if (badge > 0)
              PositionedDirectional(
                top: 2,
                end: 10,
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
        IndexedStack(index: tab, children: const [AccountsHome(), SubscriptionsTab(), StatsPage()]),
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
                _item(1, Icons.event_repeat_rounded, 'Subscriptions', badge: repo.recurring.length),
                _item(2, Icons.pie_chart_rounded, 'Reports'),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
