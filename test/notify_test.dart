import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cashu/core/extras.dart';
import 'package:cashu/core/notify.dart';
import 'package:cashu/core/store.dart';

int ms(DateTime d) => d.millisecondsSinceEpoch;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await store.init();
  });

  final now = DateTime.now();

  test('اشتراك: تذكير قبل التجديد بالأيام المختارة الساعة ٩ صباحًا', () {
    final due = DateTime(now.year, now.month, now.day).add(const Duration(days: 10));
    final s = Sub(id: 's1', name: 'Netflix', amt: 200, first: ms(due), remind: 2);
    final r = buildReminders([s], [], [], now: now);
    expect(r.length, 1);
    expect(r.first.payload, 'sub:s1');
    expect(r.first.when, DateTime(due.year, due.month, due.day - 2, kReminderHour));
  });

  test('اشتراك بدون تذكير (remind = -1) ومتوقف: مفيش إشعار', () {
    final due = ms(now.add(const Duration(days: 10)));
    expect(buildReminders([Sub(id: 'a', name: 'x', amt: 1, first: due, remind: -1)], [], [], now: now), isEmpty);
    expect(buildReminders([Sub(id: 'b', name: 'x', amt: 1, first: due, state: 'paused')], [], [], now: now), isEmpty);
  });

  test('التجربة المجانية: تذكير قبل انتهائها', () {
    final end = DateTime(now.year, now.month, now.day).add(const Duration(days: 6));
    final s = Sub(id: 't1', name: 'Spotify', amt: 100, first: ms(now.subtract(const Duration(days: 20))), trial: true, trialEnd: ms(end), remind: 3);
    final r = buildReminders([s], [], [], now: now);
    expect(r.length, 1);
    expect(r.first.when, DateTime(end.year, end.month, end.day - 3, kReminderHour));
    expect(r.first.title.contains('Spotify'), true);
  });

  test('قسط: تذكير قبل الاستحقاق بيوم، والمسدد بالكامل مفيهوش', () {
    final due = DateTime(now.year, now.month, now.day).add(const Duration(days: 5));
    final i = Inst(id: 'i1', name: 'ثلاجة', total: 3000, count: 3, first: ms(due));
    final r = buildReminders([], [i], [], now: now);
    expect(r.single.payload, 'inst:i1');
    expect(r.single.when, DateTime(due.year, due.month, due.day - 1, kReminderHour));
    i.pays.addAll([1, 2, 3]);
    expect(buildReminders([], [i], [], now: now), isEmpty);
  });

  test('جمعية: تذكير القسط + تذكير القبض، مرتبين بالوقت', () {
    final start = DateTime(now.year, now.month, now.day).add(const Duration(days: 4));
    final a = Assoc(id: 'a1', name: 'جمعية', amt: 500, members: 5, turn: 3, start: ms(start));
    final r = buildReminders([], [], [a], now: now);
    expect(r.length, 2);
    expect(r.every((x) => x.payload == 'assoc:a1'), true);
    expect(r.first.when.isBefore(r.last.when), true);
  });

  test('الموعد فات والاستحقاق اليوم: بيتأجل ليوم الاستحقاق لو لسه جاي، وإلا مفيش', () {
    // قسط مستحق بعد ساعة اليوم ← تذكير يوم الاستحقاق ٩ ص لو لسه جاي، وإلا لا شيء. الحالتان مقبولتان ولا يجب أن يرجع وقت ماضٍ.
    final i = Inst(id: 'i2', name: 'x', total: 100, count: 1, first: ms(now.add(const Duration(hours: 1))));
    for (final r in buildReminders([], [i], [], now: now)) {
      expect(r.when.isAfter(now), true);
    }
  });
}
