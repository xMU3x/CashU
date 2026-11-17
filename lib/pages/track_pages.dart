import 'package:material_ui/material_ui.dart' hide Text;
import '../ui/loc_text.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/store.dart';
import '../core/sync.dart';
import '../core/settings.dart' show S;
import '../core/util.dart';
import '../sms/sms_rules.dart';
import '../sms/sms_tracker.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/sheets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'acc_edit.dart';
import 'sms_pages.dart' show SmsReviewPage, SmsScanPage, SmsWordsPage;

// =====================================================================
//  التتبع التلقائي: SMS + إشعارات تطبيق البنك + أرقام من الرسائل + المتجاهَل + الاستيراد
// =====================================================================

Widget _live(Widget Function(BuildContext) b) => AnimatedBuilder(animation: Listenable.merge([smsTracker, repo, store]), builder: (c, _) => b(c));

Widget _row(Pal p, {required IconData icon, required String title, String? sub, Widget? trailing, VoidCallback? onTap, bool last = false}) => Column(children: [
      Tap(
        scale: .99,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon, color: p.ink2, size: 24),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              if (sub != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, style: TextStyle(fontSize: 13, color: p.ink2))),
            ])),
            if (trailing != null) trailing else if (onTap != null) Icon(Icons.chevron_right_rounded, color: p.ink2),
          ]),
        ),
      ),
      if (!last) hair(p, indent: 52),
    ]);

/// زر كبسولة رئيسي (نفس ستايل أزرار التطبيق).
Widget _pill(Pal p, String t, VoidCallback? onTap, {Color? color, double h = 52}) => Tap(
      scale: .98,
      onTap: onTap,
      child: Container(
        height: h,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: (color ?? kBlue).withValues(alpha: onTap == null ? .4 : 1), borderRadius: BorderRadius.circular(h / 2)),
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
      ),
    );

Widget _chip(Pal p, String w, VoidCallback onDel) => Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 14, 8),
      decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(18)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Tap(onTap: onDel, child: Container(width: 22, height: 22, decoration: BoxDecoration(color: p.ink2.withValues(alpha: .3), shape: BoxShape.circle), child: Icon(Icons.close_rounded, size: 14, color: p.ink2))),
        const SizedBox(width: 8),
        Flexible(child: Text(w, style: const TextStyle(fontSize: 15))),
      ]),
    );

Future<String?> _ask(BuildContext c, String title, {String hint = '', bool number = false}) async {
  final r = await promptText(c, title, hint: hint, number: number);
  if (r == null) return null;
  final t = r.trim();
  return t.isEmpty ? null : t;
}

String _accName(String id) => repo.account(id)?.name ?? '—';

/// يفتح صفحة إنشاء حساب ويرجّع معرّف الحساب الجديد (أو null لو المستخدم رجع من غير ما يحفظ).
Future<String?> _createAccount(BuildContext c) async {
  final before = repo.accList.map((a) => a.id).toSet();
  await Navigator.of(c).push(flowRoute(const AccountEditPage(kind: 'bank')));
  final added = repo.accList.where((a) => !before.contains(a.id)).toList();
  return added.isEmpty ? null : added.first.id;
}

/// «التطبيق ده تبع أنهي حساب؟»: '' = الحساب الافتراضي · معرّف حساب · أو null لو اتلغى.
/// «إنشاء حساب جديد» بيفتح صفحة الحساب ويرجّع الحساب اللي اتعمل.
Future<String?> _chooseAccount(BuildContext c, {String title = 'التطبيق ده تبع أنهي حساب؟', String current = ''}) async {
  final r = await showSheet<String>(c, (ctx) {
    final p = Pal.of(ctx);
    Widget item(String id, String name, {Widget? lead, bool on = false}) => Tap(
          scale: .99,
          onTap: () => Navigator.of(ctx).pop(id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line.withValues(alpha: .6), width: .6))),
            child: Row(children: [
              if (lead != null) ...[lead, const SizedBox(width: 12)],
              Expanded(child: Text(name, style: const TextStyle(fontSize: 18))),
              if (on) Icon(Icons.check_rounded, color: kBlue),
            ]),
          ),
        );
    return SheetFrame(
      title: title,
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 16), children: [
        item('', 'الحساب الافتراضي', on: current.isEmpty),
        for (final a in repo.accList) item(a.id, a.name, lead: accIcon(a, size: 36), on: current == a.id),
        Tap(
          scale: .99,
          onTap: () => Navigator.of(ctx).pop('__new__'),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), child: Row(children: [Text('+ إنشاء حساب جديد', style: TextStyle(color: kBlue, fontSize: 18, fontWeight: FontWeight.w600))])),
        ),
      ]),
    );
  });
  if (r == null) return null;
  if (r == '__new__') {
    if (!c.mounted) return null;
    return _createAccount(c);
  }
  return r;
}

// ---------------------------------------------------------------------
//  خطوات «عشان التتبع يفضل شغال»: بطارية · خلفية · صلاحيات
// ---------------------------------------------------------------------
class _PowerCard extends StatefulWidget {
  const _PowerCard();
  @override
  State<_PowerCard> createState() => _PowerCardState();
}

class _PowerCardState extends State<_PowerCard> with WidgetsBindingObserver {
  Map<String, bool> st = {'battery': true, 'background': true, 'revoke': true};

