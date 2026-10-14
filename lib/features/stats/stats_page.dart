import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/categories.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

const _palette = [
  Color(0xFF2B4BCF), Color(0xFF2E7D6B), Color(0xFFC8962B), Color(0xFF9B4A38),
  Color(0xFF8E44AD), Color(0xFF16A085), Color(0xFFE67E22), Color(0xFF7F8C8D),
];

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(txProvider);
    final month = ref.watch(monthProvider);
    final s = summarize(txs, month);
    final tt = Theme.of(context).textTheme;
    final cats = s.byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // آخر 6 شهور
    final months = [
      for (var i = 5; i >= 0; i--) DateTime(month.year, month.month - i)
    ];
    final sums = [for (final m in months) summarize(txs, m)];
    final maxY = sums.fold<double>(
        1, (p, x) => [p, x.income, x.expense].reduce((a, b) => a > b ? a : b));

    void shift(int d) => ref.read(monthProvider.notifier).state =
        DateTime(month.year, month.month + d);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
                onPressed: () => shift(-1),
                icon: const Icon(Icons.chevron_right)),
            Text(monthLabel(month), style: tt.titleLarge),
            IconButton(
                onPressed: () => shift(1), icon: const Icon(Icons.chevron_left)),
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              _stat('إجمالي الدخل', s.income, kIncome),
              _stat('إجمالي المصروفات', s.expense, kExpense),
              _stat('الصافي', s.income - s.expense, kTransfer),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Text('التصنيفات', style: tt.titleMedium),
        const SizedBox(height: 8),
        if (cats.isEmpty)
          const Text('لا توجد بيانات للتصنيفات')
        else ...[
          SizedBox(
            height: 180,
            child: PieChart(PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 44,
              sections: [
                for (var i = 0; i < cats.length; i++)
                  PieChartSectionData(
                    value: cats[i].value,
                    color: _palette[i % _palette.length],
                    title: '',
                    radius: 40,
                  ),
              ],
            )),
          ),
          for (var i = 0; i < cats.length; i++)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                  radius: 6, backgroundColor: _palette[i % _palette.length]),
              title: Text(
                  '${catById(cats[i].key)?.emoji ?? ''} ${catById(cats[i].key)?.label ?? cats[i].key}'),
              trailing: Text(
                  '${money(cats[i].value)}  (${(cats[i].value / s.expense * 100).round()}%)'),
            ),
        ],
        const SizedBox(height: 16),
        Text('الدخل والمصروف', style: tt.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: BarChart(BarChartData(
            maxY: maxY * 1.15,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(DateFormat.MMM('ar').format(months[v.toInt()]),
                        style: const TextStyle(fontSize: 11)),
                  ),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < months.length; i++)
                BarChartGroupData(x: i, barsSpace: 3, barRods: [
                  BarChartRodData(
                      toY: sums[i].income, color: kIncome, width: 9,
                      borderRadius: BorderRadius.circular(3)),
                  BarChartRodData(
                      toY: sums[i].expense, color: kExpense, width: 9,
                      borderRadius: BorderRadius.circular(3)),
                ]),
            ],
          )),
        ),
        const SizedBox(height: 8),
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.circle, size: 10, color: kIncome),
          SizedBox(width: 4),
          Text('دخل'),
          SizedBox(width: 16),
          Icon(Icons.circle, size: 10, color: kExpense),
          SizedBox(width: 4),
          Text('مصروف'),
        ]),
      ],
    );
  }

  Widget _stat(String l, double v, Color c) => Expanded(
        child: Column(children: [
          Text(l, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(money(v),
              style: TextStyle(color: c, fontWeight: FontWeight.w700)),
        ]),
      );
}
