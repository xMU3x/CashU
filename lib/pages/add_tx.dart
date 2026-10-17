import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../core/currency.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/util.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/sheets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'more_pages.dart';

/// صفحات: 0 مصروف · 1 دخل · 2 تحويل · 3 نقل عملية · 4 إرسال معاملة · 5 سلفة · 6 تسوية رصيد
class AddTxPage extends StatefulWidget {
  final Tx? edit;
  final int page;
  final String? cat, accId;
  const AddTxPage({super.key, this.edit, this.page = 0, this.cat, this.accId});
  @override
  State<AddTxPage> createState() => _AddTxState();
}

class _AddTxState extends State<AddTxPage> with TickerProviderStateMixin {
  late final PageController pc;
  late final AnimationController shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 460));
  final saveKey = GlobalKey();
  int page = 0;
  double amt = 0;
  String tags = '', link = '';
  String cur = S.cur, acc = '', to = '', cat = 'other', icat = 'other_i', sub = '', rep = 'none', loanDir = 'owe', payee = '';
  DateTime when = DateTime.now();
  DateTime recv = DateTime.now();
  DateTime? due;
  Tx? moveTx;
  bool swapped = false, pend = false, showAll = false, catPicked = false;
  List<(String, double)> splits = []; // تقسيم المبلغ على أكثر من حساب
  final noteE = TextEditingController(), noteI = TextEditingController(), noteL = TextEditingController(), noteT = TextEditingController(), person = TextEditingController();

  static const _segPages = [0, 1, 2, 6];
  static const _titles = ['Expense', 'Income', 'Transfer', 'Move Transaction', 'Share Transaction', 'Loan', 'Balance Adjustment'];

  @override
  void initState() {
    super.initState();
    final l = repo.accList;
    acc = l.first.id;
    if (widget.accId != null && repo.account(widget.accId!) != null && !(repo.account(widget.accId!)!.arch)) acc = widget.accId!;
    to = l.firstWhere((a) => a.id != acc, orElse: () => l.first).id;
    if (widget.cat != null) {
      cat = widget.cat!;
      catPicked = true;
    }
    page = widget.page;
    final e = widget.edit;
    if (e != null) {
      page = e.type == 'inc' ? 1 : 0;
      amt = e.amt;
      cur = e.cur;
      acc = e.acc;
      when = e.date;
      rep = e.rep;
      pend = e.pend;
      payee = e.pay;
      tags = e.tags;
      link = e.link;
      catPicked = true;
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
  Color _col(int pi) => pi == 0 ? kRed : (pi == 1 ? kGreen : kBlue);
  double _rate() => (cur == S.cur || !S.flag('conv', true)) ? 1.0 : rates.rate(cur, S.cur);
  void _bad() {
    shake.forward(from: 0);
    HapticFeedback.heavyImpact();
  }

  void _go(int i) => pc.animateToPage(i, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);

  Future<void> _calc({bool allowNeg = false}) async {
    final r = await showCalc(context, amt, cur);
    if (r != null) {
      setState(() {
        amt = (!allowNeg && r < 0) ? 0 : r;
        if (splits.isNotEmpty && (splits.fold(0.0, (a, x) => a + x.$2) - amt).abs() > 0.005) splits = [];
      });
    }
  }

  Future<void> _cur() async {
    final r = await showCurrencySheet(context, cur);
    if (r != null) setState(() => cur = r);
  }

  Future<void> _pickDate(bool second) async {
    final base = second ? recv : when;
    final d = await showDatePicker(context: context, initialDate: base, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d != null) {
      setState(() {
        final n = DateTime(d.year, d.month, d.day, base.hour, base.minute);
        if (second) {
          recv = n;
        } else {
          when = n;
        }
      });
    }
  }

  Future<void> _pickTime(bool second) async {
    final base = second ? recv : when;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
    if (t != null) {
      setState(() {
        final n = DateTime(base.year, base.month, base.day, t.hour, t.minute);
        if (second) {
          recv = n;
        } else {
          when = n;
        }
      });
    }
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
          final parts = (old == null && splits.length > 1) ? splits : <(String, double)>[(acc, amt)];
          final gid = parts.length > 1 ? uid() : '';
          for (final part in parts) {
            repo.saveTx(Tx(
              id: parts.length > 1 ? uid() : (old?.id ?? uid()), type: inc ? 'inc' : 'exp', amt: part.$2, cur: cur, rate: _rate(), acc: part.$1,
              cat: inc ? icat : cat, sub: inc ? '' : sub, note: (inc ? noteI : noteE).text.trim(), pay: payee, pend: pend, ts: ts,
              rep: rep, nx: rep == 'none' ? 0 : nextOcc(ts, rep), src: old?.src ?? '', split: gid, tags: tags, link: link,
            ));
          }
          break;
        }
      case 2:
        if (amt <= 0 || acc == to) return _bad();
        repo.saveTx(Tx(id: uid(), type: 'xfer', amt: amt, cur: cur, rate: _rate(), acc: acc, to: to, note: noteT.text.trim(), pend: pend, ts: when.millisecondsSinceEpoch));
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
      case 6:
        {
          final delta = amt - repo.bal(acc);
          if (delta.abs() < 0.005) return _bad();
          repo.saveTx(Tx(id: uid(), type: 'adj', amt: delta.abs(), cur: S.cur, rate: 1, acc: acc, sign: delta >= 0 ? 1 : -1, note: 'New balance', pend: false, ts: when.millisecondsSinceEpoch));
          break;
        }
    }
    final box = saveKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) coinBurst(context, box.localToGlobal(box.size.center(Offset.zero)));
    HapticFeedback.mediumImpact();
    if (S.flag('sound', true)) SystemSound.play(SystemSoundType.click);
    if (again) {
      setState(() {
        amt = 0;
        moveTx = null;
        payee = '';
        splits = [];
        for (final c in [noteE, noteI, noteL, noteT, person]) {
          c.clear();
        }
      });
    } else {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  // ---------- لبنات الواجهة ----------
  Widget _card(Pal p, List<Widget> rows) => Container(
        decoration: iosCard(p, r: 22),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[rows[i], if (i < rows.length - 1) hair(p, indent: 48)],
        ]),
      );

  Widget _line(Pal p, IconData ic, Widget content, {VoidCallback? onTap, bool chev = true, Widget? trailing}) => Tap(
        onTap: onTap,
        scale: .99,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            Icon(ic, color: p.ink2, size: 22),
            const SizedBox(width: 12),
            Expanded(child: content),
            if (trailing != null) trailing,
            if (chev) Icon(Icons.chevron_right_rounded, color: p.ink2.withValues(alpha: .7), size: 22),
          ]),
        ),
      );

  Widget _ph(Pal p, String t) => Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, color: p.ink2.withValues(alpha: .75)));
  Widget _val(String t) => Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16));

  Widget _accLine(Pal p, String id, void Function(String) set, {String? hint, String? exclude}) {
    final a = repo.account(id);
    final Widget content = a == null
        ? _val(hint ?? 'Select Account')
        : Text.rich(TextSpan(children: [TextSpan(text: a.name, style: const TextStyle(fontSize: 16)), TextSpan(text: ' (${egp(repo.bal(a.id))})', style: TextStyle(fontSize: 15, color: p.ink2))]), maxLines: 1, overflow: TextOverflow.ellipsis);
    return _line(p, Icons.credit_card_rounded, content, onTap: () async {
      final r = await showPickAccount(context, id, exclude: exclude);
      if (r != null) setState(() => set(r));
    });
  }

  Widget _amountLine(Pal p, {String hint = 'Amount', bool neg = false}) => AnimatedBuilder(
        animation: shake,
        builder: (c, ch) => Transform.translate(offset: Offset(math.sin(shake.value * math.pi * 6) * 9 * (1 - shake.value), 0), child: ch),
        child: _line(
          p,
          Icons.exposure_rounded,
          Tap(
            onTap: () => _calc(allowNeg: neg),
            child: Align(alignment: Alignment.centerLeft, child: Text(amt == 0 ? hint : fmt(amt), style: TextStyle(fontSize: 16, color: amt == 0 ? p.ink2.withValues(alpha: .75) : p.ink))),
          ),
          chev: false,
          trailing: Tap(onTap: _cur, child: Row(children: [Text(cur, style: const TextStyle(fontSize: 16, color: kBlue)), Icon(Icons.chevron_right_rounded, color: p.ink2.withValues(alpha: .7), size: 22)])),
        ),
      );

  Widget _textLine(Pal p, IconData ic, String hint, String value, void Function(String) set) => _line(p, ic, value.isEmpty ? _ph(p, hint) : _val(value), onTap: () async {
        final r = await promptText(context, hint, hint: hint, initial: value);
        if (r != null) setState(() => set(r.trim()));
      });

  Widget _dateChip(Pal p, String t, VoidCallback f) => Tap(onTap: f, child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(18)), child: Text(t, style: const TextStyle(fontSize: 15))));

  Widget _dateLine(Pal p, IconData ic, String label, DateTime d, bool second) => Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          Icon(ic, color: p.ink2, size: 22),
          const SizedBox(width: 10),
          _dateChip(p, enDate(d), () => _pickDate(second)),
          const SizedBox(width: 8),
          _dateChip(p, enTime(d), () => _pickTime(second)),
          const Spacer(),
          Text(label, style: TextStyle(fontSize: 13.5, color: p.ink2)),
        ]),
      );

  Widget _statusLine(Pal p) => Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          Icon(Icons.bookmark_border_rounded, color: p.ink2, size: 24),
          const SizedBox(width: 12),
          smallChip('Cleared', !pend, () => setState(() => pend = false)),
          const SizedBox(width: 8),
          smallChip('Pending', pend, () => setState(() => pend = true)),
        ]),
      );

  static const _reps = [('none', 'Does not repeat'), ('daily', 'Daily'), ('weekly', 'Weekly'), ('monthly', 'Monthly')];
  Widget _repLine(Pal p) => _line(p, Icons.autorenew_rounded, Text('Repeat: ${_reps.firstWhere((r) => r.$1 == rep).$2}', style: const TextStyle(fontSize: 16)), onTap: () async {
        final r = await showSelect(context, 'Repeat', _reps, rep);
        if (r != null) setState(() => rep = r);
      });

  Widget _subChips(Pal p, Cat c) {
    final subs = repo.subsOf(c);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        smallChip('None', sub.isEmpty, () => setState(() => sub = '')),
        for (final s in subs) smallChip(s, sub == s, () => setState(() => sub = s)),
        Tap(
          onTap: () async {
            final r = await promptText(context, 'New sub-category for ${c.name}', hint: 'Name');
            if (r != null && r.isNotEmpty) {
              repo.addSub(c.id, r);
              setState(() => sub = r);
            }
          },
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: p.line, width: 1.4)), child: Icon(Icons.add_rounded, size: 18, color: p.ink2)),
        ),
      ]),
    );
  }

  Future<void> _split(bool inc) async {
    if (amt <= 0) {
      _bad();
      toast(context, 'اكتب المبلغ أولًا ثم قسّمه');
      return;
    }
    if (widget.edit != null) {
      toast(context, 'التقسيم متاح عند إضافة معاملة جديدة');
      return;
    }
    final r = await showSplitSheet(context, amt, cur, acc, splits);
    if (r != null) setState(() => splits = r.length > 1 ? r : []);
  }

  Widget _catLine(Pal p, bool inc) {
    final c = catOf(inc ? icat : cat);
    return SizedBox(
      height: 52,
      child: Row(children: [
        Expanded(
          child: _line(p, Icons.folder_open_rounded, catPicked ? _val(c.name) : const Text('Select Category', style: TextStyle(fontSize: 16)), onTap: () async {
            final r = await showPickCat(context, inc, c.id);
            if (r != null) {
              setState(() {
                catPicked = true;
                if (inc) {
                  icat = r.id;
                } else {
                  cat = r.id;
                  sub = '';
                }
              });
            }
          }),
        ),
        Container(width: .6, height: 52, color: p.line),
        Tap(onTap: () => _split(inc), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Row(children: [const Text('Split', style: TextStyle(fontSize: 16)), const SizedBox(width: 6), Icon(Icons.call_split_rounded, size: 20, color: p.ink)]))),
      ]),
    );
  }

  Widget _splitLine(Pal p) => _line(p, Icons.call_split_rounded, Text(splits.map((x) => '${repo.account(x.$1)?.name ?? ''} (${fmt(x.$2)})').join(' + '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)), onTap: () => _split(page == 1), trailing: Tap(onTap: () => setState(() => splits = []), child: Icon(Icons.cancel_rounded, color: p.ink2, size: 20)), chev: false);

  Widget _bottomPills(Pal p) => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Tap(onTap: _options, child: Glass(radius: 22, height: 44, padding: const EdgeInsets.symmetric(horizontal: 38), child: const Center(child: Text('Options', style: TextStyle(color: kBlue, fontSize: 16))))),
          Tap(
            onTap: () => setState(() => showAll = !showAll),
            child: Glass(radius: 22, height: 44, padding: const EdgeInsets.symmetric(horizontal: 30), child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [const Text('Show All', style: TextStyle(color: kBlue, fontSize: 16)), const SizedBox(width: 4), Icon(showAll ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, color: kBlue)]))),
          ),
        ]),
      );

  void _options() => showPillMenu(context, [
        ('Save & Add Another', () => _save(again: true)),
        ('Repeat…', () => setState(() => showAll = true)),
        ('Loan / Debt', () => _go(5)),
        ('Move Transaction', () => _go(3)),
        ('Share Transaction', () => _go(4)),
      ]);

  // ---------- الصفحات ----------
  Widget _scroll(List<Widget> c) => ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 30), physics: const BouncingScrollPhysics(), children: c);

  Widget _money(Pal p, bool inc) {
    final c = catOf(inc ? icat : cat);
    return _scroll([
      _card(p, [
        splits.length > 1 ? _splitLine(p) : _accLine(p, acc, (v) => acc = v),
        _amountLine(p),
        _line(p, Icons.person_outline_rounded, payee.isEmpty ? _ph(p, 'Payee') : _val(payee), onTap: () async {
          final r = await showPayeeSheet(context, payee);
          if (r != null) setState(() => payee = r);
        }),
        _textLine(p, Icons.text_fields_rounded, 'Description', (inc ? noteI : noteE).text, (v) => (inc ? noteI : noteE).text = v),
        _catLine(p, inc),
        if (showAll && !inc && catPicked) _subChips(p, c),
        _dateLine(p, Icons.calendar_month_rounded, 'Date & time', when, false),
        _textLine(p, Icons.sell_outlined, 'Tags (comma separated)', tags, (v) => tags = v.split(RegExp(r'[,،]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().join(', ')),
        _textLine(p, Icons.link_rounded, 'Attachment / Link', link, (v) => link = v),
        _statusLine(p),
        if (showAll) _repLine(p),
      ]),
      _bottomPills(p),
    ]);
  }

  Widget _xfer(Pal p) {
    final a = repo.account(acc), b = repo.account(to);
    final def = 'Transfer ${a?.name ?? ''} ▶ ${b?.name ?? ''}';
    return _scroll([
      _card(p, [
        Stack(alignment: Alignment.centerRight, children: [
          Column(children: [
            _accLine(p, acc, (v) => acc = v, hint: 'Select Account'),
            hair(p, indent: 48),
            _accLine(p, to, (v) => to = v, hint: 'Select Account'),
          ]),
          Padding(
            padding: const EdgeInsets.only(right: 40),
            child: Tap(
              onTap: () => setState(() {
                final t = acc;
                acc = to;
                to = t;
                swapped = !swapped;
              }),
              child: AnimatedRotation(turns: swapped ? .5 : 0, duration: const Duration(milliseconds: 360), curve: Curves.easeOutBack, child: Container(width: 38, height: 38, decoration: BoxDecoration(color: p.field, shape: BoxShape.circle), child: const Icon(Icons.swap_vert_rounded, size: 22))),
            ),
          ),
        ]),
        _amountLine(p, hint: 'Transfer amount'),
        _line(p, Icons.text_fields_rounded, noteT.text.isEmpty ? _val(def) : _val(noteT.text), onTap: () async {
          final r = await promptText(context, 'Description', hint: def, initial: noteT.text);
          if (r != null) setState(() => noteT.text = r.trim());
        }),
        _dateLine(p, Icons.calendar_month_rounded, 'Send date', when, false),
        _dateLine(p, Icons.edit_calendar_rounded, 'Receive date', recv, true),
        _statusLine(p),
      ]),
      _bottomPills(p),
    ]);
  }

  Widget _txPick(Pal p, {bool too = true}) {
    final t = moveTx;
    return _line(p, Icons.drive_file_move_rounded, t == null ? _ph(p, 'Select transaction') : _val('${txTitle(t)} · ${fmt(t.amt)} ${curOf(t.cur).sym}'), onTap: () async {
      final r = await showPickTx(context, accId: too ? acc : null);
      if (r != null) setState(() => moveTx = r);
    });
  }

  Widget _move(Pal p) => _scroll([
        _card(p, [
          _accLine(p, acc, (v) {
            acc = v;
            moveTx = null;
          }),
          _txPick(p),
          _accLine(p, to, (v) => to = v),
        ]),
        Padding(padding: const EdgeInsets.all(16), child: Text('The transaction moves to the new account with its amount, date and category unchanged.', textAlign: TextAlign.center, style: TextStyle(color: p.ink2, height: 1.5))),
      ]);

  Widget _send(Pal p) => _scroll([
        _card(p, [_txPick(p, too: false)]),
        Padding(padding: const EdgeInsets.all(16), child: Text('Pick a transaction, then tap Save to share it with anyone via any app.', textAlign: TextAlign.center, style: TextStyle(color: p.ink2, height: 1.5))),
      ]);

  Widget _loan(Pal p) => _scroll([
        _card(p, [
          _accLine(p, acc, (v) => acc = v),
          _amountLine(p),
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              Icon(Icons.swap_vert_rounded, color: p.ink2, size: 22),
              const SizedBox(width: 12),
              smallChip('They owe me', loanDir == 'owed', () => setState(() => loanDir = 'owed')),
              const SizedBox(width: 8),
              smallChip('I owe them', loanDir == 'owe', () => setState(() => loanDir = 'owe')),
            ]),
          ),
          _line(p, Icons.person_outline_rounded, TextField(controller: person, style: const TextStyle(fontSize: 16), decoration: InputDecoration(border: InputBorder.none, isDense: true, hintText: 'Person name', hintStyle: TextStyle(color: p.ink2.withValues(alpha: .75)))), chev: false),
          _line(p, Icons.event_busy_rounded, due == null ? _ph(p, 'Due date (optional)') : _val(enDate(due!)), onTap: () async {
            final d = await showDatePicker(context: context, initialDate: due ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime(2100));
            if (d != null) setState(() => due = d);
          }, trailing: due == null ? null : Tap(onTap: () => setState(() => due = null), child: Icon(Icons.cancel_rounded, color: p.ink2, size: 20))),
          _line(p, Icons.text_fields_rounded, noteL.text.isEmpty ? _ph(p, 'Note') : _val(noteL.text), onTap: () async {
            final r = await promptText(context, 'Note', hint: 'Note', initial: noteL.text);
            if (r != null) setState(() => noteL.text = r.trim());
          }),
          _dateLine(p, Icons.calendar_month_rounded, 'Date & time', when, false),
        ]),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(alignment: WrapAlignment.center, children: [
            Text('Borrowed money is not counted as income. ', style: TextStyle(color: p.ink2, height: 1.5)),
            GestureDetector(onTap: () => Navigator.of(context).push(flowRoute(const LoansPage())), child: const Text('Open loans', style: TextStyle(color: kBlue, height: 1.5))),
          ]),
        ),
      ]);

  Widget _adj(Pal p) => _scroll([
        _card(p, [
          _accLine(p, acc, (v) => acc = v),
          _amountLine(p, hint: 'New balance', neg: true),
          _dateLine(p, Icons.calendar_month_rounded, 'Date & time', when, false),
        ]),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(amt == 0 ? 'Enter the real balance of the account. The difference is saved as a "New balance" entry.' : 'Difference: ${fixed2(amt - repo.bal(acc))} ${S.cur}', textAlign: TextAlign.center, style: TextStyle(color: p.ink2, height: 1.5)),
        ),
      ]);

  // ---------- الشريط العلوي ----------
  Widget _ringIcon(IconData i, Color c, {bool ring = true}) => ring
      ? Container(width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c, width: 1.6)), child: Icon(i, color: c, size: 15))
      : Icon(i, color: c, size: 26);

  /// تبويبات علوية بشكل كبسولة (مصروف · دخل · تحويل · تسوية) — عرض كامل بلا تداخل على أي حجم شاشة.
  Widget _tabs(Pal p, int pi, Color col, bool editing) {
    final seg = _segPages.indexOf(pi == 3 || pi == 4 ? 2 : pi);
    const labels = ['Expense', 'Income', 'Transfer', 'Adjust'];
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(26), border: Border.all(color: p.line)),
      child: LayoutBuilder(builder: (c, bc) {
        final w = bc.maxWidth / 4;
        return Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            left: (seg < 0 ? 0 : seg) * w,
            top: 0,
            bottom: 0,
            width: w,
            child: AnimatedOpacity(duration: const Duration(milliseconds: 180), opacity: seg < 0 ? 0 : 1, child: Container(decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(22), border: Border.all(color: col.withValues(alpha: .6), width: 1.2)))),
          ),
          Row(children: [
            for (var i = 0; i < 4; i++)
              SizedBox(
                width: w,
                child: Tap(
                  scale: .96,
                  onTap: editing ? null : () => _go(_segPages[i]),
                  child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: FittedBox(fit: BoxFit.scaleDown, child: Text(labels[i], maxLines: 1, style: TextStyle(fontSize: 15, fontWeight: i == seg ? FontWeight.w700 : FontWeight.w500, color: i == seg ? p.ink : p.ink2))))),
                ),
              ),
          ]),
        ]);
      }),
    );
  }

  // ---------- الهيكل ----------
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final editing = widget.edit != null;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SheetPage(
        child: AnimatedBuilder(
          animation: pc,
          builder: (ctx, child) {
            final v = (pc.hasClients && pc.position.haveDimensions) ? (pc.page ?? page.toDouble()) : page.toDouble();
            final pi = v.round().clamp(0, 6);
            final col = _col(pi);
            return Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(children: [
                  GlassBtn(Icons.arrow_back_rounded, () => Navigator.of(context).pop(), size: 46),
                  const SizedBox(width: 12),
                  Expanded(child: Text(editing ? 'Edit ${_titles[pi]}' : (_segPages.contains(pi) ? 'New transaction' : _titles[pi]), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                  const SizedBox(width: 8),
                  Tap(
                    onTap: () => _save(),
                    child: Container(key: saveKey, height: 44, padding: const EdgeInsets.symmetric(horizontal: 20), alignment: Alignment.center, decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(22)), child: const Text('Save', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
                  ),
                ]),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), child: _tabs(p, pi, col, editing)),
              Expanded(child: child!),
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
            children: [_money(p, false), _money(p, true), _xfer(p), _move(p), _send(p), _loan(p), _adj(p)],
          ),
        ),
      ),
    );
  }
}
