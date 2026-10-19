import 'package:flutter/foundation.dart';
import 'models.dart';
import 'repo.dart';
import 'store.dart';
import 'util.dart';

int _nowMs() => DateTime.now().millisecondsSinceEpoch;
int _ii(dynamic v, [int d = 0]) => v is num ? v.toInt() : d;
double _dd(dynamic v, [double d = 0]) => v is num ? v.toDouble() : d;
String _ss(dynamic v, [String d = '']) => v is String ? v : d;
bool _bb(dynamic v, [bool d = false]) => v is bool ? v : d;

/// تاريخ بعد [m] شهر مع ضبط آخر يوم في الشهر.
DateTime addMonths(DateTime d, int m) {
  final t = d.year * 12 + (d.month - 1) + m;
  final y = t ~/ 12, mo = t % 12 + 1;
  final day = d.day > daysIn(y, mo) ? daysIn(y, mo) : d.day;
  return DateTime(y, mo, day, d.hour, d.minute);
}

// ===================== الاشتراكات =====================
/// دورات الدفع: week · month · q3 · h6 · year · once
const kSubCycles = <(String, String)>[('week', 'أسبوعي'), ('month', 'شهري'), ('q3', 'كل 3 شهور'), ('h6', 'كل 6 شهور'), ('year', 'سنوي'), ('once', 'دفعة واحدة')];
String cycleName(String c) => kSubCycles.firstWhere((x) => x.$1 == c, orElse: () => kSubCycles[1]).$2;

DateTime nextCycle(DateTime d, String c) {
  switch (c) {
    case 'week':
      return DateTime(d.year, d.month, d.day + 7, d.hour, d.minute);
    case 'q3':
      return addMonths(d, 3);
    case 'h6':
      return addMonths(d, 6);
    case 'year':
      return addMonths(d, 12);
    default:
      return addMonths(d, 1);
  }
}

class SubPay {
  int ts;
  double amt;
  SubPay(this.ts, this.amt);
  Map<String, dynamic> toJson() => {'ts': ts, 'amt': amt};
}

/// state: active | paused | stopped
class Sub {
  String id, name, cyc, acc, note, state, svc;
  double amt;
  int first, until, trialEnd, remind, u;
  bool trial, auto, budget, del;
  List<SubPay> pays;
  Sub({required this.id, required this.name, required this.amt, this.cyc = 'month', this.svc = '', this.acc = '', this.note = '', this.state = 'active', required this.first, this.until = 0, this.trial = false, this.trialEnd = 0, this.remind = 2, this.auto = false, this.budget = true, this.del = false, this.u = 0, List<SubPay>? pays}) : pays = pays ?? [];

  factory Sub.fromJson(Map<String, dynamic> j) => Sub(
        id: _ss(j['id']), name: _ss(j['name']), amt: _dd(j['amt']), cyc: _ss(j['cyc'], 'month'), svc: _ss(j['svc']), acc: _ss(j['acc']), note: _ss(j['note']),
        state: _ss(j['state'], 'active'), first: _ii(j['first']), until: _ii(j['until']), trialEnd: _ii(j['trialEnd']), remind: _ii(j['remind'], 2),
        trial: _bb(j['trial']), auto: _bb(j['auto']), budget: _bb(j['budget'], true), del: _bb(j['del']), u: _ii(j['u']),
        pays: [for (final x in (j['pays'] is List ? j['pays'] as List : const [])) if (x is Map) SubPay(_ii(x['ts']), _dd(x['amt']))],
      );
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'amt': amt, 'cyc': cyc, 'svc': svc, 'acc': acc, 'note': note, 'state': state, 'first': first, 'until': until,
        'trialEnd': trialEnd, 'remind': remind, 'trial': trial, 'auto': auto, 'budget': budget, 'del': del, 'u': u, 'pays': [for (final x in pays) x.toJson()],
      };

  DateTime get firstDate => DateTime.fromMillisecondsSinceEpoch(first);
  bool get inTrial => trial && trialEnd > _nowMs();
  bool get isActive => state == 'active';

  /// قيمة شهرية تقريبية (للدونات والإجمالي).
  double get monthly {
    switch (cyc) {
      case 'week':
        return amt * 52 / 12;
      case 'q3':
        return amt / 3;
      case 'h6':
        return amt / 6;
      case 'year':
        return amt / 12;
      case 'once':
        return 0;
      default:
        return amt;
    }
  }

  double get paid => pays.fold(0.0, (a, x) => a + x.amt);
  Sub clone() => Sub.fromJson(toJson());

  /// موعد التجديد القادم (بعد آخر دفعة/بداية)، أو null لو منتهي/دفعة واحدة/متوقف.
  DateTime? get nextDue {
    if (state == 'stopped') return null;
    if (inTrial) return DateTime.fromMillisecondsSinceEpoch(trialEnd);
    var d = firstDate;
    final now = DateTime.now();
    var guard = 0;
    if (cyc == 'once') return d.isAfter(now) ? d : null;
    while (!d.isAfter(now) && guard++ < 1200) {
      d = nextCycle(d, cyc);
    }
    if (until > 0 && d.millisecondsSinceEpoch > until) return null;
    return d;
  }

  int? get daysLeft {
    final n = nextDue;
    if (n == null) return null;
    final t = DateTime.now();
    return DateTime(n.year, n.month, n.day).difference(DateTime(t.year, t.month, t.day)).inDays;
  }
}

