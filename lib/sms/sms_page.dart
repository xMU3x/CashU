import 'package:flutter/material.dart' hide Text;
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/store.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/sheets.dart';
import '../ui/theme.dart';
import '../ui/tr.dart';
import '../ui/widgets.dart';
import 'sms_service.dart';

// ---------- عناصر مشتركة ----------
Widget _scaffold(BuildContext c, String title, List<Widget> kids, {Widget? bottom}) {
  final p = Pal.of(c);
  return Scaffold(
    backgroundColor: p.bg,
    body: SwipeBack(
      child: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 40), physics: const BouncingScrollPhysics(), children: [
          Container(
            height: 66,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(33)),
            child: Row(children: [
              Tap(onTap: () => Navigator.of(c).pop(), child: Container(width: 44, height: 44, decoration: BoxDecoration(color: p.field, shape: BoxShape.circle), child: Icon(L.rtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded, color: p.ink))),
              const SizedBox(width: 14),
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700))),
            ]),
          ),
          const SizedBox(height: 18),
          ...kids,
        ]),
      ),
    ),
  );
}

Widget _head(Pal p, String t) => Padding(padding: const EdgeInsets.fromLTRB(4, 22, 4, 8), child: Text(t, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)));

Widget _tile(Pal p, String title, String? sub, VoidCallback? onTap, {Widget? leading, Widget? trailing, bool chevron = true, Color? color}) => Tap(
      scale: .99,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line.withValues(alpha: .6), width: .6))),
        child: Row(children: [
          if (leading != null) ...[leading, const SizedBox(width: 12)],
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: color)),
            if (sub != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, style: TextStyle(fontSize: 14, color: p.ink2))),
          ])),
          if (trailing != null) trailing,
          if (chevron) Icon(L.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: p.ink2),
        ]),
      ),
    );

String kindLabel(String k) => kSmsKindAr[k] ?? 'غير محدد';

Color _kindColor(String k) => k == 'xfer_in' || k == 'refund' ? kGreen : (k == 'atm' ? kOrange : kRed);

String _bankName(String key) {
  for (final b in kSmsBanks) {
    if (b.$1 == key) return b.$2;
  }
  return key;
}

// =============== الصفحة الرئيسية ===============
class SmsTrackingPage extends StatefulWidget {
  const SmsTrackingPage({super.key});
  @override
  State<SmsTrackingPage> createState() => _SmsTrackingState();
}

class _SmsTrackingState extends State<SmsTrackingPage> {
  @override
  void initState() {
    super.initState();
    smsService.refreshPerms();
  }

