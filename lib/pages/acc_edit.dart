import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import '../core/currency.dart';
import '../core/groups.dart';
import '../core/models.dart';
import '../core/i18n.dart';
import '../core/icon_pick.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/util.dart';
import '../ui/anim.dart';
import '../ui/icon_library.dart';
import '../ui/ios.dart';
import '../ui/sheets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

String kindTitle(String k) {
  switch (k) {
    case 'cash':
    case 'wallet':
      return 'Cash/Wallet Account';
    case 'credit':
      return 'Credit Card';
    case 'debit':
      return 'Debit Card';
    default:
      return 'Bank Account';
  }
}

/// إضافة / تعديل حساب بنفس شكل MoneyWiz.
class AccountEditPage extends StatefulWidget {
  final Account? edit;
  final String kind;
  final String? group;
  const AccountEditPage({super.key, this.edit, this.kind = 'cash', this.group});
  @override
  State<AccountEditPage> createState() => _AccountEditState();
}

class _AccountEditState extends State<AccountEditPage> {
  late final TextEditingController name = TextEditingController(text: widget.edit?.name ?? '');
  late final TextEditingController sms = TextEditingController(text: widget.edit?.sms ?? '');
  late bool showAvail = widget.edit?.showAvail ?? false;
  late int stmtDay = widget.edit?.stmtDay ?? 31;
  late String wkend = widget.edit?.wkend ?? 'none';
  late final TextEditingController last4 = TextEditingController(text: widget.edit?.last4 ?? '');
  late String kind = widget.edit?.kind ?? widget.kind;
  late String icon = widget.edit?.icon ?? '';
  late double start = widget.edit?.start ?? 0;
  late double limit = widget.edit?.limit ?? 0;
  late bool nw = widget.edit?.nw ?? true;
  late bool gb = widget.edit?.gb ?? true;
  late bool ac = widget.edit?.ac ?? true;
  late String grp = widget.edit?.grp ?? widget.group ?? '';
  int tab = 0;

  @override
  void dispose() {
    name.dispose();
    sms.dispose();
    last4.dispose();
    super.dispose();
  }

  Account get _tmp => widget.edit ?? Account(id: '', name: '', kind: kind);

  void _save() {
    if (name.text.trim().isEmpty) {
      toast(context, 'Enter an account name');
      return;
    }
    final a = widget.edit ?? Account(id: uid(), name: '');
    a.name = name.text.trim();
    a.kind = kind;
    a.icon = icon;
    a.start = start;
    a.limit = kind == 'credit' ? limit : 0;
    a.sms = kind == 'wallet' ? sms.text.trim() : '';
    a.showAvail = kind == 'credit' && showAvail;
    a.stmtDay = stmtDay;
    a.wkend = wkend;
    a.last4 = normDigits(last4.text.trim()).replaceAll(RegExp(r'[^0-9]'), '');
    a.nw = nw;
    a.gb = gb;
    a.ac = ac;
    a.grp = grp;
    repo.saveAccount(a);
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final a = widget.edit;
    if (a == null) return;
    if (await confirmDialog(context, 'Delete account', '"${a.name}" will be deleted. Its transactions stay in the history.')) {
      if (!repo.deleteAccount(a.id)) {
        if (mounted) toast(context, 'You cannot delete the last account');
        return;
      }
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _iconMenu() => showPillMenu(context, [
        ('Default', () => setState(() => icon = '')),
        ('Icon', () async {
          final r = await showIconLibrary(context, current: icon, title: 'أيقونة الحساب', resetLabel: 'الافتراضي');
          if (r != null && mounted) setState(() => icon = r);
        }),
        ("Icon from bank's website", () => soon(context, 'Bank icons')),
        ('Custom URL', () async {
          final r = await Navigator.of(context).push<String>(sheetRoute(CustomUrlPage(initial: icon.startsWith('http') ? icon : '')));
          if (r == null || !mounted) return;
          if (r.isEmpty) {
            setState(() => icon = '');
            return;
          }
          toast(context, tl('Downloading image...'));
          final d = await iconFromUrl(r);
          if (!mounted) return;
          if (d == null) {
            toast(context, tl('Could not download the image. The link will be used directly.'));
            setState(() => icon = r);
          } else {
            setState(() => icon = d);
          }
        }),
        ('Upload Image', () async {
          final d = await pickIconFromGallery();
          if (!mounted) return;
          if (d == null) return;
          setState(() => icon = d);
        }),
      ]);

  Widget _segment(Pal p) => Container(
        height: 46,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(23)),
        child: LayoutBuilder(builder: (c, bc) {
          final w = bc.maxWidth / 2;
          return Stack(children: [
            AnimatedPositionedDirectional(duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic, start: tab * w, top: 0, bottom: 0, width: w, child: Container(decoration: BoxDecoration(color: const Color(0xFF48484A), borderRadius: BorderRadius.circular(20)))),
            Row(children: [
              for (var i = 0; i < 2; i++) Expanded(child: Tap(scale: .97, onTap: () => setState(() => tab = i), child: Center(child: Text(i == 0 ? 'Basic' : 'Advanced', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))))),
            ]),
          ]);
        }),
      );

