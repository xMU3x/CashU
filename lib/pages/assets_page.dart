import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import '../core/assets.dart';
import '../core/currency.dart';
import '../core/settings.dart';
import '../core/util.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/motion.dart';
import '../ui/pickers.dart';
import '../ui/sheets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

// ======================= الأصول =======================

class _TypeInfo {
  final String title, sub;
  final IconData icon;
  final Color color;
  const _TypeInfo(this.title, this.sub, this.icon, this.color);
}

const Map<String, _TypeInfo> _types = {
  'stock': _TypeInfo('أسهم', 'تابع الأسهم والصناديق وأداء استثماراتك.', Icons.show_chart_rounded, Color(0xFF64B5F6)),
  'gold': _TypeInfo('ذهب', 'اعرف قيمة الذهب حسب الجرام والعيار.', Icons.workspace_premium_rounded, Color(0xFFFFC107)),
  'silver': _TypeInfo('فضة', 'تابع قيمة الفضة اللي بتملكها.', Icons.diamond_outlined, Color(0xFFB0BEC5)),
  'realestate': _TypeInfo('شقة أو أرض', 'تمتلكها بشكل كامل أو تمتلكها بشكل جزئي.', Icons.home_rounded, Color(0xFF5B8DEF)),
  'car': _TypeInfo('سيارة', 'أي مركبة تملكها.', Icons.directions_car_filled_rounded, Color(0xFF8E8CF3)),
  'business': _TypeInfo('مشروع تجاري', 'حصتك في مشروع أو شركة.', Icons.work_rounded, Color(0xFF9575CD)),
  'other': _TypeInfo('أصل آخر تملكه', 'لوحات فنية أو ساعات أو معدات — أي شيء له قيمة.', Icons.inventory_2_outlined, Color(0xFFE56AA0)),
};

double _num(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final i = ar.indexOf(c);
    b.write(i >= 0 ? '$i' : (c == '٫' || c == ',' || c == '،' ? '.' : c));
  }
  return double.tryParse(b.toString().replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0;
}

String _money(double v, String cur) => '${fmt(v)} ${curOf(cur).sym}';

// ----------------------- الصفحة الرئيسية -----------------------
class AssetsPage extends StatefulWidget {
  const AssetsPage({super.key});
  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  int range = 0; // 0 الكل · 1 أسبوع · 2 شهر · 3 ٣ شهور · 4 ٦ شهور
  int _gen = 0;
  static const _labels = ['الكل', 'أسبوع', 'شهر', '3 أشهر', '6 أشهر'];
  static const _days = [0, 7, 30, 90, 180];

  void _add() => Navigator.of(context).push(flowRoute(const AssetChooserPage()));
  void _open(Asset a) => Navigator.of(context).push(flowRoute(AssetFormPage(type: a.type, edit: a)));

