import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/sync.dart';
import '../core/i18n.dart';
import '../core/util.dart';
import '../sms/sms_tracker.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'acc_edit.dart';
import 'acc_tx.dart';
import 'add_tx.dart';
import 'more_pages.dart';
import 'more_tab.dart';
import 'profile.dart';
import 'stats.dart';

const _groupColors = <String, Color>{
  'Cash': Color(0xFF28A745),
  'Bank Accounts': Color(0xFFE8610A),
  'Credit': Color(0xFF1E9BE8),
  'eWallets': Color(0xFFE5383B),
  'Debit Cards': Color(0xFFB65FD6),
};
const _extraColors = [Color(0xFF16A394), Color(0xFFD4A017), Color(0xFF6C63FF)];

class AccountsHome extends StatefulWidget {
  const AccountsHome({super.key});
  @override
  State<AccountsHome> createState() => _AccountsHomeState();
}

class _AccountsHomeState extends State<AccountsHome> {
  final sc = ScrollController();
  final off = ValueNotifier<double>(0);
  final q = TextEditingController();
  bool edit = false;
  int gen = 0;
  final folded = <String>{};
  String filter = 'all'; // all | cash | banks | cards | other

  @override
  void initState() {
    super.initState();
    folded.addAll(S.list('foldedGroups')); // حالة الطي محفوظة بين الجلسات
    sc.addListener(() => off.value = sc.hasClients ? sc.offset : 0);
  }

  @override
  void dispose() {
    sc.dispose();
    off.dispose();
    q.dispose();
    super.dispose();
  }

  // ---------- بيانات ----------
  Map<String, List<Account>> _groups() {
    final order = S.list('accOrder');
    int idx(Account a) {
      final i = order.indexOf(a.id);
      return i < 0 ? 100000 : i;
    }

    final text = q.text.trim().toLowerCase();
    final all = repo.accList.where((a) => _passes(a) && (text.isEmpty || a.name.toLowerCase().contains(text))).toList();
    final names = <String>[...kGroupNames];
    for (final a in all) {
      if (!names.contains(a.group)) names.add(a.group);
    }
    final out = <String, List<Account>>{};
    for (final n in names) {
      final l = all.where((a) => a.group == n).toList()..sort((a, b) => idx(a).compareTo(idx(b)));
      if (l.isNotEmpty) out[n] = l;
    }
    return out;
  }

  bool _passes(Account a) {
    switch (filter) {
      case 'cash':
        return a.kind == 'cash';
      case 'banks':
        return a.kind == 'bank';
      case 'cards':
        return a.kind == 'credit' || a.kind == 'debit';
      case 'other':
        return !const ['cash', 'bank', 'credit', 'debit'].contains(a.kind);
      default:
        return true;
    }
  }

  void _toggleFold(String name, bool open) {
    setState(() => open ? folded.add(name) : folded.remove(name));
    S.put('foldedGroups', folded.toList());
  }

  Color _gc(String g) {
    final c = _groupColors[g];
    if (c != null) return c;
    return _extraColors[g.length % _extraColors.length];
  }

  double _sum(List<Account> l) => l.where((a) => a.gb).fold(0.0, (s, a) => s + repo.bal(a.id));

  void _addAccountMenu() => showPillMenu(context, [
        ('Cash/Wallet Account', () => _newAcc('cash')),
        ('Bank Account', () => _newAcc('bank')),
        ('Credit Card', () => _newAcc('credit')),
        ('Debit Card', () => _newAcc('debit')),
        ('eWallet', () => _newAcc('wallet')),
      ]);

  void _newAcc(String k) => Navigator.of(context).push(sheetRoute(AccountEditPage(kind: k)));
  void _editAcc(Account a) => Navigator.of(context).push(sheetRoute(AccountEditPage(edit: a)));
  void _openAcc(Account a) => Navigator.of(context).push(flowRoute(AccountTxPage(acc: a)));
  void _addTx(Account a, int page) => Navigator.of(context).push(sheetRoute(AddTxPage(page: page, accId: a.id)));

  Future<void> _delAcc(Account a) async {
    if (await confirmDialog(context, 'Delete account', '"${a.name}" will be deleted. Its transactions stay in the history.')) {
      if (!repo.deleteAccount(a.id) && mounted) toast(context, 'You cannot delete the last account');
    }
    setState(() => gen++);
  }

  void _saveOrder(Map<String, List<Account>> g) {
    S.put('accOrder', [for (final l in g.values) for (final a in l) a.id]);
  }

