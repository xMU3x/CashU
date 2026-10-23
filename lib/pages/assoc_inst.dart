export 'installments_page.dart' show InstPage, InstFormPage;
import 'package:flutter/material.dart' hide Text;
import '../core/currency.dart';
import '../core/extras.dart';
import '../core/i18n.dart';
import '../core/repo.dart';
import '../core/util.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/loc_text.dart';
import '../ui/pickers.dart';
import '../ui/sheets.dart';
import '../ui/theme.dart';
import '../ui/shell_scope.dart';
import '../ui/widgets.dart';

String _n(double v) {
  final s = fixed2(v);
  return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
}

String _m(double v) => '${_n(v)} ${curOf('EGP').sym}';

Widget _field(Pal p, IconData ic, String hint, String value, VoidCallback f) => Tap(
      onTap: f,
      scale: .99,
      child: Container(
        height: 58,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Icon(ic, color: p.ink2, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(value.isEmpty ? hint : value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16.5, color: value.isEmpty ? p.ink2 : p.ink))),
        ]),
      ),
    );

Future<double?> _num(BuildContext c, String title, double init) async {
  final r = await promptText(c, title, hint: title, initial: init == 0 ? '' : _n(init).replaceAll(',', ''), number: true);
  if (r == null) return null;
  return double.tryParse(normDigits(r));
}

// ===================== الجمعيات =====================
const Color _kAs = Color(0xFF2E7568);
const Color _kAsLight = Color(0xFF8BE6D6);

String _k(double v) {
  if (v.abs() >= 1000000) return '${_n(v / 1000000)}M';
  if (v.abs() >= 100000) return '${_n((v / 1000).roundToDouble())}k';
  return _n(v);
}

String _km(double v) => '${_k(v)} ${curOf('EGP').sym}';

void _aboutAssoc(BuildContext c) => showSheet<void>(c, (cc) {
      final p = Pal.of(cc);
      return SheetFrame(
        title: 'عن الجمعية',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Text('الجمعية طريقة ادخار: كل واحد بيدفع نفس المبلغ كل دور، وكل دور واحد بياخد المبلغ كله.\nلو أخدت دورك قبل ما تكمّل دفعك فده قرض من غير فوايد من الجماعة، وباقي الأدوار هي سدادك ليه.', style: TextStyle(fontSize: 16, height: 1.7, color: p.ink2)),
        ),
      );
    });

class AssocPage extends StatefulWidget {
  const AssocPage({super.key});
  @override
  State<AssocPage> createState() => _AssocPageState();
}

class _AssocPageState extends State<AssocPage> {
  String filter = 'all';

