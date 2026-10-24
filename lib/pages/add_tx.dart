import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import 'package:flutter/services.dart';
import '../core/currency.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/util.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/pickers.dart';
import '../ui/sheets.dart';
import '../ui/shell_scope.dart' show DotsSpinner;
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'more_pages.dart';

/// صفحات: 0 مصروف · 1 دخل · 2 تحويل · 3 نقل عملية · 4 إرسال معاملة · 5 سلفة · 6 تسوية رصيد
class AddTxPage extends StatefulWidget {
  final Tx? edit;
  final Tx? draft; // مسودة غير محفوظة (من مراجعة الرسائل)
  final void Function(Tx)? onSaved;
  final int page;
  final String? cat, accId;
  const AddTxPage({super.key, this.edit, this.draft, this.onSaved, this.page = 0, this.cat, this.accId});
  @override
  State<AddTxPage> createState() => _AddTxState();
}

class _AddTxState extends State<AddTxPage> with TickerProviderStateMixin {
  late final PageController pc;
  late final AnimationController shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 460));
  final saveKey = GlobalKey();
  final _pull = ValueNotifier<double>(0);
  bool _pullSaving = false;
  int page = 0;
  double amt = 0;
  String tags = '', link = '';
  String cur = S.cur, acc = '', to = '', cat = 'other', icat = 'other_i', sub = '', rep = 'none', loanDir = 'owe', payee = '';
  DateTime when = DateTime.now();
  DateTime recv = DateTime.now();
  DateTime? due;
  bool swapped = false, pend = false, showAll = false, catPicked = false;
  List<(String, double)> splits = []; // تقسيم المبلغ على أكثر من حساب
  final noteE = TextEditingController(), noteI = TextEditingController(), noteL = TextEditingController(), noteT = TextEditingController(), person = TextEditingController();

  static const _segPages = [0, 1, 2, 5];

  /// الصفحات الفعلية في الـ PageView: الأربع الأساسية فقط، أو صفحة التسوية فقط عند تعديل تسوية قديمة.
  List<int> get _views => (widget.edit != null && widget.edit!.type == 'adj') ? [6] : _segPages;
  int _vi(int logical) {
    final i = _views.indexOf(logical);
    return i < 0 ? 0 : i;
  }
  static const _titles = ['Expense', 'Income', 'Transfer', '', '', 'Loan', 'Balance Adjustment'];
  static List<Color> get _tabCols => [kRed, kGreen, kBlue, kOrange];
  static const _tabIcons = [Icons.trending_down_rounded, Icons.trending_up_rounded, Icons.swap_horiz_rounded, Icons.handshake_rounded];

  @override
  void initState() {
    super.initState();
    final l = repo.accList;
    acc = l.first.id;
    if (widget.accId != null && repo.account(widget.accId!) != null && !(repo.account(widget.accId!)!.arch)) { acc = widget.accId!; }
    to = l.firstWhere((a) => a.id != acc, orElse: () => l.first).id;
    if (widget.cat != null) {
      cat = widget.cat!;
      catPicked = true;
    }
    page = widget.page;
    final e = widget.edit ?? widget.draft;
    if (e != null) {
      page = e.type == 'inc' ? 1 : (e.type == 'xfer' ? 2 : (e.type == 'adj' ? 6 : 0));
      amt = e.type == 'adj' ? e.amt * (e.sign >= 0 ? 1 : -1) : e.amt;
      cur = e.cur;
      acc = e.acc;
      when = e.date;
      rep = e.rep;
      pend = e.pend;
      payee = e.pay;
      tags = e.tags;
      link = e.link;
      catPicked = true;
      if (e.type == 'xfer') {
        to = e.to;
        recv = e.date;
        noteT.text = e.note;
      } else if (e.type == 'adj') {
        // تعديل قيمة التسوية نفسها (الفرق)، مش الرصيد الجديد
      } else if (e.type == 'inc') {
        icat = e.cat.isEmpty ? 'other_i' : e.cat;
        noteI.text = e.note;
      } else {
        cat = e.cat.isEmpty ? 'other' : e.cat;
        sub = e.sub;
        noteE.text = e.note;
      }
    }
    if (e != null && e.type != 'adj') {
      // نفس الملاحظة تفضل لو غيّرت نوع المعاملة (مصروف ↔ دخل ↔ تحويل).
      for (final c in [noteE, noteI, noteT]) {
        if (c.text.isEmpty) c.text = e.note;
      }
    }
    pc = PageController(initialPage: _vi(page));
  }

  @override
  void dispose() {
    _pull.dispose();
    pc.dispose();
    shake.dispose();
    for (final c in [noteE, noteI, noteL, noteT, person]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------- مساعدات ----------
  Color _col(int pi) => pi == 0 ? kRed : (pi == 1 ? kGreen : (pi == 5 ? kOrange : kBlue));
  double _rate() => (cur == S.cur || !S.flag('conv', true)) ? 1.0 : rates.rate(cur, S.cur);
  void _bad() {
    shake.forward(from: 0);
    HapticFeedback.heavyImpact();
  }

  void _go(int i) => pc.animateToPage(_vi(i), duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);

  Future<void> _calc({bool allowNeg = false}) async {
    final r = await showCalc(context, amt, cur);
    if (r != null) {
      setState(() {
        amt = (!allowNeg && r < 0) ? 0 : r;
        if (splits.isNotEmpty && (splits.fold(0.0, (a, x) => a + x.$2) - amt).abs() > 0.005) { splits = []; }
      });
    }
  }

  Future<void> _cur() async {
    final r = await showCurrencySheet(context, cur);
    if (r != null) setState(() => cur = r);
  }

  Future<void> _pickDate(bool second) async {
    final base = second ? recv : when;
    final d = await showDateSheet(context, base);
    if (d != null) {
      setState(() {
        if (second) {
          recv = d;
        } else {
          when = d;
        }
      });
    }
  }

  Future<void> _pickTime(bool second) async {
    final base = second ? recv : when;
    final t = await showTimeSheet(context, base);
    if (t != null) {
      setState(() {
        if (second) {
          recv = t;
        } else {
          when = t;
        }
      });
    }
  }

  // ---------- حفظ ----------
  /// يحفظ المستفيد والوسوم الجديدة في قوائم دائمة عشان تظهر للاختيار السريع بعد كده.
  void _rememberLists() {
    final py = payee.trim();
    if (py.isNotEmpty) {
      final l = S.list('savedPayees');
      if (!l.any((x) => x.toLowerCase() == py.toLowerCase())) S.put('savedPayees', [...l, py]);
    }
    final tl = splitTags(tags);
    if (tl.isNotEmpty) {
      final l = S.list('savedTags');
      final add = tl.where((t) => !l.contains(t)).toList();
      if (add.isNotEmpty) S.put('savedTags', [...l, ...add]);
    }
  }

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
              id: parts.length > 1 ? uid() : (old?.id ?? widget.draft?.id ?? uid()), type: inc ? 'inc' : 'exp', amt: part.$2, cur: cur, rate: _rate(), acc: part.$1,
              cat: inc ? icat : cat, sub: inc ? '' : sub, note: (inc ? noteI : noteE).text.trim(), pay: payee, pend: pend, ts: ts,
              rep: rep, nx: rep == 'none' ? 0 : nextOcc(ts, rep), src: old?.src ?? widget.draft?.src ?? '', split: gid, tags: tags, link: link,
            ));
          }
          break;
        }
      case 2:
        if (amt <= 0 || acc == to) return _bad();
        repo.saveTx(Tx(id: widget.edit?.id ?? uid(), type: 'xfer', amt: amt, cur: cur, rate: _rate(), acc: acc, to: to, note: noteT.text.trim(), pend: pend, ts: when.millisecondsSinceEpoch));
        break;
      case 5:
        if (amt <= 0 || payee.trim().isEmpty) return _bad();
        repo.addLoan(Loan(
          id: uid(), dir: loanDir, person: payee.trim(), amt: amt, cur: cur, rate: _rate(), acc: acc,
          due: due?.millisecondsSinceEpoch ?? 0, note: noteL.text.trim(), ts: when.millisecondsSinceEpoch,
        ));
        break;
      case 6:
        {
          final old = widget.edit;
          if (old != null) {
            // تعديل تسوية موجودة: نعدّل الفرق والتاريخ فقط
            if (amt.abs() < 0.005) return _bad();
            final n = old.clone()
              ..amt = amt.abs()
              ..sign = amt >= 0 ? 1 : -1
              ..acc = acc
              ..ts = when.millisecondsSinceEpoch;
            repo.saveTx(n);
            break;
          }
          final delta = amt - repo.bal(acc);
          if (delta.abs() < 0.005) return _bad();
          repo.saveTx(Tx(id: uid(), type: 'adj', amt: delta.abs(), cur: S.cur, rate: 1, acc: acc, sign: delta >= 0 ? 1 : -1, note: 'New balance', pend: false, ts: when.millisecondsSinceEpoch));
          break;
        }
    }
    if (widget.draft != null && widget.onSaved != null) {
      final saved = repo.tx(widget.draft!.id);
      if (saved != null) widget.onSaved!(saved);
    }
    _rememberLists();
    HapticFeedback.mediumImpact();
    if (S.flag('sound', true)) SystemSound.play(SystemSoundType.click);
    if (again) {
      setState(() {
        amt = 0;
        payee = '';
        splits = [];
        for (final c in [noteE, noteI, noteL, noteT, person]) {
          c.clear();
        }
      });
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  // ---------- لبنات الواجهة ----------
  Widget _card(Pal p, List<Widget> rows) => Container(
        decoration: iosCard(p, r: 22),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[rows[i], if (i < rows.length - 1) hair(p, indent: 48)],
        ]),
      );

  /// سطر حقل: الأيقونة + اسم الحقل في البداية (يمين في العربي / شمال في الإنجليزي)،
  /// والقيمة/المدخل في النهاية (شمال في العربي / يمين في الإنجليزي). الاتجاه تلقائي من Directionality.
  Widget _line(Pal p, IconData ic, Widget content, {VoidCallback? onTap, bool chev = true, Widget? trailing, String? label, Widget? leading}) => Tap(
        onTap: onTap,
        scale: .99,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            leading ?? Icon(ic, color: p.ink2, size: 22),
            const SizedBox(width: 12),
            Expanded(child: content),
            if (trailing != null) trailing,
            if (chev) Icon(Icons.chevron_right_rounded, color: p.ink2.withValues(alpha: .7), size: 22),
          ]),
        ),
      );

  Widget _ph(Pal p, String t) => Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, color: p.ink2.withValues(alpha: .75)));
  Widget _val(String t) => Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16));

  Widget _accLine(Pal p, String id, void Function(String) set, {String? hint, String? exclude, String label = 'Account', bool reserve = false}) {
    final a = repo.account(id);
    final Widget content = a == null
        ? _ph(p, hint ?? 'Select Account')
        : Text.rich(TextSpan(children: [TextSpan(text: a.name, style: const TextStyle(fontSize: 16)), TextSpan(text: ' (${egp(repo.bal(a.id))})', style: TextStyle(fontSize: 15, color: p.ink2))]), maxLines: 1, overflow: TextOverflow.ellipsis);
    return _line(p, Icons.credit_card_rounded, content, leading: a == null ? null : accIcon(a, size: 22), label: label, chev: !reserve, trailing: reserve ? const SizedBox(width: 48) : null, onTap: () async {
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
            child: Align(alignment: AlignmentDirectional.centerStart, child: Text(amt == 0 ? hint : fmt(amt), style: TextStyle(fontSize: 16, color: amt == 0 ? p.ink2.withValues(alpha: .75) : p.ink))),
          ),
          label: hint,
          chev: false,
          trailing: Padding(padding: const EdgeInsetsDirectional.only(start: 10), child: Tap(onTap: _cur, child: Container(padding: const EdgeInsetsDirectional.only(start: 12, end: 4, top: 5, bottom: 5), decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(14)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(curOf(cur).sym, style: TextStyle(fontSize: 16, color: kBlue, fontWeight: FontWeight.w600)), Icon(Icons.chevron_right_rounded, color: p.ink2.withValues(alpha: .7), size: 22)])))),
        ),
      );

  Widget _textLine(Pal p, IconData ic, String hint, String value, void Function(String) set) => _line(p, ic, value.isEmpty ? _ph(p, hint) : _val(value), onTap: () async {
        final r = await promptText(context, hint, hint: hint, initial: value);
        if (r != null) setState(() => set(r.trim()));
      });

  /// حقل الوصف: 7 أسطر على الأقل، وبيتحط في آخر البطاقة.
  Widget _noteBox(Pal p, TextEditingController c, {String? hint}) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Icons.text_fields_rounded, color: p.ink2, size: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: c,
              minLines: 7,
              maxLines: 7,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontSize: 16, height: 1.45),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: p.field.withValues(alpha: .5),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                hintText: tl(hint ?? 'Description'),
                hintStyle: TextStyle(color: p.ink2.withValues(alpha: .75)),
              ),
            ),
          ),
        ]),
      );

  Widget _dateChip(Pal p, String t, VoidCallback f) => Tap(onTap: f, child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(18)), child: Text(t, style: const TextStyle(fontSize: 15))));

  Widget _dateLine(Pal p, IconData ic, String label, DateTime d, bool second) => Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          Icon(ic, color: p.ink2, size: 22),
          const SizedBox(width: 12),
          _dateChip(p, enDate(d), () => _pickDate(second)),
          const SizedBox(width: 8),
          _dateChip(p, enTime(d), () => _pickTime(second)),
          const SizedBox(width: 8),
          Expanded(child: Align(alignment: AlignmentDirectional.centerEnd, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: p.ink2.withValues(alpha: .8))))),
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
          child: _line(p, Icons.folder_open_rounded, catPicked ? _val(!inc && sub.isNotEmpty ? '${c.name} › $sub' : c.name) : _ph(p, 'Select Category'), label: 'Category', onTap: () async {
            final r = await showPickCat(context, inc, c.id, selSub: inc ? '' : sub);
            if (r != null) {
              setState(() {
                catPicked = true;
                if (inc) {
                  icat = r.$1.id;
                } else {
                  cat = r.$1.id;
                  sub = r.$2;
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
          Tap(onTap: _options, child: Glass(radius: 22, height: 44, padding: const EdgeInsets.symmetric(horizontal: 38), child: Center(child: Text('Options', style: TextStyle(color: kBlue, fontSize: 16))))),
          Tap(
            onTap: () => setState(() => showAll = !showAll),
            child: Glass(radius: 22, height: 44, padding: const EdgeInsets.symmetric(horizontal: 30), child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [Text('Show All', style: TextStyle(color: kBlue, fontSize: 16)), const SizedBox(width: 4), Icon(showAll ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, color: kBlue)]))),
          ),
        ]),
      );

  void _options() => showPillMenu(context, [
        ('Save & Add Another', () => _save(again: true)),
        ('Repeat…', () => setState(() => showAll = true)),
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
        _catLine(p, inc),
        if (showAll && !inc && catPicked) _subChips(p, c),
        _dateLine(p, Icons.calendar_month_rounded, 'Date & time', when, false),
        _line(p, Icons.sell_outlined, tags.isEmpty ? _ph(p, 'Tags') : _val(tags), onTap: () async {
          final r = await showTagsSheet(context, tags);
          if (r != null) setState(() => tags = r);
        }),
        _textLine(p, Icons.link_rounded, 'Attachment / Link', link, (v) => link = v),
        _statusLine(p),
        if (showAll) _repLine(p),
        _noteBox(p, inc ? noteI : noteE),
      ]),
      _bottomPills(p),
    ]);
  }

  Widget _xfer(Pal p) {
    final a = repo.account(acc), b = repo.account(to);
    final def = 'Transfer ${a?.name ?? ''} ▶ ${b?.name ?? ''}';
    return _scroll([
      _card(p, [
        Stack(alignment: AlignmentDirectional.centerEnd, children: [
          Column(children: [
            _accLine(p, acc, (v) => acc = v, hint: 'Select Account', label: 'From', reserve: true),
            hair(p, indent: 48),
            _accLine(p, to, (v) => to = v, hint: 'Select Account', label: 'To', reserve: true),
          ]),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 10),
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
        _dateLine(p, Icons.calendar_month_rounded, 'Send date', when, false),
        _dateLine(p, Icons.edit_calendar_rounded, 'Receive date', recv, true),
        _statusLine(p),
        _noteBox(p, noteT, hint: def),
      ]),
      _bottomPills(p),
    ]);
  }

  /// سلفة/دين: نفس شكل المصروف بالظبط (حساب، مبلغ، المستفيد، تاريخ، وصف)، والفرق زر ليّا/عليّا.
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
          _line(p, Icons.person_outline_rounded, payee.isEmpty ? _ph(p, 'Payee') : _val(payee), onTap: () async {
            final r = await showPayeeSheet(context, payee);
            if (r != null) setState(() => payee = r);
          }),
          _line(p, Icons.event_busy_rounded, due == null ? _ph(p, 'Due date (optional)') : _val(enDate(due!)), onTap: () async {
            final d = await showDateSheet(context, due ?? DateTime.now(), title: 'Due date');
            if (d != null) setState(() => due = d);
          }, trailing: due == null ? null : Tap(onTap: () => setState(() => due = null), child: Icon(Icons.cancel_rounded, color: p.ink2, size: 20))),
          _dateLine(p, Icons.calendar_month_rounded, 'Date & time', when, false),
          _noteBox(p, noteL),
        ]),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(alignment: WrapAlignment.center, children: [
            Text('Borrowed money is not counted as income. ', style: TextStyle(color: p.ink2, height: 1.5)),
            GestureDetector(onTap: () => Navigator.of(context).push(flowRoute(const LoansPage())), child: Text('Open loans', style: TextStyle(color: kBlue, height: 1.5))),
          ]),
        ),
      ]);

  Widget _adj(Pal p) => _scroll([
        _card(p, [
          _accLine(p, acc, (v) => acc = v),
          _amountLine(p, hint: widget.edit != null ? 'Amount' : 'New balance', neg: true),
          _dateLine(p, Icons.calendar_month_rounded, 'Date & time', when, false),
        ]),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(amt == 0 ? 'Enter the real balance of the account. The difference is saved as a "New balance" entry.' : 'Difference: ${fixed2(amt - repo.bal(acc))} ${curOf(S.cur).sym}', textAlign: TextAlign.center, style: TextStyle(color: p.ink2, height: 1.5)),
        ),
      ]);

  // ---------- الشريط العلوي ----------
  // ignore: unused_element -- مُبقى عمدًا (مساعد أيقونات الشريط العلوي) لحين استخدامه؛ لا حذف لأي ميزة.
  Widget _ringIcon(IconData i, Color c, {bool ring = true}) => ring
      ? Container(width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c, width: 1.6)), child: Icon(i, color: c, size: 15))
      : Icon(i, color: c, size: 26);

  /// تبويبات علوية بشكل كبسولة (مصروف · دخل · تحويل · تسوية) — عرض كامل بلا تداخل على أي حجم شاشة.
  Widget _tabs(Pal p, int pi, Color col, bool editing) {
    final seg = _segPages.indexOf(pi == 3 || pi == 4 ? 2 : pi);
    const labels = ['Expense', 'Income', 'Transfer', 'Loan / Debt'];
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(26), border: Border.all(color: p.line)),
      child: LayoutBuilder(builder: (c, bc) {
        final w = bc.maxWidth / 4;
        return Stack(children: [
          AnimatedPositionedDirectional(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            start: (seg < 0 ? 0 : seg) * w,
            top: 0,
            bottom: 0,
            width: w,
            child: AnimatedOpacity(duration: const Duration(milliseconds: 180), opacity: seg < 0 ? 0 : 1, child: Container(decoration: BoxDecoration(color: seg < 0 ? p.field : _tabCols[seg].withValues(alpha: .18), borderRadius: BorderRadius.circular(22)))),
          ),
          Row(children: [
            for (var i = 0; i < 4; i++)
              SizedBox(
                width: w,
                child: Tap(
                  scale: .96,
                  onTap: (editing && (widget.edit!.type == 'adj' || i == 3)) ? null : () => _go(_segPages[i]),
                  child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(_tabIcons[i], size: 17, color: _tabCols[i].withValues(alpha: i == seg ? 1 : .65)), const SizedBox(width: 4), Text(labels[i], maxLines: 1, style: TextStyle(fontSize: 14, fontWeight: i == seg ? FontWeight.w700 : FontWeight.w500, color: i == seg ? _tabCols[i] : p.ink2))])))),
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
            final v = (pc.hasClients && pc.position.haveDimensions) ? (pc.page ?? _vi(page).toDouble()) : _vi(page).toDouble();
            final pi = _views[v.round().clamp(0, _views.length - 1)];
            final col = _col(pi);
            return Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(children: [
                  GlassBtn(Icons.arrow_back_rounded, () => Navigator.of(context).pop(), size: 46),
                  const SizedBox(width: 12),
                  Expanded(child: Text(textAlign: TextAlign.center, editing ? 'Edit ${_titles[pi]}' : (_segPages.contains(pi) ? 'New transaction' : _titles[pi]), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
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
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.axis != Axis.vertical || n.depth != 1) return false;
              if (n is ScrollUpdateNotification || n is OverscrollNotification) {
                _pull.value = (-n.metrics.pixels / 90).clamp(0.0, 1.0);
              } else if (n is ScrollEndNotification) {
                final done = _pull.value >= 1;
                _pull.value = 0;
                if (done && !_pullSaving) {
                  _pullSaving = true;
                  _save().whenComplete(() => _pullSaving = false);
                }
              }
              return false;
            },
            child: Stack(children: [
          PageView(
            controller: pc,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (i) {
              setState(() => page = _views[i]);
              FocusScope.of(context).unfocus();
              tick();
            },
            children: _views.length == 1 ? [_adj(p)] : [_money(p, false), _money(p, true), _xfer(p), _loan(p)],
          ),
          // دايرة النقط: اسحب لتحت لحد ما تكتمل وسيب إيدك عشان تتسجل المعاملة (بديل زر Save)
          PositionedDirectional(
            top: 2,
            start: 0,
            end: 0,
            child: IgnorePointer(
              child: ValueListenableBuilder<double>(
                valueListenable: _pull,
                builder: (c, k, _) => Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: k,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: p.card, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 10)]),
                      child: DotsSpinner(size: 24, color: kBlue, spinning: false, progress: k),
                    ),
                  ),
                ),
              ),
            ),
          ),
            ]),
          ),
        ),
      ),
    );
  }
}