  // ---------- عناصر ----------
  Widget _avatar(Pal p) => Tap(
        onTap: () => showProfileSheet(context),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: p.card, shape: BoxShape.circle, border: Border.all(color: p.line, width: 2)),
          child: Icon(Icons.person_rounded, color: p.ink2, size: 26),
        ),
      );

  Widget _toolbar(Pal p) => Glass(
        radius: 30,
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Tap(onTap: () => S.put('hide', !S.flag('hide')), child: Padding(padding: const EdgeInsets.all(8), child: Icon(S.flag('hide') ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 24, color: p.ink2))),
          const SizedBox(width: 10),
          Tap(onTap: () => setState(() => edit = true), child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.tune_rounded, size: 24, color: p.ink2))),
          const SizedBox(width: 10),
          Tap(onTap: _addAccountMenu, child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.create_new_folder_outlined, size: 24, color: p.ink2))),
          const SizedBox(width: 8),
          Tap(
            onTap: () => Navigator.of(context).push(sheetRoute(const AddTxPage())),
            child: Container(width: 40, height: 40, decoration: const BoxDecoration(color: kBlue, shape: BoxShape.circle), child: const Icon(Icons.add_rounded, color: Colors.white, size: 26)),
          ),
        ]),
      );

  Widget _topBar(Pal p) => ValueListenableBuilder<double>(
        valueListenable: off,
        builder: (c, o, _) {
          final t = ((o - 50) / 40).clamp(0.0, 1.0);
          return Container(
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 8),
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [p.bg, p.bg.withValues(alpha: t > 0 ? .0 : 0)], stops: const [.7, 1])),
            child: Row(children: [
              _avatar(p),
              const SizedBox(width: 12),
              Expanded(
                child: Opacity(
                  opacity: edit ? 0 : t,
                  child: const SizedBox.shrink(),
                ),
              ),
              if (edit)
                Tap(onTap: () => setState(() => edit = false), child: Container(height: 46, padding: const EdgeInsets.symmetric(horizontal: 24), alignment: Alignment.center, decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(23)), child: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))))
              else
                _toolbar(p),
            ]),
          );
        },
      );

  Widget _search(Pal p) => Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: p.card.withValues(alpha: .85), borderRadius: BorderRadius.circular(26), border: Border.all(color: Colors.white.withValues(alpha: .1))),
        child: Row(children: [
          Icon(Icons.search_rounded, color: p.ink2, size: 24),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: q, onChanged: (_) => setState(() {}), style: const TextStyle(fontSize: 17), decoration: InputDecoration(border: InputBorder.none, isDense: true, hintText: tl('Search'), hintStyle: TextStyle(color: p.ink2)))),
        ]),
      );

  /// صافي الثروة + رسم اتجاه أرصدة الحسابات (آخر ٦ أشهر) + الأصول والالتزامات.
  Widget _netCard(Pal p) {
    final liab = repo.liabilities;
    final assets = repo.netWorth + liab;
    final now = DateTime.now();
    // رصيد الحسابات (المشمولة في صافي الثروة) في نهاية كل شهر؛ آخر نقطة = الرصيد الحالي.
    final pts = <double>[
      for (var i = 5; i >= 1; i--) repo.accList.where((a) => a.nw).fold(0.0, (s, a) => s + repo.balAt(a.id, DateTime(now.year, now.month - i + 1, 1))),
      repo.accList.where((a) => a.nw).fold(0.0, (s, a) => s + repo.bal(a.id)),
    ];
    Widget mini(String l, double v, Color c, IconData ic, double frac) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: iosCard(p, r: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 32, height: 32, decoration: BoxDecoration(color: c.withValues(alpha: .16), borderRadius: BorderRadius.circular(10)), child: Icon(ic, color: c, size: 18)),
                const SizedBox(width: 8),
                Text(l, style: TextStyle(fontSize: 13, color: c, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 8),
              Text(egp(v), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: frac.clamp(0.0, 1.0), minHeight: 5, backgroundColor: p.field, valueColor: AlwaysStoppedAnimation(c))),
            ]),
          ),
        );
    final total = assets + liab;
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: iosCard(p, r: 26),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('NET WORTH', style: TextStyle(fontSize: 13, color: p.ink2, letterSpacing: .4)),
            const SizedBox(width: 8),
            Tap(onTap: () => S.put('hide', !S.flag('hide')), child: Icon(S.flag('hide') ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 19, color: p.ink2)),
          ]),
          const SizedBox(height: 4),
          Text(egp(repo.netWorth), style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: repo.netWorth < 0 ? kRed : p.ink)),
          const SizedBox(height: 10),
          SizedBox(height: 56, width: double.infinity, child: CustomPaint(painter: _SparkPainter(pts, kGreen))),
        ]),
      ),
      const SizedBox(height: 10),
      Row(children: [
        mini('Assets', assets, kBlue, Icons.trending_up_rounded, total > 0 ? assets / total : 0),
        const SizedBox(width: 10),
        mini('LIABILITIES', liab, kOrange, Icons.trending_down_rounded, total > 0 ? liab / total : 0),
      ]),
    ]);
  }

  Widget _actions(Pal p) {
    Widget btn(IconData ic, String l, VoidCallback f) => Expanded(
          child: Tap(
            scale: .95,
            onTap: f,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: iosCard(p, r: 18),
              child: Column(children: [
                Icon(ic, color: kBlue, size: 24),
                const SizedBox(height: 6),
                Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        );
    return Row(children: [
      btn(Icons.add_rounded, 'Add', _addAccountMenu),
      btn(Icons.swap_horiz_rounded, 'Transfer', () => Navigator.of(context).push(sheetRoute(const AddTxPage(page: 2)))),
      btn(Icons.currency_exchange_rounded, 'Exchange', () => Navigator.of(context).push(flowRoute(const RatesPage()))),
      btn(Icons.bar_chart_rounded, 'Statistics', () => Navigator.of(context).push(flowRoute(const SubPage(child: StatsPage())))),
    ]);
  }

  Widget _filters(Pal p) {
    const items = [('all', 'All'), ('cash', 'Cash'), ('banks', 'Banks'), ('cards', 'Cards'), ('other', 'Other')];
    return SizedBox(
      height: 40,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final it in items)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Tap(
              scale: .95,
              onTap: () => setState(() => filter = it.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: filter == it.$1 ? kBlue : p.card, borderRadius: BorderRadius.circular(20)),
                child: Text(it.$2, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: filter == it.$1 ? Colors.white : p.ink)),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _pill(Pal p, String text, Color c) => Container(
        padding: const EdgeInsets.fromLTRB(12, 5, 10, 5),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(16)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Tap(onTap: () => S.put('hide', !S.flag('hide')), child: Icon(S.flag('hide') ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white, size: 18)),
        ]),
      );

  Widget _minus(VoidCallback f) => Tap(onTap: f, child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: kRed, shape: BoxShape.circle), child: const Icon(Icons.remove_rounded, color: Colors.white, size: 18)));

  Widget _accTile(Pal p, Account a, {bool last = false}) {
    final b = repo.bal(a.id);
    return Container(
      color: p.card,
      padding: const EdgeInsets.only(left: 14),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 11, 14, 11),
          child: Row(children: [
            accIcon(a, size: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
                const SizedBox(height: 1),
                Text(egp(b), style: TextStyle(fontSize: 15, color: b > 0 ? kGreen : (b < 0 ? kRed : p.ink))),
              ]),
            ),
          ]),
        ),
        if (!last) hair(p, indent: 56),
      ]),
    );
  }

  Widget _accRow(Pal p, Account a, {bool last = false}) => SwipeRow(
        key: ValueKey('${a.id}_$gen'),
        bg: p.bg,
        rightW: 290,
        rightActions: Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 6),
          swipeCircle(Icons.edit_rounded, 'Edit', const Color(0xFF636366), () {
            setState(() => gen++);
            _editAcc(a);
          }),
          swipeCircle(Icons.swap_vert_rounded, 'Reorder', kBlue, () => setState(() {
                gen++;
                edit = true;
              })),
          swipeCircle(Icons.archive_outlined, 'Archive', kOrange, () {
            if (repo.accList.length <= 1) {
              toast(context, 'You cannot archive the last account');
              setState(() => gen++);
              return;
            }
            a.arch = true;
            repo.saveAccount(a);
            toast(context, '"${a.name}" archived');
          }),
          swipeCircle(Icons.delete_outline_rounded, 'Delete', kRed, () => _delAcc(a)),
        ]),
        leftW: 150,
        leftActions: Row(mainAxisSize: MainAxisSize.min, children: [
          swipeCircle(Icons.add_rounded, 'Income', const Color(0xFF28A745), () {
            setState(() => gen++);
            _addTx(a, 1);
          }),
          swipeCircle(Icons.remove_rounded, 'Expense', const Color(0xFFFF453A), () {
            setState(() => gen++);
            _addTx(a, 0);
          }),
        ]),
        child: Tap(scale: .99, onTap: () => _openAcc(a), child: _accTile(p, a, last: last)),
      );

  Widget _header(Pal p, String name, List<Account> l) {
    final open = !folded.contains(name);
    return Tap(
      scale: .99,
      onTap: edit ? null : () => _toggleFold(name, open),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Row(children: [
          if (edit) ...[_minus(() => _delGroup(name, l)), const SizedBox(width: 10)],
          AnimatedRotation(turns: open ? 0 : -.25, duration: const Duration(milliseconds: 220), child: const Icon(Icons.arrow_drop_down_rounded, size: 26)),
          const SizedBox(width: 6),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
          _pill(p, egp(_sum(l)), _gc(name)),
        ]),
      ),
    );
  }

  Future<void> _delGroup(String name, List<Account> l) async {
    if (await confirmDialog(context, 'Delete group', 'Delete "$name" and its ${l.length} account(s)?')) {
      for (final a in l) {
        repo.deleteAccount(a.id);
      }
    }
  }

  Widget _groupCard(Pal p, Map<String, List<Account>> all, String name, List<Account> l) {
    final open = !folded.contains(name) || edit;
    Widget body;
    if (edit) {
      body = ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorder: (o, n) {
          if (n > o) n--;
          final it = l.removeAt(o);
          l.insert(n, it);
          _saveOrder(all);
          setState(() {});
        },
        children: [
          for (var i = 0; i < l.length; i++)
            Container(
              key: ValueKey('e_${l[i].id}'),
              color: p.card,
              padding: const EdgeInsets.only(left: 14, right: 12),
              child: Row(children: [
                _minus(() => _delAcc(l[i])),
                const SizedBox(width: 12),
                Expanded(child: Row(children: [accIcon(l[i], size: 42), const SizedBox(width: 14), Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)), Text(egp(repo.bal(l[i].id)), style: const TextStyle(fontSize: 15, color: kGreen))])))])),
                ReorderableDragStartListener(index: i, child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.drag_handle_rounded, color: p.ink2))),
              ]),
            ),
        ],
      );
    } else {
      body = AnimatedSize(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic, alignment: Alignment.topCenter, child: Column(children: [for (var i = 0; i < l.length; i++) KeyedSubtree(key: ValueKey('r_${l[i].id}'), child: _accRow(p, l[i], last: i == l.length - 1))]));
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: iosCard(p, r: 26),
      child: Column(children: [
        _header(p, name, l),
        AnimatedSize(duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic, alignment: Alignment.topCenter, child: open ? body : const SizedBox(width: double.infinity)),
      ]),
    );
  }

  /// سحب للتحديث: يسحب الرسائل الجديدة، يشغّل المتكرر، ثم يزامن كل البيانات مع Supabase.
  Future<void> _refresh() async {
    await smsTracker.drainNative();
    repo.runRecurring();
    if (sync.user == null) {
      if (mounted) toast(context, 'سجّل الدخول لمزامنة بياناتك مع السيرفر');
      return;
    }
    final ok = await sync.refresh();
    if (mounted) toast(context, ok ? 'تمت المزامنة' : 'تعذّرت المزامنة — سيُعاد المحاولة تلقائيًا');
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final top = MediaQuery.of(context).padding.top;
    return Live(b: (c) {
      final g = _groups();
      return Stack(children: [
        RefreshIndicator(
          edgeOffset: top + 64,
          color: p.acc,
          backgroundColor: p.card,
          onRefresh: _refresh,
          child: ListView(
            controller: sc,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: EdgeInsets.fromLTRB(16, top + 72, 16, 130),
            children: [
              Reveal(i: 1, child: _search(p)),
              const SizedBox(height: 16),
              Reveal(i: 2, child: _netCard(p)),
              const SizedBox(height: 14),
              Reveal(i: 2, child: _actions(p)),
              const SizedBox(height: 14),
              Reveal(i: 3, child: _filters(p)),
              const SizedBox(height: 14),
              for (final e in g.entries) Reveal(i: 3, child: _groupCard(p, g, e.key, e.value)),
            ],
          ),
        ),
        Positioned(top: 0, left: 0, right: 0, child: _topBar(p)),
      ]);
    });
  }
}

/// رسم خطي بسيط لاتجاه صافي الأرصدة.
class _SparkPainter extends CustomPainter {
  final List<double> v;
  final Color c;
  _SparkPainter(this.v, this.c);
  @override
  void paint(Canvas canvas, Size size) {
    if (v.length < 2) return;
    final lo = v.reduce(math.min), hi = v.reduce(math.max);
    final span = (hi - lo).abs() < 1e-9 ? 1.0 : hi - lo;
    Offset pt(int i) => Offset(size.width * i / (v.length - 1), size.height - 6 - (size.height - 12) * ((v[i] - lo) / span));
    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < v.length; i++) {
      final a = pt(i - 1), b = pt(i), mx = (a.dx + b.dx) / 2;
      line.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.withValues(alpha: .28), c.withValues(alpha: 0)]).createShader(Offset.zero & size));
    canvas.drawPath(line, Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 2.4..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_SparkPainter o) => o.v.length != v.length || o.c != c || !_same(o.v, v);
  static bool _same(List<double> a, List<double> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
