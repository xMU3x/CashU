import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import '../core/groups.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/sync.dart';
import '../sms/sms_tracker.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/theme.dart';
import '../ui/shell_scope.dart';
import '../ui/widgets.dart';
import '../ui/acc_menu.dart';
import 'acc_edit.dart';
import 'acc_tx.dart';
import 'add_tx.dart';
import 'group_edit.dart';
import 'profile.dart';
import 'more_pages.dart' show showWriteSpent;

const _extraColors = [Color(0xFF16A394), Color(0xFFD4A017), Color(0xFF6C63FF)];
const _defaultGroupColors = <String, Color>{
  'Cash': Color(0xFF28A745),
  'Bank Accounts': Color(0xFFE8610A),
  'Credit': Color(0xFF1E9BE8),
  'eWallets': Color(0xFFE5383B),
  'Debit Cards': Color(0xFFB65FD6),
};

class AccountsHome extends StatefulWidget {
  const AccountsHome({super.key});
  @override
  State<AccountsHome> createState() => _AccountsHomeState();
}

class _AccountsHomeState extends State<AccountsHome> {
  final sc = ScrollController();
  final off = ValueNotifier<double>(0);
  bool edit = false;
  int gen = 0;
  final folded = <String>{};

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
    super.dispose();
  }

  // ---------- بيانات ----------
  Map<String, List<Account>> _groups() {
    final order = S.list('accOrder');
    int idx(Account a) {
      final i = order.indexOf(a.id);
      return i < 0 ? 100000 : i;
    }

    final all = repo.accList.toList();
    final names = allGroupNames();
    final out = <String, List<Account>>{};
    for (final n in names) {
      final l = all.where((a) => a.group == n).toList()..sort((a, b) => idx(a).compareTo(idx(b)));
      // المجموعات المخصّصة تظهر حتى لو فاضية عشان تقدر تعدّلها وتضيف لها حسابات.
      if (l.isNotEmpty || S.list('customGroups').contains(n)) out[n] = l;
    }
    return out;
  }

  void _toggleFold(String name, bool open) {
    setState(() => open ? folded.add(name) : folded.remove(name));
    S.put('foldedGroups', folded.toList());
  }

  Color _gc(String g) {
    final c = groupColorOf(g) ?? _defaultGroupColors[g];
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
        ('New Group', _newGroup),
      ]);

  void _newGroup() => Navigator.of(context).push(sheetRoute(const GroupEditPage()));
  void _editGroup(String name) => Navigator.of(context).push(sheetRoute(GroupEditPage(name: name, color: _gc(name))));

  /// إضافة حساب جديد داخل نفس المجموعة (يختار نوع الحساب ثم يُحفظ في المجموعة).
  void _addToGroup(String g) => showPillMenu(context, [
        ('Cash/Wallet Account', () => Navigator.of(context).push(sheetRoute(AccountEditPage(kind: 'cash', group: g)))),
        ('Bank Account', () => Navigator.of(context).push(sheetRoute(AccountEditPage(kind: 'bank', group: g)))),
        ('Credit Card', () => Navigator.of(context).push(sheetRoute(AccountEditPage(kind: 'credit', group: g)))),
        ('Debit Card', () => Navigator.of(context).push(sheetRoute(AccountEditPage(kind: 'debit', group: g)))),
        ('eWallet', () => Navigator.of(context).push(sheetRoute(AccountEditPage(kind: 'wallet', group: g)))),
      ]);

  void _newAcc(String k) => Navigator.of(context).push(sheetRoute(AccountEditPage(kind: k)));
  void _editAcc(Account a) => Navigator.of(context).push(sheetRoute(AccountEditPage(edit: a)));
  void _openAcc(Account a) => Navigator.of(context).push(flowRoute(AccountTxPage(acc: a)));
  void _addTx(Account a, int page) => Navigator.of(context).push(sheetRoute(AddTxPage(page: page, accId: a.id)));

  Future<void> _delAcc(Account a) async {
    if (await confirmDialog(context, 'Delete account', '"${a.name}" will be deleted. Its transactions stay in the history.')) {
      if (!repo.deleteAccount(a.id) && mounted) { toast(context, 'You cannot delete the last account'); }
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
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: p.card, shape: BoxShape.circle, border: Border.all(color: p.line, width: 1.5)),
          child: Icon(Icons.person_rounded, color: p.ink2, size: 22),
        ),
      );

  /// «اللي صرفته»: أيقونة دفتر وقلم زرقاء تفتح كتابة المصروفات النصية.
  Widget _writeBtn(Pal p) => Tap(
        onTap: () => showWriteSpent(context),
        child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.edit_note_rounded, size: 24, color: kBlue)),
      );

  Widget _toolbar(Pal p) => Glass(
        radius: 24,
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Tap(onTap: () => S.put('hide', !S.flag('hide')), child: Padding(padding: const EdgeInsets.all(6), child: Icon(S.flag('hide') ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 21, color: p.ink2))),
          const SizedBox(width: 4),
          Tap(onTap: () => setState(() => edit = true), child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.tune_rounded, size: 21, color: p.ink2))),
          const SizedBox(width: 4),
          Tap(onTap: _addAccountMenu, child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.create_new_folder_outlined, size: 21, color: p.ink2))),
          const SizedBox(width: 4),
          _writeBtn(p),
        ]),
      );

  Widget _topBar(Pal p) => ValueListenableBuilder<double>(
        valueListenable: off,
        builder: (c, o, _) {
          final t = ((o - 50) / 40).clamp(0.0, 1.0);
          return Container(
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 6, 16, 6),
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
                Tap(onTap: () => setState(() => edit = false), child: Container(height: 38, padding: const EdgeInsets.symmetric(horizontal: 20), alignment: Alignment.center, decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(19)), child: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))))
              else
                _toolbar(p),
            ]),
          );
        },
      );

  /// لوحة صافي الثروة / الالتزامات (الشكل القديم): أيقونة قبل كل اسم + شريط تقدم خفيف + صف «كل المعاملات».
  Widget _netCard(Pal p) {
    final liab = repo.liabilities;
    final net = repo.netWorth;
    final assets = net + liab;
    final hide = S.flag('hide');
    Widget col(String l, IconData ic, double v, Color c, double frac) => Expanded(
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(ic, size: 15, color: c),
              const SizedBox(width: 5),
              Text(l, style: TextStyle(fontSize: 12.5, color: c, fontWeight: FontWeight.w600, letterSpacing: .4)),
            ]),
            const SizedBox(height: 6),
            Text(hide ? '••••' : egp(v), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.ink)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: frac.clamp(0.0, 1.0), minHeight: 3, backgroundColor: p.ink.withValues(alpha: .08), valueColor: AlwaysStoppedAnimation(c.withValues(alpha: .75)))),
            ),
          ]),
        );
    final total = assets.abs() + liab.abs();
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 4),
      decoration: iosCard(p, r: 22),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          col('NET WORTH', Icons.account_balance_wallet_outlined, net, kBlue, total > 0 ? assets.abs() / total : 0),
          col('LIABILITIES', Icons.trending_down_rounded, liab, const Color(0xFFFF6B5E), total > 0 ? liab.abs() / total : 0),
        ]),
        const SizedBox(height: 10),
        Divider(color: p.line, height: 1),
        Tap(
          onTap: () {
            if (!ShellNav.go('tx')) Navigator.of(context).push(flowRoute(const AccountTxPage(embedded: true)));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(children: [
              Icon(Icons.history_rounded, size: 22, color: p.ink2),
              const SizedBox(width: 12),
              Expanded(child: Text('All Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.ink))),
              Icon(Icons.chevron_right_rounded, size: 22, color: p.ink2.withValues(alpha: .7)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _pill(Pal p, String text, Color c) => Container(
        padding: const EdgeInsets.fromLTRB(11, 3, 9, 3),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(14)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600)),
          const SizedBox(width: 7),
          Tap(onTap: () => S.put('hide', !S.flag('hide')), child: Icon(S.flag('hide') ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white, size: 16)),
        ]),
      );

  Widget _minus(VoidCallback f) => Tap(onTap: f, child: Container(width: 24, height: 24, decoration: BoxDecoration(color: kRed, shape: BoxShape.circle), child: const Icon(Icons.remove_rounded, color: Colors.white, size: 18)));

  Widget _accTile(Pal p, Account a, {bool last = false}) {
    final b = repo.bal(a.id);
    return Container(
      color: p.card,
      padding: const EdgeInsets.only(left: 14),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 14, 8),
          child: Row(children: [
            accIcon(a, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
                const SizedBox(height: 1),
                Text(egp(b), style: TextStyle(fontSize: 15, color: b > 0 ? kGreen : (b < 0 ? kRed : p.ink))),
              ]),
            ),
          ]),
        ),
        if (!last) hair(p, indent: 54),
      ]),
    );
  }

  Widget _accRow(Pal p, Account a, {bool last = false}) => SwipeRow(
        key: ValueKey('${a.id}_$gen'),
        bg: p.bg,
        rightW: 290,
        rightActions: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
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
            toast(context, 'تمت أرشفة "${a.name}"');
          }),
          swipeCircle(Icons.delete_outline_rounded, 'Delete', kRed, () => _delAcc(a)),
        ]),
        leftW: 150,
        leftActions: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          swipeCircle(Icons.add_rounded, 'Income', const Color(0xFF28A745), () {
            setState(() => gen++);
            _addTx(a, 1);
          }),
          swipeCircle(Icons.remove_rounded, 'Expense', const Color(0xFFFF453A), () {
            setState(() => gen++);
            _addTx(a, 0);
          }),
        ]),
        child: Tap(scale: .99, onTap: () => _openAcc(a), onLongPress: () => _accMenu(a), child: _accTile(p, a, last: last)),
      );

  void _accMenu(Account a) => showAccountMenu(context, a, [
        AccMenuAction(Icons.remove_rounded, 'New Expense', () => _addTx(a, 0)),
        AccMenuAction(Icons.add_rounded, 'New Income', () => _addTx(a, 1)),
        AccMenuAction(Icons.swap_horiz_rounded, 'New Transfer', () => _addTx(a, 2)),
        AccMenuAction(Icons.layers_outlined, 'Reorder', () => setState(() => edit = true), dividerBefore: true),
        AccMenuAction(Icons.edit_note_rounded, 'Edit', () => _editAcc(a)),
        AccMenuAction(Icons.archive_outlined, 'Archive', () {
          if (repo.accList.length <= 1) {
            toast(context, 'You cannot archive the last account');
            return;
          }
          a.arch = true;
          repo.saveAccount(a);
          toast(context, 'تمت أرشفة "${a.name}"');
        }, danger: true),
        AccMenuAction(Icons.delete_outline_rounded, 'Delete', () => _delAcc(a), danger: true),
      ]);

  Widget _header(Pal p, String name, List<Account> l) {
    final open = !folded.contains(name);
    return Tap(
      scale: .99,
      onTap: edit ? () => _editGroup(name) : () => _toggleFold(name, open),
      onLongPress: () => showPillMenu(context, [
        ('Edit group', () => _editGroup(name)),
        ('إضافة حساب جديد', () => _addToGroup(name)),
        ('Delete group', () => _delGroup(name, l)),
      ]),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        child: Row(children: [
          if (edit) ...[_minus(() => _delGroup(name, l)), const SizedBox(width: 10)],
          AnimatedRotation(turns: open ? 0 : -.25, duration: const Duration(milliseconds: 220), child: const Icon(Icons.arrow_drop_down_rounded, size: 24)),
          const SizedBox(width: 4),
          Expanded(child: Text(name, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, color: p.ink2.withValues(alpha: .85)))),
          if (edit) Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: Icon(Icons.edit_rounded, size: 18, color: p.ink2)),
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
      S.put('customGroups', S.list('customGroups')..remove(name));
      setState(() {});
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
                Expanded(child: Row(children: [accIcon(l[i], size: 42), const SizedBox(width: 14), Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)), Text(egp(repo.bal(l[i].id)), style: TextStyle(fontSize: 15, color: kGreen))])))])),
                ReorderableDragStartListener(index: i, child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.drag_handle_rounded, color: p.ink2))),
              ]),
            ),
        ],
      );
    } else {
      body = AnimatedSize(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic, alignment: Alignment.topCenter, child: Column(children: [for (var i = 0; i < l.length; i++) KeyedSubtree(key: ValueKey('r_${l[i].id}'), child: _accRow(p, l[i], last: i == l.length - 1))]));
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: iosCard(p, r: 22),
      child: Column(children: [
        _header(p, name, l),
        AnimatedSize(duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic, alignment: Alignment.topCenter, child: open ? body : const SizedBox(width: double.infinity)),
      ]),
    );
  }

  /// سحب للتحديث: يسحب الرسائل الجديدة، يشغّل المتكرر، ثم يزامن كل البيانات مع Supabase.
  bool _synced = false;

  Future<void> _refresh() async {
    setState(() => _synced = false);
    await smsTracker.drainNative();
    repo.runRecurring();
    if (sync.user == null) return;
    final ok = await sync.refresh();
    if (!mounted) return;
    // سهم التحديث العلوي يبقى أخضر لما المزامنة تتم (من غير بانل/رسالة).
    setState(() => _synced = ok);
    if (ok) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _synced = false);
      });
    }
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
          color: _synced ? kGreen : p.acc,
          backgroundColor: p.card,
          onRefresh: _refresh,
          child: ListView(
            controller: sc,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: EdgeInsets.fromLTRB(16, top + 72, 16, 130),
            children: [
              Reveal(i: 2, child: _netCard(p)),
              const SizedBox(height: 14),
              for (final e in g.entries) Reveal(i: 3, child: _groupCard(p, g, e.key, e.value)),
            ],
          ),
        ),
        // ضبابية بدل اللون الأسود لما المحتوى يتحرك تحت الشريط العلوي
        Positioned(top: 0, left: 0, right: 0, child: ValueListenableBuilder<double>(valueListenable: off, builder: (c, o, _) => Opacity(opacity: ((o - 4) / 30).clamp(0.0, 1.0), child: BlurEdge(height: top + 58, tint: p.bg)))),
        Positioned(top: 0, left: 0, right: 0, child: _topBar(p)),
        PositionedDirectional(
          end: 28,
          bottom: (EmbeddedScope.maybeOf(context)?.bottomInset ?? (96 + MediaQuery.of(context).padding.bottom)) + 16,
          child: Tap(
            scale: .92,
            onTap: () => Navigator.of(context).push(sheetRoute(const AddTxPage())),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: kBlue, shape: BoxShape.circle, boxShadow: [BoxShadow(color: kBlue.withValues(alpha: .3), blurRadius: 10, offset: const Offset(0, 3))]),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
            ),
          ),
        ),
      ]);
    });
  }
}