// ===================== الجمعيات =====================
class Assoc {
  String id, name, acc, rules;
  double amt; // القسط الشهري على العضو
  int members, turn, start, u; // turn: دوري (1..members)
  bool del, received;
  List<int> pays; // تواريخ دفعاتي
  Assoc({required this.id, required this.name, required this.amt, this.members = 10, this.turn = 1, required this.start, this.acc = '', this.rules = '', this.del = false, this.received = false, this.u = 0, List<int>? pays}) : pays = pays ?? [];
  factory Assoc.fromJson(Map<String, dynamic> j) => Assoc(
        id: _ss(j['id']), name: _ss(j['name']), amt: _dd(j['amt']), members: _ii(j['members'], 10), turn: _ii(j['turn'], 1), start: _ii(j['start']), acc: _ss(j['acc']),
        rules: _ss(j['rules']), del: _bb(j['del']), received: _bb(j['received']), u: _ii(j['u']), pays: [for (final x in (j['pays'] is List ? j['pays'] as List : const [])) _ii(x)],
      );
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'amt': amt, 'members': members, 'turn': turn, 'start': start, 'acc': acc, 'rules': rules, 'del': del, 'received': received, 'u': u, 'pays': pays};
  DateTime get startDate => DateTime.fromMillisecondsSinceEpoch(start);
  /// شهر قبضي: بداية + (دوري - 1) شهر.
  DateTime get payoutDate => addMonths(startDate, turn - 1);
  double get payout => amt * members;
  double get paidTotal => amt * pays.length;
  int get monthsDone => pays.length;
}

// ===================== الأقساط =====================
class Inst {
  String id, name, acc, note;
  double total;
  int count, first, u;
  bool del;
  List<int> pays;
  Inst({required this.id, required this.name, required this.total, this.count = 12, required this.first, this.acc = '', this.note = '', this.del = false, this.u = 0, List<int>? pays}) : pays = pays ?? [];
  factory Inst.fromJson(Map<String, dynamic> j) => Inst(
        id: _ss(j['id']), name: _ss(j['name']), total: _dd(j['total']), count: _ii(j['count'], 12), first: _ii(j['first']), acc: _ss(j['acc']), note: _ss(j['note']),
        del: _bb(j['del']), u: _ii(j['u']), pays: [for (final x in (j['pays'] is List ? j['pays'] as List : const [])) _ii(x)],
      );
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'total': total, 'count': count, 'first': first, 'acc': acc, 'note': note, 'del': del, 'u': u, 'pays': pays};
  double get each => count <= 0 ? 0 : total / count;
  double get paid => each * pays.length;
  double get left => (total - paid).clamp(0, double.infinity);
  bool get done => pays.length >= count;
  DateTime? dueOf(int i) => i >= count ? null : addMonths(DateTime.fromMillisecondsSinceEpoch(first), i);
  DateTime? get nextDue => dueOf(pays.length);
}

class Extras extends ChangeNotifier {
  Map<String, Sub> _sub = {};
  Map<String, Assoc> _assoc = {};
  Map<String, Inst> _inst = {};

  void init() {
    load();
    store.changes.listen((k) {
      if (k == 'cashu_sub' || k == 'cashu_assoc' || k == 'cashu_inst') {
        load();
        notifyListeners();
      }
    });
  }

  void load() {
    Map<String, T> rd<T>(String k, T Function(Map<String, dynamic>) f) {
      final o = <String, T>{};
      store.peekMap(k).forEach((id, v) {
        if (v is Map) o[id] = f(Map<String, dynamic>.from(v));
      });
      return o;
    }

    _sub = rd('cashu_sub', Sub.fromJson);
    _assoc = rd('cashu_assoc', Assoc.fromJson);
    _inst = rd('cashu_inst', Inst.fromJson);
  }

