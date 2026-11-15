import 'package:flutter/material.dart' hide Text;
import '../core/settings.dart';
import 'anim.dart';
import 'sheets.dart' show showSelect;
import 'theme.dart';

/// خيارات الترتيب الموحّدة لصفحات (اشتراكاتي / مستحقاتي): المفتاح المحفوظ + الاسم.
const kSortOptions = <(String, String)>[
  ('none', 'الافتراضي'),
  ('date_asc', 'التاريخ: الأقرب أولًا'),
  ('date_desc', 'التاريخ: الأبعد أولًا'),
  ('amt_asc', 'المبلغ: الأقل أولًا'),
  ('amt_desc', 'المبلغ: الأعلى أولًا'),
];

/// الترتيب المحفوظ لصفحة [prefKey] (بيفضل زي ما اخترته بعد قفل التطبيق).
String savedSort(String prefKey) {
  final k = S.str(prefKey, 'none');
  return kSortOptions.any((o) => o.$1 == k) ? k : 'none';
}

/// ترتيب قائمة حسب [key] باستخدام دالتي التاريخ والمبلغ. العناصر بلا تاريخ (null) بتتحط في الآخر.
List<T> applySort<T>(List<T> l, String key, {required int? Function(T) date, required double Function(T) amt}) {
  final out = List<T>.of(l);
  if (key == 'none') return out;
  int cmpDate(T a, T b) {
    final x = date(a), y = date(b);
    if (x == null && y == null) return 0;
    if (x == null) return 1;
    if (y == null) return -1;
    return x.compareTo(y);
  }

  switch (key) {
    case 'date_asc':
      out.sort(cmpDate);
    case 'date_desc':
      out.sort((a, b) {
        final x = date(a), y = date(b);
        if (x == null && y == null) return 0;
        if (x == null) return 1;
        if (y == null) return -1;
        return y.compareTo(x);
      });
    case 'amt_asc':
      out.sort((a, b) => amt(a).compareTo(amt(b)));
    case 'amt_desc':
      out.sort((a, b) => amt(b).compareTo(amt(a)));
  }
  return out;
}

/// زر فلتر/ترتيب دائري (بنفس مقاس زر الإضافة): بيفتح قائمة الاختيار ويحفظ الاختيار في الإعدادات.
Widget sortButton(BuildContext context, {required String prefKey, required VoidCallback onChanged, double size = 40, Color? bg, Color? fg}) {
  final on = savedSort(prefKey) != 'none';
  return Tap(
    onTap: () async {
      final r = await showSelect(context, 'ترتيب حسب', kSortOptions, savedSort(prefKey));
      if (r == null) return;
      S.put(prefKey, r);
      onChanged();
    },
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: on ? kBlue.withValues(alpha: .18) : (bg ?? Colors.black.withValues(alpha: .12)), shape: BoxShape.circle),
      child: Icon(Icons.filter_list_rounded, color: on ? kBlue : (fg ?? Colors.grey), size: size * .55),
    ),
  );
}