  /// بعض أجهزة أندرويد (Xiaomi/Oppo/Samsung...) بتقفل «Manage unused apps» من شاشتها بس والنظام مش بيعكسها في الـ API،
  /// فالحالة بتفضل «محتاجة تعديل» حتى لو اتقفلت. بعد ما المستخدم يفتح الإعدادات ويرجع بنسأله، ولو أكّد بنحفظ تأكيده ونعتبرها تمام.
  bool _askedBack = false;
  bool get _revokeConfirmed => S.flag('powerRevokeDone');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final r = await smsTracker.powerStatus();
    if (!mounted) return;
    setState(() {
      st = r;
      if (r['revoke'] == true && _revokeConfirmed) S.put('powerRevokeDone', false); // النظام بقى بيأكدها بنفسه: نشيل التأكيد اليدوي
    });
  }

  Future<void> _openRevoke() async {
    setState(() => _askedBack = true);
    await smsTracker.openAppPermissions();
  }

  Future<void> _openBackground() async {
    await smsTracker.openAppDetails();
  }

  Widget _mark(bool ok) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: ok ? const Color(0xFF2E7D32) : const Color(0xFFD9541E), shape: BoxShape.circle),
        child: Icon(ok ? Icons.check_rounded : Icons.priority_high_rounded, color: Colors.white, size: 22),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final revokeOk = st['revoke'] == true || _revokeConfirmed;
    final left = [st['battery'] == true, st['background'] == true, revokeOk].where((v) => !v).length;
    Widget item(String title, bool ok, {VoidCallback? onTap}) => Tap(
          scale: .99,
          onTap: ok ? null : onTap,
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [
            _mark(ok),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          ])),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('عشان التتبع يفضل شغال', style: TextStyle(fontSize: 14, color: p.ink2)),
      if (left > 0) ...[
        const SizedBox(height: 6),
        Text('أندرويد بيوقف التطبيقات اللي شغالة في الخلفية، ووقتها معاملات البنك بتبطل توصل. فاضل ${toAr('$left')} ${left > 2 ? 'خطوات' : left == 2 ? 'خطوتين' : 'خطوة'}.', style: const TextStyle(fontSize: 13.5, color: Color(0xFFD9541E), height: 1.5)),
      ],
      const SizedBox(height: 4),
      item(st['battery'] == true ? 'البطارية: بدون قيود' : 'البطارية: محتاجة تعديل', st['battery'] == true, onTap: smsTracker.requestBattery),
      hair(p),
      item(st['background'] == true ? 'الشغل في الخلفية' : 'الشغل في الخلفية: مقيّد', st['background'] == true, onTap: _openBackground),
      hair(p),
      item('خلّي الصلاحيات حتى لو مفتحتوش', revokeOk, onTap: _openRevoke),
      if (!revokeOk) ...[
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 52, bottom: 10),
          child: Text('اقفل «إيقاف نشاط التطبيق لو مش مستخدم». غير كده أندرويد هيشيل صلاحية الرسائل من CashU بعد كام شهر.', style: TextStyle(fontSize: 13.5, color: p.ink2, height: 1.5)),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 52),
            child: Tap(
              onTap: _openRevoke,
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13), decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(26)), child: const Text('فتح الإعدادات', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
            ),
          ),
        ),
        if (_askedBack)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 52, top: 12),
            child: Row(children: [
              Expanded(child: Text('قفلت الخيار (Manage unused apps / إيقاف النشاط)؟', style: TextStyle(fontSize: 13.5, color: p.ink2, height: 1.4))),
              const SizedBox(width: 8),
              Tap(
                onTap: () => setState(() {
                  S.put('powerRevokeDone', true);
                  _askedBack = false;
                }),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9), decoration: BoxDecoration(color: kGreen.withValues(alpha: .18), borderRadius: BorderRadius.circular(20)), child: Text('أيوه، قفلته', style: TextStyle(color: kGreen, fontSize: 14, fontWeight: FontWeight.w700))),
              ),
            ]),
          ),
      ],
    ]);
  }
}

/// كارت التفعيل (سويتش + حالة) مع خطوات بقاء التتبع شغال لما يكون مفعّل.
Widget _enableCard(Pal p, {required String label, required bool on, required ValueChanged<bool> onChanged, String? desc, String? extra}) => Container(
      padding: const EdgeInsets.all(18),
      decoration: iosCard(p, r: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 14, color: p.ink2)),
            const SizedBox(height: 2),
            Text(on ? 'مفعّل' : 'معطّل', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          ]),
          const Spacer(),
          Switch(value: on, activeTrackColor: kBlue, activeThumbColor: Colors.white, onChanged: onChanged),
        ]),
        if (desc != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(desc, style: TextStyle(fontSize: 14.5, color: p.ink2, height: 1.55))),
        if (on && extra != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(extra, style: TextStyle(fontSize: 14, color: p.ink2))),
        if (on) ...[const SizedBox(height: 12), hair(p), const SizedBox(height: 12), const _PowerCard()],
      ]),
    );

/// بانل صغير في آخر الصفحة: الرسائل مش بتتخزن.
Widget _privacyNote(Pal p) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: p.card.withValues(alpha: .6), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(Icons.verified_user_outlined, color: kGreen, size: 17),
        const SizedBox(width: 8),
        Expanded(child: Text('رسائلك لا يتم تخزينها أبداً. فقط بيانات المصروفات يتم حفظها.', style: TextStyle(fontSize: 12, color: p.ink2, height: 1.4))),
      ]),
    );

Future<void> _addCardFlow(BuildContext c, {String? accId}) async {
  final l4 = await _ask(c, 'آخر ٤ أرقام من البطاقة أو الحساب', hint: '7748', number: true);
  if (l4 == null) return;
  if (!RegExp(r'^\d{4}$').hasMatch(normDigits(l4))) {
    if (c.mounted) toast(c, 'اكتب ٤ أرقام بالضبط');
    return;
  }
  if (!c.mounted) return;
  final acc = accId ?? await showPickAccount(c, repo.defaultAcc, title: 'اربط الرقم بحساب');
  if (acc != null) smsTracker.linkCard(normDigits(l4), acc);
}

Future<void> _removeCardFlow(BuildContext c, String l4) async {
  if (await confirmDialog(c, 'حذف الرقم', 'الرقم •••• $l4 هيتشال نهائيًا من الربط ومش هيرجع تلقائيًا. تقدر تضيفه تاني يدويًا.', ok: 'حذف نهائي')) smsTracker.unlinkCard(l4);
}

List<String> _senderPatterns(Account a) => [for (final w in a.sms.split(RegExp(r'[\n,،;]'))) if (w.trim().isNotEmpty) w.trim()];

Future<void> _addSenderFlow(BuildContext c, {String? accId}) async {
  final w = await _ask(c, 'اسم مرسل الرسالة أو كلمة فيها', hint: 'مثلاً: Telda أو VodafoneCash');
  if (w == null || !c.mounted) return;
  final id = accId ?? await showPickAccount(c, repo.defaultAcc, title: 'الرسايل دي تتسجل على أنهي حساب؟');
  final a = id == null ? null : repo.account(id);
  if (a == null) return;
  final l = _senderPatterns(a);
  if (!l.map((x) => x.toLowerCase()).contains(w.toLowerCase())) l.add(w);
  a.sms = l.join('\n');
  repo.saveAccount(a);
}

Future<void> _removeSenderFlow(BuildContext c, Account a, String w) async {
  if (!await confirmDialog(c, 'إزالة المرسل', '«$w» مش هيتربط بحساب «${a.name}» تاني.', ok: 'إزالة')) return;
  a.sms = (_senderPatterns(a)..remove(w)).join('\n');
  repo.saveAccount(a);
}

Future<void> _addAppFlow(BuildContext c, {String? accId}) async {
  final app = await Navigator.of(c).push<({String name, String pkg})>(sheetRoute(const _PickAppPage()));
  if (app == null || !c.mounted) return;
  final acc = accId ?? await _chooseAccount(c);
  if (acc == null) return;
  await smsTracker.addNotifApp(app.pkg, app.name, acc);
  if (!smsTracker.trackNotifs) await smsTracker.setTrackNotifs(true);
}

Widget _linkChip(Pal p, String text, {VoidCallback? onDel, IconData? icon, bool ltr = false}) => Container(
      padding: EdgeInsetsDirectional.fromSTEB(10, 5, onDel == null ? 10 : 6, 5),
      decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(16)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: p.ink2), const SizedBox(width: 5)],
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: ltr ? TextDirection.ltr : null, style: const TextStyle(fontSize: 13.5))),
        if (onDel != null) ...[
          const SizedBox(width: 4),
          Tap(onTap: onDel, child: Padding(padding: const EdgeInsets.all(3), child: Icon(Icons.close_rounded, size: 15, color: p.ink2))),
        ],
      ]),
    );

