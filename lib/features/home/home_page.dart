import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../widgets/inbox_banner.dart';
import '../../widgets/tx_tile.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(syncProvider).user?.userMetadata;
    final fullName = (meta?['full_name'] ?? meta?['name'] ?? '').toString();
    final accs = ref.watch(accountsProvider);
    final txs = ref.watch(txProvider);
    final now = DateTime.now();
    final s = summarize(txs, DateTime(now.year, now.month));
    final budget = accs.fold<double>(0, (p, a) => p + a.monthlyBudget);
    final remaining = budget - s.expense;
    final daysLeft = DateUtils.getDaysInMonth(now.year, now.month) - now.day + 1;
    final daily = budget > 0 && daysLeft > 0 ? remaining / daysLeft : null;
    final first = fullName.split(' ').first;
    final tt = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Text(first.isEmpty ? 'مرحباً' : 'مرحباً $first', style: tt.titleLarge),
        const SizedBox(height: 12),
        _BudgetCard(
          spent: s.expense,
          budget: budget,
          remaining: remaining,
          income: s.income,
          month: monthLabel(now),
        ),
        const InboxBanner(),
        if (daily != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ListTile(
              tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              leading: const Icon(Icons.speed),
              title: Text('متاح ${money(daily < 0 ? 0 : daily)} يوميًا'),
              subtitle: Text('باقٍ $daysLeft يومًا في الشهر'),
            ),
          ),
        const SizedBox(height: 20),
        Text('آخر المعاملات', style: tt.titleMedium),
        if (txs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('لا توجد معاملات بعد. اضغط + للإضافة.')),
          ),
        for (final t in txs.take(10)) TxTile(tx: t, accounts: accs),
      ],
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.spent,
    required this.budget,
    required this.remaining,
    required this.income,
    required this.month,
  });
  final double spent, budget, remaining, income;
  final String month;

  @override
  Widget build(BuildContext context) {
    final p = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    Widget stat(String l, String v, {Color? c}) => Expanded(
          child: Column(children: [
            Text(l, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 4),
            Text(v,
                style: TextStyle(
                    color: c ?? Colors.white, fontWeight: FontWeight.w700)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('المصروف · $month',
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(money(spent),
              style: const TextStyle(
                  color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: p,
              minHeight: 8,
              backgroundColor: Colors.white12,
              color: p > .9 ? Colors.redAccent : Colors.tealAccent,
            ),
          ),
          const SizedBox(height: 18),
          Row(children: [
            stat('الميزانية', budget > 0 ? money(budget) : '—'),
            stat('المتبقي', budget > 0 ? money(remaining) : '—',
                c: remaining < 0 ? Colors.redAccent : null),
            stat('دخل الشهر', money(income), c: Colors.greenAccent),
          ]),
        ],
      ),
    );
  }
}
