import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/store.dart';
import '../core/sync.dart';
import 'models.dart';
import 'repository.dart';

final storeProvider = ChangeNotifierProvider<Store>((ref) => store);
final syncProvider = ChangeNotifierProvider<SyncService>((ref) => sync);

final repoProvider = Provider<Repo>((ref) => Repo());

final accountsProvider = Provider<List<Account>>((ref) {
  ref.watch(storeProvider);
  return ref.read(repoProvider).accounts();
});

final txProvider = Provider<List<Tx>>((ref) {
  ref.watch(storeProvider);
  return ref.read(repoProvider).txs();
});

final monthProvider = StateProvider<DateTime>((ref) {
  final n = DateTime.now();
  return DateTime(n.year, n.month);
});

/// رصيد كل حساب = الرصيد الافتتاحي + كل حركاته.
final balancesProvider = Provider<Map<String, double>>((ref) {
  final accs = ref.watch(accountsProvider);
  final txs = ref.watch(txProvider);
  return computeBalances(accs, txs);
});

Map<String, double> computeBalances(List<Account> accs, List<Tx> txs) {
  final b = {for (final a in accs) a.id: a.initialBalance};
  void add(String? id, double v) {
    if (id != null && b.containsKey(id)) b[id] = b[id]! + v;
  }

  for (final t in txs) {
    switch (t.type) {
      case TxType.expense:
        add(t.accountId, -t.amount);
      case TxType.income:
        add(t.accountId, t.amount);
      case TxType.transfer:
        add(t.accountId, -t.amount);
        add(t.toAccountId, t.amount);
      case TxType.loan:
        add(t.accountId, t.iOwe ? t.amount : -t.amount);
    }
  }
  return b;
}
