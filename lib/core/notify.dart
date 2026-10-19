import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'extras.dart';
import 'notify_plan.dart';

const _kChannel = 'cashu_reminders_v1';

/// تذكيرات محلية (بدون إنترنت): تجديد الاشتراكات، الأقساط، الجمعيات. تُعاد جدولتها كلما تغيّرت البيانات أو رجع التطبيق للواجهة.
class Notifier {
  final FlutterLocalNotificationsPlugin _p = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Timer? _debounce;
  String lastError = '';

  /// يُستدعى عند الضغط على إشعار (المسار النصي: sub/<id> · inst · assoc).
  void Function(String route)? onOpen;

  AndroidFlutterLocalNotificationsPlugin? get _android => _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (e) {
      // بديل: أول منطقة بنفس إزاحة الجهاز (بدل UTC فتتأخر الإشعارات ساعات)
      final off = DateTime.now().timeZoneOffset;
      for (final l in tz.timeZoneDatabase.locations.values) {
        if (l.name.contains('/') && tz.TZDateTime.now(l).timeZoneOffset == off) {
          tz.setLocalLocation(l);
          break;
        }
      }
    }
    await _p.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (r) {
        final go = r.payload;
        if (go != null && go.isNotEmpty) onOpen?.call(go);
      },
    );
    await _android?.createNotificationChannel(const AndroidNotificationChannel(_kChannel, 'تذكيرات CashU', description: 'تجديد الاشتراكات والأقساط والجمعيات', importance: Importance.high));
    _ready = true;
    extras.addListener(scheduleSoon);
    final launch = await _p.getNotificationAppLaunchDetails();
    final go = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true && go != null && go.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 700), () => onOpen?.call(go));
    }
    await schedule();
  }

  Future<bool> notificationsAllowed() async => (await _android?.areNotificationsEnabled()) ?? false;
  Future<bool> requestPermission() async => (await _android?.requestNotificationsPermission()) ?? false;

  void scheduleSoon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), schedule);
  }

  /// يلغي القديم ويجدول الدفعة القادمة (idempotent).
  Future<void> schedule() async {
    if (!_ready) return;
    try {
      await _p.cancelAll();
      final plans = planReminders(extras.subs, extras.insts, extras.assocs, DateTime.now());
      for (final x in plans) {
        await _p.zonedSchedule(
          x.id, x.title, x.body, tz.TZDateTime.from(x.at, tz.local),
          const NotificationDetails(android: AndroidNotificationDetails(_kChannel, 'تذكيرات CashU', importance: Importance.high, priority: Priority.high)),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: x.payload,
        );
      }
      lastError = '';
    } catch (e) {
      lastError = '$e';
      debugPrint('notify.schedule: $e');
    }
  }
}

final Notifier notifier = Notifier();
