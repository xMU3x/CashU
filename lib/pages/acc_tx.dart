import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart' hide Text;
import 'package:share_plus/share_plus.dart';
import '../ui/loc_text.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/i18n.dart';
import '../core/settings.dart';
import '../core/util.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/sheets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'acc_edit.dart';
import 'add_tx.dart';
import 'notif_bell.dart';

/// كشف حساب (أو كل المعاملات لو [acc] = null) بتصميم MoneyWiz.
class AccountTxPage extends StatefulWidget {
  final Account? acc;

  /// true لما تتعرض كتبويب رئيسي (من غير زر رجوع، ومسافة سفلية للشريط).
  final bool embedded;
  const AccountTxPage({super.key, this.acc, this.embedded = false});
  @override
  State<AccountTxPage> createState() => _AccountTxState();
}

class _AccountTxState extends State<AccountTxPage> {
  final q = TextEditingController();
  int gen = 0;

  /// فلتر النوع: all | inc | exp | xfer
  String kind = 'all';

  /// ترتيب: new | old | high | low
  String sort = 'new';

  /// عرض جدولي مضغوط (Table View).
  bool table = false;

  /// وضع التحديد المتعدد (Bulk edit) والمعاملات المحددة.
  bool bulk = false;
  final sel = <String>{};

  /// المعاملات الظاهرة حاليًا (بعد الفلترة) — تُستخدم لزر «تحديد الكل» والتصدير.
  List<Tx> _visible = [];

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  String get _aid => widget.acc?.id ?? '';

  String _title(Tx t) {
    if (t.type == 'adj') return 'New balance';
    if (t.type == 'xfer') {
      if (t.note.isNotEmpty) return t.note;
      final from = repo.account(t.acc)?.name ?? '';
      final to = repo.account(t.to)?.name ?? '';
      if (_aid.isEmpty) return 'Transfer $from ▶ $to';
      return t.to == _aid ? 'Transfer from $from' : 'Transfer to $to';
    }
    if (t.type == 'loan') return t.note.isNotEmpty ? t.note : txTitle(t);
    final cn = catOf(t.cat.isEmpty ? (t.type == 'inc' ? 'other_i' : 'other') : t.cat).name;
    final tail = t.note.isNotEmpty ? t.note : t.pay;
    return tail.isEmpty ? '($cn)' : '($cn) $tail';
  }

  /// +1 دخول، -1 خروج، 0 محايد بالنسبة للحساب المعروض.
  int _dir(Tx t) {
    switch (t.type) {
      case 'inc':
        return 1;
      case 'exp':
        return -1;
      case 'adj':
        return t.sign >= 0 ? 1 : -1;
      case 'loan':
        return t.sign >= 0 ? 1 : -1;
      case 'xfer':
        if (_aid.isEmpty) return 0;
        return t.to == _aid ? 1 : -1;
    }
    return 0;
  }

  // ---------- إجراءات ----------
  void _edit(Tx t) {
    if (t.type == 'exp' || t.type == 'inc' || t.type == 'xfer' || t.type == 'adj') {
      Navigator.of(context).push(sheetRoute(AddTxPage(edit: t)));
    } else {
      toast(context, 'عدّل السلفة من صفحة السلف');
    }
  }

