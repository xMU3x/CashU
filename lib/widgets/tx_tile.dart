import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/categories.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../data/models.dart';
import '../data/providers.dart';

class TxTile extends ConsumerWidget {
  const TxTile({super.key, required this.tx, required this.accounts});
  final Tx tx;
  final List<Account> accounts;

  String _acc(String? id) {
    for (final a in accounts) {
      if (a.id == id) return a.name;
    }
    return '—';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = tx;
    late String title, emoji, sign;
    late Color color;
    switch (t.type) {
      case TxType.expense:
        final c = catById(t.categoryId);
        title = c?.label ?? 'مصروف';
        emoji = c?.emoji ?? '💸';
        sign = '-';
        color = kExpense;
      case TxType.income:
        final c = catById(t.categoryId);
        title = c?.label ?? 'دخل';
        emoji = c?.emoji ?? '💰';
        sign = '+';
        color = kIncome;
      case TxType.transfer:
        title = '${_acc(t.accountId)} ← ${_acc(t.toAccountId)}';
        emoji = '🔁';
        sign = '';
        color = kTransfer;
      case TxType.loan:
        title = t.iOwe
            ? 'سلفة من ${t.person ?? ''}'
            : 'سلّفت ${t.person ?? ''}';
        emoji = '🤝';
        sign = t.iOwe ? '+' : '-';
        color = kLoan;
    }
    final sub = [dayLabel(t.date), if ((t.note ?? '').isNotEmpty) t.note!]
        .join(' · ');

    return Dismissible(
      key: ValueKey(t.id),
      direction: DismissDirection.horizontal,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.center,
        child: const Icon(Icons.delete_outline),
      ),
      onDismissed: (_) => ref.read(repoProvider).deleteTx(t.id),
      child: ListTile(
        leading: CircleAvatar(child: Text(emoji)),
        title: Text(title),
        subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text('$sign${money(t.amount)}',
            style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
