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
  const AccountTxPage({super.key, this.acc});
  @override
  State<AccountTxPage> createState() => _AccountTxState();
}

class _AccountTxState extends State<AccountTxPage> {
  final q = TextEditingController();
  int gen = 0;

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
    return SwipeRow(
      key: ValueKey('${t.id}_$gen'),
      bg: p.bg,
      rightW: 130,
      rightActions: Tap(
        onTap: () => _duplicate(t),
        child: Container(height: 46, width: 112, decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(23)), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.copy_rounded, color: Colors.white, size: 18), SizedBox(width: 6), Text('Duplicate', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500))])),
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
              padding: const EdgeInsets.fromLTRB(0, 10, 14, 10),
              child: Row(children: [
                Container(width: 42, height: 42, decoration: BoxDecoration(color: p.field.withValues(alpha: .55), borderRadius: BorderRadius.circular(11), border: Border.all(color: Colors.white.withValues(alpha: .08))), child: Icon(ic.$1, color: ic.$2, size: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_title(t), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Text(enDateTime(t.date), style: TextStyle(fontSize: 13, color: p.ink2)),
                      if (t.pend) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2), decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(10)), child: const Text('pending', style: TextStyle(fontSize: 12)))],
                    ]),
                  ]),
                ),
                const SizedBox(width: 8),
                Text(S.flag('hide') ? '••••' : fixed2(t.amt), style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w500, color: col)),
              ]),
            ),
            if (!last) hair(p, indent: 54),
          ]),
        ),
      ),
    );
  }

  Widget _section(Pal p, String title, Widget chips, List<Tx> l) => Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(6, 0, 0, 8), child: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
          chips,
          const SizedBox(height: 10),
          Container(clipBehavior: Clip.antiAlias, decoration: iosCard(p, r: 20), child: Column(children: [for (var i = 0; i < l.length; i++) _row(p, l[i], last: i == l.length - 1)])),
        ]),
      );

  Widget _header(Pal p) {
    final a = widget.acc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(children: [
        GlassBtn(Icons.chevron_left_rounded, () => Navigator.of(context).maybePop(), size: 48),
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
          Expanded(
            child: Live(b: (c) {
              final text = q.text.trim().toLowerCase();
              final all = repo.txOf(widget.acc?.id).where((t) => text.isEmpty || _title(t).toLowerCase().contains(text) || t.note.toLowerCase().contains(text) || t.pay.toLowerCase().contains(text)).toList();
              if (all.isEmpty) return ListView(children: [emptyState(p, '🗂️', 'No transactions yet')]);
              final pend = all.where((t) => t.pend).toList();
              final months = <int, List<Tx>>{};
              for (final t in all.where((t) => !t.pend)) {
                months.putIfAbsent(t.date.year * 100 + t.date.month, () => []).add(t);
              }
              double out(List<Tx> l) => l.fold(0.0, (s, t) => s + (_dir(t) < 0 ? t.base : 0));
              double inn(List<Tx> l) => l.fold(0.0, (s, t) => s + (_dir(t) > 0 ? t.base : 0));
              final now = DateTime.now();
              return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), physics: const BouncingScrollPhysics(), children: [
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