/// «البطاقات والحسابات»: كل الحسابات وكل اللي مربوط بكل واحد (أرقام · رسائل البنك · تطبيق الإشعارات)، وأيقونة تعديل على يمين كل حساب.
class LinkedAccountsPage extends StatelessWidget {
  const LinkedAccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: 'البطاقات والحسابات',
      icon: Icons.credit_card_rounded,
      iconColor: kBlue,
      child: _live((c) {
        final t = smsTracker;
        final cards = t.cards;
        final apps = t.notifApps;
        final list = [for (final a in repo.accList) if (!a.del && !a.arch) a];
        if (list.isEmpty) return emptyState(p, Icons.credit_card_off_outlined, 'مفيش حسابات لسه.');
        return ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 40), physics: const BouncingScrollPhysics(), children: [
          Padding(padding: const EdgeInsets.fromLTRB(6, 0, 6, 12), child: Text('أي رسالة أو إشعار يطابق رقم أو مرسل أو تطبيق مربوط بحساب بيتسجّل فيه مباشرة. اضغط على القلم لتعديل ربط أي حساب.', style: TextStyle(fontSize: 13.5, color: p.ink2, height: 1.55))),
          for (final a in list)
            Builder(builder: (_) {
              final nums = [for (final e in cards.entries) if (e.value == a.id) e.key]..sort();
              final senders = _senderPatterns(a);
              final myApps = [for (final e in apps.entries) if ((e.value['acc'] ?? '') == a.id) e.value['name'] ?? e.key];
              final empty = nums.isEmpty && senders.isEmpty && myApps.isEmpty;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.fromLTRB(10, 12, 14, 12),
                decoration: iosCard(p, r: 22),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Tap(
                    onTap: () => Navigator.of(c).push(flowRoute(AccountLinksEditPage(accId: a.id))),
                    child: Container(width: 40, height: 40, decoration: BoxDecoration(color: p.field, shape: BoxShape.circle), child: Icon(Icons.edit_outlined, size: 20, color: kBlue)),
                  ),
                  const SizedBox(width: 12),
                  accIcon(a, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.name, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      if (empty)
                        Text('مفيش أرقام أو رسائل أو تطبيق مربوط', style: TextStyle(fontSize: 13, color: p.ink2))
                      else
                        Wrap(spacing: 8, runSpacing: 6, children: [
                          for (final n in nums) _linkChip(p, '•••• $n', ltr: true),
                          for (final w in senders) _linkChip(p, w, icon: Icons.sms_outlined),
                          for (final n in myApps) _linkChip(p, n, icon: Icons.notifications_none_rounded),
                        ]),
                    ]),
                  ),
                ]),
              );
            }),
        ]);
      }),
    );
  }
}

/// تعديل ربط حساب واحد: أرقام البطاقة/الحساب · مرسل/كلمات رسالة البنك · تطبيق الإشعارات.
class AccountLinksEditPage extends StatelessWidget {
  final String accId;
  const AccountLinksEditPage({super.key, required this.accId});

  Widget _section(BuildContext c, Pal p, {required IconData icon, required String title, required String hint, required List<Widget> chips, required String addLabel, required VoidCallback onAdd}) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: iosCard(p, r: 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: kBlue, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700))]),
          const SizedBox(height: 4),
          Text(hint, style: TextStyle(fontSize: 13, color: p.ink2, height: 1.5)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ...chips,
            Tap(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: kBlue.withValues(alpha: .6))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_rounded, size: 16, color: kBlue), const SizedBox(width: 4), Text(addLabel, style: TextStyle(color: kBlue, fontSize: 13.5, fontWeight: FontWeight.w600))]),
              ),
            ),
          ]),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return _live((c) {
      final a = repo.account(accId);
      if (a == null) return PageShell(title: 'ربط الحساب', icon: Icons.credit_card_rounded, child: emptyState(p, Icons.credit_card_off_outlined, 'الحساب ده مش موجود.'));
      final t = smsTracker;
      final nums = [for (final e in t.cards.entries) if (e.value == accId) e.key]..sort();
      final senders = _senderPatterns(a);
      final myApps = [for (final e in t.notifApps.entries) if ((e.value['acc'] ?? '') == accId) e];
      return PageShell(
        title: a.name,
        icon: Icons.edit_outlined,
        iconColor: kBlue,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 40), physics: const BouncingScrollPhysics(), children: [
          _section(c, p,
              icon: Icons.credit_card_rounded,
              title: 'أرقام البطاقة / الحساب',
              hint: 'آخر ٤ أرقام كما تظهر في رسالة البنك. أي رسالة بنفس الرقم بتتسجل في الحساب ده.',
              chips: [for (final n in nums) _linkChip(p, '•••• $n', ltr: true, onDel: () => _removeCardFlow(c, n))],
              addLabel: 'إضافة رقم',
              onAdd: () => _addCardFlow(c, accId: accId)),
          _section(c, p,
              icon: Icons.sms_outlined,
              title: 'رسالة البنك (المرسل / كلمات)',
              hint: 'اسم المرسل أو كلمة بتظهر في رسايل الحساب ده (مثلًا Telda).',
              chips: [for (final w in senders) _linkChip(p, w, onDel: () => _removeSenderFlow(c, a, w))],
              addLabel: 'إضافة مرسل',
              onAdd: () => _addSenderFlow(c, accId: accId)),
          _section(c, p,
              icon: Icons.notifications_none_rounded,
              title: 'تطبيق الإشعارات',
              hint: 'إشعارات تطبيق البنك دي بتتسجل مباشرة في الحساب ده.',
              chips: [
                for (final e in myApps)
                  _linkChip(p, e.value['name'] ?? e.key, onDel: () async {
                    if (await confirmDialog(c, 'إزالة التطبيق', 'CashU هيبطل يقرأ إشعارات «${e.value['name']}».', ok: 'إزالة')) await smsTracker.removeNotifApp(e.key);
                  }),
              ],
              addLabel: 'إضافة تطبيق',
              onAdd: () => _addAppFlow(c, accId: accId)),
        ]),
      );
    });
  }
}

// =====================================================================
//  1) الشاشة الرئيسية: «التتبع التلقائي»
// =====================================================================
class SmsTrackingPage extends StatelessWidget {
  const SmsTrackingPage({super.key});

