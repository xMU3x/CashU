import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/repo.dart';
import 'core/settings.dart';
import 'core/store.dart';
import 'core/sync.dart';
import 'core/util.dart';
import 'pages/add_tx.dart';
import 'pages/home.dart';
import 'pages/shop.dart';
import 'pages/stats.dart';
import 'pages/supervise.dart';
import 'ui/anim.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';

class TayyarApp extends StatelessWidget {
  const TayyarApp({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (c, _) {
          final dark = S.flag('dark');
          final pal = Pal.make(dark, themeById(S.str('theme', 'terra')).color);
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'تيّار',
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
            theme: buildTheme(pal, dark),
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
  final pc = PageController();
  final tab = ValueNotifier<int>(0);
  final fabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    pc.addListener(() {
      final p = pc.page;
      if (p != null && p.round() != tab.value) {
        tab.value = p.round();
        tick();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pc.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      sync.onResume();
      repo.runRecurring();
    }
  }

  void _go(int i) => pc.animateToPage(i, duration: const Duration(milliseconds: 460), curve: Curves.easeOutCubic);

  void _add() {
    final box = fabKey.currentContext?.findRenderObject() as RenderBox?;
    final size = MediaQuery.of(context).size;
    final c = box == null ? Offset(size.width - 50, size.height - 70) : box.localToGlobal(box.size.center(Offset.zero));
    Navigator.of(context).push(circleRoute(const AddTxPage(), c));
  }

  Widget _page(int i, Widget child) => AnimatedBuilder(
        animation: pc,
        builder: (c, ch) {
          var page = 0.0;
          if (pc.hasClients && pc.position.haveDimensions) page = pc.page ?? 0;
          final d = (page - i).clamp(-1.0, 1.0);
          return Opacity(opacity: 1 - d.abs() * .5, child: Transform.translate(offset: Offset(d * -30, 0), child: Transform.scale(scale: 1 - d.abs() * .05, child: ch)));
        },
        child: child,
      );

  Widget _navItem(Pal p, int i, int sel, IconData ic, String label) {
    final on = sel == i;
    return Tap(
      onTap: () => _go(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: on ? 18 : 12, vertical: 12),
        decoration: BoxDecoration(color: on ? Colors.white.withValues(alpha: .08) : Colors.transparent, borderRadius: BorderRadius.circular(26)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ic, color: on ? Colors.white : Colors.white60, size: 26),
          AnimatedSize(
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
            child: on ? Padding(padding: const EdgeInsets.only(right: 8), child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))) : const SizedBox.shrink(),
          ),
        ]),
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
        PageView(controller: pc, physics: const BouncingScrollPhysics(), children: [
          _page(0, const HomePage()),
          _page(1, const StatsPage()),
          _page(2, ShopPage.embedded()),
          _page(3, const SupervisePage()),
        ]),
        Positioned(
          left: 16,
          right: 16,
          bottom: 14 + bottom,
          child: ValueListenableBuilder<int>(
            valueListenable: tab,
            builder: (c, sel, _) => Row(children: [
              Tap(
                onTap: _add,
                child: Container(key: fabKey, width: 68, height: 68, decoration: BoxDecoration(color: p.dark, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 18, offset: const Offset(0, 8))]), child: const Icon(Icons.add_rounded, color: Colors.white, size: 32)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 68,
                  decoration: BoxDecoration(color: p.dark, borderRadius: BorderRadius.circular(34), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 18, offset: const Offset(0, 8))]),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        _navItem(p, 0, sel, Icons.home_outlined, 'الرئيسية'),
                        _navItem(p, 1, sel, Icons.bar_chart_rounded, 'الإحصائيات'),
                        _navItem(p, 2, sel, Icons.shopping_bag_outlined, 'المتجر'),
                        _navItem(p, 3, sel, Icons.verified_user_outlined, 'الرقابة'),
                      ]),
                    ),
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