  void _delete(Tx t) {
    repo.delTx(t.id);
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(content: const Text('Deleted'), action: SnackBarAction(label: 'Undo', onPressed: () => repo.restoreTx(t.id))));
  }

  void _duplicate(Tx t) {
    final c = t.clone()
      ..id = uid()
      ..ts = DateTime.now().millisecondsSinceEpoch
      ..rep = 'none'
      ..nx = 0
      ..pend = false;
    repo.saveTx(c);
    setState(() => gen++);
    toast(context, 'Duplicated');
  }

  void _pending(Tx t) {
    final c = t.clone()..pend = !t.pend;
    repo.saveTx(c);
  }

  void _schedule(Tx t) {
    if (t.type != 'exp' && t.type != 'inc') {
      toast(context, 'Only expenses and income can be scheduled');
      return;
    }
    final c = t.clone()
      ..rep = 'monthly'
      ..nx = nextOcc(t.ts, 'monthly');
    repo.saveTx(c);
    toast(context, 'Scheduled monthly');
  }

  Future<void> _refund(Tx t) async {
    if (t.type != 'exp' && t.type != 'inc') {
      toast(context, 'Only expenses and income can be refunded');
      return;
    }
    final cn = catOf(t.cat.isEmpty ? (t.type == 'inc' ? 'other_i' : 'other') : t.cat).name;
    final what = t.note.isNotEmpty ? t.note : cn;
    if (!await confirmDialog(context, 'Refund', 'Add a pending refund of ${t.cur} ${fixed2(t.amt)} for "$what"?', ok: 'Refund')) { return; }
    // الاسترداد معاملة عكسية معلّقة (pending) على نفس الحساب؛ تتحسب في الرصيد لما تتحوّل Cleared.
    final c = t.clone()
      ..id = uid()
      ..type = t.type == 'exp' ? 'inc' : 'exp'
      ..note = 'Refund of $what'
      ..ts = DateTime.now().millisecondsSinceEpoch
      ..rep = 'none'
      ..nx = 0
      ..pend = true;
    repo.saveTx(c);
    if (mounted) toast(context, 'Refund added');
  }

  void _menu(Tx t) => showPillMenu(context, [
        ('Edit', () => _edit(t)),
        ('Delete', () => _delete(t)),
        (t.pend ? 'Set as Cleared' : 'Set as Pending', () => _pending(t)),
        ('Make Scheduled', () => _schedule(t)),
        ('Refund', () => _refund(t)),
      ]);

  // ---------- تحديد متعدد ----------
  void _enterBulk() => setState(() {
        bulk = true;
        sel.clear();
      });

  void _exitBulk() => setState(() {
        bulk = false;
        sel.clear();
      });

  void _toggleSel(Tx t) => setState(() => sel.contains(t.id) ? sel.remove(t.id) : sel.add(t.id));

  void _selectAll() => setState(() {
        final ids = _visible.map((t) => t.id).toSet();
        if (sel.containsAll(ids)) {
          sel.clear();
        } else {
          sel.addAll(ids);
        }
      });

  List<Tx> get _picked => [for (final id in sel) if (repo.tx(id) != null) repo.tx(id)!];

  bool _needSel() {
    if (sel.isNotEmpty) return false;
    toast(context, 'Select transactions first');
    return true;
  }

  void _bulkEdit() {
    if (_needSel()) return;
    showPillMenu(context, [
      ('Change Category', _bulkCategory),
      ('Change Account', _bulkAccount),
      ('Set as Cleared', () => _bulkPending(false)),
      ('Set as Pending', () => _bulkPending(true)),
    ]);
  }

  Future<void> _bulkCategory() async {
    final opts = <(String, String)>[
      for (final c in repo.cats(false)) (c.id, c.name),
      for (final c in repo.cats(true)) (c.id, c.name),
    ];
    final r = await showSelect(context, 'Change Category', opts, '');
    if (r == null) return;
    var n = 0;
    for (final t in _picked) {
      if (t.type != 'exp' && t.type != 'inc') continue;
      // كل نوع معاملة له تصنيفاته: مصروف للمصروفات ودخل للدخل.
      final isInc = repo.cats(true).any((c) => c.id == r);
      if (isInc != (t.type == 'inc')) continue;
      repo.saveTx(t.clone()
        ..cat = r
        ..sub = '');
      n++;
    }
    if (mounted) { toast(context, n == 0 ? 'No matching transactions' : 'Updated $n'); }
    _exitBulk();
  }

  Future<void> _bulkAccount() async {
    final r = await showPickAccount(context, '');
    if (r == null) return;
    var n = 0;
    for (final t in _picked) {
      if (t.type == 'xfer') continue;
      repo.saveTx(t.clone()..acc = r);
      n++;
    }
    if (mounted) toast(context, 'Updated $n');
    _exitBulk();
  }

  void _bulkPending(bool pend) {
    for (final t in _picked) {
      repo.saveTx(t.clone()..pend = pend);
    }
    toast(context, 'Updated ${sel.length}');
    _exitBulk();
  }

  Future<void> _bulkDelete() async {
    if (_needSel()) return;
    final ids = sel.toList();
    if (!await confirmDialog(context, 'Delete', 'Delete ${ids.length} transaction(s)?')) { return; }
    for (final id in ids) {
      repo.delTx(id);
    }
    _exitBulk();
    if (!mounted) return;
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(content: Text('Deleted ${ids.length}'), action: SnackBarAction(label: 'Undo', onPressed: () {
      for (final id in ids) {
        repo.restoreTx(id);
      }
    })));
  }

  void _bulkDuplicate() {
    if (_needSel()) return;
    for (final t in _picked) {
      repo.saveTx(t.clone()
        ..id = uid()
        ..ts = DateTime.now().millisecondsSinceEpoch
        ..rep = 'none'
        ..nx = 0
        ..pend = false);
    }
    toast(context, 'Duplicated');
    _exitBulk();
  }

  void _bulkMore() => showPillMenu(context, [
        ('Duplicate Selected', _bulkDuplicate),
        ('Delete Selected', _bulkDelete),
      ], danger: {'Delete Selected'});

  // ---------- قائمة (...) ----------
  void _filtersSort() => showPillMenu(context, [
        for (final k in const [('all', 'All'), ('inc', 'Income'), ('exp', 'Expense'), ('xfer', 'Transfer')]) ((kind == k.$1 ? '✓ ' : '') + k.$2, () => setState(() => kind = k.$1)),
        for (final k in const [('new', 'Newest first'), ('old', 'Oldest first'), ('high', 'Amount: high to low'), ('low', 'Amount: low to high')]) ((sort == k.$1 ? '✓ ' : '') + k.$2, () => setState(() => sort = k.$1)),
      ]);

  String _csvCell(String v) => '"${v.replaceAll('"', '""')}"';

  Future<void> _exportCsv() async {
    final l = _visible.isNotEmpty ? _visible : repo.txOf(widget.acc?.id);
    if (l.isEmpty) {
      toast(context, 'No transactions yet');
      return;
    }
    final rows = <String>['Date,Type,Account,To,Category,Payee,Note,Amount,Currency,Status'];
    for (final t in l) {
      final cat = t.type == 'exp' || t.type == 'inc' ? catOf(t.cat.isEmpty ? (t.type == 'inc' ? 'other_i' : 'other') : t.cat).name : '';
      rows.add([
        t.date.toIso8601String(),
        t.type,
        repo.account(t.acc)?.name ?? '',
        repo.account(t.to)?.name ?? '',
        cat,
        t.pay,
        t.note,
        t.amt.toStringAsFixed(2),
        t.cur,
        t.pend ? 'pending' : 'cleared',
      ].map(_csvCell).join(','));
    }
    // BOM عشان Excel يقرأ العربي صح.
    final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(rows.join('\n'))]);
    try {
      await Share.shareXFiles([XFile.fromData(bytes, mimeType: 'text/csv')], fileNameOverrides: ['cashu_transactions.csv']);
    } catch (e) {
      if (mounted) toast(context, 'Export failed');
    }
  }

  void _customizeToolbar() => showPillMenu(context, [
        (S.flag('txSearch', true) ? 'Hide search bar' : 'Show search bar', () {
          S.put('txSearch', !S.flag('txSearch', true));
          setState(() {});
        }),
        (table ? 'Use list view' : 'Use table view', () => setState(() => table = !table)),
      ]);

  void _moreMenu() {
    final a = widget.acc;
    showPopMenu(context, [
      if (a != null) PopItem(Icons.edit_outlined, 'Edit Account', () => Navigator.of(context).push(sheetRoute(AccountEditPage(edit: a)))),
      PopItem(Icons.filter_list_rounded, 'Filters & Sort', _filtersSort, divider: a != null),
      PopItem(Icons.table_chart_outlined, table ? 'List View' : 'Table View', () => setState(() => table = !table)),
      PopItem(Icons.check_circle_outline_rounded, 'Bulk edit', _enterBulk),
      PopItem(Icons.ios_share_rounded, 'Export CSV', _exportCsv),
      PopItem(Icons.tune_rounded, 'Customize Toolbar', _customizeToolbar, divider: true),
    ]);
  }

  // ---------- عناصر ----------
  Widget _chip(String t, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(t, style: TextStyle(fontSize: 13, color: fg)),
      );

  Widget _chips(Pal p, double? bal, double out, double inn) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          if (bal != null) ...[_chip('Balance: ${egp(bal)}', p.card, p.ink), const SizedBox(width: 8)],
          _chip(egp(-out), kRed.withValues(alpha: .16), kRed),
          const SizedBox(width: 8),
          _chip(egp(inn), kGreen.withValues(alpha: .16), kGreen),
        ]),
      );

  /// أيقونة الحساب + شارة صغيرة بتصنيف المعاملة (زي صورة All Transactions).
  Widget _leading(Pal p, Tx t) {
    final acc = repo.account(t.acc);
    final ic = txIcon(t, viewAcc: _aid);
    // داخل كشف حساب معيّن: نعرض أيقونة المعاملة (التصنيف) نفسها زي MoneyWiz، من غير أيقونة الحساب.
    if (_aid.isNotEmpty) {
      return Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(color: p.dark, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.line.withValues(alpha: .7))),
        child: Icon(ic.$1, color: ic.$2, size: 25),
      );
    }
    return SizedBox(
      width: 50,
      height: 48,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(left: 0, top: 0, child: acc != null ? accIcon(acc, size: 44) : Container(width: 44, height: 44, decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(11)))),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: p.dark, borderRadius: BorderRadius.circular(7), border: Border.all(color: p.card, width: 1.5)),
            child: Icon(ic.$1, color: ic.$2, size: 14),
          ),
        ),
      ]),
    );
  }

  /// عنوان الصف: «المستفيد (التصنيف/الملاحظة)» أو «(التصنيف) ملاحظة».
  Widget _titleText(Pal p, Tx t) {
    const base = TextStyle(fontSize: 16, fontWeight: FontWeight.w500);
    if (t.type == 'exp' || t.type == 'inc') {
      final cn = catOf(t.cat.isEmpty ? (t.type == 'inc' ? 'other_i' : 'other') : t.cat).name;
      if (t.pay.isNotEmpty) {
        return Text.rich(TextSpan(children: [
          TextSpan(text: t.pay, style: base),
          TextSpan(text: ' (${t.note.isNotEmpty ? t.note : cn})', style: base.copyWith(color: p.ink2, fontWeight: FontWeight.w400)),
        ]), maxLines: 1, overflow: TextOverflow.ellipsis);
      }
      return Text.rich(TextSpan(children: [
        TextSpan(text: '($cn)', style: base.copyWith(color: p.ink2, fontWeight: FontWeight.w400)),
        if (t.note.isNotEmpty) TextSpan(text: ' ${t.note}', style: base),
      ]), maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return Text(_title(t), maxLines: 1, overflow: TextOverflow.ellipsis, style: base);
  }

  Widget _check(bool on) => Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(shape: BoxShape.circle, color: on ? kBlue : Colors.transparent, border: Border.all(color: on ? kBlue : const Color(0xFF48484A), width: 2)),
        child: on ? const Icon(Icons.check_rounded, size: 17, color: Colors.white) : null,
      );

  BorderRadius _rr(bool first, bool last) => BorderRadius.vertical(top: Radius.circular(first ? 18 : 0), bottom: Radius.circular(last ? 18 : 0));

  Widget _row(Pal p, Tx t, {bool first = false, bool last = false}) {
    final d = _dir(t);
    final col = d > 0 ? kGreen : (d < 0 ? kRed : p.ink);
    final amount = S.flag('hide') ? '••••' : '${t.cur} ${fixed2(t.amt)}';

    final Widget content;
    if (table) {
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(children: [
          SizedBox(width: 78, child: Text(enDate(t.date), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: p.ink2))),
          const SizedBox(width: 6),
          Expanded(child: _titleText(p, t)),
          const SizedBox(width: 6),
          Text(amount, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: col)),
        ]),
      );
    } else {
      content = Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
        child: Row(children: [
          _leading(p, t),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _titleText(p, t),
              const SizedBox(height: 2),
              Row(children: [
                Flexible(child: Text(t.pend ? enDate(t.date) : enDateTime(t.date), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: p.ink2))),
                if (t.pend) ...[
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(12)), child: Text('Pending', style: TextStyle(fontSize: 13, color: p.ink2))),
                ],
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Text(amount, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: col)),
        ]),
      );
    }

    Widget card = Container(
      decoration: BoxDecoration(color: p.card, borderRadius: _rr(first, last)),
      child: Column(children: [content, if (!last) hair(p, indent: table ? 12 : 72)]),
    );

    if (bulk) {
      final on = sel.contains(t.id);
      return Tap(
        scale: .995,
        onTap: () => _toggleSel(t),
        child: Row(children: [
          Padding(padding: const EdgeInsets.only(right: 10), child: _check(on)),
          Expanded(child: card),
        ]),
      );
    }

    return SwipeRow(
      key: ValueKey('${t.id}_$gen'),
      bg: p.bg,
      rightW: 130,
      rightActions: Tap(
        onTap: () => _duplicate(t),
        child: Container(height: 40, width: 106, decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(20)), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.copy_rounded, color: Colors.white, size: 18), SizedBox(width: 6), Text('Duplicate', style: TextStyle(color: Colors.white, fontSize: 14))])),
      ),
      leftW: 90,
      leftActions: swipeCircle(Icons.delete_outline_rounded, 'Delete', kRed, () => _delete(t)),
      child: Tap(scale: .995, onTap: () => _edit(t), onLongPress: () => _menu(t), child: card),
    );
  }

  List<Tx> _sorted(List<Tx> l) {
    final c = [...l];
    switch (sort) {
      case 'old':
        c.sort((a, b) => a.ts.compareTo(b.ts));
        break;
      case 'high':
        c.sort((a, b) => b.base.compareTo(a.base));
        break;
      case 'low':
        c.sort((a, b) => a.base.compareTo(b.base));
        break;
      default:
        c.sort((a, b) => b.ts.compareTo(a.ts));
    }
    return c;
  }

  Widget _section(Pal p, String title, Widget chips, List<Tx> l) {
    final rows = _sorted(l);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(6, 0, 0, 8), child: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
        chips,
        const SizedBox(height: 10),
        Column(children: [for (var i = 0; i < rows.length; i++) _row(p, rows[i], first: i == 0, last: i == rows.length - 1)]),
      ]),
    );
  }

  Widget _pillBtn(Pal p, IconData ic, VoidCallback f, {Color? color}) => Tap(onTap: f, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), child: Icon(ic, color: color ?? kBlue, size: 26)));

  Widget _header(Pal p) {
    final a = widget.acc;
    final rightPill = Glass(
      radius: 28,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const NotifBell(),
        Tap(onTap: _moreMenu, child: Container(width: 38, height: 38, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.ink2, width: 1.4)), child: Icon(Icons.more_horiz_rounded, color: p.ink2, size: 22))),
        const SizedBox(width: 8),
        Tap(onTap: () => Navigator.of(context).push(sheetRoute(AddTxPage(accId: a?.id))), child: Container(width: 40, height: 40, decoration: const BoxDecoration(color: kBlue, shape: BoxShape.circle), child: const Icon(Icons.add_rounded, color: Colors.white, size: 26))),
      ]),
    );

    // وضع التحديد المتعدد: زر إغلاق + شريط أدوات (تحديد الكل / تعديل / المزيد) + نفس زرّي (...) و(+).
    if (bulk) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(children: [
          GlassBtn(Icons.close_rounded, _exitBulk, size: 48),
          const SizedBox(width: 10),
          Expanded(
            child: Glass(
              radius: 28,
              height: 52,
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _pillBtn(p, Icons.checklist_rounded, _selectAll),
                _pillBtn(p, Icons.edit_note_rounded, _bulkEdit, color: kGreen),
                _pillBtn(p, Icons.more_horiz_rounded, _bulkMore, color: p.ink),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          rightPill,
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(children: [
        if (!widget.embedded) GlassBtn(Icons.chevron_left_rounded, () => Navigator.of(context).maybePop(), size: 48) else const SizedBox(width: 4),
        Expanded(
          child: Center(
            child: a == null
                ? Column(mainAxisSize: MainAxisSize.min, children: [const Text('All Transactions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), Text(egp(repo.totalBal), style: TextStyle(fontSize: 14, color: repo.totalBal < 0 ? kRed : kGreen))])
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    accIcon(a, size: 38),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      Text(egp(repo.bal(a.id)), style: TextStyle(fontSize: 14, color: repo.bal(a.id) < 0 ? kRed : kGreen)),
                    ]),
                  ]),
          ),
        ),
        rightPill,
      ]),
    );
  }

  Widget _searchBar(Pal p) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: p.card.withValues(alpha: .85), borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.white.withValues(alpha: .1))),
          child: Row(children: [
            Icon(Icons.search_rounded, color: p.ink2),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: q, onChanged: (_) => setState(() {}), style: const TextStyle(fontSize: 16), decoration: InputDecoration(border: InputBorder.none, isDense: true, hintText: tl('Search'), hintStyle: TextStyle(color: p.ink2)))),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _header(p),
          if (S.flag('txSearch', true)) _searchBar(p),
          const SizedBox(height: 6),
          Expanded(
            child: Live(b: (c) {
              final text = q.text.trim().toLowerCase();
              final all = repo.txOf(widget.acc?.id).where((t) => (kind == 'all' || t.type == kind) && (text.isEmpty || _title(t).toLowerCase().contains(text) || t.note.toLowerCase().contains(text) || t.pay.toLowerCase().contains(text))).toList();
              _visible = all;
              if (all.isEmpty) { return ListView(children: [emptyState(p, Icons.folder_open_rounded, 'No transactions yet')]); }
              final pend = all.where((t) => t.pend).toList();
              final months = <int, List<Tx>>{};
              for (final t in all.where((t) => !t.pend)) {
                months.putIfAbsent(t.date.year * 100 + t.date.month, () => []).add(t);
              }
              double out(List<Tx> l) => l.fold(0.0, (s, t) => s + (_dir(t) < 0 ? t.base : 0));
              double inn(List<Tx> l) => l.fold(0.0, (s, t) => s + (_dir(t) > 0 ? t.base : 0));
              final now = DateTime.now();
              return ListView(padding: EdgeInsets.fromLTRB(16, 4, 16, widget.embedded ? 130 : 40), physics: const BouncingScrollPhysics(), children: [
                if (pend.isNotEmpty) _section(p, 'Pending', _chips(p, widget.acc == null ? null : repo.bal(_aid), out(pend), inn(pend)), pend),
                for (final e in months.entries)
                  _section(
                    p,
                    e.key ~/ 100 == now.year ? monthEn(e.key % 100) : '${monthEn(e.key % 100)} ${e.key ~/ 100}',
                    _chips(p, widget.acc == null ? null : repo.balAt(_aid, DateTime(e.key ~/ 100, e.key % 100 + 1, 1)), out(e.value), inn(e.value)),
                    e.value,
                  ),
              ]);
            }),
          ),
        ]),
      ),
    );
  }
}
