import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import '../core/currency.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/util.dart';
import '../ui/anim.dart';
import '../ui/sheets.dart';
import '../ui/ios.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});
  @override
  State<StatsPage> createState() => _StatsState();
}

class _StatsState extends State<StatsPage> {
  final pc = PageController();
  int back = 0;
  String accF = '';

  DateTime _m(int b) => DateTime(DateTime.now().year, DateTime.now().month - b);

  @override
  void dispose() {
    pc.dispose();
    super.dispose();
  }

  void _go(int b) {
    if (b < 0 || b > 23) return;
    pc.animateToPage(b, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final m = _m(back);
    return Live(b: (c) => Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TopBar(
                back: false,
                title: 'الإحصائيات',
                sub: 'تحليل شامل لمصاريفك',
                icon: Icons.pie_chart_rounded,
                iconColor: const Color(0xFF5B8DEF),
                trailing: Tap(
                  onTap: () async {
                    final r = await showPickAccount(context, accF, title: 'تصفية بالحساب');
                    if (r != null) setState(() => accF = r);
                  },
                  onLongPress: () => setState(() => accF = ''),
                  child: Container(width: 46, height: 46, decoration: BoxDecoration(color: accF.isEmpty ? p.field : p.acc.withValues(alpha: .18), shape: BoxShape.circle), child: Icon(Icons.tune_rounded, color: accF.isEmpty ? p.ink : p.acc, size: 20)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                RoundBtn(Icons.chevron_right_rounded, () => _go(back + 1), size: 48),
                Expanded(child: Center(child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), transitionBuilder: (w, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween<double>(begin: .9, end: 1).animate(a), child: w)), child: Text('${kMonths[m.month - 1]} ${toAr('${m.year}')}', key: ValueKey(back), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))))),
                Opacity(opacity: back == 0 ? .35 : 1, child: RoundBtn(Icons.chevron_left_rounded, back == 0 ? null : () => _go(back - 1), size: 48)),
              ]),
            ),
            Expanded(
              child: PageView.builder(
                reverse: true,
                controller: pc,
                itemCount: 24,
                onPageChanged: (i) {
                  setState(() => back = i);
                  tick();
                },
                itemBuilder: (c, i) => _MonthStats(month: _m(i), acc: accF),
              ),
            ),
          ]),
        ));
  }
}

class _MonthStats extends StatefulWidget {
  final DateTime month;
  final String acc;
  const _MonthStats({required this.month, required this.acc});
  @override
  State<_MonthStats> createState() => _MonthStatsState();
}

class _MonthStatsState extends State<_MonthStats> {
  bool days = true;