  Widget _chip(Pal p, String id, String t) => Expanded(
        child: Tap(
          onTap: () => setState(() => filter = id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: filter == id ? p.card : Colors.transparent, borderRadius: BorderRadius.circular(23), border: Border.all(color: filter == id ? p.ink2 : p.line)),
            child: Text(t, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: filter == id ? p.ink : p.ink2)),
          ),
        ),
      );

  Widget _summary(Pal p, List<Assoc> all) {
    final live = all.where((a) => !a.finished).toList();
    final owe = live.fold(0.0, (s, a) => s + a.leftToPay);
    final get = live.fold(0.0, (s, a) => s + a.leftToGet);
    final pos = live.fold(0.0, (s, a) => s + a.position);
    final lateN = live.where((a) => a.lateCount > 0).length;
    final hold = pos > 0.5, ahead = pos < -0.5;
    final col = hold ? kOrange : (ahead ? kGreen : p.ink2);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: p.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Text('مركزك', style: TextStyle(fontSize: 15, color: p.ink2)), const SizedBox(width: 8), Container(width: 16, height: 3, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(2)))]),
        const SizedBox(height: 4),
        Text(_km(pos.abs()), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
        Text(hold ? 'إنت ماسك فلوس الجماعة دلوقتي' : (ahead ? 'إنت دافع قدّام الجماعة' : 'حسابك متعادل'), style: TextStyle(fontSize: 15, color: p.ink2)),
        const SizedBox(height: 12),
        Divider(color: p.line, height: 1),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('باقي عليك', style: TextStyle(fontSize: 14, color: p.ink2)), const SizedBox(height: 4), Text(_km(owe), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))])),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('باقي ليك', style: TextStyle(fontSize: 14, color: p.ink2)), const SizedBox(height: 4), Text(_km(get), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))])),
        ]),
        if (lateN > 0) Padding(padding: const EdgeInsets.only(top: 10), child: Text('${toAr('$lateN')} متأخرة في السداد', style: TextStyle(fontSize: 15, color: kRed))),
        if (lateN == 0 && live.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text('${toAr('${live.length}')} جمعية شغالة', style: TextStyle(fontSize: 15, color: p.ink2))),
      ]),
    );
  }

  Widget _card(Pal p, Assoc a) {
    final lt = a.lateAmt;
    final frac = a.rounds == 0 ? 0.0 : a.paidCount / a.rounds;
    return Tap(
      scale: .985,
      onTap: () => Navigator.of(context).push(flowRoute(AssocDetailPage(id: a.id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(24)),
        child: Column(children: [
          Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: (lt > 0 ? kRed : _kAs).withValues(alpha: .16), borderRadius: BorderRadius.circular(15)), child: Icon(a.isAdmin ? Icons.supervisor_account_rounded : Icons.account_circle_outlined, color: lt > 0 ? kRed : _kAs)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Text(a.isAdmin ? 'بتديرها إنت' : (a.mgr.isEmpty ? 'مشترك فيها' : 'بيديرها ${a.mgr}'), style: TextStyle(fontSize: 13, color: p.ink2)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_m(a.amt * (a.iAmIn ? a.share : 1)), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Text(a.periodWord, style: TextStyle(fontSize: 13, color: p.ink2)),
            ]),
          ]),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: frac.clamp(0.0, 1.0), minHeight: 6, backgroundColor: p.field, valueColor: AlwaysStoppedAnimation(lt > 0 ? kRed : _kAs))),
          const SizedBox(height: 8),
          Row(children: [
            Text('${toAr('${a.paidCount}')} من ${toAr('${a.rounds}')} دور', style: TextStyle(fontSize: 14, color: p.ink2)),
            const Spacer(),
            if (a.finished) Text('خلصت', style: TextStyle(fontSize: 14, color: kGreen, fontWeight: FontWeight.w600)) else if (lt > 0) Text('متأخر ${_n(lt)}', style: TextStyle(fontSize: 14, color: kRed, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: 'الجمعيات',
      icon: Icons.groups_rounded,
      iconColor: _kAs,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Tap(onTap: () => _aboutAssoc(context), child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.info_outline_rounded, color: p.ink2))),
        Tap(onTap: () => Navigator.of(context).push(flowRoute(const AssocFormPage())), child: Container(width: 40, height: 40, decoration: BoxDecoration(color: p.acc, shape: BoxShape.circle), child: const Icon(Icons.add_rounded, color: Colors.white, size: 24))),
      ]),
      child: Live(b: (c) {
        final all = extras.assocs;
        final list = all.where((a) => filter == 'all' || (filter == 'live' ? !a.finished : a.finished)).toList();
        return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), physics: const BouncingScrollPhysics(), children: [
          Reveal(i: 0, child: _summary(p, all)),
          const SizedBox(height: 14),
          Row(children: [_chip(p, 'done', 'خلصت'), _chip(p, 'live', 'شغالة'), _chip(p, 'all', 'الكل')]),
          const SizedBox(height: 14),
          if (all.isEmpty) ...[
            emptyState(p, Icons.groups_rounded, 'مفيش جمعيات لسه\nأقدم طريقة ادخار عرفها الناس: كل واحد بيدفع نفس المبلغ كل دور، وكل دور واحد بياخد المبلغ كله.'),
            Center(child: Tap(onTap: () => _aboutAssoc(context), child: Padding(padding: const EdgeInsets.all(10), child: Text('عن الجمعية', style: TextStyle(color: _kAs, fontSize: 16, fontWeight: FontWeight.w600))))),
          ] else
            for (var i = 0; i < list.length; i++) Reveal(i: i + 1, child: _card(p, list[i])),
        ]);
      }),
    );
  }
}

// ===================== تفاصيل جمعية =====================
class AssocDetailPage extends StatelessWidget {
  final String id;
  const AssocDetailPage({super.key, required this.id});

  Assoc? get _a => extras.assocs.where((x) => x.id == id).firstOrNull;