  Widget _option(Pal p, {required IconData icon, required Color color, required String title, required String sub, required VoidCallback onTap, bool on = false}) => Tap(
        scale: .985,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: iosCard(p, r: 26),
          child: Row(children: [
            Container(width: 66, height: 66, decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(20)), child: Icon(icon, color: color, size: 34)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(title, style: const TextStyle(fontSize: 18.5, fontWeight: FontWeight.w800, height: 1.3))),
                if (on) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: kGreen.withValues(alpha: .16), borderRadius: BorderRadius.circular(10)), child: Text('مفعّل', style: TextStyle(fontSize: 11.5, color: kGreen, fontWeight: FontWeight.w700)))],
              ]),
              const SizedBox(height: 6),
              Text(sub, style: TextStyle(fontSize: 14, color: p.ink2, height: 1.5)),
            ])),
            Icon(Icons.chevron_right_rounded, color: p.ink2),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: 'التتبع التلقائي',
      icon: Icons.sms_rounded,
      iconColor: kBlue,
      child: _live((c) {
        final t = smsTracker;
        return ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 40), physics: const BouncingScrollPhysics(), children: [
          const Padding(padding: EdgeInsets.fromLTRB(4, 0, 4, 16), child: Text('البنك بيعرّفك إزاي لما تشتري حاجة؟', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.35))),
          _option(p, icon: Icons.sms_rounded, color: const Color(0xFF34A853), title: 'بنكي بيبعت SMS', sub: 'CIB وQNB والأهلي وأغلب البنوك هنا.', on: t.enabled, onTap: () => Navigator.of(c).push(flowRoute(const SmsAutoPage()))),
          _option(p, icon: Icons.notifications_active_rounded, color: const Color(0xFF2F7FA3), title: 'تطبيق البنك بيبعت إشعارات', sub: 'فوري وتيلدا وKlivvr وRevolut وWise وMonzo.', on: t.trackNotifs, onTap: () => Navigator.of(c).push(flowRoute(const NotifTrackPage()))),
          Padding(padding: const EdgeInsets.fromLTRB(6, 4, 6, 0), child: Text('لو البنك بيبعت SMS وإشعار مع بعض، اختار واحد بس. الاتنين هيسجّلوا كل عملية مرتين.', style: TextStyle(fontSize: 14, color: p.ink2, height: 1.55))),
          const SizedBox(height: 18),
          Container(
            decoration: iosCard(p, r: 22),
            child: Column(children: [
              _row(p, icon: Icons.credit_card_rounded, title: 'البطاقات والحسابات', sub: '${toAr('${t.cards.length}')} رقم · ${toAr('${t.notifApps.length}')} تطبيق — اربط أرقام ورسائل وتطبيق كل حساب', onTap: () => Navigator.of(c).push(flowRoute(const LinkedAccountsPage()))),
              _row(p, icon: Icons.visibility_off_outlined, title: 'البطاقات المتجاهلة', sub: t.ignoredNums.isEmpty && t.ignoredTexts.isEmpty ? 'أرقام ونصوص مخفية من التتبع التلقائي' : '${toAr('${t.ignoredNums.length}')} رقم · ${toAr('${t.ignoredTexts.length}')} نص', onTap: () => Navigator.of(c).push(flowRoute(const IgnoredCardsPage())), last: true),
            ]),
          ),
          if (t.unlinked.isNotEmpty) ...[
            const SizedBox(height: 18),
            _UnlinkedBanner(count: t.unlinked.length),
          ],
        ]);
      }),
    );
  }
}

/// تنبيه «في أرقام جديدة محتاجة تربطها بحساب».
class _UnlinkedBanner extends StatelessWidget {
  final int count;
  const _UnlinkedBanner({required this.count});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Tap(
      scale: .985,
      onTap: () => Navigator.of(context).push(flowRoute(const UnlinkedNumbersPage())),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: kBlue.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Icon(Icons.credit_card_rounded, color: kBlue),
          const SizedBox(width: 12),
          Expanded(child: Text('${toAr('$count')} ${count > 2 ? 'أرقام' : 'رقم'} من الرسائل مش مربوطة بحساب — اضغط تربطها', style: TextStyle(fontSize: 14, color: p.ink, height: 1.4))),
          Icon(Icons.chevron_right_rounded, color: p.ink2),
        ]),
      ),
    );
  }
}

// =====================================================================
//  2) «التتبع التلقائي للرسائل» (SMS)
// =====================================================================
class SmsAutoPage extends StatelessWidget {
  const SmsAutoPage({super.key});

