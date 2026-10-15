import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../core/currency.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/util.dart';
import '../ui/anim.dart';
import '../ui/sheets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'more_pages.dart';

/// صفحات: 0 مصروف · 1 دخل · 2 تحويل مبلغ · 3 نقل عملية · 4 إرسال معاملة · 5 سلفة
/// كلها في PageView واحد، فالسحب يمينًا ويسارًا يتنقّل بين كل الأنواع حتى التبويبات الفرعية.
class AddTxPage extends StatefulWidget {
  final Tx? edit;
  final int page;
  final String? cat;
  const AddTxPage({super.key, this.edit, this.page = 0, this.cat});
  @override
  State<AddTxPage> createState() => _AddTxState();
}

class _AddTxState extends State<AddTxPage> with TickerProviderStateMixin {
  late final PageController pc;
  late final AnimationController shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 460));
  final saveKey = GlobalKey();
  int page = 0;
  double amt = 0;
  String cur = S.cur, acc = '', to = '', cat = 'other', icat = 'other_i', sub = '', rep = 'none', loanDir = 'owe';
  DateTime when = DateTime.now();
  DateTime? due;
  Tx? moveTx;
  bool swapped = false;
  final noteE = TextEditingController(), noteI = TextEditingController(), noteL = TextEditingController(), noteT = TextEditingController(), person = TextEditingController();

  @override
  void initState() {
    super.initState();
    final l = repo.accList;
    acc = l.first.id;
    to = l.length > 1 ? l[1].id : acc;
    if (widget.cat != null) cat = widget.cat!;
    page = widget.page;
    final e = widget.edit;
    if (e != null) {
      page = e.type == 'inc' ? 1 : 0;
      amt = e.amt;
      cur = e.cur;
      acc = e.acc;
      when = e.date;
      rep = e.rep;
      if (e.type == 'inc') {
        icat = e.cat.isEmpty ? 'other_i' : e.cat;
        noteI.text = e.note;
      } else {
        cat = e.cat.isEmpty ? 'other' : e.cat;
        sub = e.sub;
        noteE.text = e.note;
      }
    }
    pc = PageController(initialPage: page);
  }

  @override
  void dispose() {
    pc.dispose();
    shake.dispose();
    for (final c in [noteE, noteI, noteL, noteT, person]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------- مساعدات ----------
  double _tabPos(double v) => v <= 2 ? v : (v <= 4 ? 2 : 2 + (v - 4));
  Color _colorAt(Pal p, double v) {
    final cols = [p.acc, kInc, kXfer, kXfer, kXfer, p.acc];
    final i = v.floor().clamp(0, 4);
    return Color.lerp(cols[i], cols[i + 1], (v - i).clamp(0.0, 1.0))!;
  }

  double _rate() => (cur == S.cur || !S.flag('conv', true)) ? 1.0 : rates.rate(cur, S.cur);
  void _bad() {
    shake.forward(from: 0);
    HapticFeedback.heavyImpact();
  }

  void _go(int i) => pc.animateToPage(i, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);

  Future<void> _calc() async {
    final r = await showCalc(context, amt, cur);
    if (r != null) setState(() => amt = r < 0 ? 0 : r);
  }

  Future<void> _cur() async {
    final r = await showCurrencySheet(context, cur);
    if (r != null) setState(() => cur = r);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: when, firstDate: DateTime(2000), lastDate: DateTime(2100), locale: const Locale('ar'));
    if (d != null) setState(() => when = DateTime(d.year, d.month, d.day, when.hour, when.minute));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(when));
    if (t != null) setState(() => when = DateTime(when.year, when.month, when.day, t.hour, t.minute));
  }

  // ---------- حفظ ----------
  Future<void> _save({bool again = false}) async {
    FocusScope.of(context).unfocus();
    switch (page) {
      case 0:
      case 1:
        {
          if (amt <= 0) return _bad();
          final inc = page == 1;
          final old = widget.edit;
          final ts = when.millisecondsSinceEpoch;
          repo.saveTx(Tx(
            id: old?.id ?? uid(), type: inc ? 'inc' : 'exp', amt: amt, cur: cur, rate: _rate(), acc: acc,
            cat: inc ? icat : cat, sub: inc ? '' : sub, note: (inc ? noteI : noteE).text.trim(), ts: ts,
            rep: rep, nx: rep == 'none' ? 0 : nextOcc(ts, rep), src: old?.src ?? '',
          ));
          break;
        }
      case 2:
        if (amt <= 0 || acc == to) return _bad();
        repo.saveTx(Tx(id: uid(), type: 'xfer', amt: amt, cur: cur, rate: _rate(), acc: acc, to: to, note: noteT.text.trim(), ts: when.millisecondsSinceEpoch));
        break;
      case 3:
        if (moveTx == null || to == moveTx!.acc) return _bad();
        moveTx!.acc = to;
        repo.saveTx(moveTx!);
        break;
      case 4:
        if (moveTx == null) return _bad();
        final t = moveTx!;
        Share.share('${txTitle(t)} — ${fmt(t.amt)} ${curOf(t.cur).sym} — ${dateLabel(t.date)}');
        return;
      case 5:
        if (amt <= 0 || person.text.trim().isEmpty) return _bad();
        repo.addLoan(Loan(
          id: uid(), dir: loanDir, person: person.text.trim(), amt: amt, cur: cur, rate: _rate(), acc: acc,
          due: due?.millisecondsSinceEpoch ?? 0, note: noteL.text.trim(), ts: when.millisecondsSinceEpoch,
        ));
        break;
    }
    final box = saveKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) coinBurst(context, box.localToGlobal(box.size.center(Offset.zero)));
    HapticFeedback.mediumImpact();
    if (S.flag('sound', true)) SystemSound.play(SystemSoundType.click);
    if (again) {
      setState(() {
        amt = 0;
        moveTx = null;
        for (final c in [noteE, noteI, noteL, noteT, person]) {
          c.clear();
        }
      });
    } else {
      Future.delayed(const Duration(milliseconds: 650), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  // ---------- عناصر ----------
  Widget _label(Pal p, String t) => Padding(padding: const EdgeInsets.fromLTRB(8, 18, 8, 8), child: Text(t, style: TextStyle(fontSize: 15, color: p.ink2)));

  Widget _amountCard(Pal p, {bool camera = true}) => AnimatedBuilder(
        animation: shake,
        builder: (c, ch) => Transform.translate(offset: Offset(math.sin(shake.value * math.pi * 6) * 9 * (1 - shake.value), 0), child: ch),
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: cardDeco(p, r: 26),
          child: Row(children: [
            Tap(
              onTap: _cur,
              child: Row(children: [
                Text(curOf(cur).sym, style: TextStyle(fontSize: 20, color: p.ink2)),
                Icon(Icons.keyboard_arrow_down_rounded, color: p.ink2),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Tap(
                onTap: _calc,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(fontFamily: 'PlexArabic', fontSize: amt == 0 ? 28 : 30, fontWeight: amt == 0 ? FontWeight.w400 : FontWeight.w700, color: amt == 0 ? p.line : p.ink),
                    child: Text(amt == 0 ? '0' : fmt(amt)),
                  ),
                ),
              ),
            ),
            if (camera) ...[
              Tap(onTap: () => showSheet<void>(context, (c) => SheetFrame(title: 'مسح الفاتورة', child: Padding(padding: const EdgeInsets.only(bottom: 20), child: emptyState(Pal.of(c), '📸', 'قراءة الفاتورة بالكاميرا قريباً.\nحالياً اكتب المبلغ أو استخدم «تحدث».')))), child: Icon(Icons.photo_camera_rounded, color: p.ink2)),
              Container(width: 1, height: 26, margin: const EdgeInsets.symmetric(horizontal: 14), color: p.line),
            ],
            Tap(onTap: _calc, child: Icon(Icons.calculate_rounded, color: p.ink2, size: 28)),
          ]),
        ),
      );

  Widget _select(Pal p, {required Widget lead, required String title, Widget? sub, required VoidCallback onTap, String? hint}) => Tap(
        onTap: onTap,
        scale: .98,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: cardDeco(p, r: 26),
          child: Row(children: [
            lead,
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                if (hint != null) Text(hint, style: TextStyle(fontSize: 14, color: p.ink2)),
                Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                if (sub != null) sub,
              ]),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: p.ink2, size: 28),
          ]),
        ),
      );

  Widget _accSelect(Pal p, String id, void Function(String) set, {String? hint, String? exclude}) {
    final a = repo.account(id) ?? repo.accList.first;
    return _select(
      p,
      hint: hint,
      lead: bankIcon(a.kind, size: 52),
      title: a.name,
      sub: Row(children: [
        Icon(Icons.bar_chart_rounded, size: 14, color: p.acc),
        const SizedBox(width: 4),
        Text(repo.budgetFor(a).name, style: TextStyle(color: p.ink2, fontSize: 14)),
      ]),
      onTap: () async {
        final r = await showPickAccount(context, id, exclude: exclude);
        if (r != null) setState(() => set(r));
      },
    );
  }

  Widget _noteField(Pal p, TextEditingController c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: cardDeco(p, r: 22),
        child: TextField(controller: c, decoration: InputDecoration(border: InputBorder.none, hintText: 'إضافة ملاحظة', hintStyle: TextStyle(color: p.ink2.withValues(alpha: .6)))),
      );

  Widget _rowCard(Pal p, IconData ic, String hint, String val, VoidCallback f, {VoidCallback? onLong}) => Tap(
        onTap: f,
        onLongPress: onLong,
        scale: .98,
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: cardDeco(p, r: 22),
          child: Row(children: [
            Icon(ic, color: p.ink2),
            const SizedBox(width: 12),
            Text(hint, style: TextStyle(color: p.ink2, fontSize: 16)),
            const SizedBox(width: 8),
            Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  static const _subEmoji = {'كهرباء': '⚡', 'مياه': '💧', 'غاز': '🔥', 'رسوم النظافة': '🗑️', 'قهوة': '☕', 'وقود': '⛽', 'دواء': '💊'};

  Widget _subChips(Pal p, Cat c) {
    final subs = repo.subsOf(c);
    Widget chip(String label, bool on, VoidCallback f, {bool dashed = false, VoidCallback? long, IconData? ic}) => Tap(
          onTap: f,
          onLongPress: long,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(color: on ? p.ink : (dashed ? Colors.transparent : p.field), borderRadius: BorderRadius.circular(26), border: dashed ? Border.all(color: p.line, width: 1.6) : null),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: on ? p.bg : (dashed ? p.ink2 : p.ink))),
              if (ic != null) ...[const SizedBox(width: 6), Icon(ic, size: 18, color: p.ink2)],
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Wrap(spacing: 10, runSpacing: 10, children: [
        chip('بدون', sub.isEmpty, () => setState(() => sub = '')),
        for (final s in subs) chip('${_subEmoji[s] ?? ''} $s'.trim(), sub == s, () => setState(() => sub = s)),
        chip('تعديل', false, () async {
          final r = await promptText(context, 'تصنيف فرعي جديد لـ ${c.name}', hint: 'اسم التصنيف');
          if (r != null && r.isNotEmpty) {
            repo.addSub(c.id, r);
            setState(() => sub = r);
          }
        }, dashed: true, ic: Icons.account_tree_rounded),
      ]),
    );
  }

  Widget _catBlock(Pal p, bool inc) {
    final c = catOf(inc ? icat : cat);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(p, 'التصنيف'),
      _select(p, lead: emojiBubble(p, c.emoji, size: 44, bg: Colors.transparent), title: c.name, onTap: () async {
        final r = await showPickCat(context, inc, c.id);
        if (r != null) {
          setState(() {
            if (inc) {
              icat = r.id;
            } else {
              cat = r.id;
              sub = '';
            }
          });
        }
      }),
      if (!inc) _subChips(p, c),
    ]);
  }

  Widget _noteBlock(Pal p, TextEditingController c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label(p, 'ملاحظة (اختياري)'), _noteField(p, c)]);

  Widget _dateTime(Pal p) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(p, 'التاريخ'),
        _rowCard(p, Icons.event_rounded, 'اختر التاريخ', dateLabel(when), _pickDate),
        _label(p, 'الوقت'),
        _rowCard(p, Icons.schedule_rounded, 'الوقت', timeLabel(when), _pickTime),
      ]);

  static const _reps = [('none', 'لا يتكرر'), ('daily', 'يومياً'), ('weekly', 'أسبوعياً'), ('monthly', 'شهرياً')];
  Widget _repBlock(Pal p) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(p, 'تكرار المعاملة'),
        _select(p, lead: Icon(Icons.autorenew_rounded, color: p.ink2), title: _reps.firstWhere((r) => r.$1 == rep).$2, onTap: () async {
          final r = await showSelect(context, 'تكرار المعاملة', _reps, rep);
          if (r != null) setState(() => rep = r);
        }),
      ]);

  // ---------- الصفحات ----------
  Widget _scroll(List<Widget> c) => ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), physics: const BouncingScrollPhysics(), children: c);

  Widget _money(Pal p, bool inc) {
    final catFirst = S.flag('catFirst', true);
    final cb = _catBlock(p, inc), nb = _noteBlock(p, inc ? noteI : noteE);
    return _scroll([
      _amountCard(p),
      _label(p, 'الحساب والميزانية'),
      _accSelect(p, acc, (v) => acc = v),
      if (catFirst) ...[cb, nb] else ...[nb, cb],
      _dateTime(p),
      _repBlock(p),
    ]);
  }

  Widget _subTabs(Pal p) {
    const names = ['تحويل مبلغ', 'نقل عملية', 'إرسال معاملة'];
    final cur2 = page.clamp(2, 4) - 2;
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 12),
      child: Row(children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: Tap(
              onTap: () => _go(2 + i),
              child: Column(children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: TextStyle(fontFamily: 'PlexArabic', fontSize: 17, fontWeight: cur2 == i ? FontWeight.w700 : FontWeight.w400, color: cur2 == i ? p.ink : p.ink2),
                  child: Text(names[i]),
                ),
                const SizedBox(height: 8),
                AnimatedContainer(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic, height: 3, width: cur2 == i ? 52 : 0, decoration: BoxDecoration(color: p.ink2, borderRadius: BorderRadius.circular(3))),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _xferAmt(Pal p) => _scroll([
        _amountCard(p, camera: false),
        _subTabs(p),
        _accSelect(p, acc, (v) => acc = v, hint: 'من حساب'),
        Padding(padding: const EdgeInsets.only(top: 6, right: 6), child: Text('المتاح: ${money(repo.bal(acc))}', style: TextStyle(color: p.ink2))),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Tap(
              onTap: () => setState(() {
                final t = acc;
                acc = to;
                to = t;
                swapped = !swapped;
              }),
              child: AnimatedRotation(
                turns: swapped ? .5 : 0,
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                child: Container(width: 54, height: 54, decoration: BoxDecoration(color: p.card, shape: BoxShape.circle), child: Icon(Icons.swap_vert_rounded, color: p.ink2)),
              ),
            ),
          ),
        ),
        _accSelect(p, to, (v) => to = v, hint: 'إلى حساب'),
        _noteBlock(p, noteT),
        _label(p, 'التاريخ'),
        _rowCard(p, Icons.event_rounded, 'اختر التاريخ', dateLabel(when), _pickDate),
      ]);

  Widget _txPick(Pal p, {bool too = true}) {
    final t = moveTx;
    return Column(children: [
      Center(
        child: Tap(
          onTap: () async {
            final r = await showPickTx(context, accId: too ? acc : null);
            if (r != null) setState(() => moveTx = r);
          },
          child: Column(children: [
            AnimatedContainer(duration: const Duration(milliseconds: 300), width: 62, height: 62, decoration: BoxDecoration(color: t == null ? p.card : kXfer.withValues(alpha: .12), shape: BoxShape.circle), child: Icon(Icons.drive_file_move_rounded, color: t == null ? p.ink2 : kXfer)),
            const SizedBox(height: 8),
            AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: Text(t == null ? 'اختر العملية' : '${txTitle(t)} · ${fmt(t.amt)} ${curOf(t.cur).sym}', key: ValueKey(t?.id ?? ''), style: TextStyle(color: p.ink2, fontSize: 17))),
          ]),
        ),
      ),
    ]);
  }

  Widget _xferMove(Pal p) => _scroll([
        _subTabs(p),
        _accSelect(p, acc, (v) {
          acc = v;
          moveTx = null;
        }, hint: 'من حساب'),
        const SizedBox(height: 14),
        _txPick(p),
        const SizedBox(height: 14),
        _accSelect(p, to, (v) => to = v, hint: 'إلى حساب'),
        Padding(padding: const EdgeInsets.all(14), child: Text('تُنقل العملية بمبلغها وتاريخها وتصنيفها كما هي إلى الحساب الجديد.', textAlign: TextAlign.center, style: TextStyle(color: p.ink2, height: 1.6))),
      ]);

  Widget _xferSend(Pal p) => _scroll([
        _subTabs(p),
        const SizedBox(height: 10),
        _txPick(p, too: false),
        Padding(padding: const EdgeInsets.all(18), child: Text('اختر عملية ثم اضغط «إرسال» لمشاركتها مع شخص عبر أي تطبيق.', textAlign: TextAlign.center, style: TextStyle(color: p.ink2, height: 1.6))),
      ]);

  Widget _loan(Pal p) {
    Widget dirBtn(String d, String label, IconData ic, Color c) {
      final on = loanDir == d;
      return Expanded(
        child: Tap(
          onTap: () => setState(() => loanDir = d),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            height: 68,
            decoration: BoxDecoration(color: on ? c.withValues(alpha: .16) : p.field, borderRadius: BorderRadius.circular(26)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(label, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: on ? c : p.ink2)),
              const SizedBox(width: 8),
              AnimatedRotation(turns: on ? 0 : .25, duration: const Duration(milliseconds: 300), child: Icon(ic, color: on ? c : p.ink2)),
            ]),
          ),
        ),
      );
    }

    return _scroll([
      _amountCard(p, camera: false),
      const SizedBox(height: 14),
      Row(children: [dirBtn('owed', 'ليّا فلوس', Icons.arrow_downward_rounded, kInc), const SizedBox(width: 12), dirBtn('owe', 'عليّا فلوس', Icons.arrow_upward_rounded, p.acc)]),
      const SizedBox(height: 14),
      Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(22)),
        child: Row(children: [
          Icon(Icons.person_rounded, color: p.ink2),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: person, decoration: InputDecoration(border: InputBorder.none, hintText: 'اسم الشخص', hintStyle: TextStyle(color: p.ink2)))),
        ]),
      ),
      const SizedBox(height: 12),
      Tap(
        scale: .98,
        onTap: () async {
          final d = await showDatePicker(context: context, initialDate: due ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime(2100), locale: const Locale('ar'));
          if (d != null) setState(() => due = d);
        },
        onLongPress: () => setState(() => due = null),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(22)),
          child: Row(children: [
            Icon(Icons.schedule_rounded, color: p.ink2),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('تاريخ الاستحقاق', style: TextStyle(color: p.ink2, fontSize: 14)),
              Text(due == null ? 'بدون موعد' : dateLabel(due!), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
        child: Text('كل سلفة تُسجَّل تلقائياً في سجل الحركات — والمبلغ المستلَف لا يُحتسب دخلاً', style: TextStyle(color: p.ink2, height: 1.6)),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: Wrap(children: [
          Text('يمكنك متابعة السلفة من «السلف والديون» في الأدوات، أو ', style: TextStyle(color: p.ink2, height: 1.6)),
          GestureDetector(onTap: () => Navigator.of(context).push(flowRoute(const LoansPage())), child: Text('اضغط هنا', style: TextStyle(color: p.ink, decoration: TextDecoration.underline, height: 1.6))),
        ]),
      ),
      _noteBlock(p, noteL),
      _dateTime(p),
    ]);
  }

  // ---------- الهيكل ----------
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final editing = widget.edit != null;
    const tabNames = ['المصاريف', 'الدخل', 'تحويل', 'سلف'];
    const labels = ['حفظ المصروف', 'حفظ الدخل', 'حفظ التحويل', 'نقل عملية', 'إرسال', 'حفظ'];
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: pc,
          builder: (ctx, child) {
            final v = (pc.hasClients && pc.position.haveDimensions) ? (pc.page ?? page.toDouble()) : page.toDouble();
            final col = _colorAt(p, v);
            final pos = _tabPos(v);
            final pi = v.round().clamp(0, 5);
            return Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(children: [
                  RoundBtn(Icons.close_rounded, () => Navigator.of(context).pop(), bg: Colors.transparent),
                  Expanded(child: Center(child: Text(editing ? 'تعديل معاملة' : 'إضافة معاملة', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)))),
                  RoundBtn(Icons.check_rounded, () => _save(), bg: Colors.transparent),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Container(
                  height: 66,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(28)),
                  child: LayoutBuilder(builder: (c, bc) {
                    final seg = bc.maxWidth / 4;
                    return Stack(children: [
                      PositionedDirectional(start: pos * seg, top: 0, bottom: 0, width: seg, child: Container(decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(22)))),
                      Row(children: [
                        for (var i = 0; i < 4; i++)
                          Expanded(
                            child: Tap(
                              scale: .96,
                              onTap: editing ? null : () => _go(const [0, 1, 2, 5][i]),
                              child: Center(child: Text(tabNames[i], style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color.lerp(p.ink2, Colors.white, (1 - (pos - i).abs()).clamp(0.0, 1.0))))),
                            ),
                          ),
                      ]),
                    ]);
                  }),
                ),
              ),
              Expanded(child: child!),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                child: Row(children: [
                  if (pi != 3 && pi != 4 && !editing) ...[
                    Tap(
                      onTap: () => _save(again: true),
                      child: Container(width: 62, height: 62, decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: col, width: 1.6)), child: Icon(Icons.add_rounded, color: col, size: 30)),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(child: bigButton(p, editing ? 'حفظ التعديل' : labels[pi], col, () => _save(), key: saveKey)),
                ]),
              ),
            ]);
          },
          child: PageView(
            controller: pc,
            physics: editing ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
            onPageChanged: (i) {
              setState(() => page = i);
              FocusScope.of(context).unfocus();
              tick();
            },
            children: [_money(p, false), _money(p, true), _xferAmt(p), _xferMove(p), _xferSend(p), _loan(p)],
          ),
        ),
      ),
    );
  }
}
