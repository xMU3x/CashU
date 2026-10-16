import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'currency.dart';
import 'i18n.dart';
import 'settings.dart';

const kMonths = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
const kWeekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
const _arDigits = '٠١٢٣٤٥٦٧٨٩';

/// الأرقام تبقى غربية (0-9) في كل اللغات لتوحيد شكل المبالغ.
String toAr(String s) => s;

String normDigits(String s) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = _arDigits.indexOf(ch);
    b.write(i >= 0 ? '$i' : ch);
  }
  return b.toString();
}

String fmt(double v, {int dec = 2}) {
  final neg = v < 0;
  v = v.abs();
  var s = v.toStringAsFixed(dec);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  final parts = s.split('.');
  final ip = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '${neg ? '-' : ''}$ip${parts.length > 1 ? '.${parts[1]}' : ''}';
}

String money(double v, [String? code]) => '${fmt(v)} ${curOf(code ?? S.cur).sym}';

String dateLabel(DateTime d) => '${d.day} ${monthName(d.month)} ${d.year}';
String timeLabel(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final pm = d.hour >= 12;
  return '$h:${d.minute.toString().padLeft(2, '0')} ${L.ar ? (pm ? 'م' : 'ص') : (pm ? 'PM' : 'AM')}';
}

String dayLabel(DateTime d) => '${weekdayName(d.weekday)} · ${d.day} ${monthName(d.month)}';
int daysIn(int y, int m) => DateTime(y, m + 1, 0).day;
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

final _rnd = math.Random();
String uid() => DateTime.now().microsecondsSinceEpoch.toRadixString(36) + _rnd.nextInt(1296).toRadixString(36).padLeft(2, '0');

void tick() {
  if (S.flag('haptic', true)) HapticFeedback.selectionClick();
}
