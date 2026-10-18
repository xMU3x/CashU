import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Color;
import 'cat_icons.dart';
import 'models.dart';
import 'settings.dart';
import 'store.dart';
import 'util.dart';

int _now() => DateTime.now().millisecondsSinceEpoch;

/// موعد التكرار التالي بعد [ms].
int nextOcc(int ms, String rep) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  if (rep == 'daily') { return DateTime(d.year, d.month, d.day + 1, d.hour, d.minute).millisecondsSinceEpoch; }
  if (rep == 'weekly') { return DateTime(d.year, d.month, d.day + 7, d.hour, d.minute).millisecondsSinceEpoch; }
  final ny = d.month == 12 ? d.year + 1 : d.year;
  final nm = d.month == 12 ? 1 : d.month + 1;
  final day = d.day > daysIn(ny, nm) ? daysIn(ny, nm) : d.day;
  return DateTime(ny, nm, day, d.hour, d.minute).millisecondsSinceEpoch;
}

String txTitle(Tx t) {
  if (t.note.isNotEmpty) return t.note;
  if (t.type == 'adj') return 'New balance';
  if (t.type == 'xfer') return 'تحويل';
  if (t.type == 'loan') return t.sign < 0 ? 'سلفة (ليّا)' : 'سلفة (عليّا)';
  if (t.sub.isNotEmpty) return t.sub;
  if (t.type == 'inc') return catOf(t.cat.isEmpty ? 'other_i' : t.cat).name;
  return catOf(t.cat).name;
}

class Repo extends ChangeNotifier {
  Map<String, Account> _acc = {};
  Map<String, Budget> _bud = {};
  Map<String, Tx> _tx = {};
  Map<String, Loan> _loan = {};
  Map<String, Goal> _goal = {};
  Map<String, List<String>> _subs = {};
  Map<String, CatDef> _ctg = {};
  bool _seeding = false;

  void init() {
    if (!store.has('tyr_bud')) {
      store.set('tyr_bud', {'bud_main': Budget(id: 'bud_main', name: 'الميزانية الرئيسية', u: 1).toJson()});
    }
    if (!store.has('tyr_acc')) {
      store.set('tyr_acc', {'acc_main': Account(id: 'acc_main', name: 'الحساب الرئيسي', u: 1).toJson()});
    }
    load();
    store.changes.listen((k) {
      if (k.startsWith('tyr_')) {
        load();
        notifyListeners();
      }
    });
    seedCats();
  }

  Map<String, T> _read<T>(String k, T Function(Map<String, dynamic>) f) {
    final out = <String, T>{};
    store.peekMap(k).forEach((id, v) {
      if (v is Map) out[id] = f(Map<String, dynamic>.from(v));
    });
    return out;
  }

  void load() {
    _acc = _read('tyr_acc', Account.fromJson);
    _bud = _read('tyr_bud', Budget.fromJson);
    _tx = _read('tyr_tx', Tx.fromJson);
    _loan = _read('tyr_loan', Loan.fromJson);
    _goal = _read('tyr_goal', Goal.fromJson);
    _ctg = _read('tyr_ctg', CatDef.fromJson);
    catLookup = _lookupCat;
    _subs = {};
    store.peekMap('tyr_cat').forEach((k, v) {
      if (v is List) _subs[k] = v.map((e) => '$e').toList();
    });
  }

  void _put(String k, String id, Map<String, dynamic> j) {
    final m = store.getMap(k);
    m[id] = j;
    store.set(k, m);
    load();
    notifyListeners();
  }

  // ---------- الحسابات والميزانيات ----------
  List<Account> get accList => (_acc.values.where((a) => !a.del && !a.arch).toList()
    ..sort((a, b) => a.id == 'acc_main' ? -1 : b.id == 'acc_main' ? 1 : a.id.compareTo(b.id)));
  Account? account(String id) => _acc[id];
  String get defaultAcc => accList.isEmpty ? 'acc_main' : accList.first.id;
  void saveAccount(Account a) {
    a.u = _now();
    _put('tyr_acc', a.id, a.toJson());
  }

  bool deleteAccount(String id) {
    if (accList.length <= 1) return false;
    final a = _acc[id];
    if (a == null) return false;
    a.del = true;
    saveAccount(a);
    return true;
  }

  Budget budgetFor(Account a) => _bud[a.bud] ?? _bud['bud_main'] ?? Budget(id: 'bud_main', name: 'الميزانية الرئيسية');
  void saveBudget(Budget b) {
    b.u = _now();
    _put('tyr_bud', b.id, b.toJson());
  }

  // ---------- المعاملات ----------
  List<Tx> get allTx => (_tx.values.where((t) => !t.del).toList()..sort((a, b) => b.ts.compareTo(a.ts)));
  Tx? tx(String id) => _tx[id];
  void saveTx(Tx t) {
    t.u = _now();
    _put('tyr_tx', t.id, t.toJson());
  }

