enum TxType { expense, income, transfer, loan }

double _d(dynamic v) => v is num ? v.toDouble() : 0;
DateTime? _dt(dynamic v) =>
    v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;

class Account {
  final String id, name, type, last4;
  final double initialBalance, monthlyBudget;
  const Account({
    required this.id,
    required this.name,
    this.type = 'bank',
    this.last4 = '',
    this.initialBalance = 0,
    this.monthlyBudget = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'last4': last4,
        'initialBalance': initialBalance,
        'monthlyBudget': monthlyBudget,
      };

  factory Account.fromMap(Map<String, dynamic> m) => Account(
        id: m['id'] ?? '',
        name: m['name'] ?? '',
        type: m['type'] ?? 'bank',
        last4: m['last4'] ?? '',
        initialBalance: _d(m['initialBalance']),
        monthlyBudget: _d(m['monthlyBudget']),
      );
}

class Tx {
  final String id;
  final TxType type;
  final double amount;
  final String accountId;
  final String? toAccountId, categoryId, note, person;

  /// للسلف: true = أنا مديون (استلفت)، false = ليّا فلوس عند حد (سلّفت).
  final bool iOwe;
  final DateTime date;
  final DateTime? dueDate;

  const Tx({
    required this.id,
    required this.type,
    required this.amount,
    required this.accountId,
    required this.date,
    this.toAccountId,
    this.categoryId,
    this.note,
    this.person,
    this.iOwe = false,
    this.dueDate,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'accountId': accountId,
        'toAccountId': toAccountId,
        'categoryId': categoryId,
        'note': note,
        'person': person,
        'iOwe': iOwe,
        'date': date.millisecondsSinceEpoch,
        'dueDate': dueDate?.millisecondsSinceEpoch,
      };

  factory Tx.fromMap(Map<String, dynamic> m) => Tx(
        id: m['id'] ?? '',
        type: TxType.values.asNameMap()[m['type']] ?? TxType.expense,
        amount: _d(m['amount']),
        accountId: m['accountId'] ?? '',
        toAccountId: m['toAccountId'],
        categoryId: m['categoryId'],
        note: m['note'],
        person: m['person'],
        iOwe: m['iOwe'] ?? false,
        date: _dt(m['date']) ?? DateTime.now(),
        dueDate: _dt(m['dueDate']),
      );
}