  Future<void> _scan() async {
    toast(context, 'جارٍ مسح الرسائل القديمة…');
    final n = await smsService.scanInbox(30);
    if (!mounted) return;
    toast(context, n < 0 ? 'يلزم السماح بقراءة الرسائل' : (n == 0 ? 'لا توجد عمليات جديدة' : 'تمت إضافة $n عملية للسجل/المراجعة'));
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([smsService, store]),
      builder: (c, _) {
        final on = smsService.enabled;
        final rc = smsService.reviewCount;
        final cards = smsService.cards;
        return _scaffold(c, 'تتبع رسائل البنك', [
          _tile(p, 'قراءة رسائل البنك', 'تُقرأ الرسائل الجديدة من البنوك والمحافظ فقط', null, chevron: false, trailing: iosSwitch(on, (v) => smsService.setEnabled(v))),
          if (on && smsService.supported && smsService.perms['receive'] != true)
            Padding(padding: const EdgeInsets.only(top: 10), child: Tap(onTap: () => smsService.requestPerms(), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: kOrange.withValues(alpha: .15), borderRadius: BorderRadius.circular(16)), child: Row(children: [const Icon(Icons.warning_amber_rounded, color: kOrange), const SizedBox(width: 10), Expanded(child: Text('لم تُمنح صلاحية قراءة الرسائل بعد — اضغط للسماح.', style: TextStyle(color: p.ink)))])))),
          _head(p, 'تحتاج مراجعة'),
          _tile(p, 'مراجعة الرسائل', rc == 0 ? 'لا توجد عمليات' : (rc == 1 ? 'عملية واحدة' : '$rc عمليات'), () => Navigator.of(c).push(flowRoute(const _ReviewPage()))),
          _tile(p, 'السجل', 'ما سُجّل وما استُبعد', () => Navigator.of(c).push(flowRoute(const _LogPage()))),
          _tile(p, 'الكلمات المتتبَّعة', '${smsService.wordCount} كلمة — أضف كلماتك أو عدّل كلماتنا', () => Navigator.of(c).push(flowRoute(const _WordsPage()))),
          _head(p, 'البطاقات والحسابات'),
          for (final cd in cards)
            _tile(
              p,
              'بطاقة •••• ${cd.last4}',
              '${cd.auto ? 'تلقائي' : 'بمراجعة'} · ${cd.bank.isEmpty ? '—' : '${cd.bank} · ${_bankName(cd.bank)}'}',
              () => Navigator.of(c).push(flowRoute(_CardPage(card: cd))),
              leading: Container(width: 46, height: 46, decoration: BoxDecoration(color: kBlue.withValues(alpha: .14), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.account_balance_rounded, color: kBlue, size: 22)),
            ),
          _tile(p, 'إضافة بطاقة', null, () => Navigator.of(c).push(flowRoute(const _CardPage()))),
          _head(p, 'الذكاء الاصطناعي'),
          _tile(p, 'حلّل بالذكاء الاصطناعي', smsService.aiReady ? 'مفعّل — زر التحليل يظهر في المراجعة والتجربة' : 'اربط مفتاح مزوّد الذكاء الاصطناعي لتفعيله', () => Navigator.of(c).push(flowRoute(const _AiPage())), leading: Container(width: 46, height: 46, decoration: BoxDecoration(color: const Color(0xFFBF5AF2).withValues(alpha: .15), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFBF5AF2), size: 22))),
          _head(p, 'خيارات'),
          _tile(p, 'تسجيل تلقائي', 'تُسجَّل العمليات الواضحة من بطاقاتك المربوطة بدون مراجعة', null, chevron: false, trailing: iosSwitch(S.flag('smsAuto', true), (v) {
            S.put('smsAuto', v);
            smsService.pushConfig();
          })),
          _tile(p, 'إشعار عند كل عملية', 'يصلك إشعار بما سُجّل أو بما يحتاج مراجعة', null, chevron: false, trailing: iosSwitch(S.flag('smsNotify', true), (v) {
            S.put('smsNotify', v);
            smsService.pushConfig();
          })),
          _tile(p, 'مسح الرسائل القديمة', 'يحلّل رسائل آخر ٣٠ يومًا ويضيفها للمراجعة', on ? _scan : null),
          _tile(p, 'تجربة رسالة', 'الصق رسالة بنك لترى كيف ستُقرأ', () => Navigator.of(c).push(flowRoute(const _TryPage()))),
          const SizedBox(height: 22),
          Text('الرسائل تُقرأ على هاتفك فقط وتُحفظ محلياً، ولا يُرسل نصها إلى أي خادم. رسائل الأشخاص ورموز التحقق تُتجاهل ولا تُحفظ. (زر الذكاء الاصطناعي هو الاستثناء الوحيد: يرسل نص الرسالة التي تحلّلها فقط إلى المزوّد الذي اخترته.)', style: TextStyle(color: p.ink2, fontSize: 14, height: 1.6)),
        ]);
      },
    );
  }
}

// =============== مراجعة الرسائل ===============
class _ReviewPage extends StatelessWidget {
  const _ReviewPage();

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return AnimatedBuilder(
      animation: smsService,
      builder: (c, _) {
        final l = smsService.byStatus('review');
        return _scaffold(c, 'مراجعة الرسائل', [
          if (l.isEmpty) emptyState(p, '✅', 'لا توجد عمليات تحتاج مراجعة'),
          for (final e in l) _ReviewCard(e: e, key: ValueKey(e['id'])),
        ]);
      },
    );
  }
}

String _reasonAr(String r) {
  switch (r) {
    case 'unlinked_card':
      return 'البطاقة غير مربوطة بحساب';
    case 'foreign_currency':
      return 'عملة أجنبية';
    case 'kind_needs_review':
      return 'النوع يحتاج تأكيدك';
    case 'auto_off':
    case 'auto_post_off':
      return 'التسجيل التلقائي متوقف';
    case 'unverified_sender':
      return 'مرسل غير معروف';
    case 'unknown_kind':
      return 'لم يُفهم نوع العملية';
    case 'failed':
      return 'عملية فاشلة';
    case 'ai_none':
      return 'ليست عملية مالية (الذكاء الاصطناعي)';
    default:
      return '';
  }
}

class _ReviewCard extends StatefulWidget {
  final Map<String, dynamic> e;
  const _ReviewCard({super.key, required this.e});
  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool busy = false;

