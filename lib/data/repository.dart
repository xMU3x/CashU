import 'dart:math';
import '../core/store.dart';
import 'models.dart';

String _newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${Random().nextInt(1 << 24).toRadixString(36)}';

/// طبقة بيانات محلية: كل شيء بيتكتب في [store] (والمزامنة بتشتغل لوحدها فوقه).
/// السجلات: id → {..بيانات.., u: وقت التعديل}، والحذف = {id, d: true, u}.
class Repo {
  Iterable<Map<String, dynamic>> _live(String key) => store
      .peekMap(key)
      .values
      .whereType<Map>()
      .where((m) => m['d'] != true)
      .map((m) => Map<String, dynamic>.from(m));

  List<Account> accounts() {
    final l = _live('accounts').map(Account.fromMap).toList();
    l.sort((a, b) => a.name.compareTo(b.name));
    return l;
  }

  List<Tx> txs() {
    final l = _live('transactions').map(Tx.fromMap).toList();
    l.sort((a, b) => b.date.compareTo(a.date));
    return l;
  }

  void _put(String key, String id, Map<String, dynamic> rec) =>
      store.upd(key, (m) => m[id] = rec);

  int get _now => DateTime.now().millisecondsSinceEpoch;

  Future<void> saveAccount(Account a) async {
    final id = a.id.isEmpty ? _newId() : a.id;
    final m = Account(
      id: id,
      name: a.name,
      type: a.type,
      last4: a.last4,
      initialBalance: a.initialBalance,
      monthlyBudget: a.monthlyBudget,
    ).toMap();
    _put('accounts', id, {...m, 'u': _now});
  }

  Future<void> deleteAccount(String id) async =>
      _put('accounts', id, {'id': id, 'd': true, 'u': _now});

  Future<void> addTx(Tx t) async {
    final id = _newId();
    final m = Tx(
      id: id,
      type: t.type,
      amount: t.amount,
      accountId: t.accountId,
      date: t.date,
      toAccountId: t.toAccountId,
      categoryId: t.categoryId,
      note: t.note,
      person: t.person,
      iOwe: t.iOwe,
      dueDate: t.dueDate,
    ).toMap();
    _put('transactions', id, {...m, 'u': _now});
  }

  Future<void> deleteTx(String id) async =>
      _put('transactions', id, {'id': id, 'd': true, 'u': _now});

  /// أول تشغيل: حساب "نقدي" افتراضي بمعرّف ثابت (u=0 عشان أي تعديل حقيقي يكسب عند الدمج).
  Future<void> ensureDefaults() async {
    if (store.has('accounts')) return;
    final m = const Account(id: 'cash', name: 'نقدي', type: 'cash').toMap();
    _put('accounts', 'cash', {...m, 'u': 0});
  }
}