  void _menu(BuildContext context, Assoc a) => showSheet<void>(context, (c) {
        final p = Pal.of(c);
        Widget row(IconData ic, Color col, String t, VoidCallback f) => Tap(
              onTap: () {
                Navigator.of(c).pop();
                f();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(22)),
                child: Row(children: [
                  Container(width: 44, height: 44, decoration: BoxDecoration(color: col.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)), child: Icon(ic, color: col)),
                  const SizedBox(width: 14),
                  Expanded(child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
                ]),
              ),
            );
        return SheetFrame(
          title: a.name,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              row(Icons.edit_rounded, _kAs, 'تعديل', () => Navigator.of(context).push(flowRoute(AssocFormPage(edit: a)))),
              row(a.closed ? Icons.lock_open_rounded : Icons.lock_outline_rounded, p.ink2, a.closed ? 'افتح الجمعية' : 'اقفل الجمعية', () {
                a.closed = !a.closed;
                extras.saveAssoc(a);
              }),
              row(Icons.delete_outline_rounded, kRed, 'حذف', () async {
                if (await confirmDialog(context, 'تمسح الجمعية دي؟', 'سجلها هيروح، ومعاه كل الحركات اللي كتبتها في المحفظة.', ok: 'حذف', cancel: 'إلغاء')) {
                  for (var k = 0; k < a.rounds; k++) {
                    for (final t in ['as_${a.id}_p$k', 'asr_${a.id}_$k']) {
                      if (repo.tx(t) != null) repo.delTx(t);
                    }
                  }
                  extras.delAssoc(a);
                  if (context.mounted) Navigator.of(context).maybePop();
                }
              }),
            ]),
          ),
        );
      });

  void _round(BuildContext context, Assoc a, int k) => showSheet<void>(context, (c) => Live(b: (cc) {
        final p = Pal.of(cc);
        final cur = extras.assocs.where((x) => x.id == a.id).firstOrNull;
        if (cur == null) return const SizedBox.shrink();
        final holder = cur.holderOf(k);
        final mine = holder == 'me';
        final got = cur.got.contains(k);
        final deliveredOther = cur.delivered.contains(k);
        Widget line(IconData ic, String t, String sub, {bool on = false, VoidCallback? f, String? trail}) => Tap(
              onTap: f,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(22)),
                child: Row(children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: on ? _kAsLight : p.line, shape: BoxShape.circle), child: Icon(on ? Icons.check_rounded : ic, color: on ? const Color(0xFF0B3D36) : p.ink2, size: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), if (sub.isNotEmpty) Text(sub, style: TextStyle(fontSize: 13, color: p.ink2))])),
                  if (trail != null) Text(trail, style: TextStyle(fontSize: 15, color: p.ink2)),
                ]),
              ),
            );
        return SheetFrame(
          title: 'الدور ${k + 1}',
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('موعده ${enDate(cur.dueOf(k))}', style: TextStyle(color: p.ink2, fontSize: 15))),
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: _kAs.withValues(alpha: .14), borderRadius: BorderRadius.circular(20)),
                child: Row(children: [Icon(Icons.autorenew_rounded, color: _kAs), const SizedBox(width: 10), Expanded(child: Text(mine ? 'دوري' : (holder.isEmpty ? 'الدور لسه متحددش' : holder), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))), Text(mine ? (got ? 'اتسلّم' : 'مستني') : (deliveredOther ? 'اتسلّم' : ''), style: TextStyle(color: p.ink2))]),
              ),
              if (cur.iAmIn) line(Icons.payments_outlined, 'أنا', cur.isPaid(k) ? 'دفعت' : 'لسه', on: cur.isPaid(k), trail: _m(cur.myPay), f: () {
                    if (cur.isPaid(k)) {
                      extras.undoAssocPay(cur, k);
                    } else {
                      extras.payAssocRound(cur, k);
                      toast(context, 'اتسجّل الدفع');
                    }
                  }),
              for (final x in cur.ppl.where((x) => x.turns.contains(k + 1))) line(Icons.person_outline_rounded, x.name, 'صاحب الدور', on: cur.delivered.contains(k), trail: _m(cur.pot * x.share / x.count), f: () => extras.deliverAssoc(cur, k, !cur.delivered.contains(k))),
              if (mine) ...[
                const SizedBox(height: 4),
                if (!got) bigButton(p, 'استلمت الدور (${_m(cur.myPayoutPerTurn)})', _kAs, () {
                      extras.receiveAssocRound(cur, k);
                      toast(context, 'اتسجّل القبض');
                    }) else Tap(onTap: () => extras.undoAssocReceive(cur, k), child: Container(height: 54, alignment: Alignment.center, decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(27)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.undo_rounded, color: p.ink2), const SizedBox(width: 8), const Text('تراجع عن التسليم', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))]))),
              ],
            ]),
          ),
        );
      }));

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Live(b: (c) {
      final a = _a;
      if (a == null) return PageShell(title: 'الجمعية', icon: Icons.groups_rounded, child: emptyState(p, Icons.search_off_rounded, 'الجمعية دي اتحذفت'));
      final pos = a.position;
      final hold = pos > 0.5, ahead = pos < -0.5;
      final col = hold ? kOrange : (ahead ? kGreen : p.ink2);
      return PageShell(
        title: a.name,
        sub: a.isAdmin ? 'بتديرها إنت' : 'مشترك فيها',
        icon: Icons.groups_rounded,
        iconColor: _kAs,
        trailing: Tap(onTap: () => _menu(context, a), child: Container(width: 40, height: 40, decoration: BoxDecoration(color: p.field, shape: BoxShape.circle), child: Icon(Icons.menu_rounded, color: p.ink2))),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), physics: const BouncingScrollPhysics(), children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('إنت فين دلوقتي', style: TextStyle(fontSize: 15, color: p.ink2)),
              const SizedBox(height: 6),
              Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: col, shape: BoxShape.circle)), const SizedBox(width: 8), Text(hold ? 'إنت ماسك فلوس الجمعية دلوقتي' : (ahead ? 'إنت دافع أكتر ما قبضت' : 'متعادل'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))]),
              const SizedBox(height: 6),
              Text(hold ? 'خدت دورك قبل ما تكمّل دفعه. ده قرض من غير فوايد من الجماعة، وباقي الأدوار هي سدادك ليه.' : (ahead ? 'دفعت أكتر من اللي قبضته، ودورك لسه جاي.' : 'قبضت بالظبط اللي دفعته.'), style: TextStyle(fontSize: 15, color: p.ink2, height: 1.5)),
              if (a.lateAmt > 0) Padding(padding: const EdgeInsets.only(top: 8), child: Text('متأخر ${_m(a.lateAmt)}', style: TextStyle(fontSize: 18, color: kRed, fontWeight: FontWeight.w700))),
              const SizedBox(height: 12),
              Divider(color: p.line, height: 1),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('دفعت', style: TextStyle(color: p.ink2)), Text(_km(a.paidTotal), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)), const SizedBox(height: 8), Text('باقي عليك', style: TextStyle(color: p.ink2)), Text(_km(a.leftToPay), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700))])),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('قبضت', style: TextStyle(color: p.ink2)), Text(_km(a.gotTotal), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)), const SizedBox(height: 8), Text('باقي ليك', style: TextStyle(color: p.ink2)), Text(_km(a.leftToGet), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700))])),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          for (var k = 0; k < a.rounds; k++)
            Builder(builder: (_) {
              final holder = a.holderOf(k);
              final mine = holder == 'me';
              final paid = a.isPaid(k);
              final isLate = !paid && a.iAmIn && a.dueOf(k).isBefore(DateTime.now());
              return Tap(
                scale: .985,
                onTap: () => _round(context, a, k),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22)),
                  child: Row(children: [
                    Container(width: 44, height: 44, alignment: Alignment.center, decoration: BoxDecoration(color: mine ? _kAs.withValues(alpha: .2) : p.field, borderRadius: BorderRadius.circular(14)), child: mine ? Icon(Icons.autorenew_rounded, color: _kAs) : Text(toAr('${k + 1}'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(mine ? 'دوري' : (holder.isEmpty ? 'الدور لسه متحددش' : holder), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      Text('موعده ${dateLabel(a.dueOf(k))}', style: TextStyle(fontSize: 13, color: p.ink2)),
                    ])),
                    if (a.iAmIn)
                      Tap(
                        onTap: () {
                          if (paid) {
                            _round(context, a, k);
                          } else {
                            extras.payAssocRound(a, k);
                            toast(context, 'اتسجّل الدفع');
                          }
                        },
                        child: Padding(padding: const EdgeInsets.all(6), child: Text(paid ? 'اتدفع' : 'سجّل السداد', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: paid ? p.ink2 : (isLate ? kRed : _kAs)))),
                      ),
                  ]),
                ),
              );
            }),
        ]),
      );
    });
  }
}

