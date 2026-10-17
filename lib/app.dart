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
import 'pages/acc_tx.dart';
import 'pages/accounts_home.dart';
import 'pages/add_tx.dart';
import 'pages/extra_tabs.dart';
import 'pages/more_tab.dart';
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

  Widget _item(int i, IconData ic, String label) {
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
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          decoration: BoxDecoration(color: on ? kBlue.withValues(alpha: .14) : Colors.transparent, borderRadius: BorderRadius.circular(26)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(ic, color: c, size: 25),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  void _openAdd() {
    tick();
    Navigator.of(context).push(sheetRoute(const AddTxPage()));
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final bottom = MediaQuery.of(context).padding.bottom;
    // ترتيب العناصر يتبع اتجاه اللغة تلقائيًا (RTL/LTR) عبر Directionality.
    final pages = <Widget>[const AccountsHome(), const AccountTxPage(embedded: true), const BudgetsTab(), const MoreTab()];
    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (w, a) => FadeTransition(opacity: a, child: w),
          child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 10 + bottom,
          child: SizedBox(
            height: 84,
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
              Glass(
                radius: 34,
                height: 68,
                child: Row(children: [
                  _item(0, Icons.account_balance_wallet_rounded, 'Accounts'),
                  _item(1, Icons.format_list_bulleted_rounded, 'Transactions'),
                  const SizedBox(width: 68), // مساحة زر + الأوسط
                  _item(2, Icons.donut_large_rounded, 'Budgets'),
                  _item(3, Icons.grid_view_rounded, 'More'),
                ]),
              ),
              Positioned(
                top: 0,
                child: Tap(
                  scale: .92,
                  onTap: _openAdd,
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(color: kBlue, shape: BoxShape.circle, boxShadow: [BoxShadow(color: kBlue.withValues(alpha: .45), blurRadius: 18, offset: const Offset(0, 6))]),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 34),
                  ),
                ),
              ),
            ]),
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