  Future<void> _delete(Asset a) async {
    setState(() => _gen++);
    final ok = await confirmDialog(context, 'حذف الأصل', 'هيتحذف «${a.name.isEmpty ? _types[a.type]!.title : a.name}» نهائيًا.');
    if (ok) assetsRepo.delete(a.id);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: 'الأصول',
      icon: Icons.account_balance_rounded,
      iconColor: kBlue,
      trailing: Tap(onTap: _add, child: Container(width: 44, height: 44, decoration: BoxDecoration(color: p.acc, shape: BoxShape.circle), child: const Icon(Icons.add_rounded, color: Colors.white, size: 26))),
      child: Live(b: (c) {
        final items = assetsRepo.list;
        if (items.isEmpty) {
          return ListView(physics: const BouncingScrollPhysics(), children: [emptyState(p, Icons.account_balance_rounded, 'مفيش أصول لسه. اضغط + وضيف أول أصل.')]);
        }
        final total = assetsRepo.total();
        final from = _days[range] == 0 ? null : DateTime.now().subtract(Duration(days: _days[range])).millisecondsSinceEpoch;
        final pts = assetsRepo.series(from: from);
        final first = pts.isEmpty ? 0.0 : pts.first[1];
        final diff = total - first;
        final pct = first > 0 ? diff / first * 100 : 0.0;
        final up = diff >= 0;
        final col = up ? kGreen : kRed;
        return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), physics: const BouncingScrollPhysics(), children: [
          Padding(padding: const EdgeInsets.fromLTRB(4, 4, 4, 0), child: Text('القيمة الإجمالية', style: TextStyle(fontSize: 15, color: p.ink2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
            child: Align(alignment: AlignmentDirectional.centerStart, child: FittedBox(fit: BoxFit.scaleDown, child: Text(_money(total, S.cur), maxLines: 1, style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800)))),
          ),
          if (pts.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: col.withValues(alpha: .14), borderRadius: BorderRadius.circular(14)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: col, size: 15),
                    const SizedBox(width: 3),
                    Text('${pct.abs().toStringAsFixed(1)}%', style: TextStyle(color: col, fontWeight: FontWeight.w700, fontSize: 14)),
                  ]),
                ),
                const SizedBox(width: 10),
                Text('${up ? '+' : '-'}${fmt(diff.abs())} ${curOf(S.cur).sym}', style: TextStyle(color: p.ink2, fontSize: 14)),
              ]),
            ),
          Container(
            height: 190,
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
            decoration: cardDeco(p, r: 24),
            clipBehavior: Clip.antiAlias,
            child: CustomPaint(painter: _LinePainter(pts, col), size: Size.infinite),
          ),
          const SizedBox(height: 12),
          Container(
            height: 44,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22)),
            child: Row(children: [
              for (var i = 0; i < _labels.length; i++)
                Expanded(
                  child: Tap(
                    scale: .97,
                    onTap: () => setState(() => range = i),
                    child: AnimatedContainer(
                      duration: CashUMotion.of(context),
                      curve: CashUMotion.curve,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: range == i ? p.field : Colors.transparent, borderRadius: BorderRadius.circular(18)),
                      child: Text(_labels[i], maxLines: 1, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: range == i ? p.ink : p.ink2)),
                    ),
                  ),
                ),
            ]),
          ),
          sectionLabel(p, 'الأصول (${items.length})'),
          for (final a in items) _card(p, a),
        ]);
      }),
    );
  }

  Widget _card(Pal p, Asset a) {
    final ti = _types[a.type]!;
    final up = a.gain >= 0;
    final col = up ? kGreen : kRed;
    final label = a.name.isEmpty ? ti.title : a.name;
    final pts = [for (final h in a.hist) h];
    final body = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: cardDeco(p, r: 26),
      clipBehavior: Clip.antiAlias,
      child: Tap(
        scale: .985,
        onTap: () => _open(a),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: ti.color.withValues(alpha: .16), borderRadius: BorderRadius.circular(16)), child: Icon(ti.icon, color: ti.color)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('آخر تحديث ${enDate(DateTime.fromMillisecondsSinceEpoch(a.updated))}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: p.ink2)),
                  if (assetIsUnit(a.type)) Text('${fmt(a.qty, dec: 2)} ${a.type == 'stock' ? 'سهم' : 'جرام'}${a.karat.isEmpty ? '' : ' · عيار ${a.karat}'}', style: TextStyle(fontSize: 13, color: p.ink2)),
                ]),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_money(a.value, a.cur), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                if (a.cost > 0) Text('${up ? '+' : '-'}${a.gainPct.abs().toStringAsFixed(1)}%', style: TextStyle(fontSize: 13.5, color: col, fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
          SizedBox(height: 56, width: double.infinity, child: CustomPaint(painter: _LinePainter(pts, col, compact: true))),
        ]),
      ),
    );
    return SwipeRow(
      key: ValueKey('as_${a.id}_$_gen'),
      bg: p.bg,
      leftW: kSwipeSlotW,
      leftActions: swipeCircle(Icons.delete_outline_rounded, 'حذف', kRed, () => _delete(a)),
      onFullLeft: () => _delete(a),
      child: body,
    );
  }
}

