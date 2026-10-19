import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import '../core/groups.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/store.dart';
import '../core/sync.dart';
import '../sms/sms_tracker.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/acc_menu.dart';
import 'acc_edit.dart';
import 'acc_tx.dart';
import 'add_tx.dart';
import 'group_edit.dart';
import 'sms_pages.dart' show SmsReviewPage;
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
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: p.card, shape: BoxShape.circle, border: Border.all(color: p.line, width: 2)),
          child: Icon(Icons.person_rounded, color: p.ink2, size: 26),
        ),
      );

  /// جرس الإشعارات: عدّاد بالمعاملات (من الرسائل) اللي محتاجة تسجيل يدوي. بيفتح شاشة المراجعة.
  Widget _bell(Pal p) => AnimatedBuilder(
        animation: Listenable.merge([store, smsTracker]),
        builder: (c, _) {
          final n = smsTracker.review.length;
          return Tap(
            onTap: () => Navigator.of(context).push(flowRoute(const SmsReviewPage())),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Stack(clipBehavior: Clip.none, children: [
                Icon(n > 0 ? Icons.notifications_rounded : Icons.notifications_none_rounded, size: 26, color: n > 0 ? kBlue : p.ink2),
                if (n > 0)
                  PositionedDirectional(
                    top: -5,
                    end: -6,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(9)),
                      child: Center(child: Text(n > 99 ? '99+' : '$n', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
                    ),
                  ),
              ]),
            ),
          );
        },
      );

  /// «ما الجديد»: أيقونة ✨ مسطّحة بجوار الجرس، بتعرض الإضافات الجديدة في التطبيق.
  Widget _whatsNew(Pal p) => Tap(
        onTap: () => showSheet<void>(context, (c) => SheetFrame(
              title: 'ما الجديد',
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final t in const ['شاشة اشتراكاتي الجديدة: دونات ونسب وتجربة مجانية وسجل دفعات', 'الجمعيات والأقساط', 'الحسابات المؤرشفة مع إمكانية الاسترجاع', 'شريط سفلي جديد وتبويبات معاملات ملوّنة'])
                    Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.auto_awesome_outlined, size: 18, color: kBlue), const SizedBox(width: 10), Expanded(child: Text(t, style: const TextStyle(fontSize: 15)))])),
                ]),
              ),
            )),
        child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.auto_awesome_outlined, size: 26, color: p.ink2)),
      );

  Widget _toolbar(Pal p) => Glass(
        radius: 30,
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Tap(onTap: () => S.put('hide', !S.flag('hide')), child: Padding(padding: const EdgeInsets.all(8), child: Icon(S.flag('hide') ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 26, color: p.ink2))),
          const SizedBox(width: 10),
          Tap(onTap: () => setState(() => edit = true), child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.tune_rounded, size: 26, color: p.ink2))),
          const SizedBox(width: 10),
          Tap(onTap: _addAccountMenu, child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.create_new_folder_outlined, size: 26, color: p.ink2))),
          const SizedBox(width: 2),
          _whatsNew(p),
          _bell(p),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // ألوان البانل تتبع ثيم التطبيق (داكن/فاتح) بدل لون أزرق ثابت.
    final panelA = isDark ? Color.lerp(p.card, p.acc, .10)! : p.card;
    final panelB = isDark ? p.card : Color.lerp(p.card, p.bg, .6)!;
    BoxDecoration glass(double r) => BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [panelA, panelB]),
          borderRadius: BorderRadius.circular(r),
          border: Border.all(color: p.line.withValues(alpha: isDark ? .6 : .9)),
        );
    final white = p.ink, dim = p.ink2;
    Widget mini(String l, double v, Color c, IconData ic, double frac) => Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
            decoration: glass(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 26, height: 26, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)), child: Icon(ic, color: Colors.white, size: 15)),
                const SizedBox(width: 8),
                Text(l, style: TextStyle(fontSize: 12.5, color: c, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 6),
              Text(S.flag('hide') ? '••••' : egp(v), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: white)),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: frac.clamp(0.0, 1.0), minHeight: 4, backgroundColor: p.ink.withValues(alpha: .08), valueColor: AlwaysStoppedAnimation(c))),
            ]),
          ),
        );
    final total = assets + liab;
    // نسبة التغيّر: آخر رصيد مقابل أول رصيد في رسم الاتجاه
    final first = pts.first;
    final chg = first.abs() < 1e-9 ? 0.0 : (pts.last - first) / first.abs() * 100;
    final up = chg >= 0;
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: glass(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Net Worth', style: TextStyle(fontSize: 13, color: white)),
            const SizedBox(width: 8),
            Tap(onTap: () => S.put('hide', !S.flag('hide')), child: Icon(S.flag('hide') ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: dim)),
            const Spacer(),
            // شارة النسبة: أصغر ومرفوعة في سطر العنوان عشان ما تتداخلش مع خط التقدم
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: (up ? kGreen : kRed).withValues(alpha: .14), borderRadius: BorderRadius.circular(10), border: Border.all(color: (up ? kGreen : kRed).withValues(alpha: .4), width: .8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 11, color: up ? kGreen : kRed),
                const SizedBox(width: 2),
                Text('${chg.abs().toStringAsFixed(0)}%', textDirection: TextDirection.ltr, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: up ? kGreen : kRed)),
              ]),
            ),
          ]),
          const SizedBox(height: 2),
          Text(S.flag('hide') ? '••••••' : egp(repo.netWorth), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: white)),
          const SizedBox(height: 4),
          SizedBox(height: 38, width: double.infinity, child: CustomPaint(painter: _SparkPainter(pts, kGreen))),
        ]),
      ),
      const SizedBox(height: 8),
      Row(children: [
        mini('Assets', assets, const Color(0xFF3DA5FF), Icons.account_balance_wallet_rounded, total > 0 ? assets / total : 0),
        const SizedBox(width: 10),
        mini('Liabilities', liab, const Color(0xFFFF6B5E), Icons.arrow_downward_rounded, total > 0 ? liab / total : 0),
      ]),
    ]);
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

  Widget _minus(VoidCallback f) => Tap(onTap: f, child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: kRed, shape: BoxShape.circle), child: const Icon(Icons.remove_rounded, color: Colors.white, size: 18)));

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
          toast(context, '\"${a.name}\" archived');
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
        Positioned(top: 0, left: 0, right: 0, child: _topBar(p)),
        PositionedDirectional(
          end: 18,
          bottom: 96 + MediaQuery.of(context).padding.bottom,
          child: Tap(
            scale: .92,
            onTap: () => Navigator.of(context).push(sheetRoute(const AddTxPage())),
            onLongPress: () => showPillMenu(context, [('اكتب اللي صرفته', () => showWriteSpent(context))]),
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