  Future<void> _toggle(BuildContext c, bool v) async {
    final ok = await smsTracker.setEnabled(v);
    if (!c.mounted) return;
    if (v && !ok) {
      toast(c, 'لم تُمنح صلاحية الرسائل. إن كان التطبيق مثبّتًا من ملف APK: افتح معلومات التطبيق ← ⋮ ← «السماح بالإعدادات المقيّدة» ثم أعد المحاولة.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: 'التتبع التلقائي للرسائل',
      icon: Icons.sms_rounded,
      iconColor: kBlue,
      child: _live((c) {
        final t = smsTracker;
        final rv = t.review.length;
        final unk = t.unlinked.length;
        return ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 40), physics: const BouncingScrollPhysics(), children: [
          _enableCard(p, label: 'تتبع الرسائل النصية', on: t.enabled, onChanged: (v) => _toggle(c, v)),
          const SizedBox(height: 14),
          Container(
            decoration: iosCard(p, r: 22),
            child: _row(p, icon: Icons.cloud_download_outlined, title: 'استيراد الرسائل السابقة', sub: 'افحص صندوق الوارد وحوّل رسائل البنك القديمة إلى مصروفات', last: true, onTap: () => Navigator.of(c).push(flowRoute(const ImportPastPage()))),
          ),
          sectionLabel(p, 'أدوات التتبع'),
          Container(
            decoration: iosCard(p, r: 22),
            child: Column(children: [
              _row(p, icon: Icons.credit_card_rounded, title: 'أرقام من الرسائل', sub: unk == 0 ? 'كل الأرقام مربوطة بحسابات' : '${toAr('$unk')} ${unk > 2 ? 'أرقام' : 'رقم'} مش مربوط بحساب',
                  trailing: unk == 0 ? null : Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(12)), child: Text(toAr('$unk'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                  onTap: () => Navigator.of(c).push(flowRoute(const UnlinkedNumbersPage()))),
              _row(p, icon: Icons.fact_check_rounded, title: 'مراجعة الرسائل', sub: rv == 0 ? 'لا شيء للمراجعة' : '${toAr('$rv')} عملية',
                  trailing: rv == 0 ? null : Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(12)), child: Text(toAr('$rv'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                  onTap: () => Navigator.of(c).push(flowRoute(const SmsReviewPage()))),
              if (t.lastScan != null) _row(p, icon: Icons.manage_search_rounded, title: 'نتيجة آخر فحص', sub: '${toAr('${t.lastScan!.items.length}')} رسالة مالية · ${toAr('${t.lastScan!.count(SmsStatus.fresh) + t.lastScan!.count(SmsStatus.pending)}')} غير مسجّلة', onTap: () => Navigator.of(c).push(flowRoute(const SmsScanPage()))),
              _row(p, icon: Icons.label_rounded, title: 'الكلمات المتابعة والرسائل', sub: 'كل الكلمات حسب نوع العملية والكلمات المستبعدة، وجرّب رسالة قبل ما تتسجل', onTap: () => Navigator.of(c).push(flowRoute(const SmsWordsPage()))),
              _row(p, icon: Icons.auto_awesome_rounded, title: 'تحليل بالذكاء الاصطناعي', sub: sync.user == null ? 'يحتاج تسجيل دخول' : 'يصنّف المعاملة (أكل، تسوق، …) قبل تسجيلها',
                  trailing: Switch(value: t.aiEnabledFlag, activeTrackColor: kBlue, activeThumbColor: Colors.white, onChanged: (v) => t.setAi(v)), onTap: () => t.setAi(!t.aiEnabledFlag)),
              _row(p, icon: Icons.notifications_active_rounded, title: 'إشعار عند كل عملية', sub: 'إشعار عند تسجيل أي معاملة جديدة',
                  trailing: Switch(value: t.notifyOn, activeTrackColor: kBlue, activeThumbColor: Colors.white, onChanged: (v) => t.setNotify(v)), onTap: () => t.setNotify(!t.notifyOn), last: true),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 18, 8, 0),
            child: Text('كل معاملة بتتسجل تلقائيًا في الحساب اللي رقم بطاقته/حسابه أو اسم مرسله مطابق للرسالة (والبطاقات والحسابات في صفحة «التتبع التلقائي»). لو الرقم جديد بتتسجل على حسابك الافتراضي لحد ما تربطه. الرسائل تُقرأ على هاتفك فقط ولا تُرسل نصًا إلى أي خادم، ورموز التحقق تُتجاهل ولا تُحفظ.', style: TextStyle(fontSize: 13, color: p.ink2, height: 1.5)),
          ),
          const SizedBox(height: 14),
          _privacyNote(p),
        ]);
      }),
    );
  }
}

// =====================================================================
//  3) «إشعارات البنك»: تتبع إشعارات تطبيقات بنوك مختارة فقط
// =====================================================================
class NotifTrackPage extends StatefulWidget {
  const NotifTrackPage({super.key});
  @override
  State<NotifTrackPage> createState() => _NotifTrackState();
}

class _NotifTrackState extends State<NotifTrackPage> with WidgetsBindingObserver {
  bool? access;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final a = await smsTracker.notifAccess();
    if (mounted) setState(() => access = a);
  }

  Future<void> _addApp(BuildContext c) async {
    final app = await Navigator.of(c).push<({String name, String pkg})>(sheetRoute(const _PickAppPage()));
    if (app == null || !c.mounted) return;
    final acc = await _chooseAccount(c);
    if (acc == null) return;
    await smsTracker.addNotifApp(app.pkg, app.name, acc);
    if (!smsTracker.trackNotifs) await smsTracker.setTrackNotifs(true);
  }

  Future<void> _changeAcc(BuildContext c, String pkg, String current) async {
    final acc = await _chooseAccount(c, current: current);
    if (acc != null) await smsTracker.setNotifAppAcc(pkg, acc);
  }

  Future<void> _remove(BuildContext c, String pkg, String name) async {
    if (await confirmDialog(c, 'إزالة التطبيق', 'CashU هيبطل يقرأ إشعارات «$name». المعاملات اللي اتسجّلت قبل كده مش هتتأثر.', ok: 'إزالة')) {
      await smsTracker.removeNotifApp(pkg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: 'إشعارات البنك',
      icon: Icons.notifications_active_rounded,
      iconColor: kBlue,
      child: _live((c) {
        final t = smsTracker;
        final apps = t.notifApps;
        return ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 40), physics: const BouncingScrollPhysics(), children: [
          _enableCard(p,
              label: 'تتبّع الإشعارات',
              on: t.trackNotifs,
              onChanged: (v) => t.setTrackNotifs(v),
              desc: 'بيقرأ الإشعارات اللي تطبيق البنك بيبعتها أصلاً ويسجّل كل عملية شراء.',
              extra: apps.isEmpty ? 'لسه ماوصلش إشعار من تطبيقات البنك' : null),
          const SizedBox(height: 14),
          Tap(
            scale: .99,
            onTap: access == true ? null : () => smsTracker.openNotifAccess(),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: iosCard(p, r: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('الوصول للإشعارات', style: TextStyle(fontSize: 14, color: p.ink2)),
                const SizedBox(height: 4),
                Text(access == true ? 'مسموح' : 'غير مسموح — اضغط للتفعيل', style: TextStyle(fontSize: access == true ? 26 : 19, fontWeight: FontWeight.w800, color: access == false ? kOrange : null)),
                const SizedBox(height: 10),
                Text('أندرويد بيطلب ده مرة واحدة من إعدادات النظام. CashU بيقرأ إشعارات التطبيقات اللي تختارها تحت بس.', style: TextStyle(fontSize: 14.5, color: p.ink2, height: 1.55)),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Text('تطبيقات البنوك', style: TextStyle(fontSize: 17, color: p.ink2, fontWeight: FontWeight.w700)),
            const Spacer(),
            Tap(onTap: () => _addApp(c), child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('أضف تطبيق', style: TextStyle(color: kBlue, fontSize: 17, fontWeight: FontWeight.w600)))),
          ]),
          const SizedBox(height: 8),
          if (apps.isEmpty)
            Container(padding: const EdgeInsets.all(18), decoration: iosCard(p, r: 22), child: Text('مفيش تطبيقات لسه. أضف التطبيق اللي بيبعتلك إشعار مع كل عملية.', style: TextStyle(fontSize: 15.5, color: p.ink, height: 1.55)))
          else
            for (final e in apps.entries)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: iosCard(p, r: 22),
                child: Row(children: [
                  Container(width: 50, height: 50, decoration: BoxDecoration(color: kBlue.withValues(alpha: .12), borderRadius: BorderRadius.circular(15)), child: Icon(Icons.notifications_rounded, color: kBlue)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.value['name']!, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Tap(
                        onTap: () => _changeAcc(c, e.key, e.value['acc']!),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('الحساب: ', style: TextStyle(fontSize: 14.5, color: p.ink2)),
                          Flexible(child: Text(e.value['acc']!.isEmpty || repo.account(e.value['acc']!) == null ? 'الحساب الافتراضي' : _accName(e.value['acc']!), style: TextStyle(fontSize: 15, color: kBlue, fontWeight: FontWeight.w600))),
                          Icon(Icons.chevron_right_rounded, size: 18, color: kBlue),
                        ]),
                      ),
                    ]),
                  ),
                  Tap(onTap: () => _remove(c, e.key, e.value['name']!), child: Container(width: 34, height: 34, decoration: BoxDecoration(color: p.ink2.withValues(alpha: .25), shape: BoxShape.circle), child: Icon(Icons.close_rounded, size: 18, color: p.ink2))),
                ]),
              ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
            child: Text('نص الإشعارات دي بس هو اللي بيوصل لـ CashU عشان يقرأ المبلغ والتاجر. مفيش حاجة تانية على موبايلك بتتقري، ومفيش أي إشعار تاني بيتلقط.', style: TextStyle(fontSize: 13.5, color: p.ink2, height: 1.55)),
          ),
        ]);
      }),
    );
  }
}

/// «اختار تطبيق البنك»: بحث في التطبيقات المثبّتة.
class _PickAppPage extends StatefulWidget {
  const _PickAppPage();
  @override
  State<_PickAppPage> createState() => _PickAppState();
}

class _PickAppState extends State<_PickAppPage> {
  List<({String name, String pkg})>? apps;
  String q = '';