  Future<void> _record() async {
    final e = widget.e;
    var acc = '${e['acc'] ?? ''}';
    if (repo.accList.every((a) => a.id != acc)) {
      final r = await showPickAccount(context, repo.defaultAcc);
      if (r == null) return;
      acc = r;
    }
    var kind = '${e['kind'] ?? ''}';
    if (!kSmsKinds.contains(kind)) {
      final k = await showSelect(context, 'نوع العملية', [for (final k in kSmsKinds) (k, kindLabel(k))], 'purchase');
      if (k == null) return;
      kind = k;
    }
    if (!mounted) return;
    final ok = smsService.confirm('${e['id']}', accId: acc, kind: kind);
    toast(context, ok ? 'تم التسجيل ✓' : 'تعذّر التسجيل — تحقق من المبلغ');
  }

  Future<void> _ai() async {
    setState(() => busy = true);
    final ok = await smsService.aiRefine('${widget.e['id']}');
    if (!mounted) return;
    setState(() => busy = false);
    toast(context, ok ? 'تم التحليل' : 'تعذّر التحليل بالذكاء الاصطناعي');
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final e = widget.e;
    final kind = '${e['kind'] ?? ''}';
    final amt = (e['amt'] is num) ? (e['amt'] as num).toDouble() : 0.0;
    final why = _reasonAr('${e['reason'] ?? ''}');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: iosCard(p, r: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(kSmsKinds.contains(kind) ? kindLabel(kind) : 'عملية غير محددة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kSmsKinds.contains(kind) ? _kindColor(kind) : p.ink))),
          Text(amt > 0 ? '${amt.toStringAsFixed(2)} ${e['cur'] ?? ''}' : '—', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        Text([if ('${e['bankName'] ?? ''}'.isNotEmpty) '${e['bankName']}', if ('${e['last4'] ?? ''}'.isNotEmpty) '•••• ${e['last4']}', if ('${e['merchant'] ?? ''}'.isNotEmpty) '${e['merchant']}'].join(' · '), style: TextStyle(color: p.ink2, fontSize: 14)),
        if (why.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(why, style: const TextStyle(color: kOrange, fontSize: 13))),
        const SizedBox(height: 10),
        Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(12)), child: Text('${e['text'] ?? ''}', maxLines: 5, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: TextStyle(fontSize: 13, color: p.ink2, height: 1.45))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Tap(onTap: _record, child: Container(height: 44, alignment: Alignment.center, decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(22)), child: const Text('تسجيل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))))),
          const SizedBox(width: 8),
          if (smsService.aiReady) ...[
            Tap(onTap: busy ? null : _ai, child: Container(height: 44, width: 52, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFBF5AF2).withValues(alpha: .18), borderRadius: BorderRadius.circular(22)), child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded, color: Color(0xFFBF5AF2)))),
            const SizedBox(width: 8),
          ],
          Expanded(child: Tap(onTap: () => smsService.dismiss('${e['id']}'), child: Container(height: 44, alignment: Alignment.center, decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(22)), child: Text('تجاهل', style: TextStyle(color: p.ink, fontWeight: FontWeight.w600))))),
        ]),
      ]),
    );
  }
}

// =============== السجل ===============
class _LogPage extends StatefulWidget {
  const _LogPage();
  @override
  State<_LogPage> createState() => _LogState();
}

class _LogState extends State<_LogPage> {
  int tab = 0; // 0 سُجّل، 1 استُبعد/تُجوهل

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return AnimatedBuilder(
      animation: smsService,
      builder: (c, _) {
        final l = tab == 0 ? smsService.byStatus('recorded') : [...smsService.byStatus('excluded'), ...smsService.byStatus('ignored')];
        return _scaffold(c, 'السجل', [
          Row(children: [
            Expanded(child: smallChipFull('سُجّل', tab == 0, () => setState(() => tab = 0))),
            const SizedBox(width: 8),
            Expanded(child: smallChipFull('استُبعد', tab == 1, () => setState(() => tab = 1))),
          ]),
          const SizedBox(height: 12),
          if (l.isEmpty) emptyState(p, '🗒️', 'لا يوجد شيء هنا بعد'),
          for (final e in l)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: iosCard(p, r: 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(e['kind'] != null && kSmsKinds.contains('${e['kind']}') ? kindLabel('${e['kind']}') : _reasonAr('${e['reason'] ?? ''}'), style: const TextStyle(fontWeight: FontWeight.w700))),
                  if (e['amt'] is num && (e['amt'] as num) > 0) Text('${(e['amt'] as num).toStringAsFixed(2)} ${e['cur'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 4),
                Text('${e['bankName'] ?? ''} · ${enDateTime(DateTime.fromMillisecondsSinceEpoch((e['ts'] as num?)?.toInt() ?? 0))}', style: TextStyle(color: p.ink2, fontSize: 13)),
                if (tab == 0) Align(alignment: AlignmentDirectional.centerEnd, child: Tap(onTap: () => smsService.undoRecorded('${e['id']}'), child: Padding(padding: const EdgeInsets.only(top: 6), child: Text('تراجع عن التسجيل', style: const TextStyle(color: kRed, fontSize: 13))))),
              ]),
            ),
          if (l.isNotEmpty && tab == 1) Center(child: Tap(onTap: smsService.clearLog, child: const Padding(padding: EdgeInsets.all(12), child: Text('مسح السجل', style: TextStyle(color: kRed))))),
        ]);
      },
    );
  }
}