  void delTx(String id) {
    final t = _tx[id];
    if (t == null) return;
    t.del = true;
    saveTx(t);
  }

  void restoreTx(String id) {
    final t = _tx[id];
    if (t == null) return;
    t.del = false;
    saveTx(t);
  }

  // ---------- الحسابات الرقمية ----------
  double bal(String accId) {
    final a = _acc[accId];
    var b = a?.start ?? 0;
    for (final t in _tx.values) {
      if (t.del || t.pend) continue;
      final v = t.base;
      switch (t.type) {
        case 'adj':
          if (t.acc == accId) b += t.sign * v;
          break;
        case 'inc':
          if (t.acc == accId) b += v;
          break;
        case 'exp':
          if (t.acc == accId) b -= v;
          break;
        case 'xfer':
          if (t.acc == accId) b -= v;
          if (t.to == accId) b += v;
          break;
        case 'loan':
          if (t.acc == accId) b += t.sign * v;
          break;
      }
    }
    return b;
  }

  /// رصيد الحساب في نهاية اللحظة [before] (للشرائح الشهرية).
  double balAt(String accId, DateTime before) {
    var b = _acc[accId]?.start ?? 0;
    final lim = before.millisecondsSinceEpoch;
    for (final t in _tx.values) {
      if (t.del || t.pend || t.ts >= lim) continue;
      final v = t.base;
      switch (t.type) {
        case 'adj':
          if (t.acc == accId) b += t.sign * v;
          break;
        case 'inc':
          if (t.acc == accId) b += v;
          break;
        case 'exp':
          if (t.acc == accId) b -= v;
          break;
        case 'xfer':
          if (t.acc == accId) b -= v;
          if (t.to == accId) b += v;
          break;
        case 'loan':
          if (t.acc == accId) b += t.sign * v;
          break;
      }
    }
    return b;
  }

  /// كل معاملات حساب (أو الكل لو [accId] فاضي) — الأحدث أولًا.
  List<Tx> txOf(String? accId) => allTx.where((t) => accId == null || accId.isEmpty || t.acc == accId || t.to == accId).toList();

  /// مجموع الالتزامات: ديون عليّا + عجز بطاقات الائتمان.
  double get liabilities {
    var v = 0.0;
    for (final l in loanList) {
      if (!l.settled && l.dir == 'owe') v += l.base;
    }
    for (final a in accList) {
      if (a.kind == 'credit') {
        final b = bal(a.id);
        if (b < 0) v += -b;
      }
    }
    return v;
  }

  double get netWorth {
    var v = 0.0;
    for (final a in accList) {
      if (a.nw) v += bal(a.id);
    }
    return v - liabilities;
  }

  double get totalBal => accList.fold(0.0, (s, a) => s + bal(a.id));

  Iterable<Tx> inMonth(int y, int m, {String? acc}) => allTx.where((t) {
        final d = t.date;
        return d.year == y && d.month == m && (acc == null || acc.isEmpty || t.acc == acc || t.to == acc);
      });

  double spent(int y, int m, {String? acc}) => inMonth(y, m, acc: acc).where((t) => t.type == 'exp').fold(0.0, (s, t) => s + t.base);
  double income(int y, int m, {String? acc}) => inMonth(y, m, acc: acc).where((t) => t.type == 'inc').fold(0.0, (s, t) => s + t.base);

  double budgetSpent(String budId, int y, int m) => inMonth(y, m)
      .where((t) => t.type == 'exp' && (_acc[t.acc]?.bud ?? 'bud_main') == budId)
      .fold(0.0, (s, t) => s + t.base);

  List<double> daily(int y, int m, {String? acc}) {
    final out = List<double>.filled(daysIn(y, m), 0);
    for (final t in inMonth(y, m, acc: acc)) {
      if (t.type == 'exp') out[t.date.day - 1] += t.base;
    }
    return out;
  }

