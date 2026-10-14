import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'store.dart';
import '../data/models.dart';

final _nf = NumberFormat('#,##0.##');
String money(num v) => '${_nf.format(v)} ج.م';

/// يقبل الأرقام العربية والإنجليزية.
double? parseAmount(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  var t = s.trim().replaceAll('٫', '.').replaceAll(',', '');
  for (var i = 0; i < 10; i++) {
    t = t.replaceAll(ar[i], '$i');
  }
  return double.tryParse(t);
}

String dayLabel(DateTime d) => DateFormat('EEEE d MMMM', 'ar').format(d);
String monthLabel(DateTime d) => DateFormat('MMMM yyyy', 'ar').format(d);

class Summary {
  double income = 0, expense = 0;
  final Map<String, double> byCat = {};
}

Summary summarize(List<Tx> txs, DateTime month) {
  final s = Summary();
  for (final t in txs) {
    if (t.date.year != month.year || t.date.month != month.month) continue;
    if (t.type == TxType.income) {
      s.income += t.amount;
    } else if (t.type == TxType.expense) {
      s.expense += t.amount;
      final k = t.categoryId ?? 'other';
      s.byCat[k] = (s.byCat[k] ?? 0) + t.amount;
    }
  }
  return s;
}

/// اهتزاز خفيف (لو مفعّل من الإعدادات).
void tick() {
  if (cfg.get('vibrate') == true) HapticFeedback.selectionClick();
}
