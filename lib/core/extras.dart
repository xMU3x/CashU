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
  String acc; // الحساب اللي اتسحبت منه الدفعة (فاضي = الحساب الافتراضي للاشتراك)
  String tx; // معاملة قديمة مربوطة بالدفعة (مش من إنشاء التطبيق) — فاضي = الدفعة أنشأت معاملتها بنفسها
  SubPay(this.ts, this.amt, [this.acc = '', this.tx = '']);
  Map<String, dynamic> toJson() => {'ts': ts, 'amt': amt, if (acc.isNotEmpty) 'acc': acc, if (tx.isNotEmpty) 'tx': tx};
}

/// state: active | paused | stopped
class Sub {
  String id, name, cyc, acc, note, state, svc, img; // img: صورة مخصّصة (data-URI) أو رابط
  double amt;
  int first, until, trialEnd, remind, u, colorV; // colorV: لون مخصّص ARGB (0 = تلقائي حسب الخدمة)
  bool trial, auto, budget, del, hidden; // hidden = منتهي ومخفي من القائمة (معاملاته تفضل)
  List<SubPay> pays;
  Sub({required this.id, required this.name, required this.amt, this.cyc = 'month', this.svc = '', this.acc = '', this.note = '', this.state = 'active', required this.first, this.until = 0, this.trial = false, this.trialEnd = 0, this.remind = 2, this.auto = false, this.budget = true, this.del = false, this.hidden = false, this.u = 0, this.img = '', this.colorV = 0, List<SubPay>? pays}) : pays = pays ?? [];

  factory Sub.fromJson(Map<String, dynamic> j) => Sub(
        id: _ss(j['id']), name: _ss(j['name']), amt: _dd(j['amt']), cyc: _ss(j['cyc'], 'month'), svc: _ss(j['svc']), acc: _ss(j['acc']), note: _ss(j['note']),
        state: _ss(j['state'], 'active'), first: _ii(j['first']), until: _ii(j['until']), trialEnd: _ii(j['trialEnd']), remind: _ii(j['remind'], 2),
        trial: _bb(j['trial']), auto: _bb(j['auto']), budget: _bb(j['budget'], true), del: _bb(j['del']), u: _ii(j['u']),
        img: _ss(j['img']), colorV: _ii(j['colorV']), hidden: _bb(j['hidden']),
        pays: [for (final x in (j['pays'] is List ? j['pays'] as List : const [])) if (x is Map) SubPay(_ii(x['ts']), _dd(x['amt']), _ss(x['acc']), _ss(x['tx']))],
      );
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'amt': amt, 'cyc': cyc, 'svc': svc, 'acc': acc, 'note': note, 'state': state, 'first': first, 'until': until,
        'trialEnd': trialEnd, 'remind': remind, 'trial': trial, 'auto': auto, 'budget': budget, 'del': del, 'hidden': hidden, 'u': u, 'img': img, 'colorV': colorV, 'pays': [for (final x in pays) x.toJson()],
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

  /// استحقاق الدفعة غير المدفوعة لو فات ميعادها (null = مفيش تأخير).
  /// الدورة رقم n تستحق في (البداية + n دورة)، والمدفوعة = عدد الدفعات المسجلة.
  DateTime? get overdueDate {
    if (state != 'active' || inTrial) return null;
    var d = firstDate;
    for (var i = 0; i < pays.length && i < 1200; i++) {
      d = nextCycle(d, cyc);
    }
    if (until > 0 && d.millisecondsSinceEpoch > until) return null;
    final t = DateTime.now();
    final today = DateTime(t.year, t.month, t.day);
    return DateTime(d.year, d.month, d.day).isBefore(today) ? d : null;
  }

  bool get overdue => overdueDate != null;

  /// أيام التأخير (0 لو مش متأخر).
  int get overdueDays {
    final o = overdueDate;
    if (o == null) return 0;
    final t = DateTime.now();
    return DateTime(t.year, t.month, t.day).difference(DateTime(o.year, o.month, o.day)).inDays;
  }

  int? get daysLeft {
    final n = nextDue;
    if (n == null) return null;
    final t = DateTime.now();
    return DateTime(n.year, n.month, n.day).difference(DateTime(t.year, t.month, t.day)).inDays;
  }
}