  List<MapEntry<String, double>> byCat(int y, int m, {String? acc}) {
    final mp = <String, double>{};
    for (final t in inMonth(y, m, acc: acc)) {
      if (t.type == 'exp') mp[t.cat] = (mp[t.cat] ?? 0) + t.base;
    }
    return mp.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  /// المتاح يوميًا من ميزانية الحساب.
  double allowance(Account a, DateTime now) {
    final b = budgetFor(a);
    if (b.limit <= 0) return 0;
    final left = b.limit - budgetSpent(b.id, now.year, now.month);
    final days = daysIn(now.year, now.month) - now.day + 1;
    return left / days;
  }

  int get streak {
    int key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
    final days = allTx.where((t) => t.src.isEmpty).map((t) => key(t.date)).toSet();
    var d = DateTime.now();
    if (!days.contains(key(d))) d = DateTime(d.year, d.month, d.day - 1);
    var n = 0;
    while (days.contains(key(d))) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }

  int get coins {
    final days = allTx.map((t) => t.date.year * 10000 + t.date.month * 100 + t.date.day).toSet().length;
    final c = days * 5 + streak * 2 - S.num_('spent').toInt();
    return c < 0 ? 0 : c;
  }

  // ---------- المتكررة ----------
  void runRecurring() {
    final now = _now();
    for (final t in _tx.values.toList()) {
      if (t.del || t.rep == 'none' || t.rep.isEmpty) continue;
      var nx = t.nx == 0 ? nextOcc(t.ts, t.rep) : t.nx;
      var guard = 0;
      while (nx <= now && guard++ < 400) {
        final inst = t.clone()
          ..id = '${t.id}_$nx'
          ..src = t.id
          ..ts = nx
          ..rep = 'none'
          ..nx = 0;
        if (!_tx.containsKey(inst.id)) saveTx(inst);
        nx = nextOcc(nx, t.rep);
      }
      if (nx != t.nx) {
        t.nx = nx;
        saveTx(t);
      }
    }
  }

  List<Tx> get recurring => allTx.where((t) => t.rep != 'none' && t.rep.isNotEmpty).toList();

  // ---------- السلف ----------
  List<Loan> get loanList => (_loan.values.where((l) => !l.del).toList()..sort((a, b) => b.ts.compareTo(a.ts)));
  void addLoan(Loan l) {
    l.u = _now();
    _put('tyr_loan', l.id, l.toJson());
    saveTx(Tx(
        id: 'ln_${l.id}', type: 'loan', amt: l.amt, cur: l.cur, rate: l.rate, acc: l.acc.isEmpty ? defaultAcc : l.acc,
        note: l.person, ts: l.ts, loan: l.id, sign: l.dir == 'owed' ? -1 : 1));
  }

  void settleLoan(Loan l) {
    l.settled = true;
    l.u = _now();
    _put('tyr_loan', l.id, l.toJson());
    saveTx(Tx(
        id: 'ls_${l.id}', type: 'loan', amt: l.amt, cur: l.cur, rate: l.rate, acc: l.acc.isEmpty ? defaultAcc : l.acc,
        note: 'تسوية: ${l.person}', ts: _now(), loan: l.id, sign: l.dir == 'owed' ? 1 : -1));
  }

  void delLoan(Loan l) {
    l.del = true;
    l.u = _now();
    _put('tyr_loan', l.id, l.toJson());
    for (final id in ['ln_${l.id}', 'ls_${l.id}']) {
      if (_tx.containsKey(id)) delTx(id);
    }
  }

  // ---------- الأهداف ----------
  List<Goal> get goalList => _goal.values.where((g) => !g.del).toList()..sort((a, b) => a.id.compareTo(b.id));
  void saveGoal(Goal g) {
    g.u = _now();
    _put('tyr_goal', g.id, g.toJson());
  }

  // ---------- التصنيفات (قابلة للتعديل) ----------
  /// أول مرة: ننسخ التصنيفات الافتراضية (والفرعية القديمة) كسجلات قابلة للتعديل. بنفس المعرّفات القديمة فالعمليات القديمة ما بتتأثرش.
  void seedCats() {
    if (_seeding || S.flag('ctgSeeded') || _ctg.isNotEmpty) {
      if (_ctg.isNotEmpty && !S.flag('ctgSeeded')) S.put('ctgSeeded', true);
      return;
    }
    _seeding = true;
    final m = store.getMap('tyr_ctg');
    void add(CatDef d) => m[d.id] = d.toJson();
    var o = 0;
    for (final entry in [(false, kExpCats), (true, kIncCats)]) {
      for (final c in entry.$2) {
        add(CatDef(id: c.id, kind: entry.$1 ? 'inc' : 'exp', name: c.name, ord: o++, u: 1));
        final names = [...c.subs, ...(_subs[c.id] ?? const <String>[])];
        var so = 0;
        for (final n in names.toSet()) {
          add(CatDef(id: _subId(c.id, n), kind: entry.$1 ? 'inc' : 'exp', name: n, parent: c.id, ord: so++, u: 1));
        }
      }
    }
    store.set('tyr_ctg', m);
    S.put('ctgSeeded', true);
    _seeding = false;
    load();
    notifyListeners();
  }

  bool get _custom => _ctg.isNotEmpty;
  String _subId(String parent, String name) => 'sub_${parent}_${name.hashCode.toUnsigned(32).toRadixString(36)}';

  Cat? _lookupCat(String id) {
    final d = _ctg[id];
    if (d == null || d.isSub) return null;
    return Cat(d.id, d.name, _childNames(d.id));
  }

  List<String> _childNames(String parent) => (_ctg.values.where((c) => c.parent == parent && !c.del).toList()..sort((a, b) => a.ord.compareTo(b.ord))).map((c) => c.name).toList();

  CatDef? catDef(String id) => _ctg[id];

  /// التصنيفات الرئيسية الظاهرة (غير المحذوفة) بالترتيب.
  List<Cat> cats(bool inc) {
    if (!_custom) return inc ? kIncCats : kExpCats;
    final kind = inc ? 'inc' : 'exp';
    final l = _ctg.values.where((c) => c.kind == kind && !c.isSub && !c.del).toList()..sort((a, b) => a.ord.compareTo(b.ord));
    return [for (final d in l) Cat(d.id, d.name, _childNames(d.id))];
  }

  List<CatDef> mainDefs(bool inc) => _ctg.values.where((c) => c.kind == (inc ? 'inc' : 'exp') && !c.isSub && !c.del).toList()..sort((a, b) => a.ord.compareTo(b.ord));
  List<CatDef> subDefs(String parent) => _ctg.values.where((c) => c.parent == parent && !c.del).toList()..sort((a, b) => a.ord.compareTo(b.ord));

  List<String> subsOf(Cat c) => _custom ? _childNames(c.id) : [...c.subs, ...(_subs[c.id] ?? const <String>[])];

  /// أيقونة ولون مخصّصين لتصنيف (أو null = الافتراضي).
  (IconData?, Color?) catStyle(String id) {
    final d = _ctg[id];
    if (d == null) return (null, null);
    return (d.icon.isEmpty ? null : catIconByKey(d.icon), d.color == 0 ? null : Color(d.color));
  }

  void addSub(String catId, String name) {
    if (_custom) {
      if (_ctg.values.any((c) => c.parent == catId && !c.del && c.name == name)) return;
      final p = _ctg[catId];
      saveCat(CatDef(id: 'c_${_now()}', kind: p?.kind ?? 'exp', name: name, parent: catId, ord: subDefs(catId).length));
      return;
    }
    final m = store.getMap('tyr_cat');
    final l = List<String>.from(((m[catId] as List?) ?? const []).map((e) => '$e'));
    if (!l.contains(name)) l.add(name);
    m[catId] = l;
    store.set('tyr_cat', m);
  }

  void saveCat(CatDef d) {
    d.u = _now();
    _put('tyr_ctg', d.id, d.toJson());
  }

  /// تغيير اسم تصنيف فرعي مع تحديث العمليات القديمة اللي مخزّنة باسمه.
  void renameSub(CatDef d, String newName) {
    final old = d.name;
    if (old == newName) return;
    for (final t in _tx.values.where((t) => !t.del && t.cat == d.parent && t.sub == old).toList()) {
      t.sub = newName;
      saveTx(t);
    }
    d.name = newName;
    saveCat(d);
  }

  /// حذف ناعم: العمليات القديمة تفضل بتعرض اسم التصنيف ولا تضيع. (الرئيسي بيشيل فروعه معاه.)
  void deleteCat(String id) {
    final d = _ctg[id];
    if (d == null) return;
    final m = store.getMap('tyr_ctg');
    final t = _now();
    for (final c in _ctg.values.where((c) => c.id == id || c.parent == id)) {
      c.del = true;
      c.u = t;
      m[c.id] = c.toJson();
    }
    store.set('tyr_ctg', m);
    load();
    notifyListeners();
  }

  void reorderCats(List<String> ids) {
    final m = store.getMap('tyr_ctg');
    final t = _now();
    for (var i = 0; i < ids.length; i++) {
      final c = _ctg[ids[i]];
      if (c == null || c.ord == i) continue;
      c.ord = i;
      c.u = t;
      m[c.id] = c.toJson();
    }
    store.set('tyr_ctg', m);
    load();
    notifyListeners();
  }

  /// عدد المعاملات (غير المحذوفة) على التصنيف — الرئيسي يشمل فروعه.
  int catCount(String id, {String sub = ''}) => _tx.values.where((t) => !t.del && t.cat == id && (sub.isEmpty || t.sub == sub)).length;

  void resetCats() => store.set('tyr_cat', <String, dynamic>{});

  /// مسح كل العمليات (حذف ناعم حتى يصل الحذف لباقي الأجهزة).
  void wipeData() {
    for (final t in _tx.values.toList()) {
      if (!t.del) {
        t.del = true;
        t.u = _now();
      }
    }
    store.set('tyr_tx', _tx.map((k, v) => MapEntry(k, v.toJson())));
    for (final l in _loan.values.toList()) {
      l.del = true;
      l.u = _now();
    }
    store.set('tyr_loan', _loan.map((k, v) => MapEntry(k, v.toJson())));
    load();
    notifyListeners();
  }
}

final Repo repo = Repo();