  Widget _basic(Pal p) {
    final a = widget.edit;
    return Container(
      decoration: iosCard(p),
      child: Column(children: [
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            Icon(Icons.badge_outlined, color: p.ink2, size: 22),
            const SizedBox(width: 12),
            Text('Account name', style: TextStyle(fontSize: 15, color: p.ink2)),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: name, textAlign: TextAlign.start, style: const TextStyle(fontSize: 16), decoration: const InputDecoration(border: InputBorder.none, isDense: true))),
          ]),
        ),
        hair(p, indent: 14),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            Icon(Icons.pin_outlined, color: p.ink2, size: 22),
            const SizedBox(width: 12),
            Text('Account number', style: TextStyle(fontSize: 15, color: p.ink2)),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: last4, maxLength: 4, keyboardType: TextInputType.number, textDirection: TextDirection.ltr, textAlign: TextAlign.right, style: const TextStyle(fontSize: 16), decoration: InputDecoration(border: InputBorder.none, isDense: true, counterText: '', hintText: '1234', hintStyle: TextStyle(color: p.ink2)))),
          ]),
        ),
        hair(p, indent: 14),
        FormRow(
          icon: Icons.gesture_rounded,
          label: 'Icon',
          onTap: _iconMenu,
          trailing: Padding(padding: const EdgeInsets.only(right: 2), child: accIcon(Account(id: 'x', name: '', kind: kind, icon: icon), size: 34)),
        ),
        if (kind == 'credit') ...[
          hair(p, indent: 14),
          FormRow(
            icon: Icons.credit_score_rounded,
            label: 'Credit limit',
            value: limit <= 0 ? 'Not set' : '${fixed2(limit)}  ${curOf(S.cur).sym}',
            onTap: () async {
              final r = await promptText(context, 'Credit limit (${curOf(S.cur).sym})', hint: '0.00', initial: limit == 0 ? '' : limit.toString(), number: true);
              if (r == null) return;
              final v = double.tryParse(normDigits(r));
              if (v != null && v >= 0) setState(() => limit = v);
            },
          ),
        ],
        hair(p, indent: 14),
        FormRow(
          icon: Icons.exposure_rounded,
          label: 'Opening balance',
          value: '${fixed2(start)}  ${curOf(S.cur).sym}',
          onTap: () async {
            final r = await promptText(context, 'Opening balance (${curOf(S.cur).sym})', hint: '0.00', initial: start == 0 ? '' : start.toString(), number: true);
            if (r == null) return;
            final v = double.tryParse(normDigits(r));
            if (v != null) setState(() => start = v);
          },
        ),
        if (kind == 'credit') ...[
          hair(p, indent: 14),
          _balanceBoxRow(p),
        ] else ...[
        hair(p, indent: 14),
        FormRow(
          icon: Icons.exposure_rounded,
          label: 'Current balance',
          value: fixed2(a == null ? start : repo.bal(a.id)),
          valueColor: p.ink2,
          chevron: false,
          trailing: Padding(padding: const EdgeInsets.only(left: 10), child: Icon(Icons.refresh_rounded, color: p.ink2, size: 22)),
          onTap: () => setState(() {}),
        ),
        ],
        if (kind == 'wallet') ...[hair(p, indent: 14), _walletSmsRow(p)],
        hair(p, indent: 14),
        Container(
          height: 52,
          padding: const EdgeInsetsDirectional.only(start: 14, end: 8),
          child: Row(children: [
            Icon(Icons.verified_rounded, color: p.ink2, size: 22),
            const SizedBox(width: 12),
            Text('Auto-clear transactions', style: TextStyle(fontSize: 15, color: p.ink2)),
            const Spacer(),
            iosSwitch(ac, (v) => setState(() => ac = v)),
          ]),
        ),
      ]),
    );
  }

  /// «في صندوق الرصيد اعرض»: الرصيد | الائتمان المتاح (شاشة بطاقة الائتمان).
  Widget _balanceBoxRow(Pal p) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Icon(Icons.visibility_outlined, color: p.ink2, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text('In the Balance box show', style: TextStyle(fontSize: 15, color: p.ink2))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final o in [(false, 'Balance'), (true, 'Available Credit')])
              Tap(scale: .97, onTap: () => setState(() => showAvail = o.$1), child: Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text(o.$2, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: showAvail == o.$1 ? kBlue : p.ink)))),
          ]),
        ]),
      );

  /// المحفظة الإلكترونية: كلمات/أسماء مرسلين (سطر لكل واحدة) يُربط بها أي رسالة تخص المحفظة تلقائيًا.
  Widget _walletSmsRow(Pal p) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.sms_outlined, color: p.ink2, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text('رسائل المحفظة (اسم المرسل أو كلمة من الرسالة)', style: TextStyle(fontSize: 15, color: p.ink2))),
          ]),
          const SizedBox(height: 6),
          TextField(controller: sms, minLines: 2, maxLines: 4, style: const TextStyle(fontSize: 15), decoration: InputDecoration(border: InputBorder.none, isDense: true, hintText: 'مثال:\nVodafone Cash\nفودافون كاش', hintStyle: TextStyle(color: p.ink2.withValues(alpha: .6)))),
          Text('أي رسالة فيها واحدة من الكلمات دي (أو جاية من المرسل ده) هتتسجل على المحفظة دي — التحليل على الجهاز بدون إنترنت.', style: TextStyle(fontSize: 12, color: p.ink2)),
        ]),
      );

  static const _wk = {'none': 'No change', 'before': 'Move to Friday', 'after': 'Move to Monday'};

  Widget _swRow(Pal p, IconData i, String t, bool v, ValueChanged<bool> f) => Container(
        height: 52,
        padding: const EdgeInsets.only(left: 14, right: 8),
        child: Row(children: [
          Icon(i, color: p.ink2, size: 22),
          const SizedBox(width: 12),
          Text(t, style: TextStyle(fontSize: 15, color: p.ink2)),
          const Spacer(),
          iosSwitch(v, f),
        ]),
      );

  Widget _advanced(Pal p) {
    final grpShown = grp.isNotEmpty ? grp : _tmp.group;
    return Container(
      decoration: iosCard(p),
      child: Column(children: [
        _swRow(p, Icons.monitor_heart_outlined, 'Include in Net Worth', nw, (v) => setState(() => nw = v)),
        hair(p, indent: 14),
        _swRow(p, Icons.monitor_heart_rounded, 'Include in Group balance', gb, (v) => setState(() => gb = v)),
        hair(p, indent: 14),
        FormRow(
          icon: Icons.folder_open_rounded,
          label: 'Put in Group',
          value: grpShown,
          onTap: () async {
            final r = await showSelect(context, 'Put in Group', [for (final g in allGroupNames()) (g, g)], grpShown);
            if (r != null) setState(() => grp = r);
          },
        ),
        if (kind == 'credit') ...[
          hair(p, indent: 14),
          FormRow(
            icon: Icons.event_repeat_rounded,
            label: 'Statement\nclose day',
            value: '$stmtDay',
            onTap: () async {
              final r = await showSelect(context, 'Statement close day', [for (var d = 1; d <= 31; d++) ('$d', '$d')], '$stmtDay');
              if (r != null) setState(() => stmtDay = int.tryParse(r) ?? 31);
            },
          ),
          hair(p, indent: 14),
          FormRow(
            icon: Icons.weekend_outlined,
            label: 'When it falls on\na weekend',
            value: _wk[wkend] ?? 'No change',
            onTap: () async {
              final r = await showSelect(context, 'When it falls on a weekend', [for (final e in _wk.entries) (e.key, e.value)], wkend);
              if (r != null) setState(() => wkend = r);
            },
          ),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final editing = widget.edit != null;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SheetPage(
        child: ListView(padding: EdgeInsets.fromLTRB(16, 16, 16, 30 + MediaQuery.of(context).viewInsets.bottom), children: [
          Row(children: [
            GlassBtn(Icons.close_rounded, () => Navigator.of(context).pop(), size: 46),
            const Spacer(),
            if (editing) ...[GlassBtn(Icons.delete_outline_rounded, _delete, size: 46, fg: kRed), const SizedBox(width: 12)],
            Tap(onTap: _save, child: Glass(radius: 23, height: 46, padding: const EdgeInsets.symmetric(horizontal: 24), child: Center(child: Text('Save', style: TextStyle(color: kBlue, fontSize: 16, fontWeight: FontWeight.w600))))),
          ]),
          const SizedBox(height: 14),
          Text('${editing ? 'Edit a' : 'New'} ${kindTitle(kind)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          _segment(p),
          const SizedBox(height: 14),
          AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: KeyedSubtree(key: ValueKey(tab), child: tab == 0 ? _basic(p) : _advanced(p))),
          if (tab == 0) ...[
            const SizedBox(height: 18),
            Center(child: Tap(onTap: () => soon(context, 'Online banking'), child: Container(padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14), decoration: iosCard(p, r: 16), child: const Text('Connect to Online Banking', style: TextStyle(fontSize: 16))))),
          ],
        ]),
      ),
    );
  }
}

/// إدخال رابط صورة مخصص (صورة 14).
class CustomUrlPage extends StatefulWidget {
  final String initial;
  const CustomUrlPage({super.key, this.initial = ''});
  @override
  State<CustomUrlPage> createState() => _CustomUrlState();
}

class _CustomUrlState extends State<CustomUrlPage> {
  late final TextEditingController c = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SheetPage(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 20), children: [
          Row(children: [
            GlassBtn(Icons.close_rounded, () => Navigator.of(context).pop(), size: 46),
            const Spacer(),
            Tap(onTap: () => Navigator.of(context).pop(c.text.trim()), child: Container(height: 46, padding: const EdgeInsets.symmetric(horizontal: 26), alignment: Alignment.center, decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(23)), child: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)))),
          ]),
          const SizedBox(height: 14),
          const Text('Custom URL', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('Enter the web address of any image with JPG or PNG extension and the app will attempt to download it.', textAlign: TextAlign.center, style: TextStyle(color: p.ink2, fontSize: 15, height: 1.4))),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: iosCard(p, r: 20),
            child: Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(12), child: c.text.startsWith('http') ? Image.network(c.text, width: 42, height: 42, fit: BoxFit.cover, errorBuilder: (a, b, d) => Container(width: 42, height: 42, color: p.field)) : Container(width: 42, height: 42, color: p.field)),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: c, autofocus: true, keyboardType: TextInputType.url, onChanged: (_) => setState(() {}), style: const TextStyle(fontSize: 16), decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'https://i.imgur.com/xxxx.png'))),
              Tap(onTap: () => setState(() => c.clear()), child: Icon(Icons.cancel_rounded, color: p.ink2)),
            ]),
          ),
        ]),
      ),
    );
  }
}