// ===================== الجمعيات =====================
/// فرد في الجمعية (لما أنا المدير): الاسم + نصيبه + أدواره (أرقام الأدوار 1..N، 0 = لسه متحددش).
class AssocPerson {
  String name;
  double share;
  List<int> turns;
  AssocPerson(this.name, {this.share = 1, List<int>? turns}) : turns = turns ?? [];
  Map<String, dynamic> toJson() => {'n': name, 's': share, 't': turns};
  factory AssocPerson.fromJson(Map<String, dynamic> j) => AssocPerson(_ss(j['n']), share: _dd(j['s'], 1), turns: [for (final x in (j['t'] is List ? j['t'] as List : const [])) _ii(x)]);
  int get count => share.floor() < 1 ? 1 : share.floor();
}

/// جمعية: أنا إما مدير (بجمّع من الناس وبسلّم الدور) أو مشترك (بدفع قسطي وبستلم دوري).
/// [amt] = قسط النصيب الواحد في الدور · [members] = عدد الأفراد = عدد الأدوار · [share] = نصيبي (0.5 = نص قسط) ·
/// [turns] = أدواري (أرقام 1..members، 0 = لسه متحددش) · [paidIdx]/[got] = الأدوار اللي دفعتها / استلمتها.
class Assoc {
  String id, name, acc, rules;
  double amt; // القسط على النصيب الواحد في الدور
  int members, turn, start, u; // turn: أول دور ليا (1..members) — للتوافق مع النسخ القديمة
  bool del, received, hidden; // hidden = منتهية ومخفية (معاملاتها تفضل)
  List<int> skipped; // أدوار (0-based) اتدفعت قبل استخدام التطبيق: معلّمة مسددة ومش بتتسجل في المعاملات
  List<int> pays; // تواريخ دفعاتي
  String role; // member | admin
  String mgr; // اسم المدير (لما أكون مشترك)
  String every; // week | 2week | month
  double share; // نصيبي
  String order; // agreed | lottery
  bool budget, closed, imIn; // imIn: المدير مشترك فيها كمان
  String note;
  List<int> turns; // أدوار نصيبي
  List<int> paidIdx; // أرقام الأدوار (0-based) اللي دفعتها
  List<int> got; // أرقام الأدوار (0-based) اللي استلمتها
  List<AssocPerson> ppl; // باقي الأفراد (للمدير)
  List<int> delivered; // الأدوار (0-based) اللي المدير سلّمها لصاحبها
  Assoc({
    required this.id, required this.name, required this.amt, this.members = 10, this.turn = 1, required this.start, this.acc = '', this.rules = '',
    this.del = false, this.received = false, this.hidden = false, this.u = 0, List<int>? pays, List<int>? skipped,
    this.role = 'member', this.mgr = '', this.every = 'month', this.share = 1, this.order = 'agreed', this.budget = true, this.closed = false, this.imIn = true, this.note = '',
    List<int>? turns, List<int>? paidIdx, List<int>? got, List<AssocPerson>? ppl, List<int>? delivered,
  })  : pays = pays ?? [],
        skipped = skipped ?? [],
        turns = turns ?? [],
        paidIdx = paidIdx ?? [],
        got = got ?? [],
        ppl = ppl ?? [],
        delivered = delivered ?? [];
  factory Assoc.fromJson(Map<String, dynamic> j) {
    final a = Assoc(
      id: _ss(j['id']), name: _ss(j['name']), amt: _dd(j['amt']), members: _ii(j['members'], 10), turn: _ii(j['turn'], 1), start: _ii(j['start']), acc: _ss(j['acc']),
      rules: _ss(j['rules']), del: _bb(j['del']), received: _bb(j['received']), hidden: _bb(j['hidden']), u: _ii(j['u']),
      skipped: [for (final x in (j['skipped'] is List ? j['skipped'] as List : const [])) _ii(x)], pays: [for (final x in (j['pays'] is List ? j['pays'] as List : const [])) _ii(x)],
      role: _ss(j['role'], 'member'), mgr: _ss(j['mgr']), every: _ss(j['every'], 'month'), share: _dd(j['share'], 1), order: _ss(j['order'], 'agreed'),
      budget: _bb(j['budget'], true), closed: _bb(j['closed']), imIn: _bb(j['imIn'], true), note: _ss(j['note']),
      turns: [for (final x in (j['turns'] is List ? j['turns'] as List : const [])) _ii(x)],
      paidIdx: [for (final x in (j['paidIdx'] is List ? j['paidIdx'] as List : const [])) _ii(x)],
      got: [for (final x in (j['got'] is List ? j['got'] as List : const [])) _ii(x)],
      ppl: [for (final x in (j['ppl'] is List ? j['ppl'] as List : const [])) if (x is Map<String, dynamic>) AssocPerson.fromJson(x)],
      delivered: [for (final x in (j['delivered'] is List ? j['delivered'] as List : const [])) _ii(x)],
    );
    // بيانات قديمة: القبض كان علامة واحدة
    if (a.received && a.got.isEmpty) a.got.add(a.turn - 1);
    return a;
  }
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'amt': amt, 'members': members, 'turn': turn, 'start': start, 'acc': acc, 'rules': rules, 'del': del, 'received': received, 'hidden': hidden, 'skipped': skipped, 'u': u, 'pays': pays,
        'role': role, 'mgr': mgr, 'every': every, 'share': share, 'order': order, 'budget': budget, 'closed': closed, 'imIn': imIn, 'note': note,
        'turns': turns, 'paidIdx': paidIdx, 'got': got, 'ppl': [for (final x in ppl) x.toJson()], 'delivered': delivered,
      };
  DateTime get startDate => DateTime.fromMillisecondsSinceEpoch(start);
  bool get isAdmin => role == 'admin';
  bool get iAmIn => !isAdmin || imIn;
  int get rounds => members;
  bool isSkipped(int k) => skipped.contains(k);

  /// موعد الدور رقم [k] (0-based) حسب التكرار.
  DateTime dueOf(int k) {
    final d = startDate;
    switch (every) {
      case 'week':
        return DateTime(d.year, d.month, d.day + 7 * k, d.hour, d.minute);
      case '2week':
        return DateTime(d.year, d.month, d.day + 14 * k, d.hour, d.minute);
      default:
        return addMonths(d, k);
    }
  }

  /// موعد قبضي: أول دور ليا (أو الدور القديم [turn]).
  DateTime get payoutDate => dueOf(((turns.where((t) => t > 0).isEmpty ? turn : turns.where((t) => t > 0).reduce((a, b) => a < b ? a : b)) - 1).clamp(0, rounds - 1));
  double get pot => amt * members; // قيمة الدور الواحد
  double get payout => pot;
  double get myPay => amt * (iAmIn ? share : 0); // اللي بدفعه في كل دور
  int get myTurnCount => share.floor() < 1 ? 1 : share.floor();
  double get myPayoutPerTurn => pot * share / myTurnCount;
  double get totalToPay => myPay * rounds;
  double get totalToGet => iAmIn ? pot * share : 0;
  bool isPaid(int k) => paidIdx.isNotEmpty || pays.isEmpty ? paidIdx.contains(k) : k < pays.length;
  int get paidCount => paidIdx.isNotEmpty || pays.isEmpty ? paidIdx.length : pays.length;
  double get paidTotal => myPay * paidCount;
  double get gotTotal => myPayoutPerTurn * got.length;
  double get leftToPay => (totalToPay - paidTotal).clamp(0.0, double.infinity).toDouble();
  double get leftToGet => (totalToGet - gotTotal).clamp(0.0, double.infinity).toDouble();
  int get monthsDone => paidCount;
  bool get finished => closed || (paidCount >= rounds && (!iAmIn || got.length >= myTurnCount));
  int get lateCount => [for (var k = 0; k < rounds; k++) if (!isPaid(k) && dueOf(k).isBefore(DateTime.now())) k].length;
  double get lateAmt => myPay * lateCount;

  /// صافي مركزي: اللي قبضته - اللي دفعته (موجب = ماسك فلوس الجمعية).
  double get position => gotTotal - paidTotal;

  /// اللي ماسك الدور رقم [k]: 'me' | اسم | '' (لسه متحددش).
  String holderOf(int k) {
    if (iAmIn && turns.contains(k + 1)) return 'me';
    for (final p in ppl) {
      if (p.turns.contains(k + 1)) return p.name;
    }
    if (!isAdmin && !iAmIn) return '';
    return '';
  }

  String get periodWord => every == 'week' ? 'كل أسبوع' : every == '2week' ? 'كل أسبوعين' : 'كل شهر';
}

