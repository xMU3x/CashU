import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'assets.dart';
import 'currency.dart';
import 'store.dart';

/// العملات المشفرة المدعومة: الرمز → (معرّف CoinGecko، الاسم).
const Map<String, (String, String)> kCrypto = {
  'USDT': ('tether', 'Tether'),
  'BTC': ('bitcoin', 'Bitcoin'),
  'ETH': ('ethereum', 'Ethereum'),
  'USDC': ('usd-coin', 'USD Coin'),
  'BNB': ('binancecoin', 'BNB'),
  'SOL': ('solana', 'Solana'),
  'XRP': ('ripple', 'XRP'),
  'TON': ('the-open-network', 'Toncoin'),
  'TRX': ('tron', 'TRON'),
  'DOGE': ('dogecoin', 'Dogecoin'),
  'LTC': ('litecoin', 'Litecoin'),
  'ADA': ('cardano', 'Cardano'),
};

class PriceResult {
  final int updated, failed;
  const PriceResult(this.updated, this.failed);
}

class _Ctx {
  double? xau, xag; // دولار لكل أونصة
  Map<String, double> crypto = {}; // رمز → دولار
}

/// أسعار اليوم للأصول بالوحدة (أسهم · ذهب · فضة · عملات). أي مصدر يفشل = السعر القديم يفضل زي ما هو.
/// ملحوظة: الذهب والفضة بالسعر العالمي (أونصة ÷ ٣١٫١٠٣٥ × العيار) — مش سعر الصاغة المحلي بالمصنعية.
class Prices extends ChangeNotifier {
  bool loading = false;

  int get lastAt => (store.get('prices_t') as num?)?.toInt() ?? 0;

  Future<dynamic> _json(String url) async {
    final r = await http.get(Uri.parse(url), headers: const {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) throw Exception('http ${r.statusCode}');
    return jsonDecode(r.body);
  }

  Future<double?> _usdPerOz(String metal) async {
    try {
      final j = await _json('https://api.gold-api.com/price/$metal');
      final v = j is Map ? j['price'] : null;
      if (v is num && v > 0) return v.toDouble();
    } catch (_) {}
    final r = rates.perUsd[metal]; // open.er-api: وحدات المعدن لكل دولار
    return (r != null && r > 0) ? 1 / r : null;
  }

  Future<Map<String, double>> _cryptoUsd(Set<String> syms) async {
    final out = <String, double>{};
    if (syms.isEmpty) return out;
    try {
      final ids = [for (final s in syms) if (kCrypto[s] != null) kCrypto[s]!.$1];
      final j = await _json('https://api.coingecko.com/api/v3/simple/price?ids=${ids.join(',')}&vs_currencies=usd');
      if (j is Map) {
        for (final s in syms) {
          final m = j[kCrypto[s]?.$1];
          final v = m is Map ? m['usd'] : null;
          if (v is num && v > 0) out[s] = v.toDouble();
        }
      }
    } catch (_) {}
    return out;
  }

  Future<(double, String)?> _stock(String sym, bool egx) async {
    try {
      final j = await _json('https://query1.finance.yahoo.com/v8/finance/chart/${egx ? '$sym.CA' : sym}?interval=1d&range=1d');
      final m = j['chart']['result'][0]['meta'];
      final v = m['regularMarketPrice'];
      if (v is num && v > 0) return (v.toDouble(), '${m['currency'] ?? 'USD'}'.toUpperCase());
    } catch (_) {}
    return null;
  }

  Future<_Ctx> _load(List<Asset> items) async {
    final c = _Ctx();
    final gold = items.any((a) => a.type == 'gold');
    final silver = items.any((a) => a.type == 'silver');
    if (gold) c.xau = await _usdPerOz('XAU');
    if (silver) c.xag = await _usdPerOz('XAG');
    c.crypto = await _cryptoUsd({for (final a in items) if (a.type == 'currency' && kCrypto.containsKey(a.symbol)) a.symbol});
    return c;
  }

  /// سعر الوحدة بعملة الأصل (a.cur) — أو null لو مفيش مصدر.
  Future<double?> _quote(Asset a, _Ctx c, bool Function(String) isEgx) async {
    final toCur = rates.rate('USD', a.cur);
    switch (a.type) {
      case 'gold':
        final k = double.tryParse(a.karat) ?? 21;
        return c.xau == null ? null : c.xau! / 31.1035 * (k / 24) * toCur;
      case 'silver':
        final f = (double.tryParse(a.karat) ?? 999) / 1000;
        return c.xag == null ? null : c.xag! / 31.1035 * f * toCur;
      case 'currency':
        if (kCrypto.containsKey(a.symbol)) {
          final u = c.crypto[a.symbol];
          return u == null ? null : u * toCur;
        }
        return rates.perUsd.containsKey(a.symbol) ? rates.rate(a.symbol, a.cur) : null;
      case 'stock':
        if (a.symbol.isEmpty) return null;
        final r = await _stock(a.symbol, isEgx(a.symbol));
        return r == null ? null : r.$1 * rates.rate(r.$2, a.cur);
    }
    return null;
  }

  /// سعر اليوم لأصل واحد (للنموذج) من غير حفظ.
  Future<double?> todayPrice(Asset probe, {required bool Function(String) isEgx}) async {
    try {
      await rates.refresh();
      final c = await _load([probe]);
      final p = await _quote(probe, c, isEgx);
      return (p != null && p.isFinite && p > 0) ? p : null;
    } catch (_) {
      return null;
    }
  }

  /// تحديث أسعار كل الأصول بالوحدة بسعر اليوم.
  Future<PriceResult> refreshAll(List<Asset> items, {required bool Function(String) isEgx}) async {
    if (loading) return const PriceResult(0, 0);
    loading = true;
    notifyListeners();
    var ok = 0, bad = 0;
    try {
      await rates.refresh();
      final units = items.where((a) => assetIsUnit(a.type)).toList();
      final c = await _load(units);
      for (final a in units) {
        final p = await _quote(a, c, isEgx);
        if (p != null && p.isFinite && p > 0) {
          a.price = p;
          assetsRepo.save(a);
          ok++;
        } else {
          bad++;
        }
      }
      if (ok > 0) store.set('prices_t', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      bad++;
    }
    loading = false;
    notifyListeners();
    return PriceResult(ok, bad);
  }
}

final Prices prices = Prices();