  @override
  void initState() {
    super.initState();
    smsTracker.installedApps().then((l) {
      if (mounted) setState(() => apps = l);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final taken = smsTracker.notifApps.keys.toSet();
    final nq = q.trim().toLowerCase();
    final shown = [
      for (final a in apps ?? const <({String name, String pkg})>[])
        if (!taken.contains(a.pkg) && (nq.isEmpty || a.name.toLowerCase().contains(nq) || a.pkg.toLowerCase().contains(nq))) a,
    ];
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(children: [
              Tap(onTap: () => Navigator.of(context).pop(), child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.close_rounded, color: p.ink, size: 28))),
              const Expanded(child: Center(child: Text('اختار تطبيق البنك', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)))),
              const SizedBox(width: 44),
            ]),
          ),
          hair(p),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22), border: Border.all(color: p.line)),
              child: Row(children: [
                Icon(Icons.search_rounded, color: p.ink2),
                const SizedBox(width: 10),
                Expanded(child: TextField(autofocus: true, onChanged: (v) => setState(() => q = v), style: const TextStyle(fontSize: 18), decoration: InputDecoration(border: InputBorder.none, hintText: tl('ابحث عن التطبيق'), hintStyle: TextStyle(color: p.ink2)))),
              ]),
            ),
          ),
          Expanded(
            child: apps == null
                ? const Center(child: CircularProgressIndicator())
                : shown.isEmpty
                    ? Center(child: Text('مفيش تطبيقات مطابقة', style: TextStyle(color: p.ink2, fontSize: 16)))
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 30),
                        itemCount: shown.length,
                        separatorBuilder: (_, __) => hair(p),
                        itemBuilder: (c, i) {
                          final a = shown[i];
                          return Tap(
                            scale: .99,
                            onTap: () => Navigator.of(context).pop(a),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(a.name, style: const TextStyle(fontSize: 19)),
                                const SizedBox(height: 2),
                                Text(a.pkg, textDirection: TextDirection.ltr, style: TextStyle(fontSize: 14, color: p.ink2)),
                              ]),
                            ),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}

// =====================================================================
//  4) «أرقام من الرسائل» + «اربط الرقم ده»
// =====================================================================
class UnlinkedNumbersPage extends StatelessWidget {
  const UnlinkedNumbersPage({super.key});

  Future<void> _dismiss(BuildContext c, String l4) async {
    if (await confirmDialog(c, 'تجاهل الرقم', 'أي رسالة فيها الرقم •••• $l4 هتتجاهل ومش هتتسجل. تقدر ترجّعه من «البطاقات المتجاهلة». المعاملات اللي اتسجلت قبل كده مش هتتأثر.', ok: 'تجاهل')) {
      smsTracker.dismissNumber(l4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: 'أرقام من الرسائل',
      icon: Icons.credit_card_rounded,
      iconColor: kBlue,
      child: _live((c) {
        final l = smsTracker.unlinked;
        return ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 40), physics: const BouncingScrollPhysics(), children: [
          Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 16), child: Text('الأرقام دي ظهرت في رسائل البنك ومش مربوطة بأي حساب لسه. مصاريفها بتتسجل على حسابك الافتراضي.', style: TextStyle(fontSize: 15.5, color: p.ink2, height: 1.6))),
          if (l.isEmpty) Padding(padding: const EdgeInsets.only(top: 60), child: Center(child: Text('كل الأرقام مربوطة ✓', style: TextStyle(color: p.ink2, fontSize: 16)))),
          for (final e in l)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Tap(
                scale: .985,
                onTap: () => Navigator.of(c).push(flowRoute(LinkNumberPage(l4: '${e['l4']}'))),
                child: Row(children: [
                  Container(width: 56, height: 56, decoration: BoxDecoration(color: kBlue.withValues(alpha: .1), borderRadius: BorderRadius.circular(18)), child: Icon(Icons.credit_card_rounded, color: p.ink2, size: 28)),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${e['l4']} ••••', textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('اضغط عشان تختار مكانها', style: TextStyle(fontSize: 14.5, color: p.ink2)),
                  ]),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, color: p.ink2.withValues(alpha: .6)),
                  const SizedBox(width: 8),
                  Tap(onTap: () => _dismiss(c, '${e['l4']}'), child: Container(width: 48, height: 48, decoration: BoxDecoration(color: p.field, shape: BoxShape.circle), child: Icon(Icons.close_rounded, color: p.ink2))),
                ]),
              ),
            ),
        ]);
      }),
    );
  }
}

class LinkNumberPage extends StatelessWidget {
  final String l4;
  const LinkNumberPage({super.key, required this.l4});

  Future<void> _link(BuildContext c, String accId) async {
    final txs = smsTracker.unlinkedTxs(l4).where((t) => t.acc != accId).toList();
    var move = false;
    if (txs.isNotEmpty) {
      final r = await showDialog<bool>(
        context: c,
        builder: (ctx) => AlertDialog(
          title: const Text('ننقل المعاملات السابقة؟'),
          content: Text('${toAr('${txs.length}')} ${txs.length > 2 ? 'معاملات' : 'معاملة'} جت على الرقم ده. ننقلهم كمان لـ ${_accName(accId)}؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('اربطه بس')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('انقلهم')),
          ],
        ),
      );
      if (r == null) return;
      move = r;
    }
    final n = smsTracker.linkNumber(l4, accId, move: move);
    if (!c.mounted) return;
    toast(c, move && n > 0 ? 'اتربط •••• $l4 بـ ${_accName(accId)} واتنقلت ${toAr('$n')} معاملة' : 'اتربط •••• $l4 بـ ${_accName(accId)}');
    Navigator.of(c).pop();
  }

  Future<void> _newAccount(BuildContext c) async {
    final id = await _createAccount(c);
    if (id == null || !c.mounted) return;
    await _link(c, id);
  }

  Widget _msg(Pal p, Map<String, dynamic> e) {
    final body = '${e['body'] ?? ''}';
    final i = normDigits(body).indexOf(l4);
    final base = TextStyle(fontSize: 16, color: p.ink, height: 1.7);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(20)),
      child: i < 0
          ? Text(body, style: base)
          : RichText(
              text: TextSpan(style: base, children: [
                TextSpan(text: body.substring(0, i)),
                TextSpan(text: body.substring(i, i + l4.length), style: const TextStyle(backgroundColor: Color(0xFFFFE9A0), color: Colors.black, fontWeight: FontWeight.w700)),
                TextSpan(text: body.substring(i + l4.length)),
              ]),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: _live((c) {
          final e = smsTracker.unlinkedOf(l4);
          final txs = smsTracker.unlinkedTxs(l4);
          final cards = smsTracker.cards;
          final defName = _accName(txs.isEmpty ? repo.defaultAcc : txs.first.acc);
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Row(children: [
                Tap(onTap: () => Navigator.of(context).pop(), child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.close_rounded, color: p.ink, size: 28))),
                const Expanded(child: Center(child: Text('اربط الرقم ده', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)))),
                const SizedBox(width: 44),
              ]),
            ),
            hair(p),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 30), physics: const BouncingScrollPhysics(), children: [
                Text('•••• $l4 تبع أنهي حساب؟', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text('البطاقة دي ظهرت في رسالة بس مش مضافة على أي حساب. غالبًا بتكون بطاقة تانية، أو بطاقة Apple Pay، أو نفس البطاقة بشكل مختلف.', style: TextStyle(fontSize: 15.5, color: p.ink2, height: 1.6)),
                if (e != null) ...[
                  const SizedBox(height: 20),
                  Text('اللي البنك بعته', style: TextStyle(fontSize: 15, color: p.ink2, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _msg(p, e),
                ],
                if (txs.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(children: [
                    Icon(Icons.swap_horiz_rounded, color: kBlue),
                    const SizedBox(width: 10),
                    Expanded(child: Text('${toAr('${txs.length}')} ${txs.length > 2 ? 'معاملات' : 'معاملة'} سابقة جت على الرقم ده، ومتسجلة على $defName.', style: TextStyle(fontSize: 14.5, color: p.ink2, height: 1.5))),
                  ]),
                ],
                const SizedBox(height: 18),
                for (final a in repo.accList)
                  Tap(
                    scale: .985,
                    onTap: () => _link(c, a.id),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: iosCard(p, r: 22),
                      child: Row(children: [
                        accIcon(a, size: 54),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(a.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Builder(builder: (_) {
                              final nums = [for (final x in cards.entries) if (x.value == a.id) x.key];
                              return Text(nums.isEmpty ? 'مفيش رقم بطاقة أو حساب لسه' : nums.map((n) => '$n ••••').join('  '), textDirection: nums.isEmpty ? null : TextDirection.ltr, style: TextStyle(fontSize: 15, color: p.ink2));
                            }),
                          ]),
                        ),
                        Icon(Icons.chevron_right_rounded, color: p.ink2),
                      ]),
                    ),
                  ),
                Tap(
                  scale: .985,
                  onTap: () => _newAccount(c),
                  child: Container(
                    height: 74,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: kBlue.withValues(alpha: .1), borderRadius: BorderRadius.circular(22)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_circle_outline_rounded, color: kBlue), const SizedBox(width: 10), Text('ده حساب جديد', style: TextStyle(color: kBlue, fontSize: 19, fontWeight: FontWeight.w700))]),
                  ),
                ),
              ]),
            ),
          ]);
        }),
      ),
    );
  }
}