Widget smallChipFull(String t, bool on, VoidCallback f) => Tap(
      onTap: f,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: on ? kBlue : const Color(0xFF8E8E93).withValues(alpha: .25), borderRadius: BorderRadius.circular(21)),
        child: Text(t, style: TextStyle(color: on ? Colors.white : null, fontWeight: FontWeight.w600)),
      ),
    );

// =============== الكلمات المتتبَّعة ===============
class _WordsPage extends StatelessWidget {
  const _WordsPage();

  Future<void> _add(BuildContext c) async {
    final t = await promptText(c, 'إضافة كلمة', hint: 'مثال: تم الدفع');
    if (t == null || t.isEmpty || !c.mounted) return;
    final k = await showSelect(c, 'تصنيف الكلمة', [for (final k in kSmsKinds) (k, kindLabel(k))], 'purchase');
    if (k != null) smsService.addWord(t, k);
  }

  void _chip(BuildContext c, SmsWord w) {
    showPillMenu(c, [
      ('تغيير التصنيف', () async {
        final k = await showSelect(c, 'تصنيف الكلمة', [for (final k in kSmsKinds) (k, kindLabel(k))], w.kind);
        if (k != null && k != w.kind) smsService.moveWord(w, k);
      }),
      ('حذف', () => smsService.removeWord(w)),
    ], danger: const {'حذف'});
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return AnimatedBuilder(
      animation: smsService,
      builder: (c, _) => _scaffold(c, 'الكلمات المتتبَّعة', [
        Text('تُعدّ الرسالة عملية عندما تحتوي على إحدى هذه الكلمات. أضف كلماتك، أو اربط كلمة بتصنيف، أو احذف كلمة.', style: TextStyle(color: p.ink2, fontSize: 14, height: 1.6)),
        const SizedBox(height: 8),
        _tile(p, 'إضافة كلمة', null, () => _add(c)),
        for (final k in kSmsKinds) ...[
          _head(p, kindLabel(k)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final w in smsService.words(k))
              Tap(
                onTap: () => _chip(c, w),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(color: w.custom ? p.field : Colors.transparent, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.line)),
                  child: Text(w.text, style: const TextStyle(fontSize: 15)),
                ),
              ),
          ]),
        ],
        _head(p, 'تُستبعد دائمًا'),
        Text('لا تُسجَّل رسائل هذه الكلمات أبدًا — أكواد التحقق والعمليات الفاشلة، ولا يمكن حذفها.', style: TextStyle(color: p.ink2, fontSize: 14, height: 1.6)),
        const SizedBox(height: 6),
        Text(kSmsExcluded.join('، '), textDirection: TextDirection.ltr, style: TextStyle(color: p.ink2, fontSize: 13, height: 1.7)),
      ]),
    );
  }
}

// =============== بطاقة ===============
class _CardPage extends StatefulWidget {
  final SmsCard? card;
  const _CardPage({this.card});
  @override
  State<_CardPage> createState() => _CardState();
}

class _CardState extends State<_CardPage> {
  late final TextEditingController l4 = TextEditingController(text: widget.card?.last4 ?? '');
  late String bank = widget.card?.bank ?? '';
  late String acc = widget.card?.acc ?? repo.defaultAcc;
  late bool auto = widget.card?.auto ?? true;

  @override
  void dispose() {
    l4.dispose();
    super.dispose();
  }

