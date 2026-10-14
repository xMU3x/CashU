import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accs = ref.watch(accountsProvider);
    final bal = ref.watch(balancesProvider);
    final total = bal.values.fold<double>(0, (p, v) => p + v);
    final tt = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(children: [
            Text(money(total),
                style: tt.headlineMedium?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w800)),
            const Text('إجمالي أموالك', style: TextStyle(color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 12),
        for (final a in accs)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                  child: Icon(a.type == 'cash'
                      ? Icons.payments_outlined
                      : Icons.account_balance)),
              title: Text(a.name),
              subtitle: Text([
                a.type == 'cash' ? 'نقدي' : 'حساب بنكي',
                if (a.last4.isNotEmpty) '•••• ${a.last4}',
                if (a.monthlyBudget > 0) 'ميزانية ${money(a.monthlyBudget)}',
              ].join(' · ')),
              trailing: Text(money(bal[a.id] ?? 0),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () => _edit(context, ref, a),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _edit(context, ref, null),
          icon: const Icon(Icons.add),
          label: const Text('إضافة حساب'),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Account? a) async {
    final name = TextEditingController(text: a?.name ?? '');
    final last4 = TextEditingController(text: a?.last4 ?? '');
    final init = TextEditingController(
        text: a == null ? '' : a.initialBalance.toString());
    final budget = TextEditingController(
        text: a == null || a.monthlyBudget == 0 ? '' : a.monthlyBudget.toString());
    var type = a?.type ?? 'bank';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(a == null ? 'حساب جديد' : 'تعديل الحساب'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'bank', label: Text('بنكي')),
                  ButtonSegment(value: 'cash', label: Text('نقدي')),
                ],
                selected: {type},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setS(() => type = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'الاسم')),
              const SizedBox(height: 8),
              TextField(
                  controller: last4,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'آخر 4 أرقام (اختياري)', counterText: '')),
              const SizedBox(height: 8),
              TextField(
                  controller: init,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'الرصيد الافتتاحي')),
              const SizedBox(height: 8),
              TextField(
                  controller: budget,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'ميزانية الشهر (اختياري)')),
            ]),
          ),
          actions: [
            if (a != null)
              TextButton(
                onPressed: () async {
                  await ref.read(repoProvider).deleteAccount(a.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text('حذف',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              ),
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                await ref.read(repoProvider).saveAccount(Account(
                      id: a?.id ?? '',
                      name: name.text.trim(),
                      type: type,
                      last4: last4.text.trim(),
                      initialBalance: parseAmount(init.text) ?? 0,
                      monthlyBudget: parseAmount(budget.text) ?? 0,
                    ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
