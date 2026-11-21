import 'dart:convert';

dynamic mergeValues(dynamic a, dynamic b) {
  if (a is num && b is num) return a > b ? a : b;
  if (a is List && b is List) {
    final seen = <String>{};
    final out = <dynamic>[];
    for (final x in [...a, ...b]) {
      if (seen.add(jsonEncode(x))) out.add(x);
    }
    return out;
  }
  if (a is Map && b is Map) {
    final o = Map<String, dynamic>.from(a);
    b.forEach((k, v) {
      o[k as String] = o.containsKey(k) ? mergeValues(o[k], v) : v;
    });
    return o;
  }
  return a ?? b;
}

bool _records(Map m) => m.values.every((v) => v is Map && v.containsKey('u'));

/// دمج على مستوى السجل: لكل id يفوز الأحدث (`u`) — يدعم الحذف (del) والتعديل بين جهازين.
dynamic mergeFlow(dynamic a, dynamic b) {
  if (a is Map && b is Map && _records(a) && _records(b)) {
    final o = Map<String, dynamic>.from(a);
    b.forEach((k, v) {
      final id = k as String;
      if (!o.containsKey(id)) {
        o[id] = v;
      } else {
        final ua = ((o[id] as Map)['u'] as num?) ?? 0;
        final ub = ((v as Map)['u'] as num?) ?? 0;
        if (ub > ua) o[id] = v;
      }
    });
    return o;
  }
  return mergeValues(a, b);
}