// =====================================================================
//  5) «البطاقات المتجاهلة» (أرقام + نصوص)
// =====================================================================
class IgnoredCardsPage extends StatefulWidget {
  const IgnoredCardsPage({super.key});
  @override
  State<IgnoredCardsPage> createState() => _IgnoredCardsState();
}

class _IgnoredCardsState extends State<IgnoredCardsPage> {
  final numCtl = TextEditingController();
  final txt = TextEditingController();

  @override
  void dispose() {
    numCtl.dispose();
    txt.dispose();
    super.dispose();
  }

  Widget _addField(Pal p, TextEditingController ctl, String hint, VoidCallback onAdd, {bool number = false}) => Row(children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.line)),
            child: TextField(
              controller: ctl,
              keyboardType: number ? TextInputType.number : TextInputType.text,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => onAdd(),
              style: const TextStyle(fontSize: 17),
              decoration: InputDecoration(border: InputBorder.none, hintText: tl(hint), hintStyle: TextStyle(color: p.ink2, fontSize: 15.5)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Tap(
          onTap: ctl.text.trim().isEmpty ? null : onAdd,
          child: Container(width: 96, height: 56, alignment: Alignment.center, decoration: BoxDecoration(color: kBlue.withValues(alpha: ctl.text.trim().isEmpty ? .35 : 1), borderRadius: BorderRadius.circular(18)), child: const Text('إضافة', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700))),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: 'البطاقات المتجاهلة',
      icon: Icons.visibility_off_outlined,
      iconColor: kBlue,
      trailing: Tap(onTap: () => Navigator.of(context).pop(), child: Container(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12), decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(16)), child: const Text('تم', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)))),
      child: _live((c) {
        final t = smsTracker;
        return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), physics: const BouncingScrollPhysics(), children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: kBlue.withValues(alpha: .08), borderRadius: BorderRadius.circular(22), border: Border.all(color: kBlue.withValues(alpha: .18))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(Icons.visibility_off_outlined, color: kBlue), const SizedBox(width: 10), Text('مخفية من التتبع التلقائي', style: TextStyle(color: kBlue, fontSize: 17, fontWeight: FontWeight.w700))]),
              const SizedBox(height: 10),
              Text('افتح رسالة بنكية لا تريد تتبعها وانسخ أرقام البطاقة أو الحساب الظاهرة بها (مثل "بطاقة تنتهي بـ 1234" أو رقم حساب). سيتم تجاهل أي رسالة قادمة تخص هذه الأرقام — ولن يتم حفظ أي شيء.', style: TextStyle(fontSize: 15, color: p.ink2, height: 1.65)),
            ]),
          ),
          const SizedBox(height: 22),
          const Text('أضف أرقام بطاقة أو حساب', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _addField(p, numCtl, 'مثال: 123 أو 1234 أو رقم الحساب', () {
            if (!t.addIgnoredNum(numCtl.text)) {
              toast(c, 'اكتب ٣ أرقام على الأقل');
              return;
            }
            numCtl.clear();
            setState(() {});
          }, number: true),
          const SizedBox(height: 8),
          Text('أدخل رقم البطاقة أو الحساب كما يظهر تمامًا في الرسالة. نتجاهل الرسالة فقط عند التطابق التام للرقم.', style: TextStyle(fontSize: 13.5, color: p.ink2, height: 1.6)),
          if (t.ignoredNums.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [for (final n in t.ignoredNums) _chip(p, n, () => t.removeIgnoredNum(n))]),
          ],
          const SizedBox(height: 18),
          hair(p),
          const SizedBox(height: 18),
          const Text('تجاهل حسب النص', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('تجاهل أي رسالة بنك فيها كلمة أو جملة معينة. استخدمه للرسايل اللي مفيهاش رقم كارت أو حساب، فمتقدرش تتجاهلها بالرقم.', style: TextStyle(fontSize: 15, color: p.ink2, height: 1.65)),
          const SizedBox(height: 18),
          const Text('ضيف كلمة أو جملة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _addField(p, txt, 'مثلاً: Platinum Card, CIB, تم تحو', () {
            t.addIgnoredText(txt.text);
            txt.clear();
            setState(() {});
          }),
          const SizedBox(height: 8),
          Text('أساساً للكارت اللي رسايله مفيهاش رقم كارت أو حساب. الصق الكلمة أو الجملة بالظبط زي ما بتظهر في الرسالة. أي رسالة جاية فيها الكلمة دي هتتجاهل. الحروف الكبيرة والمسافات مش فارقة.', style: TextStyle(fontSize: 13.5, color: p.ink2, height: 1.7)),
          if (t.ignoredTexts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [for (final x in t.ignoredTexts) _chip(p, x, () => t.removeIgnoredText(x))]),
          ],
        ]);
      }),
    );
  }
}

// =====================================================================
//  6) «استيراد الرسائل السابقة»
// =====================================================================
enum _Phase { loading, preview, running, done }

class ImportPastPage extends StatefulWidget {
  const ImportPastPage({super.key});
  @override
  State<ImportPastPage> createState() => _ImportPastState();
}

