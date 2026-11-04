import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'i18n.dart';
import 'store.dart';

class Cur {
  final String code, name, flag;
  final String _sym;
  const Cur(this.code, this.name, this._sym, this.flag);

  /// رمز العملة: الجنيه المصري = «ج.م» في العربي و«EGP» في الإنجليزي.
  String get sym => code == 'EGP' ? (isAr ? 'ج.م' : 'EGP') : _sym;
}

const kCurs = <Cur>[
  Cur('EGP', 'جنيه مصري', 'ج.م', '🇪🇬'),
  Cur('USD', 'دولار أمريكي', '\$', '🇺🇸'),
  Cur('EUR', 'يورو', '€', '🇪🇺'),
  Cur('SAR', 'ريال سعودي', 'ر.س', '🇸🇦'),
  Cur('AED', 'درهم إماراتي', 'د.إ', '🇦🇪'),
  Cur('KWD', 'دينار كويتي', 'د.ك', '🇰🇼'),
  Cur('QAR', 'ريال قطري', 'ر.ق', '🇶🇦'),
  Cur('BHD', 'دينار بحريني', 'د.ب', '🇧🇭'),
  Cur('OMR', 'ريال عماني', 'ر.ع', '🇴🇲'),
  Cur('JOD', 'دينار أردني', 'د.أ', '🇯🇴'),
  Cur('GBP', 'جنيه إسترليني', '£', '🇬🇧'),
  Cur('TRY', 'ليرة تركية', '₺', '🇹🇷'),
  Cur('CAD', 'دولار كندي', 'C\$', '🇨🇦'),
  Cur('AUD', 'دولار أسترالي', 'A\$', '🇦🇺'),
  Cur('CHF', 'فرنك سويسري', 'Fr', '🇨🇭'),
  Cur('JPY', 'ين ياباني', '¥', '🇯🇵'),
  Cur('CNY', 'يوان صيني', '¥', '🇨🇳'),
  Cur('INR', 'روبية هندية', '₹', '🇮🇳'),
  Cur('MAD', 'درهم مغربي', 'د.م', '🇲🇦'),
];

Cur curOf(String code) => kCurs.firstWhere((c) => c.code == code, orElse: () => kCurs.first);

class Rates extends ChangeNotifier {
  // أسعار تقريبية احتياطية (لكل 1 دولار) — تُستبدل بالأسعار الحيّة عند توفر الإنترنت
  Map<String, double> perUsd = {
    'USD': 1, 'EGP': 48, 'EUR': .92, 'SAR': 3.75, 'AED': 3.6725, 'KWD': .307, 'QAR': 3.64, 'BHD': .376, 'OMR': .385,
    'JOD': .709, 'GBP': .78, 'TRY': 34, 'CAD': 1.37, 'AUD': 1.5, 'CHF': .88, 'JPY': 150, 'CNY': 7.2, 'INR': 84, 'MAD': 9.8,
  };
  int updated = 0;
  bool loading = false;

  void load() {
    final m = store.get('rates');
    if (m is Map && m['r'] is Map) {
      (m['r'] as Map).forEach((k, v) {
        if (v is num) perUsd[k as String] = v.toDouble();
      });
      updated = (m['t'] as num?)?.toInt() ?? 0;
    }
  }

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    notifyListeners();
    try {
      final r = await http.get(Uri.parse('https://open.er-api.com/v6/latest/USD')).timeout(const Duration(seconds: 8));
      final j = jsonDecode(r.body);
      if (j is Map && j['rates'] is Map) {
        final out = <String, double>{};
        (j['rates'] as Map).forEach((k, v) {
          if (v is num) out[k as String] = v.toDouble();
        });
        perUsd.addAll(out);
        updated = DateTime.now().millisecondsSinceEpoch;
        store.set('rates', {'r': perUsd, 't': updated});
      }
    } catch (_) {}
    loading = false;
    notifyListeners();
  }

  /// كم وحدة من [to] تساوي وحدة واحدة من [from].
  double rate(String from, String to) {
    final a = perUsd[from], b = perUsd[to];
    if (a == null || b == null || a == 0) return 1;
    return b / a;
  }
}

final Rates rates = Rates();