// ===================== الأقساط =====================
class Inst {
  String id, name, acc, note;
  double total;
  int count, first, u;
  String img; // صورة/أيقونة الخطة (data-uri أو رابط) — فاضي = حرف أول الاسم
  int remind; // التذكير قبل القسط بـ N يوم (-1 = بدون)
  bool del, auto, budget, hidden; // auto = يسجّل القسط لوحده · budget = يتحسب من الميزانية · hidden = منتهي ومخفي (معاملاته تفضل)
  Map<String, String> links; // تاريخ الدفعة (ms) → معرّف معاملة قديمة مربوطة بيها
  List<int> pays;
  List<double> amts; // مبلغ كل دفعة (موازية لـ pays)
  Inst({required this.id, required this.name, required this.total, this.count = 12, required this.first, this.acc = '', this.note = '', this.del = false, this.hidden = false, this.u = 0, this.auto = false, this.budget = true, this.img = '', this.remind = 1, List<int>? pays, List<double>? amts, Map<String, String>? links})
      : pays = pays ?? [],
        links = links ?? {},
        amts = amts ?? [] {
    _sync();
  }
  void _sync() {
    final e = count <= 0 ? 0.0 : total / count;
    while (amts.length < pays.length) {
      amts.add(e);
    }
    if (amts.length > pays.length) amts.removeRange(pays.length, amts.length);
  }

