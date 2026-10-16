double _d(dynamic v, [double d = 0]) => v is num ? v.toDouble() : d;
int _i(dynamic v, [int d = 0]) => v is num ? v.toInt() : d;
String _s(dynamic v, [String d = '']) => v is String ? v : d;
bool _b(dynamic v, [bool d = false]) => v is bool ? v : d;

class Cat {
  final String id, name, emoji;
  final List<String> subs;
  const Cat(this.id, this.name, this.emoji, [this.subs = const []]);
}

const kExpCats = <Cat>[
  Cat('bills', 'فواتير', '🧾', ['كهرباء', 'مياه', 'غاز', 'رسوم النظافة']),
  Cat('food', 'طعام وشراب', '🍔', ['مطاعم', 'بقالة', 'قهوة']),
  Cat('transport', 'مواصلات', '🚌', ['وقود', 'أوبر', 'صيانة']),
  Cat('shop', 'تسوق', '🛍️', ['ملابس', 'إلكترونيات']),
  Cat('health', 'صحة', '💊', ['دواء', 'كشف']),
  Cat('fun', 'ترفيه', '🎬'),
  Cat('edu', 'تعليم', '🎓'),
  Cat('home', 'منزل', '🏠', ['إيجار', 'صيانة']),
  Cat('other', 'أخرى', '📦'),
];
const kIncCats = <Cat>[
  Cat('salary', 'راتب', '💼'),
  Cat('free', 'عمل حر', '💻'),
  Cat('gift', 'هدية', '🎁'),
  Cat('invest', 'استثمار', '📈'),
  Cat('other_i', 'دخل', '💰'),
];
Cat catOf(String id) {
  for (final c in [...kExpCats, ...kIncCats]) {
    if (c.id == id) return c;
  }
  return kExpCats.last;
}

class Budget {
  String id, name;
  double limit;
  bool del;
  int u;
  Budget({required this.id, required this.name, this.limit = 0, this.del = false, this.u = 0});
  factory Budget.fromJson(Map<String, dynamic> j) =>
      Budget(id: _s(j['id']), name: _s(j['name'], 'الميزانية الرئيسية'), limit: _d(j['limit']), del: _b(j['del']), u: _i(j['u']));
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'limit': limit, 'del': del, 'u': u};
}

class Account {
  String id, name, kind, last4, bud, grp, info, icon;
  double start;
  bool showBud, del, nw, gb, ac, arch;
  int u;
  Account({required this.id, required this.name, this.kind = 'bank', this.last4 = '', this.bud = 'bud_main', this.grp = '', this.info = '', this.icon = '', this.start = 0, this.showBud = true, this.del = false, this.nw = true, this.gb = true, this.ac = true, this.arch = false, this.u = 0});
  factory Account.fromJson(Map<String, dynamic> j) => Account(
      id: _s(j['id']), name: _s(j['name']), kind: _s(j['kind'], 'bank'), last4: _s(j['last4']), bud: _s(j['bud'], 'bud_main'),
      grp: _s(j['grp']), info: _s(j['info']), icon: _s(j['icon']), start: _d(j['start']), showBud: _b(j['showBud'], true), del: _b(j['del']),
      nw: _b(j['nw'], true), gb: _b(j['gb'], true), ac: _b(j['ac'], true), arch: _b(j['arch']), u: _i(j['u']));
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'kind': kind, 'last4': last4, 'bud': bud, 'grp': grp, 'info': info, 'icon': icon, 'start': start,
        'showBud': showBud, 'del': del, 'nw': nw, 'gb': gb, 'ac': ac, 'arch': arch, 'u': u,
      };

  /// اسم المجموعة كما في الشاشة (cash / bank / credit / ewallet / debit).
  String get group {
    if (grp.isNotEmpty) return grp;
    switch (kind) {
      case 'cash':
        return 'Cash';
      case 'wallet':
        return 'eWallets';
      case 'credit':
        return 'Credit';
      case 'debit':
        return 'Debit Cards';
      default:
        return 'Bank Accounts';
    }
  }
}

