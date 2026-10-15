import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

/// تخزين محلي أولًا: كل مفتاح `flousy1:<key>` بقيمة JSON، وطابع زمني لكل مفتاح
/// متزامَن (`__meta`) عشان خدمة المزامنة تعرف إيه اتغيّر محليًا.
class Store extends ChangeNotifier {
  late SharedPreferences _p;
  Map<String, int> meta = {};
  final _ch = StreamController<String>.broadcast();
  Stream<String> get changes => _ch.stream;

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    meta = readIntMap('__meta');
  }

  Map<String, int> readIntMap(String k) {
    final s = _p.getString('$kStorePrefix$k');
    if (s == null) return {};
    try {
      return (jsonDecode(s) as Map)
          .map((a, b) => MapEntry(a as String, (b as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  void writeIntMap(String k, Map<String, int> m) =>
      _p.setString('$kStorePrefix$k', jsonEncode(m));

  String? raw(String k) => _p.getString('$kStorePrefix$k');
  void setRaw(String k, String v) => _p.setString('$kStorePrefix$k', v);

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

  /// قراءة سريعة للقراءة فقط (النتيجة المفكوكة بتتخزّن في الذاكرة). ما تعدّلش القيمة.
  Map<String, dynamic> peekMap(String k) {
    final r = _p.getString('$kStorePrefix$k');
    if (r == null) return const <String, dynamic>{};
    final c = _dc[k];
    if (c != null && c.$1 == r) return c.$2 as Map<String, dynamic>;
    try {
      final v = Map<String, dynamic>.from(jsonDecode(r) as Map);
      _dc[k] = (r, v);
      return v;
    } catch (_) {
      return const <String, dynamic>{};
    }
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

  /// تطبيق قيمة جاية من السيرفر من غير ما نرفع الطابع المحلي فوق طابع السيرفر.
  void applyRemote(String k, dynamic v, int ts) {
    _p.setString('$kStorePrefix$k', jsonEncode(v));
    meta[k] = ts;
    writeIntMap('__meta', meta);
    _emit(k);
  }

  void upd(String k, void Function(Map<String, dynamic>) fn) {
    final v = getMap(k);
    fn(v);
    set(k, v);
  }

  void _emit(String k) {
    _ch.add(k);
    notifyListeners();
  }

  Future<void> clearAll() async {
    for (final k in _p
        .getKeys()
        .where((x) => x.startsWith(kStorePrefix))
        .toList()) {
      await _p.remove(k);
    }
    meta = {};
    _dc.clear();
    notifyListeners();
  }
}

final Store store = Store();

/// إعدادات بسيطة (الوضع الداكن، الاهتزاز).
class Cfg {
  static const Map<String, dynamic> def = {'mode': 'auto', 'vibrate': true};

  dynamic get(String k) {
    final s = store.peekMap('settings');
    return s.containsKey(k) ? s[k] : def[k];
  }

  void set(String k, dynamic v) {
    final s = store.getMap('settings');
    s[k] = v;
    store.set('settings', s);
  }
}

final Cfg cfg = Cfg();

/// إعدادات خاصة بالجهاز ومش بتتزامن (تتبّع الرسائل، الذكاء الاصطناعي، الإضافة التلقائية).
class DevCfg {
  dynamic get(String k) => store.peekMap('device')[k];
  void set(String k, dynamic v) {
    final m = store.getMap('device');
    m[k] = v;
    store.set('device', m);
  }
}

final DevCfg dev = DevCfg();
