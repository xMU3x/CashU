import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'extras.dart';
import 'models.dart' show Loan;
import 'repo.dart' show repo;
import 'store.dart';
import 'i18n.dart';
import 'settings.dart';
import 'util.dart';

/// تذكيرات الاستحقاق (اشتراكات · تجربة مجانية · أقساط · جمعيات) كإشعارات محلية مجدولة.
/// بتشتغل بدون إنترنت (AlarmManager)، وبتتعاد جدولتها كل ما التطبيق يفتح أو البيانات تتغيّر أو الجهاز يعيد التشغيل.
/// الضغط على الإشعار بيفتح الصفحة المناسبة عن طريق payload: sub:<id> · assoc:<id> · inst:<id>.
class Reminder {
  final DateTime when;
  final String title, body, payload;
  const Reminder(this.when, this.title, this.body, this.payload);
}

/// وقت التذكير داخل اليوم (٩ صباحًا بالتوقيت المحلي).
const int kReminderHour = 9;

DateTime _at(DateTime d) => DateTime(d.year, d.month, d.day, kReminderHour);

String _t(String ar, String en) => isAr ? ar : en;

String _when(int days) {
  if (days <= 0) return _t('النهارده', 'today');
  if (days == 1) return _t('بكرة', 'tomorrow');
  return _t('بعد $days أيام', 'in $days days');
}

/// يحسب كل التذكيرات القادمة (دالة نقية لسهولة الاختبار). [now] للاختبار.
List<Reminder> buildReminders(List<Sub> subs, List<Inst> insts, List<Assoc> assocs, {DateTime? now, List<Loan> loans = const []}) {
  final n = now ?? DateTime.now();
  final out = <Reminder>[];
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// تذكير قبل الاستحقاق بـ [before] يوم؛ لو الميعاد فات والاستحقاق لسه جاي نذكّر يوم الاستحقاق نفسه.
  void add(DateTime due, int before, String title, String Function(int daysLeft) body, String payload) {
    var at = _at(due.subtract(Duration(days: before)));
    if (!at.isAfter(n)) at = _at(due);
    if (!at.isAfter(n)) return;
    final left = day(due).difference(day(at)).inDays;
    out.add(Reminder(at, title, body(left), payload));
  }

  // اشتراك متأخر: إشعار تاني يوم الساعة ٩ (أو النهارده لو لسه قبل ٩)، يتكرر مع كل فتح للتطبيق
  for (final s in subs) {
    if (s.overdue) {
      var at = _at(n);
      if (!at.isAfter(n)) at = _at(n.add(const Duration(days: 1)));
      out.add(Reminder(at, _t('اشتراك متأخر: ${s.name}', 'Overdue subscription: ${s.name}'), _t('متأخر ${s.overdueDays} يوم بمبلغ ${fmt(s.amt)}. سجّل الدفعة.', 'Overdue by ${s.overdueDays} days: ${fmt(s.amt)}. Record the payment.'), 'sub:${s.id}'));
    }
  }
  // ديون وسلف ليها تاريخ سداد
  for (final l in loans) {
    if (l.settled || l.del || l.due <= 0 || l.rem.isEmpty) continue;
    final who = l.dir == 'owe' ? _t('عليك', 'you owe') : _t('لك', 'owed to you');
    for (final b in l.rem) {
      add(DateTime.fromMillisecondsSinceEpoch(l.due), b, _t('سداد: ${l.person}', 'Repayment: ${l.person}'), (d) => _t('$who ${fmt(l.left)} — مستحق ${_when(d)}.', '${fmt(l.left)} ($who) due ${_when(d)}.'), 'loan:${l.id}');
    }
  }
  for (final s in subs) {
    if (!s.isActive || s.remind < 0 || s.overdue) continue;
    final due = s.nextDue;
    if (due == null) continue;
    if (s.inTrial) {
      add(due, s.remind, _t('انتهاء التجربة المجانية: ${s.name}', 'Free trial ending: ${s.name}'),
          (d) => _t('التجربة هتنتهي ${_when(d)}. لو مش عايز تدفع الغي الاشتراك قبلها.', 'Your trial ends ${_when(d)}. Cancel before then to avoid being charged.'), 'sub:${s.id}');
    } else {
      add(due, s.remind, _t('تجديد اشتراك: ${s.name}', 'Subscription renewal: ${s.name}'),
          (d) => _t('هيتجدد ${_when(d)} بمبلغ ${fmt(s.amt)}.', 'Renews ${_when(d)} for ${fmt(s.amt)}.'), 'sub:${s.id}');
    }
  }
  for (final i in insts) {
    if (i.done) continue;
    final due = i.nextDue;
    if (due == null) continue;
    add(due, 1, _t('قسط: ${i.name}', 'Installment: ${i.name}'), (d) => _t('القسط (${i.pays.length + 1}/${i.count}) مستحق ${_when(d)} بمبلغ ${fmt(i.each)}.', 'Installment ${i.pays.length + 1}/${i.count} is due ${_when(d)}: ${fmt(i.each)}.'), 'inst:${i.id}');
  }
  for (final a in assocs) {
    if (a.pays.length < a.members) {
      final due = addMonths(a.startDate, a.pays.length);
      add(due, 1, _t('قسط الجمعية: ${a.name}', 'Association payment: ${a.name}'), (d) => _t('قسط الجمعية مستحق ${_when(d)} بمبلغ ${fmt(a.amt)}.', 'Your association payment is due ${_when(d)}: ${fmt(a.amt)}.'), 'assoc:${a.id}');
    }
    if (!a.received) {
      add(a.payoutDate, 1, _t('دورك في الجمعية: ${a.name}', 'Your payout turn: ${a.name}'), (d) => _t('معاد قبض الجمعية ${_when(d)}.', 'Association payout is ${_when(d)}.'), 'assoc:${a.id}');
    }
  }
  out.sort((x, y) => x.when.compareTo(y.when));
  // أندرويد بيحدّ عدد الإنذارات المجدولة، فنكتفي بأقرب ٦٠ تذكير.
  return out.length > 60 ? out.sublist(0, 60) : out;
}

