import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/util.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'acc_edit.dart';
import 'add_tx.dart';

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
    if (t.type == 'exp' || t.type == 'inc') {
      Navigator.of(context).push(sheetRoute(AddTxPage(edit: t)));
    } else {
      toast(context, 'Editing this type is not supported yet');
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

  void _refund(Tx t) {
    if (t.type != 'exp' && t.type != 'inc') {
      toast(context, 'Only expenses and income can be refunded');
      return;
    }
    final c = t.clone()
      ..id = uid()
      ..type = t.type == 'exp' ? 'inc' : 'exp'
      ..note = 'Refund: ${_title(t)}'
      ..ts = DateTime.now().millisecondsSinceEpoch
      ..rep = 'none'
      ..nx = 0
      ..pend = false;
    repo.saveTx(c);
    toast(context, 'Refund added');
  }

  void _menu(Tx t) => showPillMenu(context, [
        ('Edit', () => _edit(t)),
        ('Delete', () => _delete(t)),
        (t.pend ? 'Set as Cleared' : 'Set as Pending', () => _pending(t)),
        ('Make Scheduled', () => _schedule(t)),
        ('Refund', () => _refund(t)),
      ], danger: {'Delete'});

  // ---------- عناصر ----------
  Widget _chip(String t, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(15)),
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

  Widget _row(Pal p, Tx t, {bool last = false}) {
    final ic = txIcon(t, viewAcc: _aid);
    final d = _dir(t);
    final col = d > 0 ? kGreen : (d < 0 ? kRed : p.ink);
    final sign = d > 0 ? '+' : (d < 0 ? '-' : '');
    final sub = t.pay.isNotEmpty ? t.pay : (t.note.isNotEmpty ? t.note : (repo.account(t.acc)?.name ?? ''));
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
      child: Tap(
        scale: .99,
        onTap: () => _edit(t),
        onLongPress: () => _menu(t),
        child: Container(
          color: p.card,
          padding: const EdgeInsets.only(left: 12),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 4, 8),
              child: Row(children: [
                Container(width: 34, height: 34, decoration: BoxDecoration(color: ic.$2, borderRadius: BorderRadius.circular(10)), child: Icon(ic.$1, color: Colors.white, size: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(_title(t), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600))),
                      if (t.pend) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1), decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(8)), child: Text('Pending', style: TextStyle(fontSize: 10.5, color: p.ink2)))],
                    ]),
                    if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.ink2)),
                  ]),
                ),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(S.flag('hide') ? '••••' : '$sign${S.cur == 'EGP' ? 'EGP ' : ''}${fixed2(t.amt)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: col)),
                  Text(enTime(t.date), style: TextStyle(fontSize: 11.5, color: p.ink2)),
                ]),
                Tap(onTap: () => _menu(t), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8), child: Icon(Icons.more_vert_rounded, color: p.ink2, size: 18))),
              ]),
            ),
            if (!last) hair(p, indent: 46),
          ]),
        ),
      ),
    );
  }

  /// عنوان اليوم: «Today · 16 Oct 2026» + صافي اليوم.
  Widget _dayHeader(Pal p, DateTime d, List<Tx> l) {
    final now = DateTime.now();
    final same = (DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    final label = same(d, now) ? 'Today' : (same(d, now.subtract(const Duration(days: 1))) ? 'Yesterday' : '');
    final net = l.fold(0.0, (s, t) => s + _dir(t) * t.base);
    final col = net > 0 ? kGreen : (net < 0 ? kRed : p.ink2);
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: p.card.withValues(alpha: .6), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Expanded(child: Text(label.isEmpty ? enDate(d) : '$label · ${enDate(d)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.ink2))),
        if (net != 0 && !S.flag('hide')) Text('${net > 0 ? '+' : '-'}${fixed2(net.abs())}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: col)),
      ]),
    );
  }

  List<List<Tx>> _byDay(List<Tx> l) {
    final m = <int, List<Tx>>{};
    for (final t in l) {
      m.putIfAbsent(t.date.year * 10000 + t.date.month * 100 + t.date.day, () => []).add(t);
    }
    final keys = m.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final k in keys) m[k]!];
  }

  Widget _section(Pal p, String title, Widget chips, List<Tx> l) => Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(6, 0, 0, 8), child: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
          chips,
          const SizedBox(height: 10),
          for (final g in _byDay(l)) ...[
            _dayHeader(p, g.first.date, g),
            Container(clipBehavior: Clip.antiAlias, decoration: iosCard(p, r: 16), child: Column(children: [for (var i = 0; i < g.length; i++) _row(p, g[i], last: i == g.length - 1)])),
          ],
        ]),
      );

  Widget _header(Pal p) {
    final a = widget.acc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(children: [
        if (!widget.embedded) GlassBtn(Icons.chevron_left_rounded, () => Navigator.of(context).maybePop(), size: 48) else const SizedBox(width: 4),
        Expanded(
          child: Center(
            child: a == null
                ? Column(mainAxisSize: MainAxisSize.min, children: [const Text('All Transactions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), Text(egp(repo.totalBal), style: const TextStyle(fontSize: 14, color: kGreen))])
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    accIcon(a, size: 38),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      Text(egp(repo.bal(a.id)), style: const TextStyle(fontSize: 14, color: kGreen)),
                    ]),
                  ]),
          ),
        ),
        Glass(
          radius: 28,
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Tap(
              onTap: () {
                if (a == null) {
                  toast(context, 'Open an account to edit it');
                } else {
                  showPillMenu(context, [('Edit Account', () => Navigator.of(context).push(sheetRoute(AccountEditPage(edit: a))))]);
                }
              },
              child: Container(width: 38, height: 38, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.ink2, width: 1.4)), child: Icon(Icons.more_horiz_rounded, color: p.ink2, size: 22)),
            ),
            const SizedBox(width: 8),
            Tap(onTap: () => Navigator.of(context).push(sheetRoute(AddTxPage(accId: a?.id))), child: Container(width: 40, height: 40, decoration: const BoxDecoration(color: kBlue, shape: BoxShape.circle), child: const Icon(Icons.add_rounded, color: Colors.white, size: 26))),
          ]),
        ),
      ]),
    );
  }

  Widget _kindChips(Pal p) {
    const items = [('all', 'All', Icons.apps_rounded), ('inc', 'Income', Icons.south_west_rounded), ('exp', 'Expense', Icons.north_east_rounded), ('xfer', 'Transfer', Icons.swap_horiz_rounded)];
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final it in items)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Tap(
                scale: .95,
                onTap: () => setState(() => kind = it.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: kind == it.$1 ? kBlue : p.card, borderRadius: BorderRadius.circular(21), border: Border.all(color: kind == it.$1 ? kBlue : p.line.withValues(alpha: .6))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(it.$3, size: 17, color: kind == it.$1 ? Colors.white : p.ink2),
                    const SizedBox(width: 6),
                    Text(it.$2, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kind == it.$1 ? Colors.white : p.ink)),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _header(p),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: p.card.withValues(alpha: .85), borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.white.withValues(alpha: .1))),
              child: Row(children: [
                Icon(Icons.search_rounded, color: p.ink2),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: q, onChanged: (_) => setState(() {}), style: const TextStyle(fontSize: 16), decoration: InputDecoration(border: InputBorder.none, isDense: true, hintText: 'Search', hintStyle: TextStyle(color: p.ink2)))),
              ]),
            ),
          ),
          _kindChips(p),
          const SizedBox(height: 6),
          Expanded(
            child: Live(b: (c) {
              final text = q.text.trim().toLowerCase();
              final all = repo.txOf(widget.acc?.id).where((t) => (kind == 'all' || t.type == kind) && (text.isEmpty || _title(t).toLowerCase().contains(text) || t.note.toLowerCase().contains(text) || t.pay.toLowerCase().contains(text))).toList();
              if (all.isEmpty) return ListView(children: [emptyState(p, Icons.folder_open_rounded, 'No transactions yet')]);
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
