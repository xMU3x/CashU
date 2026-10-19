import 'store.dart';

/// إعدادات المستخدم (تُزامَن ضمن المفتاح cashu_set).
class S {
  static Map<String, dynamic> get _m => store.peekMap('cashu_set');
  static String get cur => (_m['cur'] as String?) ?? 'EGP';
  static bool flag(String k, [bool d = false]) => _m[k] is bool ? _m[k] as bool : d;
  static String str(String k, String d) => _m[k] is String ? _m[k] as String : d;
  static num num_(String k, [num d = 0]) => _m[k] is num ? _m[k] as num : d;
  static List<String> list(String k) => _m[k] is List ? List<String>.from((_m[k] as List).map((e) => '$e')) : <String>[];
  static void put(String k, dynamic v) {
    final m = store.getMap('cashu_set');
    m[k] = v;
    store.set('cashu_set', m);
  }
}