  factory Inst.fromJson(Map<String, dynamic> j) => Inst(
        id: _ss(j['id']), name: _ss(j['name']), total: _dd(j['total']), count: _ii(j['count'], 12), first: _ii(j['first']), acc: _ss(j['acc']), note: _ss(j['note']),
        del: _bb(j['del']), u: _ii(j['u']), auto: _bb(j['auto']), budget: _bb(j['budget'], true), img: _ss(j['img']), remind: _ii(j['remind'], 1), hidden: _bb(j['hidden']),
        links: {if (j['links'] is Map) for (final e in (j['links'] as Map).entries) '${e.key}': '${e.value}'},
        pays: [for (final x in (j['pays'] is List ? j['pays'] as List : const [])) _ii(x)],
        amts: [for (final x in (j['amts'] is List ? j['amts'] as List : const [])) _dd(x)],
      );
  Map<String, dynamic> toJson() {
    _sync();
    return {'id': id, 'name': name, 'total': total, 'count': count, 'first': first, 'acc': acc, 'note': note, 'del': del, 'u': u, 'auto': auto, 'budget': budget, 'img': img, 'remind': remind, 'hidden': hidden, 'links': links, 'pays': pays, 'amts': amts};
  }

  double get each => count <= 0 ? 0 : total / count;
  double get paid {
    _sync();
    return amts.fold(0.0, (a, x) => a + x);
  }

  double get left => (total - paid).clamp(0, double.infinity).toDouble();
  bool get done => left < 0.005 || pays.length >= count;

  /// عدد الأقساط المتبقية.
  int get monthsLeft => done ? 0 : (count - pays.length).clamp(0, 1 << 20).toInt();

  /// مبلغ القسط القادم = المتبقي موزّع على الأقساط المتبقية.
  double get nextAmt => monthsLeft <= 0 ? left : left / monthsLeft;
  DateTime? dueOf(int i) => i >= count ? null : addMonths(DateTime.fromMillisecondsSinceEpoch(first), i);
  DateTime? get nextDue => done ? null : dueOf(pays.length);
  DateTime? get endDate => dueOf(count - 1);
}

class Extras extends ChangeNotifier {
  Map<String, Sub> _sub = {};
  Map<String, Assoc> _assoc = {};
  Map<String, Inst> _inst = {};