class _ImportPastState extends State<ImportPastPage> {
  _Phase phase = _Phase.loading;
  int days = 90;
  ImportPreview? pv;
  final Set<String> off = {};
  bool keep = true;
  int done = 0, total = 0;
  bool _cancel = false;
  ImportResult? res;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => phase = _Phase.loading);
    if (!await smsTracker.hasPermission()) await smsTracker.requestPermission();
    final r = await smsTracker.previewImport(days: days);
    if (!mounted) return;
    setState(() {
      pv = r;
      off.clear();
      phase = _Phase.preview;
    });
  }

  List<Map<String, dynamic>> get _selected => [for (final m in pv?.messages ?? const <Map<String, dynamic>>[]) if (!off.contains('${m['sender']}')) m];

  Future<void> _start() async {
    final msgs = _selected;
    if (msgs.isEmpty) return;
    _cancel = false;
    setState(() {
      phase = _Phase.running;
      done = 0;
      total = msgs.length;
    });
    final r = await smsTracker.runImport(msgs, keepBalances: keep, onProgress: (d, t) {
      if (mounted) setState(() {
        done = d;
        total = t;
      });
    }, cancelled: () => _cancel);
    if (!mounted) return;
    setState(() {
      res = r;
      phase = _Phase.done;
    });
  }

  Widget _card(Pal p, Widget child) => Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(20), decoration: iosCard(p, r: 24), child: child);

  Widget _chipDays(Pal p, int d, String t) => Tap(
        onTap: () {
          if (days == d) return;
          days = d;
          _load();
        },
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: days == d ? kBlue : p.field, borderRadius: BorderRadius.circular(18)), child: Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: days == d ? Colors.white : p.ink2))),
      );

  Widget _radio(Pal p, bool on, String title, String sub, VoidCallback f) => Tap(
        scale: .99,
        onTap: f,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 2), child: Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, color: on ? kBlue : p.ink2, size: 28)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(sub, style: TextStyle(fontSize: 14, color: p.ink2, height: 1.5)),
            ])),
          ]),
        ),
      );

  Widget _preview(Pal p) {
    final r = pv;
    if (r == null) return const SizedBox.shrink();
    if (r.error != null) {
      return ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 40), children: [
        _card(p, Column(children: [
          Text(r.error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.6)),
          const SizedBox(height: 14),
          _pill(p, 'إعادة المحاولة', _load, h: 48),
        ])),
      ]);
    }
    final sel = _selected.length;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 40), physics: const BouncingScrollPhysics(), children: [
      _card(p, Column(children: [
        Text('تم العثور على ${r.messages.length} رسالة بنكية', textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.35)),
        const SizedBox(height: 10),
        Text('راجع المرسلين ثم ابدأ الاستيراد. الرسائل غير المالية (رموز التحقق والعروض) ستُستبعد تلقائيًا أثناء الاستيراد.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: p.ink2, height: 1.6)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [_chipDays(p, 30, '٣٠ يوم'), _chipDays(p, 90, '٣ شهور'), _chipDays(p, 180, '٦ شهور'), _chipDays(p, 365, 'سنة')]),
      ])),
      _card(p, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('من', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final e in r.bySender)
          Tap(
            scale: .99,
            onTap: () => setState(() => off.contains(e.key) ? off.remove(e.key) : off.add(e.key)),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line.withValues(alpha: .6), width: .6))),
              child: Row(children: [
                Icon(off.contains(e.key) ? Icons.radio_button_unchecked_rounded : Icons.check_circle_rounded, color: off.contains(e.key) ? p.ink2 : kBlue, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(e.key, textDirection: TextDirection.ltr, textAlign: TextAlign.right, style: TextStyle(fontSize: 18, color: off.contains(e.key) ? p.ink2 : p.ink))),
                Text('${e.value}', style: TextStyle(fontSize: 18, color: p.ink2)),
              ]),
            ),
          ),
      ])),
      _card(p, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('أرصدة حساباتك', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        _radio(p, keep, 'إبقاؤها كما هي (موصى به)', 'لقد ضبطت أرصدتك بالفعل — لن يغيّرها استيراد السجل.', () => setState(() => keep = true)),
        _radio(p, !keep, 'إعادة الحساب من المعاملات المستوردة', 'استخدم هذا إذا لم تضبط أرصدتك من قبل أو كانت قديمة.', () => setState(() => keep = false)),
      ])),
      _pill(p, sel == 0 ? 'اختر مرسلًا واحدًا على الأقل' : 'استيراد $sel رسالة', sel == 0 ? null : _start, h: 60),
    ]);
  }

  Widget _running(Pal p) => ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 40), children: [
        _card(p, Column(children: [
          const Text('جارٍ الاستيراد...', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text('تتم معالجة كل رسالة محليًا على الجهاز. أبقِ التطبيق مفتوحًا — يمكنك الإلغاء في أي وقت.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: p.ink2, height: 1.6)),
          const SizedBox(height: 18),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: total == 0 ? null : done / total, minHeight: 12, backgroundColor: p.field, color: kBlue)),
          const SizedBox(height: 12),
          Text('تمت معالجة $done من $total', style: TextStyle(fontSize: 15, color: p.ink2)),
        ])),
        const SizedBox(height: 6),
        Center(child: Tap(onTap: () => setState(() => _cancel = true), child: Padding(padding: const EdgeInsets.all(14), child: Text(_cancel ? 'جارٍ الإلغاء...' : 'إلغاء', style: TextStyle(fontSize: 17, color: p.ink2))))),
      ]);

  Widget _stat(Pal p, String label, int n, {Color? color}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line.withValues(alpha: .6), width: .6))),
        child: Row(children: [
          Text(label, style: TextStyle(fontSize: 17, color: p.ink2)),
          const Spacer(),
          Text('$n', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
        ]),
      );

  Widget _done(Pal p) {
    final r = res!;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 40), physics: const BouncingScrollPhysics(), children: [
      _card(p, Column(children: [
        Container(width: 64, height: 64, decoration: BoxDecoration(color: kGreen, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: Colors.white, size: 40)),
        const SizedBox(height: 14),
        Text(r.cancelled ? 'تم إيقاف الاستيراد' : 'اكتمل الاستيراد', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        _stat(p, 'معاملات أضيفت', r.added, color: kGreen),
        _stat(p, 'تم تخطيها (ليست معاملات)', r.skipped),
        _stat(p, 'مستوردة من قبل', r.already),
        if (r.review > 0) _stat(p, 'في المراجعة (محتاجة قرارك)', r.review, color: kOrange),
        const SizedBox(height: 14),
        Text(r.added == 0 ? '' : (keep ? 'بقيت أرصدتك كما كانت.' : 'تم حساب الأرصدة من المعاملات المستوردة.'), style: TextStyle(fontSize: 15, color: p.ink2)),
      ])),
      if (r.unlinked > 0)
        _card(p, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.credit_card_rounded, color: kBlue), const SizedBox(width: 10), Expanded(child: Text('وجدنا ${r.unlinked} ${r.unlinked > 2 ? 'أرقام' : 'رقم'} بطاقات في رسائلك', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)))]),
          const SizedBox(height: 8),
          Text('تم حفظ هذه المعاملات في حسابك الافتراضي مؤقتًا. أنشئ حسابًا لكل بطاقة وسينقل CashU معاملاتها إليه.', style: TextStyle(fontSize: 15, color: p.ink2, height: 1.6)),
          const SizedBox(height: 14),
          _pill(p, 'إعداد الحسابات', () => Navigator.of(context).pushReplacement(flowRoute(const UnlinkedNumbersPage())), h: 52),
        ])),
      Center(child: Tap(onTap: () => Navigator.of(context).pop(), child: Padding(padding: const EdgeInsets.all(16), child: Text('تم', style: TextStyle(fontSize: 18, color: p.ink2))))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: 'استيراد الرسائل السابقة',
      icon: Icons.cloud_download_outlined,
      iconColor: kBlue,
      swipeBack: phase != _Phase.running,
      child: switch (phase) {
        _Phase.loading => const Center(child: CircularProgressIndicator()),
        _Phase.preview => _preview(p),
        _Phase.running => _running(p),
        _Phase.done => _done(p),
      },
    );
  }
}