/// type: exp | inc | xfer | loan | adj (تسوية رصيد: sign=±1)
class Tx {
  String id, type, cur, acc, to, cat, sub, note, rep, src, loan, pay;
  double amt, rate;
  int ts, nx, u, sign;
  bool del, pend;
  Tx({required this.id, required this.type, required this.amt, this.cur = 'EGP', this.rate = 1, required this.acc, this.to = '', this.cat = '', this.sub = '', this.note = '', required this.ts, this.rep = 'none', this.nx = 0, this.src = '', this.loan = '', this.sign = 0, this.pay = '', this.pend = false, this.del = false, this.u = 0});
  double get base => amt * rate;
  DateTime get date => DateTime.fromMillisecondsSinceEpoch(ts);
  factory Tx.fromJson(Map<String, dynamic> j) => Tx(
      id: _s(j['id']), type: _s(j['type'], 'exp'), amt: _d(j['amt']), cur: _s(j['cur'], 'EGP'), rate: _d(j['rate'], 1), acc: _s(j['acc']),
      to: _s(j['to']), cat: _s(j['cat']), sub: _s(j['sub']), note: _s(j['note']), ts: _i(j['ts']), rep: _s(j['rep'], 'none'), nx: _i(j['nx']),
      src: _s(j['src']), loan: _s(j['loan']), sign: _i(j['sign']), pay: _s(j['pay']), pend: _b(j['pend']), del: _b(j['del']), u: _i(j['u']));
  Map<String, dynamic> toJson() => {
        'id': id, 'type': type, 'amt': amt, 'cur': cur, 'rate': rate, 'acc': acc, 'to': to, 'cat': cat, 'sub': sub, 'note': note,
        'ts': ts, 'rep': rep, 'nx': nx, 'src': src, 'loan': loan, 'sign': sign, 'pay': pay, 'pend': pend, 'del': del, 'u': u,
      };
  Tx clone() => Tx.fromJson(toJson());
}

/// dir: owe (عليّا فلوس) | owed (ليّا فلوس)
class Loan {
  String id, dir, person, cur, acc, note;
  double amt, rate;
  int due, ts, u;
  bool settled, del;
  Loan({required this.id, required this.dir, required this.person, required this.amt, this.cur = 'EGP', this.rate = 1, this.acc = '', this.due = 0, this.note = '', required this.ts, this.settled = false, this.del = false, this.u = 0});
  double get base => amt * rate;
  factory Loan.fromJson(Map<String, dynamic> j) => Loan(
      id: _s(j['id']), dir: _s(j['dir'], 'owe'), person: _s(j['person']), amt: _d(j['amt']), cur: _s(j['cur'], 'EGP'), rate: _d(j['rate'], 1),
      acc: _s(j['acc']), due: _i(j['due']), note: _s(j['note']), ts: _i(j['ts']), settled: _b(j['settled']), del: _b(j['del']), u: _i(j['u']));
  Map<String, dynamic> toJson() => {
        'id': id, 'dir': dir, 'person': person, 'amt': amt, 'cur': cur, 'rate': rate, 'acc': acc, 'due': due, 'note': note,
        'ts': ts, 'settled': settled, 'del': del, 'u': u,
      };
}

class Goal {
  String id, name, emoji;
  double target, saved;
  bool del;
  int u;
  Goal({required this.id, required this.name, this.emoji = '🎯', this.target = 0, this.saved = 0, this.del = false, this.u = 0});
  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
      id: _s(j['id']), name: _s(j['name']), emoji: _s(j['emoji'], '🎯'), target: _d(j['target']), saved: _d(j['saved']), del: _b(j['del']), u: _i(j['u']));
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'emoji': emoji, 'target': target, 'saved': saved, 'del': del, 'u': u};
}
