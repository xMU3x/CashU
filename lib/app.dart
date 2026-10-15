import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/repo.dart';
import 'core/settings.dart';
import 'core/store.dart';
import 'core/sync.dart';
import 'core/util.dart';
import 'pages/accounts_home.dart';
import 'pages/extra_tabs.dart';
import 'pages/settings_page.dart';
import 'pages/stats.dart';
import 'ui/anim.dart';
import 'ui/ios.dart';
import 'ui/theme.dart';

class TayyarApp extends StatelessWidget {
  const TayyarApp({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (c, _) {
          final dark = S.flag('dark', true);
          final pal = Pal.make(dark, themeById(S.str('theme', 'terra')).color);
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'تيّار',
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
            theme: buildTheme(pal, dark),
            builder: (context, child) => Directionality(textDirection: TextDirection.ltr, child: child ?? const SizedBox.shrink()),
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
    }
  }

  void _go(int i) {
    if (i == tab) return;
    tick();
    setState(() => tab = i);
  }

  Widget _item(int i, IconData ic, String label, {int badge = 0}) {
    final on = tab == i;
    final c = on ? kBlue : Colors.white.withValues(alpha: .78);
    return Expanded(
      child: Tap(
        scale: .93,
        onTap: () => _go(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          decoration: BoxDecoration(color: on ? Colors.white.withValues(alpha: .09) : Colors.transparent, borderRadius: BorderRadius.circular(26)),
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
        IndexedStack(index: tab, children: const [AccountsHome(), BudgetsTab(), ScheduledTab(), StatsPage(), SettingsPage()]),
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
                _item(1, Icons.inbox_rounded, 'Budgets'),
                _item(2, Icons.calendar_month_rounded, 'Scheduled', badge: repo.recurring.length),
                _item(3, Icons.pie_chart_rounded, 'Reports'),
                _item(4, Icons.settings_outlined, 'Settings'),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
