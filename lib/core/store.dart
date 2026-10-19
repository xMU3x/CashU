import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

/// تخزين محلي أولًا + طابع زمني لكل مفتاح مزامَن (`__meta`).
class Store extends ChangeNotifier {
  late SharedPreferences _p;
  Map<String, int> meta = {};
  final _ch = StreamController<String>.broadcast();
  Stream<String> get changes => _ch.stream;

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    await _migrateLegacyPrefix();
    meta = readIntMap('__meta');
  }

  /// ترحيل لمرة واحدة: بيانات الإصدارات القديمة كانت بالبادئة `tyr:` ومفاتيحها `tyr_*`؛ تُنقل إلى `cashu:` / `cashu_*` دون فقد.
  Future<void> _migrateLegacyPrefix() async {
    const old = 'tyr:';
    final keys = _p.getKeys().where((k) => k.startsWith(old)).toList();
    for (final k in keys) {
      final nk = '$kStorePrefix${k.substring(old.length).replaceFirst(RegExp(r'^tyr_'), 'cashu_')}';
      final v = _p.get(k);
      if (!_p.containsKey(nk)) {
        if (v is String) {
          var out = v;
          if (k == '${old}__meta') {
            try {
              final m = (jsonDecode(v) as Map).map((a, b) => MapEntry((a as String).replaceFirst(RegExp(r'^tyr_'), 'cashu_'), b));
              out = jsonEncode(m);
            } catch (_) {}
          }
          await _p.setString(nk, out);
        } else if (v is bool) {
          await _p.setBool(nk, v);
        } else if (v is int) {
          await _p.setInt(nk, v);
        } else if (v is double) {
          await _p.setDouble(nk, v);
        } else if (v is List<String>) {
          await _p.setStringList(nk, v);
        }
      }
      await _p.remove(k);
    }
  }

  Map<String, int> readIntMap(String k) {
    final s = _p.getString('$kStorePrefix$k');
    if (s == null) return {};
    try {
      return (jsonDecode(s) as Map).map((a, b) => MapEntry(a as String, (b as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  void writeIntMap(String k, Map<String, int> m) => _p.setString('$kStorePrefix$k', jsonEncode(m));
  bool has(String k) => _p.containsKey('$kStorePrefix$k');

  dynamic get(String k, [dynamic d]) {
    final v = _p.getString('$kStorePrefix$k');
    if (v == null) return d;
    try {
      return jsonDecode(v);
    } catch (_) {
      return d;
    }
  }

  final Map<String, (String, dynamic)> _dc = {};

  /// قراءة سريعة للقراءة فقط (لا تعدّل القيمة المرجعة).
  dynamic peek(String k, [dynamic d]) {
    final raw = _p.getString('$kStorePrefix$k');
    if (raw == null) return d;
    final c = _dc[k];
    if (c != null && c.$1 == raw) return c.$2;
    try {
      final v = jsonDecode(raw);
      _dc[k] = (raw, v);
      return v;
    } catch (_) {
      return d;
    }
  }

  Map<String, dynamic> peekMap(String k) {
    final v = peek(k);
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return const <String, dynamic>{};
  }

  Map<String, dynamic> getMap(String k) {
    final v = get(k);
    return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  }

  void set(String k, dynamic v, {bool quiet = false}) {
    _p.setString('$kStorePrefix$k', jsonEncode(v));
    if (kSyncKeys.contains(k)) {
      meta[k] = DateTime.now().millisecondsSinceEpoch;
      writeIntMap('__meta', meta);
    }
    if (!quiet) _emit(k);
  }

  /// تطبيق قيمة قادمة من السيرفر دون رفع الطابع المحلي فوق طابع السيرفر.
  void applyRemote(String k, dynamic v, int ts) {
    _p.setString('$kStorePrefix$k', jsonEncode(v));
    meta[k] = ts;
    writeIntMap('__meta', meta);
    _emit(k);
  }

  void _emit(String k) {
    _ch.add(k);
    notifyListeners();
  }

  Future<void> clearAll() async {
    for (final k in _p.getKeys().where((x) => x.startsWith(kStorePrefix)).toList()) {
      await _p.remove(k);
    }
    meta = {};
    notifyListeners();
  }
}

final Store store = Store();