/// رسم خطي (درج) بتعبئة متدرّجة؛ [compact] = سباركلاين بدون هوامش.
class _LinePainter extends CustomPainter {
  final List<List<double>> pts;
  final Color color;
  final bool compact;
  _LinePainter(this.pts, this.color, {this.compact = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 2) {
      final y = size.height / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), Paint()..color = color.withValues(alpha: .6)..strokeWidth = 2);
      return;
    }
    final t0 = pts.first[0], t1 = pts.last[0];
    var lo = pts.map((e) => e[1]).reduce(math.min), hi = pts.map((e) => e[1]).reduce(math.max);
    if (hi - lo < 1e-9) {
      hi += 1;
      lo -= 1;
    }
    final padV = compact ? 8.0 : 22.0;
    double x(double t) => t1 == t0 ? 0 : (t - t0) / (t1 - t0) * size.width;
    double y(double v) => padV + (1 - (v - lo) / (hi - lo)) * (size.height - padV * 2);
    final path = Path()..moveTo(x(pts.first[0]), y(pts.first[1]));
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(x(pts[i][0]), y(pts[i - 1][1])); // درج: القيمة ثابتة لحد التحديث الجاي
      path.lineTo(x(pts[i][0]), y(pts[i][1]));
    }
    final fill = Path.from(path)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(fill, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: .38), color.withValues(alpha: 0)]).createShader(Offset.zero & size));
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = compact ? 2 : 2.5..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _LinePainter o) => o.pts != pts || o.color != color;
}

// ----------------------- اختيار نوع الأصل -----------------------
class AssetChooserPage extends StatelessWidget {
  const AssetChooserPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Widget tile(String id) {
      final t = _types[id]!;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Tap(
          scale: .98,
          onTap: () => Navigator.of(context).push(flowRoute(AssetFormPage(type: id))),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDeco(p, r: 26),
            child: Row(children: [
              Container(width: 56, height: 56, decoration: BoxDecoration(color: t.color.withValues(alpha: .16), borderRadius: BorderRadius.circular(18)), child: Icon(t.icon, color: t.color, size: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(t.sub, style: TextStyle(fontSize: 14, color: p.ink2, height: 1.35)),
                ]),
              ),
              Icon(Icons.chevron_left_rounded, color: p.ink2),
            ]),
          ),
        ),
      );
    }

    return PageShell(
      title: 'إضافة أصل',
      icon: Icons.add_business_rounded,
      iconColor: kBlue,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), physics: const BouncingScrollPhysics(), children: [
        sectionLabel(p, 'بسعر السوق'),
        tile('stock'),
        tile('gold'),
        tile('silver'),
        sectionLabel(p, 'بقيمة تحددها أنت'),
        tile('realestate'),
        tile('car'),
        tile('business'),
        tile('other'),
      ]),
    );
  }
}

// ----------------------- بحث الأسهم (قائمة مختصرة مدمجة) -----------------------
const List<(String, String, String)> _stocks = [
  ('COMI', 'البنك التجاري الدولي', 'EGX'), ('HRHO', 'إي إف جي القابضة', 'EGX'), ('TMGH', 'طلعت مصطفى القابضة', 'EGX'),
  ('EAST', 'الشرقية - إيسترن كومباني', 'EGX'), ('SWDY', 'السويدي إليكتريك', 'EGX'), ('ORAS', 'أوراسكوم للإنشاء', 'EGX'),
  ('ABUK', 'أبو قير للأسمدة', 'EGX'), ('FWRY', 'فوري', 'EGX'), ('ETEL', 'المصرية للاتصالات', 'EGX'),
  ('EKHO', 'القابضة المصرية الكويتية', 'EGX'), ('PHDC', 'بالم هيلز', 'EGX'), ('MNHD', 'مدينة نصر للإسكان', 'EGX'),
  ('AAPL', 'Apple', 'US'), ('MSFT', 'Microsoft', 'US'), ('NVDA', 'NVIDIA', 'US'), ('AMZN', 'Amazon', 'US'),
  ('GOOGL', 'Alphabet', 'US'), ('META', 'Meta Platforms', 'US'), ('TSLA', 'Tesla', 'US'), ('NFLX', 'Netflix', 'US'),
  ('VOO', 'Vanguard S&P 500 ETF', 'US'), ('SPY', 'SPDR S&P 500 ETF', 'US'), ('QQQ', 'Invesco QQQ', 'US'),
];

