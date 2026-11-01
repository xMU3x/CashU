import 'currency.dart';
import 'settings.dart';
import 'store.dart';

/// أنواع الأصول: الثلاثة الأولى بسعر السوق (كمية × سعر الوحدة)، والباقي بقيمة بتحددها إنت.
const List<String> kAssetTypes = ['stock', 'gold', 'silver', 'realestate', 'car', 'business', 'other'];
bool assetIsUnit(String t) => t == 'stock' || t == 'gold' || t == 'silver';

class Asset {
  String id, type, name, symbol, cur, karat;
  double qty, buy, price; // للأنواع بالوحدة: سعر الوحدة. لغيرها: buy = قيمة الشراء، price = القيمة الحالية، qty = 1
  int date, updated;
  bool live, nw, alert;
  List<List<double>> hist; // [وقت، القيمة الإجمالية بعملة الأصل]

  Asset({
    required this.id,
    required this.type,
    this.name = '',
    this.symbol = '',
    this.cur = 'EGP',
    this.karat = '',
    this.qty = 1,
    this.buy = 0,
    this.price = 0,
    this.date = 0,
    int? updated,
    this.live = false,
    this.nw = true,
    this.alert = false,
    List<List<double>>? hist,
  })  : updated = updated ?? DateTime.now().millisecondsSinceEpoch,
        hist = hist ?? [];

  double get value => assetIsUnit(type) ? qty * price : price;
  double get cost => assetIsUnit(type) ? qty * buy : buy;
  double get gain => value - cost;
  double get gainPct => cost > 0 ? gain / cost * 100 : 0;

  /// نقطة جديدة في سجل القيمة (لو القيمة اتغيّرت).
  void snapshot() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (hist.isEmpty && date > 0 && date < now) hist.add([date.toDouble(), cost]);
    if (hist.isEmpty || hist.last[1] != value) hist.add([now.toDouble(), value]);
    updated = now;
  }

  Map<String, dynamic> toJson() => {
        'id': id, 'type': type, 'name': name, 'symbol': symbol, 'cur': cur, 'karat': karat,
        'qty': qty, 'buy': buy, 'price': price, 'date': date, 'u': updated,
        'live': live, 'nw': nw, 'alert': alert, 'hist': hist,
      };

  static double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  factory Asset.fromJson(Map j) => Asset(
        id: '${j['id']}', type: '${j['type'] ?? 'other'}', name: '${j['name'] ?? ''}', symbol: '${j['symbol'] ?? ''}',
        cur: '${j['cur'] ?? 'EGP'}', karat: '${j['karat'] ?? ''}',
        qty: _d(j['qty'] ?? 1), buy: _d(j['buy']), price: _d(j['price']),
        date: (j['date'] as num?)?.toInt() ?? 0, updated: (j['u'] as num?)?.toInt(),
        live: j['live'] == true, nw: j['nw'] != false, alert: j['alert'] == true,
        hist: [
          for (final h in (j['hist'] as List? ?? const []))
            if (h is List && h.length >= 2) [_d(h[0]), _d(h[1])],
        ],
      );
}

const String kAssetsKey = 'tyr_assets';

/// تخزين محلي فقط (مش بيتزامن سحابيًا حاليًا).
class AssetsRepo {
  List<Asset> get list {
    final m = store.getMap(kAssetsKey);
    final out = <Asset>[for (final v in m.values) if (v is Map) Asset.fromJson(v)];
    out.sort((a, b) => b.updated.compareTo(a.updated));
    return out;
  }

  void save(Asset a) {
    a.snapshot();
    final m = store.getMap(kAssetsKey);
    m[a.id] = a.toJson();
    store.set(kAssetsKey, m);
  }

  void delete(String id) {
    final m = store.getMap(kAssetsKey);
    m.remove(id);
    store.set(kAssetsKey, m);
  }

  double _base(Asset a, double v) => a.cur == S.cur ? v : v * rates.rate(a.cur, S.cur);

  /// القيمة الإجمالية (بعملة التطبيق) لكل الأصول، أو المحتسبة في صافي الثروة بس.
  double total({bool nwOnly = false}) => list.where((a) => !nwOnly || a.nw).fold(0.0, (s, a) => s + _base(a, a.value));

  /// السلسلة الزمنية للقيمة الإجمالية بداية من [from] (ملّي ثانية). كل نقطة = [وقت، قيمة].
  List<List<double>> series({int? from}) {
    final items = list;
    final times = <double>{};
    for (final a in items) {
      for (final h in a.hist) {
        times.add(h[0]);
      }
    }
    if (times.isEmpty) return [];
    final ts = times.toList()..sort();
    double at(Asset a, double t) {
      double v = 0;
      for (final h in a.hist) {
        if (h[0] <= t) {
          v = h[1];
        } else {
          break;
        }
      }
      return _base(a, v);
    }

    final now = DateTime.now().millisecondsSinceEpoch.toDouble();
    var pts = [for (final t in ts) [t, items.fold(0.0, (s, a) => s + at(a, t))]];
    pts.add([now, total()]);
    if (from != null) {
      final f = from.toDouble();
      final startVal = items.fold(0.0, (s, a) => s + at(a, f));
      pts = [[f, startVal], ...pts.where((p) => p[0] > f)];
    }
    return pts;
  }
}

final AssetsRepo assetsRepo = AssetsRepo();
