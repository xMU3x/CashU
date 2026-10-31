import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show MethodChannel;
import 'pages/sms_pages.dart' show SmsReviewPage, openReviewItem;
import 'pages/add_tx.dart' show AddTxPage;
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
import 'pages/subs_page.dart';
import 'core/extras.dart';
import 'pages/more_tab.dart';
import 'pages/nav_items.dart';
import 'ui/motion.dart';
import 'ui/widgets.dart' show flowRoute;
import 'ui/anim.dart';
import 'ui/ios.dart' show sheetRoute, closeAllSwipes;
import 'ui/theme.dart';
import 'ui/shell_scope.dart';
import 'core/notify.dart';
import 'core/updater.dart';
import 'package:url_launcher/url_launcher.dart';

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

class CashUApp extends StatelessWidget {
  const CashUApp({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (c, _) {
          final mode = Pal.mode(); // light | dark | modern
          final pal = Pal.forMode(mode);
          final dark = mode != 'light';
          return MaterialApp(
            navigatorKey: navKey,
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
  String curId = 'accounts';
  Timer? _smsTimer;

  /// الشريط السفلي ظاهر؟ (بيختفي بنعومة مع التمرير لتحت ويرجع مع التمرير لفوق)
  final ValueNotifier<bool> _barShown = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ShellNav.bind(_go);
    notifier.onOpen = _openPayload;
    _smsTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (smsTracker.enabled) smsTracker.drainNative();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkRoute();
      _checkUpdate();
      smsTracker.drainNative();
      notifier.init().then((_) => notifier.reschedule());
    });
  }

  @override
  void dispose() {
    _smsTimer?.cancel();
    ShellNav.bind(null);
    notifier.onOpen = null;
    _barShown.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  DateTime? _lastUpdateCheck;
  String _askedVersion = '';

  /// فحص تحديث جديد على GitHub (مرة كل ساعة على الأكثر) وإظهار تنبيه لمن عنده نسخة قديمة.
  Future<void> _checkUpdate() async {
    final now = DateTime.now();
    if (_lastUpdateCheck != null && now.difference(_lastUpdateCheck!) < const Duration(hours: 1)) return;
    _lastUpdateCheck = now;
    final u = await checkForUpdate();
    if (u == null || !mounted || u.version == _askedVersion) return;
    _askedVersion = u.version;
    final ctx = navKey.currentContext;
    if (ctx == null) return;
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('تحديث جديد متاح'),
        content: Text('نسخة ${u.version} نزلت. تحب تنزّلها دلوقتي؟'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('بعدين')),
          TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('نزّل')),
        ],
      ),
    );
    if (ok == true && u.url.isNotEmpty) {
      await launchUrl(Uri.parse(u.url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      _checkUpdate();
      sync.onResume();
      repo.runRecurring();
      extras.runAuto();
      smsTracker.drainNative();
      notifier.reschedule();
      _checkRoute();
    }
  }

  /// لو التطبيق اتفتح من إشعار رسالة: نفتح بانل المعاملة نفسها (مش شاشة مراجعة الرسائل).
  /// route: `tx:<txId>` معاملة اتسجلت · `rv:<reviewId>` معاملة مستخرجة تنتظر الحفظ · `tx` بدون معرّف = تبويب المعاملات.
  Future<void> _checkRoute() async {
    try {
      final r = await const MethodChannel('cashu/sms').invokeMethod<String>('takeRoute');
      if (r == null || !mounted) return;
      final nav = navKey.currentState;
      if (nav == null) return;
      if (r.startsWith('tx:')) {
        final t = repo.tx(r.substring(3));
        if (t != null && !t.del) {
          nav.push(sheetRoute(AddTxPage(edit: t)));
        } else {
          ShellNav.go('tx');
        }
      } else if (r.startsWith('rv:')) {
        final id = r.substring(3);
        final e = smsTracker.review.where((x) => '${x['id']}' == id).toList();
        if (e.isNotEmpty) {
          await openReviewItem(nav.context, e.first);
        } else {
          ShellNav.go('tx'); // اتسجلت/اتشالت بالفعل
        }
      } else if (r == 'tx') {
        ShellNav.go('tx');
      } else if (r == 'review') {
        nav.push(flowRoute(const SmsReviewPage()));
      }
    } catch (_) {}
  }

  void _go(String id) {
    if (navById(id) == null) return;
    // لو في صفحات مفتوحة فوق الـ Shell نقفلها الأول.
    Navigator.of(context).popUntil((r) => r.isFirst);
    if (id == curId) return;
    tick();
    closeAllSwipes(); // أي صف سحب مفتوح يرجع مكانه عند تغيير الصفحة
    _barShown.value = true;
    setState(() => curId = id);
  }

  /// فتح الصفحة المناسبة لما المستخدم يضغط على إشعار (payload: sub:<id> · assoc:<id> · inst:<id>).
  void _openPayload(String payload) {
    final i = payload.indexOf(':');
    final kind = i < 0 ? payload : payload.substring(0, i);
    final id = i < 0 ? '' : payload.substring(i + 1);
    switch (kind) {
      case 'sub':
        _go('subs');
        if (id.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) showSubDetail(context, id);
          });
        }
      case 'assoc':
        _go('assoc');
      case 'inst':
        _go('inst');
      case 'loan':
        _go('loans');
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical || n.depth > 1) return false;
    if (n is ScrollUpdateNotification) {
      final d = n.scrollDelta ?? 0;
      if (n.metrics.pixels <= 8) {
        _barShown.value = true;
      } else if (d > 4) {
        _barShown.value = false;
      } else if (d < -4) {
        _barShown.value = true;
      }
    } else if (n is ScrollEndNotification && n.metrics.pixels <= 8) {
      _barShown.value = true;
    }
    return false;
  }

  /// عنصر الشريط: الأيقونة فقط، والاسم يظهر تحت العنصر المختار فقط.
  Widget _item(NavItem n, String cur) {
    final on = cur == n.id;
    final p = Pal.of(context);
    final c = on ? kBlue : p.ink2;
    return Expanded(
      flex: on ? 2 : 1,
      child: Tap(
        scale: .95,
        onTap: () => _go(n.id),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: c),
              duration: CashUMotion.of(context),
              builder: (_, col, __) => AnimatedScale(scale: on ? .9 : 1, duration: CashUMotion.of(context), curve: CashUMotion.curve, child: Icon(n.icon, color: col, size: 27)),
            ),
            AnimatedSize(
              duration: CashUMotion.of(context),
              curve: CashUMotion.curve,
              child: on ? Padding(padding: const EdgeInsets.only(top: 2), child: Text(n.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w600))) : const SizedBox.shrink(),
            ),
          ]),
        ),
      ),
    );
  }

  static const _tabIds = {'accounts', 'tx', 'subs', 'more'};

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final mq = MediaQuery.of(context);
    final bottom = mq.padding.bottom;
    final inset = 76 + bottom; // ارتفاع الشريط + المسافة تحته
    return AnimatedBuilder(animation: store, builder: (c, _) {
      final items = currentNavItems();
      final ids = [for (final n in kNavItems) n.id];
      // لو الصفحة الحالية مش معروفة (اتشالت) نرجع لأول عنصر في الشريط.
      final cur = ids.contains(curId) ? curId : items.first.id;
      final barIds = [for (final n in items) n.id];
      return Scaffold(
        backgroundColor: p.bg,
        body: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: Stack(children: [
            KeepAliveTabs(
              current: cur,
              ids: barIds,
              build: (id) => EmbeddedScope(
                bottomInset: inset,
                child: _tabIds.contains(id) ? navPage(id) : MediaQuery(data: mq.copyWith(padding: mq.padding.copyWith(bottom: inset)), child: navPage(id)),
              ),
            ),
            // ضبابية فوق منطقة شريط الحالة بدل اللون الأسود
            if (cur != 'accounts') PositionedDirectional(start: 0, end: 0, top: 0, child: BlurEdge(height: mq.padding.top + 4, tint: p.bg)),
            // ضبابية تحت الشريط الثابت
            PositionedDirectional(start: 0, end: 0, bottom: 0, child: ValueListenableBuilder<bool>(valueListenable: _barShown, builder: (c, on, _) => AnimatedOpacity(duration: CashUMotion.of(c), opacity: on ? 1 : 0, child: BlurEdge(height: 46 + bottom, top: false, tint: p.bg)))),
            PositionedDirectional(
              start: 14,
              end: 14,
              bottom: 10 + bottom,
              child: ValueListenableBuilder<bool>(
                valueListenable: _barShown,
                builder: (c, on, child) => IgnorePointer(
                  ignoring: !on,
                  child: AnimatedSlide(
                    duration: CashUMotion.of(c),
                    curve: CashUMotion.curve,
                    offset: on ? Offset.zero : const Offset(0, 1.6),
                    child: AnimatedOpacity(duration: CashUMotion.of(c), opacity: on ? 1 : 0, child: child),
                  ),
                ),
                child: RepaintBoundary(child: ClipRRect(
                  borderRadius: BorderRadius.circular(33),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      height: 66,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(color: p.card.withValues(alpha: .78), borderRadius: BorderRadius.circular(33), border: Border.all(color: p.line.withValues(alpha: .8)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 18, offset: const Offset(0, 6))]),
                      child: LayoutBuilder(builder: (c, box) {
                        // الشادو (الخلفية المختارة) هو الوحيد اللي بيتحرك؛ الصفحات نفسها بتظهر فورًا.
                        final unit = box.maxWidth / (items.length + 1);
                        final idx = items.indexWhere((n) => n.id == cur).clamp(0, items.length - 1);
                        return Stack(fit: StackFit.expand, children: [
                          AnimatedPositionedDirectional(
                            duration: CashUMotion.of(c),
                            curve: CashUMotion.curve,
                            start: idx * unit + 3,
                            width: unit * 2 - 6,
                            top: 6,
                            bottom: 6,
                            child: Container(decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(28))),
                          ),
                          Row(children: [for (final n in items) _item(n, cur)]),
                        ]);
                      }),
                    ),
                  ),
                )),
              ),
            ),
          ]),
        ),
      );
    });
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
