import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'currency.dart';
import 'settings.dart';

const kMonths = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
const kWeekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
const _arDigits = '٠١٢٣٤٥٦٧٨٩';

String toAr(String s) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = '0123456789'.indexOf(ch);
    b.write(i >= 0 ? _arDigits[i] : ch);
  }
  return b.toString();
}

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

String dateLabel(DateTime d) => toAr('${d.day} ${kMonths[d.month - 1]} ${d.year}');
String timeLabel(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return toAr('$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'م' : 'ص'}');
}

String dayLabel(DateTime d) => '${kWeekdays[d.weekday - 1]} · ${toAr('${d.day}')} ${kMonths[d.month - 1]}';
int daysIn(int y, int m) => DateTime(y, m + 1, 0).day;
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

final _rnd = math.Random();
String uid() => DateTime.now().microsecondsSinceEpoch.toRadixString(36) + _rnd.nextInt(1296).toRadixString(36).padLeft(2, '0');

void tick() {
  if (S.flag('haptic', true)) HapticFeedback.selectionClick();
}

/// يقصّ النص لأول [n] كلمات (للعرض فقط؛ النص الكامل يفضل محفوظًا في المعاملة). يضيف «…» لو اتقصّ.
String limitWords(String s, [int n = 6]) {
  final w = s.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
  if (w.length <= n) return s.trim();
  return '${w.take(n).join(' ')}…';
}