Future<(String, String)?> _pickStock(BuildContext context) => showSheet<(String, String)>(context, (c) {
      final p = Pal.of(c);
      var seg = 0; // 0 EGX · 1 US · 2 الكل
      var q = '';
      return StatefulBuilder(builder: (c, set) {
        final list = _stocks.where((s) => (seg == 2 || s.$3 == (seg == 0 ? 'EGX' : 'US')) && (q.length < 2 || s.$1.toLowerCase().contains(q.toLowerCase()) || s.$2.toLowerCase().contains(q.toLowerCase()))).toList();
        return SheetFrame(
          title: 'البحث عن أسهم',
          child: SizedBox(
            height: MediaQuery.of(c).size.height * .7,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(22)),
                  child: Row(children: [
                    for (final e in const [(0, 'EGX'), (1, 'US'), (2, 'الكل')])
                      Expanded(
                        child: Tap(
                          onTap: () => set(() => seg = e.$1),
                          child: AnimatedContainer(
                            duration: CashUMotion.of(c),
                            curve: CashUMotion.curve,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: seg == e.$1 ? p.card : Colors.transparent, borderRadius: BorderRadius.circular(18)),
                            child: Text(e.$2, style: TextStyle(fontWeight: FontWeight.w600, color: seg == e.$1 ? p.ink : p.ink2)),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    Icon(Icons.search_rounded, color: p.ink2),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(autofocus: true, onChanged: (v) => set(() => q = v.trim()), style: TextStyle(fontSize: 16, color: p.ink), decoration: InputDecoration(border: InputBorder.none, hintText: 'اسم الشركة أو رمز التداول...', hintStyle: TextStyle(color: p.ink2)))),
                  ]),
                ),
              ),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 20), children: [
                  if (q.length < 2) Padding(padding: const EdgeInsets.all(18), child: Center(child: Text('اكتب حرفين على الأقل للبحث', style: TextStyle(color: p.ink2)))),
                  for (final s in list)
                    Tap(
                      onTap: () => Navigator.of(c).pop((s.$1, s.$2)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(10)), child: Text(s.$1, style: const TextStyle(fontWeight: FontWeight.w700))),
                          const SizedBox(width: 12),
                          Expanded(child: Text(s.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16))),
                          Text(s.$3, style: TextStyle(color: p.ink2)),
                        ]),
                      ),
                    ),
                  if (q.length >= 2)
                    Tap(
                      onTap: () => Navigator.of(c).pop((q.toUpperCase(), q)),
                      child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('استخدم «$q» كما كتبته', style: TextStyle(color: p.acc, fontSize: 16))),
                    ),
                ]),
              ),
            ]),
          ),
        );
      });
    });

// ----------------------- نموذج إضافة/تعديل أصل -----------------------
class AssetFormPage extends StatefulWidget {
  final String type;
  final Asset? edit;
  const AssetFormPage({super.key, required this.type, this.edit});
  @override
  State<AssetFormPage> createState() => _AssetFormPageState();
}

class _AssetFormPageState extends State<AssetFormPage> {
  late final TextEditingController nameC, qtyC, buyC, priceC;
  late String cur, karat, symbol;
  DateTime? date;
  bool nw = true, bad = false;