  String get _accName {
    for (final a in repo.accList) {
      if (a.id == acc) return a.name;
    }
    return '—';
  }

  void _save() {
    final v = l4.text.replaceAll(RegExp(r'\D'), '');
    if (v.length != 4) {
      toast(context, 'أدخل آخر 4 أرقام من البطاقة');
      return;
    }
    final l = smsService.cards.where((x) => x.last4 != (widget.card?.last4 ?? v) && x.last4 != v).toList();
    l.add(SmsCard(last4: v, bank: bank, acc: acc, auto: auto));
    smsService.saveCards(l);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return _scaffold(context, widget.card == null ? 'إضافة بطاقة' : 'تعديل البطاقة', [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(20)),
        child: TextField(controller: l4, keyboardType: TextInputType.number, maxLength: 4, decoration: InputDecoration(border: InputBorder.none, counterText: '', hintText: tr('آخر 4 أرقام من البطاقة'), hintStyle: TextStyle(color: p.ink2))),
      ),
      const SizedBox(height: 10),
      _tile(p, 'البنك / المحفظة', bank.isEmpty ? 'أي جهة' : _bankName(bank), () async {
        final r = await showSelect(context, 'البنك / المحفظة', [('', 'أي جهة'), ...kSmsBanks], bank);
        if (r != null) setState(() => bank = r);
      }),
      _tile(p, 'الحساب المرتبط', _accName, () async {
        final r = await showPickAccount(context, acc);
        if (r != null) setState(() => acc = r);
      }),
      _tile(p, 'تسجيل تلقائي', 'بدون مراجعة لهذه البطاقة', null, chevron: false, trailing: iosSwitch(auto, (v) => setState(() => auto = v))),
      const SizedBox(height: 18),
      bigButton(p, 'حفظ', kBlue, _save),
      if (widget.card != null) ...[
        const SizedBox(height: 12),
        Center(child: Tap(onTap: () {
          smsService.saveCards(smsService.cards.where((x) => x.last4 != widget.card!.last4).toList());
          Navigator.of(context).pop();
        }, child: const Padding(padding: EdgeInsets.all(12), child: Text('حذف البطاقة', style: TextStyle(color: kRed, fontWeight: FontWeight.w600))))),
      ],
    ]);
  }
}

// =============== تجربة رسالة ===============
class _TryPage extends StatefulWidget {
  const _TryPage();
  @override
  State<_TryPage> createState() => _TryState();
}

class _TryState extends State<_TryPage> {
  final sender = TextEditingController(text: 'CIB');
  final body = TextEditingController();
  Map<String, dynamic>? res;
  String note = '';
  bool busy = false;

  @override
  void dispose() {
    sender.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> _try() async {
    setState(() => busy = true);
    final r = await smsService.parse(sender.text, body.text);
    if (!mounted) return;
    setState(() {
      busy = false;
      res = r;
      note = r == null ? 'ستُتجاهل هذه الرسالة (ليست من بنك/محفظة أو رمز تحقق أو غير مالية).' : '';
    });
  }

  Future<void> _ai() async {
    setState(() => busy = true);
    final r = await smsService.aiParse(body.text);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (r == null) {
        note = 'تعذّر التحليل بالذكاء الاصطناعي';
      } else {
        note = '';
        res = {'kind': r['kind'] == 'none' ? '' : r['kind'], 'amt': r['amount'], 'cur': r['currency'], 'last4': r['last4'], 'merchant': r['merchant'], 'status': 'review', 'reason': r['kind'] == 'none' ? 'ai_none' : '', 'bankName': sender.text};
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return _scaffold(context, 'تجربة رسالة', [
      Text('الصق رسالة بنك لترى كيف ستُقرأ. لا يُحفظ شيء.', style: TextStyle(color: p.ink2, fontSize: 14)),
      const SizedBox(height: 10),
      Container(padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(18)), child: TextField(controller: sender, decoration: InputDecoration(border: InputBorder.none, hintText: tr('اسم المرسل'), hintStyle: TextStyle(color: p.ink2)))),
      const SizedBox(height: 10),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(18)), child: TextField(controller: body, minLines: 4, maxLines: 8, decoration: InputDecoration(border: InputBorder.none, isDense: true, hintText: tr('نص الرسالة'), hintStyle: TextStyle(color: p.ink2)))),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: Tap(onTap: busy ? null : _try, child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(24)), child: Text('جرّب', style: TextStyle(color: p.bg, fontWeight: FontWeight.w700))))),
        if (smsService.aiReady) ...[
          const SizedBox(width: 8),
          Expanded(child: Tap(onTap: busy ? null : _ai, child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFBF5AF2), borderRadius: BorderRadius.circular(24)), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18), SizedBox(width: 6), Text('حلّل بالذكاء الاصطناعي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))])))),
        ],
      ]),
      if (busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
      if (note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 14), child: Text(note, style: const TextStyle(color: kOrange))),
      if (res != null) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: iosCard(p, r: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _kv(p, 'النوع', kSmsKinds.contains('${res!['kind']}') ? kindLabel('${res!['kind']}') : 'غير محدد'),
            _kv(p, 'المبلغ', '${res!['amt'] ?? '—'} ${res!['cur'] ?? ''}'),
            _kv(p, 'البطاقة', '${res!['last4'] ?? ''}'.isEmpty ? '—' : '•••• ${res!['last4']}'),
            _kv(p, 'التاجر', '${res!['merchant'] ?? ''}'.isEmpty ? '—' : '${res!['merchant']}'),
            _kv(p, 'الجهة', '${res!['bankName'] ?? '—'}'),
            _kv(p, 'القرار', res!['status'] == 'auto' ? 'تسجيل تلقائي' : (res!['status'] == 'excluded' ? 'استبعاد' : 'مراجعة')),
            if (_reasonAr('${res!['reason'] ?? ''}').isNotEmpty) _kv(p, 'السبب', _reasonAr('${res!['reason']}')),
          ]),
        ),
      ],
    ]);
  }

  Widget _kv(Pal p, String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Text(k, style: TextStyle(color: p.ink2)), const Spacer(), Flexible(child: Text(v, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600)))]));
}