  void _put(String k, String id, Map<String, dynamic> j) {
    final m = store.getMap(k);
    m[id] = j;
    store.set(k, m);
    load();
    notifyListeners();
  }

  // ---- اشتراكات ----
  List<Sub> get subs => (_sub.values.where((s) => !s.del).toList()..sort((a, b) => a.name.compareTo(b.name)));
  void saveSub(Sub s) {
    s.u = _nowMs();
    _put('cashu_sub', s.id, s.toJson());
  }

  void delSub(Sub s) {
    s.del = true;
    saveSub(s);
  }

  /// تسجيل دفعة اشتراك: تُضاف لسجل الدفعات، ولو «احسبها من الميزانية» تتسجل مصروف تحت «ترفيه › اشتراكات».
  void paySub(Sub s, {int? ts, double? amt}) {
    final t = ts ?? _nowMs();
    final a = amt ?? s.amt;
    if (s.pays.any((p) => p.ts == t)) return;
    s.pays.add(SubPay(t, a));
    s.pays.sort((x, y) => y.ts.compareTo(x.ts));
    if (s.budget) {
      repo.saveTx(Tx(id: 'sub_${s.id}_$t', type: 'exp', amt: a, acc: s.acc.isEmpty ? repo.defaultAcc : s.acc, cat: 'fun', sub: 'اشتراكات', note: s.name, ts: t, src: 'sub:${s.id}'));
    }
    saveSub(s);
  }

  /// الاشتراكات اللي «سجّل الدفعة عني» تتسجل تلقائيًا لما ميعادها يعدّي.
  void runAuto() {
    final now = _nowMs();
    for (final s in subs) {
      if (!s.auto || s.state != 'active') continue;
      var d = s.firstDate;
      var guard = 0;
      while (d.millisecondsSinceEpoch <= now && guard++ < 400) {
        final ms = d.millisecondsSinceEpoch;
        final afterTrial = !s.trial || ms >= s.trialEnd;
        final inRange = s.until == 0 || ms <= s.until;
        if (afterTrial && inRange && !s.pays.any((p) => p.ts == ms)) paySub(s, ts: ms);
        if (s.cyc == 'once') break;
        d = nextCycle(d, s.cyc);
      }
    }
  }

  // ---- جمعيات ----
  List<Assoc> get assocs => (_assoc.values.where((a) => !a.del).toList()..sort((a, b) => a.name.compareTo(b.name)));
  void saveAssoc(Assoc a) {
    a.u = _nowMs();
    _put('cashu_assoc', a.id, a.toJson());
  }

  void delAssoc(Assoc a) {
    a.del = true;
    saveAssoc(a);
  }

  void payAssoc(Assoc a) {
    final t = _nowMs();
    a.pays.add(t);
    repo.saveTx(Tx(id: 'as_${a.id}_$t', type: 'exp', amt: a.amt, acc: a.acc.isEmpty ? repo.defaultAcc : a.acc, cat: 'other', note: 'جمعية: ${a.name}', ts: t, src: 'assoc:${a.id}'));
    saveAssoc(a);
  }

  void receiveAssoc(Assoc a) {
    final t = _nowMs();
    a.received = true;
    repo.saveTx(Tx(id: 'asr_${a.id}', type: 'inc', amt: a.payout, acc: a.acc.isEmpty ? repo.defaultAcc : a.acc, cat: 'other_i', note: 'قبض جمعية: ${a.name}', ts: t, src: 'assoc:${a.id}'));
    saveAssoc(a);
  }

  // ---- أقساط ----
  List<Inst> get insts => (_inst.values.where((a) => !a.del).toList()..sort((a, b) => a.name.compareTo(b.name)));
  void saveInst(Inst i) {
    i.u = _nowMs();
    _put('cashu_inst', i.id, i.toJson());
  }

  void delInst(Inst i) {
    i.del = true;
    saveInst(i);
  }

  /// دفع القسط التالي ويتسجل كمعاملة مصروف مرتبطة بخطة القسط.
  void payInst(Inst i) {
    if (i.done) return;
    final t = _nowMs();
    i.pays.add(t);
    repo.saveTx(Tx(id: 'in_${i.id}_${i.pays.length}', type: 'exp', amt: i.each, acc: i.acc.isEmpty ? repo.defaultAcc : i.acc, cat: 'other', note: 'قسط: ${i.name} (${i.pays.length}/${i.count})', ts: t, src: 'inst:${i.id}'));
    saveInst(i);
  }
}

final Extras extras = Extras();