  void init() {
    load();
    store.changes.listen((k) {
      if (k == 'tyr_sub' || k == 'tyr_assoc' || k == 'tyr_inst') {
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

    _sub = rd('tyr_sub', Sub.fromJson);
    _assoc = rd('tyr_assoc', Assoc.fromJson);
    _inst = rd('tyr_inst', Inst.fromJson);
  }

  void _put(String k, String id, Map<String, dynamic> j) {
    final m = store.getMap(k);
    m[id] = j;
    store.set(k, m);
    load();
    notifyListeners();
  }

  // ---- اشتراكات ----
  List<Sub> get subs => (_sub.values.where((s) => !s.del && !s.hidden).toList()..sort((a, b) => a.name.compareTo(b.name)));
  void saveSub(Sub s) {
    s.u = _nowMs();
    _put('tyr_sub', s.id, s.toJson());
  }

  /// حذف الخدمة. [withTx] = true يحذف معاملاتها كمان (المنشأة منها + المربوطة)، false يحذف الخدمة وتفضل معاملاتها في الحسابات.
  void delSub(Sub s, {bool withTx = false}) {
    if (withTx) _delTxs('sub:${s.id}', [for (final x in s.pays) if (x.tx.isNotEmpty) x.tx]);
    s.del = true;
    saveSub(s);
  }

  /// إنهاء الاشتراك: يختفي من القائمة وتفضل معاملاته مسجّلة.
  void finishSub(Sub s) {
    s.hidden = true;
    s.state = 'stopped';
    saveSub(s);
  }

  /// يمسح معاملات الخدمة: كل المعاملات اللي src بتاعها [src] + معاملات قديمة مربوطة بالـ id.
  void _delTxs(String src, Iterable<String> ids) {
    for (final t in repo.allTx.where((t) => t.src == src).toList()) {
      repo.delTx(t.id);
    }
    for (final id in ids) {
      if (repo.tx(id) != null) repo.delTx(id);
    }
  }

  /// هل المعاملة مربوطة بالفعل بدفعة اشتراك أو قسط؟ (عشان متتربطش مرتين)
  bool isLinked(String txId) =>
      _sub.values.any((s) => !s.del && s.pays.any((p) => p.tx == txId)) || _inst.values.any((i) => !i.del && i.links.containsValue(txId));

  /// ربط معاملة قديمة (مصروف) بدفعة اشتراك: تتسجل في سجل الدفعات (history) من غير ما تتعمل معاملة جديدة.
  void linkSubTx(Sub s, Tx t) {
    if (s.pays.any((p) => p.tx == t.id || p.ts == t.ts)) return;
    s.pays.add(SubPay(t.ts, t.amt, t.acc, t.id));
    s.pays.sort((x, y) => y.ts.compareTo(x.ts));
    saveSub(s);
  }

  /// ربط معاملة قديمة بقسط: يتحسب في المدفوع وسجل الأقساط من غير معاملة جديدة.
  void linkInstTx(Inst i, Tx t) {
    if (i.done || i.links.containsValue(t.id)) return;
    final a = t.amt > i.left ? i.left : t.amt;
    if (a <= 0.004) return;
    i._sync();
    final pairs = <(int, double)>[for (var k = 0; k < i.pays.length; k++) (i.pays[k], i.amts[k]), (t.ts, a)]..sort((x, y) => x.$1.compareTo(y.$1));
    i.pays = [for (final x in pairs) x.$1];
    i.amts = [for (final x in pairs) x.$2];
    i.links['${t.ts}'] = t.id;
    saveInst(i);
  }

  /// تسجيل دفعة اشتراك: تُضاف لسجل الدفعات، ولو «احسبها من الميزانية» تتسجل مصروف تحت «ترفيه › اشتراكات».
  void paySub(Sub s, {int? ts, double? amt, String? acc}) {
    final t = ts ?? _nowMs();
    final a = amt ?? s.amt;
    if (s.pays.any((p) => p.ts == t)) return;
    final from = (acc != null && acc.isNotEmpty) ? acc : (s.acc.isEmpty ? repo.defaultAcc : s.acc);
    s.pays.add(SubPay(t, a, from));
    s.pays.sort((x, y) => y.ts.compareTo(x.ts));
    if (s.budget) {
      repo.saveTx(Tx(id: 'sub_${s.id}_$t', type: 'exp', amt: a, acc: from, cat: 'fun', sub: 'اشتراكات', note: s.name, ts: t, src: 'sub:${s.id}'));
    }
    saveSub(s);
  }

  /// الاشتراكات اللي «سجّل الدفعة عني» تتسجل تلقائيًا لما ميعادها يعدّي.
  void runAuto() {
    runAutoInst();
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

  /// الأقساط اللي «سجّل القسط لوحده» تتسجل تلقائيًا لما ميعادها يعدّي.
  void runAutoInst() {
    final now = _nowMs();
    for (final i in insts) {
      if (!i.auto) continue;
      var guard = 0;
      while (!i.done && guard++ < 400) {
        final d = i.nextDue;
        if (d == null || d.millisecondsSinceEpoch > now) break;
        payInst(i, when: d);
      }
    }
  }

  // ---- جمعيات ----
  List<Assoc> get assocs => (_assoc.values.where((a) => !a.del && !a.hidden).toList()..sort((a, b) => a.name.compareTo(b.name)));
  void saveAssoc(Assoc a) {
    a.u = _nowMs();
    _put('tyr_assoc', a.id, a.toJson());
  }

  /// حذف الجمعية. [withTx] = true يحذف دفعاتها وقبضها من المعاملات، false يحذف الجمعية وتفضل معاملاتها.
  void delAssoc(Assoc a, {bool withTx = false}) {
    if (withTx) _delTxs('assoc:${a.id}', const []);
    a.del = true;
    saveAssoc(a);
  }

  /// إنهاء الجمعية: تتقفل وتختفي من القائمة وتفضل معاملاتها.
  void finishAssoc(Assoc a) {
    a.closed = true;
    a.hidden = true;
    saveAssoc(a);
  }

  /// أدوار اتدفعت قبل استخدام التطبيق (Skipped): تتعلّم مسددة بالكامل من غير ما تتسجل في المعاملات.
  void skipAssocRounds(Assoc a, Iterable<int> ks) {
    if (!a.iAmIn) return;
    if (a.paidIdx.isEmpty && a.pays.isNotEmpty) a.paidIdx = [for (var i = 0; i < a.pays.length; i++) i];
    for (final k in ks) {
      if (k < 0 || k >= a.rounds || a.isPaid(k)) continue;
      a.paidIdx.add(k);
      a.pays.add(a.dueOf(k).millisecondsSinceEpoch);
      a.skipped.add(k);
    }
    saveAssoc(a);
  }

  /// تسجيل دفع قسطي في الدور [k] (ينزل مصروف لو الجمعية محسوبة من الميزانية).
  void payAssocRound(Assoc a, int k, {String? acc}) {
    if (a.isPaid(k) || !a.iAmIn) return;
    final t = _nowMs();
    // ترحيل بيانات قديمة (pays بدون paidIdx)
    if (a.paidIdx.isEmpty && a.pays.isNotEmpty) a.paidIdx = [for (var i = 0; i < a.pays.length; i++) i];
    a.paidIdx.add(k);
    a.pays.add(t);
    if (a.budget) repo.saveTx(Tx(id: 'as_${a.id}_p$k', type: 'exp', amt: a.myPay, acc: (acc != null && acc.isNotEmpty) ? acc : (a.acc.isEmpty ? repo.defaultAcc : a.acc), cat: 'other', note: 'جمعية: ${a.name} (الدور ${k + 1})', ts: t, src: 'assoc:${a.id}'));
    saveAssoc(a);
  }

  void undoAssocPay(Assoc a, int k) {
    if (!a.isPaid(k)) return;
    if (a.paidIdx.isEmpty && a.pays.isNotEmpty) a.paidIdx = [for (var i = 0; i < a.pays.length; i++) i];
    a.paidIdx.remove(k);
    a.skipped.remove(k);
    if (a.pays.isNotEmpty) a.pays.removeLast();
    if (repo.tx('as_${a.id}_p$k') != null) repo.delTx('as_${a.id}_p$k');
    saveAssoc(a);
  }

  void payAssoc(Assoc a) {
    for (var k = 0; k < a.rounds; k++) {
      if (!a.isPaid(k)) return payAssocRound(a, k);
    }
  }

  /// استلام الدور [k] (ليا أنا): ينزل دخل لو محسوبة من الميزانية، ولو المدير بيسلّم نعلّمه اتسلّم.
  void receiveAssocRound(Assoc a, int k, {String? acc}) {
    if (a.got.contains(k)) return;
    final t = _nowMs();
    a.got.add(k);
    if (!a.delivered.contains(k)) a.delivered.add(k);
    a.received = a.got.length >= a.myTurnCount;
    if (a.budget) repo.saveTx(Tx(id: 'asr_${a.id}_$k', type: 'inc', amt: a.myPayoutPerTurn, acc: (acc != null && acc.isNotEmpty) ? acc : (a.acc.isEmpty ? repo.defaultAcc : a.acc), cat: 'other_i', note: 'قبض جمعية: ${a.name} (الدور ${k + 1})', ts: t, src: 'assoc:${a.id}'));
    saveAssoc(a);
  }

  void undoAssocReceive(Assoc a, int k) {
    a.got.remove(k);
    a.delivered.remove(k);
    a.received = a.got.length >= a.myTurnCount;
    for (final id in ['asr_${a.id}_$k', 'asr_${a.id}']) {
      if (repo.tx(id) != null) repo.delTx(id);
    }
    saveAssoc(a);
  }

  /// المدير سلّم الدور [k] لحد غيره.
  void deliverAssoc(Assoc a, int k, bool v) {
    v ? (a.delivered.contains(k) ? null : a.delivered.add(k)) : a.delivered.remove(k);
    saveAssoc(a);
  }

  void receiveAssoc(Assoc a) {
    final turns = a.turns.where((t) => t > 0).toList();
    final k = (turns.isEmpty ? a.turn : turns.first) - 1;
    receiveAssocRound(a, k.clamp(0, a.rounds - 1));
  }

  // ---- أقساط ----
  List<Inst> get insts => (_inst.values.where((a) => !a.del && !a.hidden).toList()..sort((a, b) => a.name.compareTo(b.name)));
  void saveInst(Inst i) {
    i.u = _nowMs();
    _put('tyr_inst', i.id, i.toJson());
  }

  /// حذف خطة القسط. [withTx] = true يحذف أقساطها من المعاملات (المنشأة + المربوطة)، false يحذف الخطة وتفضل معاملاتها.
  void delInst(Inst i, {bool withTx = false}) {
    if (withTx) _delTxs('inst:${i.id}', i.links.values);
    i.del = true;
    saveInst(i);
  }

  /// إنهاء القسط: يختفي من القائمة وتفضل معاملاته.
  void finishInst(Inst i) {
    i.hidden = true;
    saveInst(i);
  }

  /// تسجيل قسط (القسط التالي افتراضيًا، أو مبلغ/تاريخ مخصّص). يتسجل كمصروف لو الخطة محسوبة من الميزانية.
  /// [record] = false للأقساط القديمة (قبل بداية استخدام التطبيق): تتسجل على الخطة فقط.
  void payInst(Inst i, {double? amt, DateTime? when, bool record = true, String? acc}) {
    if (i.done) return;
    final t = when?.millisecondsSinceEpoch ?? _nowMs();
    final raw = amt ?? i.nextAmt;
    final a = raw > i.left ? i.left : raw;
    if (a <= 0.004) return;
    i.pays.add(t);
    i.amts.add(a);
    if (record && i.budget) {
      repo.saveTx(Tx(id: 'in_${i.id}_$t', type: 'exp', amt: a, acc: (acc != null && acc.isNotEmpty) ? acc : (i.acc.isEmpty ? repo.defaultAcc : i.acc), cat: 'other', note: 'قسط: ${i.name} (${i.pays.length}/${i.count})', ts: t, src: 'inst:${i.id}'));
    }
    saveInst(i);
  }

  /// سدّد المتبقي كله دفعة واحدة.
  void payInstAll(Inst i, {DateTime? when, String? acc}) => payInst(i, amt: i.left, when: when, acc: acc);

  /// حذف دفعة مسجّلة (وحذف المعاملة المرتبطة بها).
  void removeInstPay(Inst i, int k) {
    if (k < 0 || k >= i.pays.length) return;
    final t = i.pays[k];
    i.pays.removeAt(k);
    if (k < i.amts.length) i.amts.removeAt(k);
    i.links.remove('$t');
    for (final id in ['in_${i.id}_$t', 'in_${i.id}_${k + 1}']) {
      if (repo.tx(id) != null) repo.delTx(id);
    }
    saveInst(i);
  }
}

final Extras extras = Extras();