  bool get unit => assetIsUnit(widget.type);
  _TypeInfo get ti => _types[widget.type]!;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    nameC = TextEditingController(text: e?.name ?? '');
    qtyC = TextEditingController(text: e == null || !unit ? '' : '${e.qty}');
    buyC = TextEditingController(text: e == null || e.buy == 0 ? '' : '${e.buy}');
    priceC = TextEditingController(text: e == null || e.price == 0 ? '' : '${e.price}');
    cur = e?.cur ?? S.cur;
    karat = e?.karat.isNotEmpty == true ? e!.karat : (widget.type == 'silver' ? '925' : '21');
    symbol = e?.symbol ?? '';
    date = e == null || e.date == 0 ? null : DateTime.fromMillisecondsSinceEpoch(e.date);
    nw = e?.nw ?? true;
  }

  @override
  void dispose() {
    nameC.dispose();
    qtyC.dispose();
    buyC.dispose();
    priceC.dispose();
    super.dispose();
  }

  void _save() {
    final qty = unit ? _num(qtyC.text) : 1.0;
    final buy = _num(buyC.text);
    var price = _num(priceC.text);
    if (price <= 0) price = buy; // لو متحدّدش سعر حالي: نفس سعر الشراء
    final needName = widget.type == 'stock' ? symbol.isEmpty && nameC.text.trim().isEmpty : !unit && nameC.text.trim().isEmpty;
    if (needName || qty <= 0 || (buy <= 0 && price <= 0)) {
      setState(() => bad = true);
      toast(context, 'كمّل البيانات المطلوبة');
      return;
    }
    final e = widget.edit;
    final a = e ?? Asset(id: uid(), type: widget.type);
    a
      ..name = nameC.text.trim()
      ..symbol = symbol
      ..cur = cur
      ..karat = widget.type == 'stock' || !unit ? '' : karat
      ..qty = qty
      ..buy = buy
      ..price = price
      ..date = date?.millisecondsSinceEpoch ?? 0
      ..nw = nw;
    assetsRepo.save(a);
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context, 'حذف الأصل', 'هيتحذف نهائيًا.');
    if (!ok || !mounted) return;
    assetsRepo.delete(widget.edit!.id);
    Navigator.of(context).pop();
  }

  Color get _wc => Theme.of(context).brightness == Brightness.dark ? Colors.white : Pal.of(context).ink;
  TextStyle _ts(double s, {FontWeight w = FontWeight.w700, double a = 1}) => TextStyle(fontSize: s, fontWeight: w, color: _wc.withValues(alpha: a));

  Widget _label(String t) => Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Align(alignment: AlignmentDirectional.centerStart, child: Text(t, style: _ts(15))));

  Widget _box(Pal p, {required Widget child, bool err = false}) => Container(
        constraints: const BoxConstraints(minHeight: 56),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(20), border: err ? Border.all(color: kRed, width: 1.5) : null),
        child: child,
      );

  Widget _text(Pal p, TextEditingController c, String hint, {bool numeric = false, bool err = false, String? suffix}) => _box(
        p,
        err: err,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: c,
              keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
              textAlign: TextAlign.start,
              style: _ts(18),
              decoration: InputDecoration(border: InputBorder.none, hintText: hint, hintStyle: _ts(16, w: FontWeight.w600, a: .45)),
            ),
          ),
          if (suffix != null) Text(suffix, style: _ts(16, a: .8)),
        ]),
      );

  Widget _card(Pal p, List<Widget> kids) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(28)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: kids),
      );

  Widget _toggle(Pal p, String title, String sub, bool v, ValueChanged<bool>? f) => Opacity(
        opacity: f == null ? .55 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: _ts(17)), const SizedBox(height: 2), Text(sub, style: _ts(13.5, w: FontWeight.w600, a: .7))])),
            const SizedBox(width: 8),
            Switch(value: v, onChanged: f, activeThumbColor: Colors.white, activeTrackColor: kGreen),
          ]),
        ),
      );

  Widget _curRow(Pal p) => Tap(
        onTap: () async {
          final r = await showCurrencySheet(context, cur);
          if (r != null) setState(() => cur = r);
        },
        child: _box(p, child: Row(children: [Text(cur, style: _ts(18)), const Spacer(), Icon(Icons.keyboard_arrow_down_rounded, color: _wc)])),
      );

  Widget _dateRow(Pal p) => Tap(
        onTap: () async {
          final d = await showDateSheet(context, date ?? DateTime.now(), title: 'تاريخ الشراء');
          if (d != null) setState(() => date = d);
        },
        child: _box(p, child: Row(children: [Text(date == null ? 'اختر التاريخ (اختياري)' : enDate(date!), style: _ts(17, w: FontWeight.w600, a: date == null ? .5 : 1)), const Spacer(), Icon(Icons.calendar_today_outlined, color: _wc, size: 22)])),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final e = widget.edit;
    final karats = widget.type == 'silver' ? const ['800', '925', '999'] : const ['18', '21', '24'];
    final title = e != null ? 'تعديل ${ti.title}' : 'إضافة ${widget.type == 'stock' ? 'سهم' : ti.title}';

    final main = <Widget>[];
    if (widget.type == 'stock') {
      main.addAll([
        _label('اختر السهم'),
        Tap(
          onTap: () async {
            final r = await _pickStock(context);
            if (r != null) {
              setState(() {
                symbol = r.$1;
                nameC.text = r.$2;
              });
            }
          },
          child: _box(p, err: bad && symbol.isEmpty && nameC.text.trim().isEmpty, child: Row(children: [
            Expanded(child: Text(symbol.isEmpty ? 'اضغط للبحث عن سهم' : '$symbol · ${nameC.text}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _ts(17, w: FontWeight.w600, a: symbol.isEmpty ? .5 : 1))),
            Icon(Icons.search_rounded, color: _wc),
          ])),
        ),
        const SizedBox(height: 16),
      ]);
    } else if (unit) {
      main.addAll([_label('اسم الأصل'), _text(p, nameC, 'اختياري'), const SizedBox(height: 16), _label('العيار'), _karatSeg(p, karats), const SizedBox(height: 16), _label('العملة'), _curRow(p), const SizedBox(height: 16)]);
    } else {
      main.addAll([_label('الاسم'), _text(p, nameC, ti.title, err: bad && nameC.text.trim().isEmpty), const SizedBox(height: 16), _label('العملة'), _curRow(p), const SizedBox(height: 16)]);
    }
    if (unit) {
      main.addAll([
        _label(widget.type == 'stock' ? 'الكمية' : 'الوزن (جرام)'),
        _text(p, qtyC, widget.type == 'stock' ? 'عدد الأسهم' : 'جرام', numeric: true, err: bad && _num(qtyC.text) <= 0),
        const SizedBox(height: 16),
        _label(widget.type == 'stock' ? 'سعر الشراء للسهم' : 'سعر الجرام عند الشراء'),
        _text(p, buyC, '0.00', numeric: true, suffix: cur),
        const SizedBox(height: 16),
        _label(widget.type == 'stock' ? 'السعر الحالي للسهم' : 'سعر الجرام الحالي'),
        _text(p, priceC, 'لو سبته فاضي = سعر الشراء', numeric: true, suffix: cur),
        const SizedBox(height: 16),
      ]);
    } else {
      main.addAll([
        _label('قيمة الشراء'),
        _text(p, buyC, '0.00', numeric: true, suffix: cur),
        const SizedBox(height: 16),
        _label('القيمة الحالية'),
        _text(p, priceC, 'لو سبتها فاضية = قيمة الشراء', numeric: true, suffix: cur, err: bad && _num(buyC.text) <= 0 && _num(priceC.text) <= 0),
        const SizedBox(height: 16),
      ]);
    }
    main.addAll([_label('تاريخ الشراء'), _dateRow(p)]);

    return Scaffold(
      backgroundColor: p.bg,
      body: SheetPage(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              Tap(onTap: _save, child: Container(width: 48, height: 48, decoration: BoxDecoration(color: p.acc, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: Colors.white, size: 26))),
              if (e != null) ...[const SizedBox(width: 10), GlassBtn(Icons.delete_outline_rounded, _delete, size: 48, fg: kRed)],
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: _ts(20))),
              GlassBtn(Icons.chevron_right_rounded, () => Navigator.of(context).pop(), size: 48),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), physics: const BouncingScrollPhysics(), children: [
              _card(p, main),
              _card(p, [
                if (unit) ...[
                  _toggle(p, 'السعر المباشر', 'التحديث تلقائيًا مع السوق — قريبًا، حاليًا السعر بتحدّثه يدويًا', false, null),
                  Divider(color: p.field, height: 14),
                ],
                _toggle(p, 'إدراج في صافي الثروة', 'احتساب هذا الأصل ضمن إجمالي صافي ثروتك', nw, (v) => setState(() => nw = v)),
              ]),
              if (unit) _card(p, [_toggle(p, 'تنبيهات السعر', 'نبهني عند تغيّر السعر بالمقدار الذي تحدده — قريبًا', false, null)]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _karatSeg(Pal p, List<String> ks) => Container(
        height: 52,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(26)),
        child: Row(children: [
          for (final k in ks)
            Expanded(
              child: Tap(
                scale: .97,
                onTap: () => setState(() => karat = k),
                child: AnimatedContainer(
                  duration: CashUMotion.of(context),
                  curve: CashUMotion.curve,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: karat == k ? p.acc : Colors.transparent, borderRadius: BorderRadius.circular(22)),
                  child: Text('عيار $k', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: karat == k ? Colors.white : _wc.withValues(alpha: .75))),
                ),
              ),
            ),
        ]),
      );
}