  Widget _tile(Pal p, IconData i, Color c, String v, String l) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: cardDeco(p, r: 20),
          child: Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: c.withValues(alpha: .15), borderRadius: BorderRadius.circular(13)), child: Icon(i, color: c, size: 20)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [FittedBox(fit: BoxFit.scaleDown, child: Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))), Text(l, style: TextStyle(color: p.ink2, fontSize: 12))])),
          ]),
        ),
      );

  Color _heat(Pal p, double r) {
    if (r <= 0) return p.field;
    if (r <= .25) return const Color(0xFFDCEBD3);
    if (r <= .5) return const Color(0xFF9CCB8F);
    if (r <= .75) return const Color(0xFFE9A653);
    return const Color(0xFFD4543F);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final y = widget.month.year, mo = widget.month.month;
    final a = widget.acc;
    final spent = repo.spent(y, mo, acc: a), inc = repo.income(y, mo, acc: a);
    final now = DateTime.now();
    final cur = now.year == y && now.month == mo;
    final elapsed = cur ? now.day : daysIn(y, mo);
    final daily = repo.daily(y, mo, acc: a);
    final cats = repo.byCat(y, mo, acc: a);
    final mx = daily.fold(0.0, math.max);
    final noSpend = daily.take(elapsed).where((v) => v == 0).length;
    final peak = mx > 0 ? daily.indexOf(mx) + 1 : 0;
    final first = DateTime(y, mo, 1);
    final lead = (first.weekday + 1) % 7; // السبت = 0
    // آخر 6 أشهر (الأقدم أولًا)
    final series = [for (var k = 5; k >= 0; k--) (() { final d = DateTime(y, mo - k); return (repo.income(d.year, d.month, acc: a), repo.spent(d.year, d.month, acc: a), kMonths[d.month - 1]); })()];
    final maxV = series.fold(1.0, (s, e) => math.max(s, math.max(e.$1, e.$2)));

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 130), physics: const BouncingScrollPhysics(), children: [
      if (spent == 0) Padding(padding: const EdgeInsets.fromLTRB(4, 4, 4, 12), child: Text('لم تُنفق شيئاً في هذه الفترة بعد.', style: TextStyle(fontSize: 17, color: p.ink2))),
      Reveal(
        i: 0,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: cardDeco(p, r: 22),
          child: Column(children: [
            Row(children: [Container(width: 18, height: 3, color: p.acc.withValues(alpha: .6)), const SizedBox(width: 8), Text('إجمالي المصروفات', style: TextStyle(color: p.ink2, fontSize: 16))]),
            Align(alignment: AlignmentDirectional.centerStart, child: CountText(spent, dec: 0, style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700))),
            Divider(color: p.line, height: 24),
            IntrinsicHeight(
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.circle, size: 9, color: kInc), const SizedBox(width: 6), Text('إجمالي الدخل', style: TextStyle(color: p.ink2))]), CountText(inc, dec: 0, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700))])),
                VerticalDivider(color: p.line, width: 24),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.circle, size: 9, color: kInc), const SizedBox(width: 6), Text('صافي الفرق', style: TextStyle(color: p.ink2))]), CountText(inc - spent, dec: 0, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700))])),
              ]),
            ),
            const SizedBox(height: 10),
            Align(alignment: AlignmentDirectional.centerStart, child: Text('متوسط ${fmt(spent / elapsed, dec: 0)} في اليوم', style: TextStyle(color: p.ink2, fontSize: 16))),
          ]),
        ),
      ),
      const SizedBox(height: 22),
      const Text('التصنيفات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      if (cats.isEmpty)
        Text('لا توجد بيانات للتصنيفات', style: TextStyle(color: p.ink2, fontSize: 16))
      else
        for (var i = 0; i < cats.length; i++)
          Reveal(
            i: i,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: cardDeco(p, r: 20),
              child: Column(children: [
                Row(children: [
                  Icon(catIcon(cats[i].key).$1, size: 22, color: catIcon(cats[i].key).$2),
                  const SizedBox(width: 10),
                  Expanded(child: Text(catOf(cats[i].key).name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                  Text(fmt(cats[i].value, dec: 0), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Text('${toAr('${(cats[i].value / spent * 100).round()}')}٪', style: TextStyle(color: p.ink2)),
                ]),
                const SizedBox(height: 10),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: cats[i].value / cats[0].value),
                  duration: Duration(milliseconds: 700 + i * 120),
                  curve: Curves.easeOutCubic,
                  builder: (c, v, _) => ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: v, minHeight: 8, backgroundColor: p.field, valueColor: AlwaysStoppedAnimation(p.acc))),
                ),
              ]),
            ),
          ),
      const SizedBox(height: 22),
      const Text('الدخل والمصروف', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Row(children: [
        Text('إجمالي المصروفات ', style: TextStyle(color: p.ink2)),
        Text(fmt(spent, dec: 0), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(width: 4),
        Container(width: 10, height: 10, decoration: BoxDecoration(color: p.acc, borderRadius: BorderRadius.circular(3))),
        const Spacer(),
        Text('إجمالي الدخل ', style: TextStyle(color: p.ink2)),
        Text(fmt(inc, dec: 0), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(width: 4),
        Container(width: 10, height: 10, decoration: BoxDecoration(color: kInc, borderRadius: BorderRadius.circular(3))),
      ]),
      const SizedBox(height: 12),
      SizedBox(
        height: 130,
        child: TweenAnimationBuilder<double>(
          key: ValueKey('${y}_$mo${a}_${spent}_$inc'),
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (c, v, _) => CustomPaint(size: Size.infinite, painter: _BarsPainter([for (final s in series) (s.$1 / maxV, s.$2 / maxV)], v, kInc, p.acc, p.field)),
        ),
      ),
      const SizedBox(height: 6),
      Row(children: [for (final s in series) Expanded(child: Center(child: Text(s.$3, style: TextStyle(fontSize: 12, color: p.ink2))))]),
      const SizedBox(height: 14),
      Divider(color: p.line),
      const SizedBox(height: 10),
      const Text('التقارير', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      Container(
        height: 52,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(18)),
        child: Stack(children: [
          AnimatedAlign(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic, alignment: days ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd, child: FractionallySizedBox(widthFactor: .5, child: Container(decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(14))))),
          Row(children: [
            Expanded(child: Tap(onTap: () => setState(() => days = true), child: Center(child: Text('الأيام', style: TextStyle(fontWeight: FontWeight.w700, color: days ? p.ink : p.ink2))))),
            Expanded(child: Tap(onTap: () => setState(() => days = false), child: Center(child: Text('الأسبوع', style: TextStyle(fontWeight: FontWeight.w700, color: days ? p.ink2 : p.ink))))),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        _tile(p, Icons.local_fire_department_rounded, p.acc, peak == 0 ? '-' : toAr('$peak'), 'يوم الذروة'),
        const SizedBox(width: 8),
        _tile(p, Icons.nights_stay_rounded, kInc, toAr('$noSpend'), 'أيام بدون إنفاق'),
        const SizedBox(width: 8),
        _tile(p, Icons.toll_rounded, const Color(0xFF5B8DEF), fmt(spent / elapsed, dec: 0), 'المتوسط اليومي'),
      ]),
      const SizedBox(height: 14),
      AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: days ? _heatmap(p, y, mo, lead, daily, mx, cur ? now.day : 99) : _week(p, y, mo, a)),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('أقل', style: TextStyle(color: p.ink2, fontSize: 13)),
        const SizedBox(width: 8),
        for (final r in [0.0, .2, .4, .7, 1.0]) Container(width: 20, height: 20, margin: const EdgeInsets.symmetric(horizontal: 2), decoration: BoxDecoration(color: _heat(p, r), borderRadius: BorderRadius.circular(6))),
        const SizedBox(width: 8),
        Text('أكثر', style: TextStyle(color: p.ink2, fontSize: 13)),
      ]),
    ]);
  }

  Widget _heatmap(Pal p, int y, int mo, int lead, List<double> daily, double mx, int today) {
    const wd = ['سب', 'أح', 'اث', 'ثل', 'أر', 'خم', 'جم'];
    final n = daily.length;
    final rows = ((lead + n) / 7).ceil();
    return Column(key: const ValueKey('h'), children: [
      Row(children: [for (final w in wd) Expanded(child: Center(child: Text(w, style: TextStyle(color: p.ink2, fontSize: 13))))]),
      const SizedBox(height: 6),
      for (var r = 0; r < rows; r++)
        Row(children: [
          for (var c = 0; c < 7; c++)
            Expanded(
              child: Builder(builder: (ctx) {
                final d = r * 7 + c - lead + 1;
                if (d < 1 || d > n) return const SizedBox(height: 46);
                final v = daily[d - 1];
                final ratio = mx > 0 ? v / mx : 0.0;
                return TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: Duration(milliseconds: 260 + d * 16),
                  curve: Curves.easeOutBack,
                  builder: (c2, s, child) => Transform.scale(scale: s.clamp(0.0, 1.15), child: child),
                  child: Tap(
                    onTap: () => _dayDetail(DateTime(y, mo, d)),
                    child: Container(
                      height: 42,
                      margin: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(color: d > today ? p.field.withValues(alpha: .4) : _heat(p, ratio), borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.center,
                      child: Text(toAr('$d'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: ratio > .5 ? Colors.white : p.ink2)),
                    ),
                  ),
                );
              }),
            ),
        ]),
    ]);
  }

  Widget _week(Pal p, int y, int mo, String a) {
    const wd = ['سب', 'أح', 'اث', 'ثل', 'أر', 'خم', 'جم'];
    final tot = List<double>.filled(7, 0), cnt = List<int>.filled(7, 0);
    final dl = repo.daily(y, mo, acc: a);
    for (var d = 1; d <= dl.length; d++) {
      final i = (DateTime(y, mo, d).weekday + 1) % 7;
      tot[i] += dl[d - 1];
      cnt[i]++;
    }
    final avg = [for (var i = 0; i < 7; i++) cnt[i] == 0 ? 0.0 : tot[i] / cnt[i]];
    final mx = avg.fold(0.0, math.max);
    return SizedBox(
      key: const ValueKey('w'),
      height: 170,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(fmt(avg[i], dec: 0), style: TextStyle(fontSize: 11, color: p.ink2)),
              const SizedBox(height: 4),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: mx == 0 ? 0 : avg[i] / mx),
                duration: Duration(milliseconds: 600 + i * 90),
                curve: Curves.easeOutBack,
                builder: (c, v, _) => Container(height: 6 + 100 * v.clamp(0.0, 1.2), margin: const EdgeInsets.symmetric(horizontal: 6), decoration: BoxDecoration(color: _heat(p, mx == 0 ? 0 : avg[i] / mx), borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 6),
              Text(wd[i], style: TextStyle(color: p.ink2, fontSize: 13)),
            ]),
          ),
      ]),
    );
  }

  void _dayDetail(DateTime d) {
    final list = repo.allTx.where((t) => sameDay(t.date, d) && (widget.acc.isEmpty || t.acc == widget.acc)).toList();
    showSheet<void>(context, (c) => SheetFrame(
          title: dateLabel(d),
          child: list.isEmpty ? Padding(padding: const EdgeInsets.only(bottom: 20), child: emptyState(Pal.of(c), Icons.bedtime_rounded, 'يوم بلا معاملات')) : ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), children: [for (final t in list) TxTile(t)]),
        ));
  }
}

class _BarsPainter extends CustomPainter {
  final List<(double, double)> d;
  final double t;
  final Color inc, exp, base;
  _BarsPainter(this.d, this.t, this.inc, this.exp, this.base);
  @override
  void paint(Canvas canvas, Size s) {
    final slot = s.width / d.length;
    final bw = math.min(22.0, slot * .3);
    for (var j = 0; j < d.length; j++) {
      // الأقدم على اليمين (تدفّق RTL)
      final cx = s.width - (j + .5) * slot;
      final e = d[j];
      void bar(double x, double v, Color c) {
        final h = (v * (s.height - 8) * t).clamp(0.0, s.height);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - bw / 2, s.height - math.max(h, 4), bw, math.max(h, 4)), const Radius.circular(6)), Paint()..color = v == 0 ? base : c);
      }

      bar(cx - bw * .6, e.$1, inc);
      bar(cx + bw * .6, e.$2, exp);
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter o) => o.t != t || o.d != d;
}