class Notifier {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _asked = false;
  Timer? _debounce;

  /// بيتضبط من الـ Shell: يفتح الصفحة المناسبة لما المستخدم يضغط على إشعار.
  void Function(String payload)? onOpen;

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        onDidReceiveNotificationResponse: (r) {
          final p = r.payload;
          if (p != null && p.isNotEmpty) onOpen?.call(p);
        },
      );
      _ready = true;
      // التطبيق اتفتح من إشعار وهو مقفول.
      final d = await _plugin.getNotificationAppLaunchDetails();
      final p = d?.notificationResponse?.payload;
      if (d != null && d.didNotificationLaunchApp && p != null && p.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 400), () => onOpen?.call(p));
      }
      // أي تغيير في الاشتراكات/الأقساط/الجمعيات يعيد الجدولة (بتأخير بسيط لتجميع التغييرات).
      extras.addListener(_later);
      store.changes.listen((k) {
        if (k == 'tyr_set') _later();
      });
    } catch (e) {
      debugPrint('notify init: $e');
    }
  }

  void _later() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), reschedule);
  }

  bool get enabled => S.flag('dueNotif', true);

  Future<void> reschedule() async {
    if (!_ready) return;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      // نلغي المجدول بس (من غير ما نمس إشعارات تانية ظاهرة).
      for (final r in await _plugin.pendingNotificationRequests()) {
        await _plugin.cancel(r.id);
      }
      if (!enabled) return;
      final list = buildReminders(extras.subs, extras.insts, extras.assocs, loans: repo.loanList);
      if (list.isEmpty) return;
      if (!_asked) {
        _asked = true;
        await android?.requestNotificationsPermission();
      }
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'due_reminders',
          _t('تذكيرات الاستحقاق', 'Due reminders'),
          channelDescription: _t('تذكير بتجديد الاشتراكات والتجارب المجانية والأقساط والجمعيات', 'Reminders for renewals, free trials, installments and associations'),
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      var id = 1000;
      for (final r in list) {
        await _plugin.zonedSchedule(
          id++,
          r.title,
          r.body,
          tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, r.when.millisecondsSinceEpoch),
          details,
          // inexact: بدون إذن SCHEDULE_EXACT_ALARM؛ التأخير المحتمل دقايق بس.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: r.payload,
        );
      }
    } catch (e) {
      debugPrint('notify reschedule: $e');
    }
  }
}

final Notifier notifier = Notifier();
