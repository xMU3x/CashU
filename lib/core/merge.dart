import 'dart:convert';

int _u(dynamic r) => r is Map && r['u'] is num ? (r['u'] as num).toInt() : 0;

/// دمج سجلات (id → سجل): اتحاد الاثنين، وعند التعارض الأحدث (u) يكسب.
/// الحذف بيتخزّن كسجل d=true عشان يتزامن بين الأجهزة.
Map<String, dynamic> mergeRecords(dynamic a, dynamic b) {
  final out = <String, dynamic>{};
  if (a is Map) a.forEach((k, v) => out[k as String] = v);
  if (b is Map) {
    b.forEach((k, v) {
      final cur = out[k as String];
      if (cur == null || _u(v) > _u(cur)) out[k] = v;
    });
  }
  return out;
}

/// دمج عام للإعدادات: الخرائط تتدمج، والقيمة المحلية بتفضل لو الاتنين موجودين.
dynamic mergeValues(dynamic a, dynamic b) {
  if (a is Map && b is Map) {
    final o = Map<String, dynamic>.from(a);
    b.forEach((k, v) {
      o[k as String] = o.containsKey(k) ? mergeValues(o[k], v) : v;
    });
    return o;
  }
  if (a is List && b is List) {
    final seen = <String>{};
    return [
      for (final x in [...a, ...b])
        if (seen.add(jsonEncode(x))) x
    ];
  }
  return a ?? b;
}