// ===================== إنشاء / تعديل جمعية =====================
class AssocFormPage extends StatefulWidget {
  final Assoc? edit;
  const AssocFormPage({super.key, this.edit});
  @override
  State<AssocFormPage> createState() => _AssocFormState();
}

class _AssocFormState extends State<AssocFormPage> {
  String role = 'member', name = '', mgr = '', every = 'month', order = 'agreed', acc = '', note = '';
  double amt = 0, share = 1;
  int members = 10;
  DateTime start = DateTime.now();
  bool budget = true, imIn = true;
  List<int> turns = [0];
  List<AssocPerson> ppl = [];

  bool get admin => role == 'admin';
  int get myCount => share.floor() < 1 ? 1 : share.floor();
  int get totalMembers => admin ? (imIn ? myCount : 0) + ppl.fold(0, (s, x) => s + x.count) : members;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      role = e.role; name = e.name; mgr = e.mgr; every = e.every; order = e.order; acc = e.acc; note = e.note;
      amt = e.amt; share = e.share; members = e.members; start = e.startDate; budget = e.budget; imIn = e.imIn;
      turns = e.turns.isEmpty ? [e.turn] : List<int>.from(e.turns);
      ppl = [for (final x in e.ppl) AssocPerson(x.name, share: x.share, turns: List<int>.from(x.turns))];
    }
    _fit();
  }

  void _fit() {
    while (turns.length < myCount) { turns.add(0); }
    if (turns.length > myCount) turns = turns.sublist(0, myCount);
    for (final x in ppl) {
      while (x.turns.length < x.count) { x.turns.add(0); }
      if (x.turns.length > x.count) x.turns = x.turns.sublist(0, x.count);
    }
  }

  Future<void> _pickTurn(int total, int cur, void Function(int) set) async {
    final r = await showSelect(context, 'حدّد الدور', [('0', 'لسه متحددش'), for (var i = 1; i <= total; i++) ('$i', 'الدور $i')], '$cur');
    if (r != null) setState(() => set(int.parse(r)));
  }

  void _save() {
    final n = totalMembers;
    if (name.trim().isEmpty || amt <= 0 || n < 2) return toast(context, 'راجع البيانات: الاسم والقسط وعدد الأفراد');
    final used = <int>[];
    for (final t in [if (!admin || imIn) ...turns, for (final x in ppl) ...x.turns]) {
      if (t > 0) {
        if (t > n) return toast(context, 'فيه دور أكبر من عدد الأدوار');
        if (used.contains(t)) return toast(context, 'الدور ${toAr('$t')} متكرر عند أكتر من واحد');
        used.add(t);
      }
    }
    final a = widget.edit ?? Assoc(id: 'as_${DateTime.now().microsecondsSinceEpoch}', name: name, amt: amt, start: start.millisecondsSinceEpoch);
    final first = turns.where((t) => t > 0).fold<int>(0, (m, t) => m == 0 || t < m ? t : m);
    a
      ..role = role ..name = name.trim() ..mgr = mgr.trim() ..amt = amt ..share = share ..members = n ..every = every ..order = order
      ..start = start.millisecondsSinceEpoch ..acc = acc ..note = note ..budget = budget ..imIn = imIn
      ..turns = List<int>.from(turns) ..turn = first == 0 ? 1 : first ..ppl = ppl;
    extras.saveAssoc(a);
    Navigator.of(context).pop();
  }

  Widget _label(Pal p, String t) => Padding(padding: const EdgeInsets.fromLTRB(6, 16, 6, 8), child: Text(t, style: TextStyle(fontSize: 14.5, color: p.ink2)));

  Widget _role(Pal p, String id, String t, String sub, IconData ic) {
    final on = role == id;
    return Tap(
      onTap: () => setState(() => role = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: on ? _kAs.withValues(alpha: .16) : p.card, borderRadius: BorderRadius.circular(22), border: Border.all(color: on ? _kAs : Colors.transparent, width: 1.5)),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: _kAs.withValues(alpha: .18), borderRadius: BorderRadius.circular(14)), child: Icon(ic, color: _kAs)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: on ? _kAs : p.ink)), Text(sub, style: TextStyle(fontSize: 13.5, color: p.ink2))])),
        ]),
      ),
    );
  }

  Widget _seg(Pal p, List<(String, String)> opts, String sel, void Function(String) f) => Row(children: [
        for (final o in opts)
          Expanded(
            child: Tap(
              onTap: () => setState(() => f(o.$1)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: sel == o.$1 ? _kAs.withValues(alpha: .16) : p.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: sel == o.$1 ? _kAs : Colors.transparent)),
                child: Text(o.$2, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: sel == o.$1 ? _kAs : p.ink2)),
              ),
            ),
          ),
      ]);

  Widget _turnChip(Pal p, String label, int total, int cur, void Function(int) set) => Tap(
        onTap: () => _pickTurn(total, cur, set),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(16), border: Border.all(color: cur > 0 ? _kAs : p.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Text(label, style: TextStyle(fontSize: 14.5, color: p.ink2)), const SizedBox(width: 6), Text(cur > 0 ? 'الدور ${toAr('$cur')}' : 'حدّد الدور', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: cur > 0 ? _kAs : p.ink)), Icon(Icons.expand_more_rounded, size: 18, color: p.ink2)]),
        ),
      );

  Widget _switch(Pal p, String t, String sub, bool v, ValueChanged<bool> f) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22)),
        child: Row(children: [
          Switch(value: v, onChanged: f, activeThumbColor: Colors.white, activeTrackColor: kGreen),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)), Text(sub, style: TextStyle(fontSize: 13, color: p.ink2))])),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    _fit();
    final n = totalMembers;
    final pot = amt * n;
    final mine = (!admin || imIn) ? share : 0.0;
    return PageShell(
      title: widget.edit == null ? 'جمعية جديدة' : 'تعديل الجمعية',
      icon: Icons.groups_rounded,
      iconColor: _kAs,
      child: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), physics: const BouncingScrollPhysics(), children: [
            _label(p, 'إنت فين في الجمعية دي؟'),
            _role(p, 'admin', 'أنت المدير', 'بتجمّع من الناس وبتسلّم الدور', Icons.supervisor_account_rounded),
            _role(p, 'member', 'مشترك فيها', 'بتدفع قسطك وبتستلم دورك', Icons.account_circle_outlined),
            _label(p, 'الجمعية'),
            _field(p, Icons.groups_rounded, 'اسم الجمعية', name, () async { final r = await promptText(context, 'اسم الجمعية', hint: 'اسم الجمعية', initial: name); if (r != null) setState(() => name = r.trim()); }),
            _field(p, Icons.payments_outlined, 'كل فرد يدفع كام في الدور؟', amt == 0 ? '' : _n(amt), () async { final r = await showCalc(context, amt, 'EGP'); if (r != null) setState(() => amt = r < 0 ? 0 : r); }),
            if (amt > 0 && n >= 2) Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 10), child: Text('يعني صاحب الدور هياخد ${_km(pot)}', style: TextStyle(color: p.ink2, fontSize: 14))),
            _field(p, Icons.event_rounded, 'أول دور', enDate(start), () async { final d = await showDateSheet(context, start, title: 'أول دور'); if (d != null) setState(() => start = DateTime(d.year, d.month, d.day, start.hour, start.minute)); }),
            _field(p, Icons.schedule_rounded, 'الوقت', enTime(start), () async { final d = await showTimeSheet(context, start); if (d != null) setState(() => start = d); }),
            _field(p, Icons.autorenew_rounded, 'التكرار', every == 'week' ? 'كل أسبوع' : every == '2week' ? 'كل أسبوعين' : 'كل شهر', () async { final r = await showSelect(context, 'كل', const [('week', 'كل أسبوع'), ('2week', 'كل أسبوعين'), ('month', 'كل شهر')], every); if (r != null) setState(() => every = r); }),
            _label(p, 'الناس'),
            if (!admin) ...[
              _field(p, Icons.badge_outlined, 'اسم المدير', mgr, () async { final r = await promptText(context, 'اسم المدير', hint: 'اسم المدير', initial: mgr); if (r != null) setState(() => mgr = r.trim()); }),
              Row(children: [
                Expanded(child: _field(p, Icons.pie_chart_outline_rounded, 'نصيبي', _n(share), () async { final v = await _num(context, 'نصيبي', share); if (v != null && v > 0) setState(() => share = v); })),
                const SizedBox(width: 10),
                Expanded(child: _field(p, Icons.people_alt_outlined, 'عدد الأفراد', '$members', () async { final v = await _num(context, 'عدد الأفراد', members.toDouble()); if (v != null && v >= 2) setState(() => members = v.toInt()); })),
              ]),
            ] else ...[
              _switch(p, 'وأنا مشترك فيها كمان', 'اقفله لو إنت بتنظّمها بس ومش بتدفع فيها', imIn, (v) => setState(() => imIn = v)),
              if (imIn) _field(p, Icons.pie_chart_outline_rounded, 'نصيبي', _n(share), () async { final v = await _num(context, 'نصيبي', share); if (v != null && v > 0) setState(() => share = v); }),
              for (var i = 0; i < ppl.length; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    Tap(onTap: () => setState(() => ppl.removeAt(i)), child: Icon(Icons.remove_circle_outline_rounded, color: kRed)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(ppl[i].name, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600))),
                    Tap(onTap: () async { final v = await _num(context, 'نصيب ${ppl[i].name}', ppl[i].share); if (v != null && v > 0) setState(() => ppl[i].share = v); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(14)), child: Text('نصيب ${_n(ppl[i].share)}'))),
                  ]),
                ),
              Tap(
                onTap: () async {
                  final r = await promptText(context, 'اسم الفرد', hint: 'زوّد اسم');
                  if (r != null && r.trim().isNotEmpty) setState(() => ppl.add(AssocPerson(r.trim())));
                },
                child: Container(height: 54, alignment: Alignment.center, decoration: BoxDecoration(color: _kAs.withValues(alpha: .14), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_rounded, color: _kAs), const SizedBox(width: 6), Text('زوّد فرد', style: TextStyle(color: _kAs, fontWeight: FontWeight.w700, fontSize: 16))])),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(8, 10, 8, 0), child: Text('عدد الأدوار = ${toAr('$n')} (حسب أنصبة الأفراد).', style: TextStyle(color: p.ink2, fontSize: 13.5))),
            ],
            Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 0), child: Text('داخل بنص اسم؟ اكتب ٠٫٥ — بتدفع نص القسط وبتقبض نص الدور.', style: TextStyle(color: p.ink2, fontSize: 13.5, height: 1.5))),
            _label(p, 'ترتيب الأدوار'),
            _seg(p, const [('lottery', 'بالقرعة'), ('agreed', 'بترتيب متفق عليه')], order, (v) => order = v),
            Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 0), child: Text(order == 'lottery' ? 'الأدوار بتتحدد بالقرعة، حدّد دورك بعد ما تنزل النتيجة.' : 'كل واحد عارف شهره من أول يوم.', style: TextStyle(color: p.ink2, fontSize: 13.5))),
            _label(p, 'أدوار الأفراد'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (!admin || imIn) ...[
                  const Text('أنا', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [for (var i = 0; i < turns.length; i++) _turnChip(p, turns.length > 1 ? 'فرد ${toAr('${i + 1}')}' : '', n, turns[i], (v) => turns[i] = v)]),
                ],
                for (final x in ppl) ...[
                  const SizedBox(height: 14),
                  Text(x.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [for (var i = 0; i < x.turns.length; i++) _turnChip(p, x.turns.length > 1 ? 'فرد ${toAr('${i + 1}')}' : '', n, x.turns[i], (v) => x.turns[i] = v)]),
                ],
              ]),
            ),
            if (amt > 0 && n >= 2 && mine > 0)
              Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('الدور الواحد = ${_km(pot)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('هتدفع ${_n(amt * mine)} ج.م كل دور × ${toAr('$n')} أدوار = ${_km(amt * mine * n)} إجمالي. هتقبض نفس الإجمالي في دورك أو أدوارك، والقبض مش بيوقف الدفع: هتكمّل كل دور لحد آخر الجمعية.', style: TextStyle(fontSize: 14.5, color: p.ink2, height: 1.6)),
                ]),
              ),
            _label(p, 'تفاصيل زيادة'),
            _field(p, Icons.credit_card_rounded, 'بتدفع من حساب', repo.account(acc)?.name ?? '', () async { final r = await showPickAccount(context, acc.isEmpty ? repo.defaultAcc : acc); if (r != null) setState(() => acc = r); }),
            _field(p, Icons.sticky_note_2_outlined, 'الملاحظة', note, () async { final r = await promptText(context, 'الملاحظة', hint: 'الملاحظة', initial: note); if (r != null) setState(() => note = r.trim()); }),
            _switch(p, 'احسبها من الميزانية', 'بتتسجل في الحركات وبتتحسب في المصاريف.', budget, (v) => setState(() => budget = v)),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 14), child: bigButton(p, 'حفظ الجمعية', _kAs, _save)),
      ]),
    );
  }
}