// =============== إعدادات الذكاء الاصطناعي ===============
class _AiPage extends StatelessWidget {
  const _AiPage();

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return AnimatedBuilder(
      animation: smsService,
      builder: (c, _) {
        final a = smsService.ai;
        final prov = '${a['prov'] ?? 'gemini'}';
        void put(String k, String v) {
          final m = smsService.ai;
          m[k] = v;
          smsService.saveAi(m);
        }

        return _scaffold(c, 'حلّل بالذكاء الاصطناعي', [
          Text('عند الضغط على زر التحليل يُرسَل نص الرسالة فقط إلى المزوّد الذي تختاره (بمفتاحك الخاص). المفتاح يُحفظ على هذا الجهاز فقط ولا يُزامَن.', style: TextStyle(color: p.ink2, fontSize: 14, height: 1.6)),
          const SizedBox(height: 8),
          _tile(p, 'المزوّد', prov == 'gemini' ? 'Google Gemini' : (prov == 'claude' ? 'Anthropic Claude' : 'OpenAI / متوافق'), () async {
            final r = await showSelect(c, 'المزوّد', const [('gemini', 'Google Gemini'), ('claude', 'Anthropic Claude'), ('openai', 'OpenAI / متوافق')], prov);
            if (r != null) put('prov', r);
          }),
          _tile(p, 'مفتاح API', '${a['key'] ?? ''}'.isEmpty ? 'غير مضبوط' : '••••••••${'${a['key']}'.length > 4 ? '${a['key']}'.substring('${a['key']}'.length - 4) : ''}', () async {
            final r = await promptText(c, 'مفتاح API', initial: '${a['key'] ?? ''}');
            if (r != null) put('key', r.trim());
          }),
          _tile(p, 'النموذج (اختياري)', '${a['model'] ?? ''}'.isEmpty ? 'الافتراضي' : '${a['model']}', () async {
            final r = await promptText(c, 'اسم النموذج', initial: '${a['model'] ?? ''}');
            if (r != null) put('model', r.trim());
          }),
          if (prov == 'openai')
            _tile(p, 'عنوان الخادم (اختياري)', '${a['url'] ?? ''}'.isEmpty ? 'https://api.openai.com/v1' : '${a['url']}', () async {
              final r = await promptText(c, 'عنوان الخادم', initial: '${a['url'] ?? ''}');
              if (r != null) put('url', r.trim());
            }),
          _tile(p, 'تحليل تلقائي للرسائل غير الواضحة', 'يحلّلها الذكاء الاصطناعي تلقائيًا عند دخولها للمراجعة (والتسجيل إن كانت البطاقة مربوطة)', null, chevron: false, trailing: iosSwitch(S.flag('smsAiAuto'), (v) => S.put('smsAiAuto', v))),
        ]);
      },
    );
  }
}
