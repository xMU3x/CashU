import 'package:material_ui/material_ui.dart' hide Text;
import '../ui/loc_text.dart';
import '../core/i18n.dart';
import '../core/repo.dart';
import '../core/store.dart';
import '../core/sync.dart';
import '../core/util.dart';
import '../sms/sms_parser.dart';
import '../sms/sms_rules.dart';
import '../sms/sms_tracker.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/sheets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'add_tx.dart';
import 'track_pages.dart';

export 'track_pages.dart' show SmsTrackingPage;

const _reasonText = <String, String>{
  'unknown_sender': 'مرسل غير معروف',
  'no_account': 'البطاقة غير مربوطة بحساب',
  'multiple_amounts': 'أكثر من مبلغ في الرسالة',
  'mixed_direction': 'اتجاه العملية غير واضح',
  'unclear_kind': 'نوع العملية غير واضح',
  'no_amount': 'لا يوجد مبلغ واضح',
  'otp': 'رمز تحقق (لم يُحفظ)',
  'failed': 'عملية فاشلة أو مرفوضة',
  'ad': 'إعلان',
  'not_financial': 'ليست رسالة مالية',
  'personal_sender': 'مرسل شخصي',
  'ok': 'تم التسجيل',
  'user': 'بموافقتك',
  'empty': 'رسالة فارغة',
};

String _reason(String r) => tl(_reasonText[r] ?? r);

Widget _live(Widget Function(BuildContext) b) => AnimatedBuilder(animation: Listenable.merge([smsTracker, repo, store]), builder: (c, _) => b(c));

Future<String?> _ask(BuildContext c, String title, {String hint = '', TextInputType? kb, int? maxLen}) async {
  final r = await promptText(c, title, hint: hint, number: kb == TextInputType.number);
  if (r == null) return null;
  final t = r.trim();
  return maxLen != null && t.length > maxLen ? t.substring(0, maxLen) : t;
}

/// تسجيل رسالة من المراجعة (نوع ← حساب ← رسائل مشابهة ← ثقة بالمرسل). مشتركة بين المراجعة ونتيجة الفحص.
Future<String?> _kindForItem(BuildContext c, Map<String, dynamic> e) async {
  var kind = '${e['kind']}';
  if (kind.isNotEmpty) return kind;
  return showSelect(c, 'نوع العملية', [for (final k in kSmsKinds) (k, tl(kSmsKindTitle[k]!))], 'purchase');
}

/// يفتح بانل المعاملة بالبيانات المستخرجة من عنصر المراجعة (يُستخدم من المراجعة ومن الإشعار).
Future<void> openReviewItem(BuildContext c, Map<String, dynamic> e) => _approveItem(c, e);

Future<void> _approveItem(BuildContext c, Map<String, dynamic> e) async {
  if ((e['minor'] as num).toInt() <= 0) {
    toast(c, 'لا يوجد مبلغ واضح في هذه الرسالة. يمكنك تجاهلها وإضافة المعاملة يدويًا.');
    return;
  }
  final kind = await _kindForItem(c, e);
  if (kind == null || !c.mounted) return;
  final accId = '${e['acc'] ?? ''}'.isNotEmpty && repo.account('${e['acc']}') != null ? '${e['acc']}' : repo.defaultAcc;
  // لا تسجيل تلقائي: نفتح بانل المعاملة بالبيانات المستخرجة عشان تراجعها وتعدّلها وتحفظ بنفسك.
  final draft = smsTracker.draftOf(e, accId, kind);
  final rid = '${e['id']}';
  await Navigator.of(c).push(sheetRoute(AddTxPage(draft: draft, accId: accId, onSaved: (tx) => smsTracker.finalizeReview(rid, tx))));
}


/// مراجعة الرسائل الملتبسة — مع تحديد متعدد (تسجيل / حذف دفعة واحدة).
class SmsReviewPage extends StatefulWidget {
  const SmsReviewPage({super.key});
  @override
  State<SmsReviewPage> createState() => _SmsReviewState();
}

class _SmsReviewState extends State<SmsReviewPage> {
  final Set<String> sel = {};
  bool get selecting => sel.isNotEmpty;

  /// تحميل/تحديث الرسائل: بيظهر دايرة النقط وهو شغال (أي معاملة جديدة متسجلتش بتظهر في القائمة).
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  /// [manual] = ضغطة زر التحديث: بيدوّر في الرسائل الأقدم (٣٠ يوم) على أي معاملة متسجلتش؛ الفتح التلقائي بيفحص آخر يومين بس.
  Future<void> _reload({bool manual = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await smsTracker.drainNative();
      if (smsTracker.enabled) await smsTracker.scanInbox(days: manual ? 30 : 2);
    } catch (e) {
      debugPrint('review reload: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(String id) => setState(() => sel.contains(id) ? sel.remove(id) : sel.add(id));

  Future<void> _approve(BuildContext c, Map<String, dynamic> e) => _approveItem(c, e);

  Future<void> _approveSelected(BuildContext c) async {
    final items = smsTracker.review.where((e) => sel.contains(e['id'])).toList();
    final ok = items.where((e) => (e['minor'] as num) > 0 && '${e['kind']}'.isNotEmpty).toList();
    final skipped = items.length - ok.length;
    if (ok.isEmpty) {
      toast(c, 'الرسائل المحددة نوعها أو مبلغها غير واضح — سجّلها واحدة واحدة');
      return;
    }
    final acc = await showPickAccount(c, repo.defaultAcc, title: 'سجّل المحدد على أي حساب؟');
    if (acc == null) return;
    final n = smsTracker.approveMany(ok.map((e) => '${e['id']}'), acc);
    setState(() => sel.clear());
    if (c.mounted) { toast(c, 'تم تسجيل ${toAr('$n')}${skipped > 0 ? ' — وتخطّي ${toAr('$skipped')} غير واضحة' : ''}'); }
  }

  Future<void> _deleteSelected(BuildContext c) async {
    if (!await confirmDialog(c, 'حذف المحدد', 'سيتم تجاهل ${toAr('${sel.length}')} رسالة وحذف نصها.', ok: 'حذف')) { return; }
    smsTracker.rejectMany(sel);
    setState(() => sel.clear());
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: selecting ? '${toAr('${sel.length}')} محددة' : 'مراجعة الرسائل',
      icon: Icons.fact_check_rounded,
      iconColor: kBlue,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        // نفس زر التحديث في صفحة الأصول: دايرة بخلفية + سبينر وهو شغال.
        Tap(
          onTap: _loading ? null : () => _reload(manual: true),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: p.field, shape: BoxShape.circle),
            child: _loading ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2.5)) : Icon(Icons.refresh_rounded, color: p.ink, size: 22),
          ),
        ),
        const SizedBox(width: 4),
        Tap(onTap: () => setState(() {
              final all = smsTracker.review.map((e) => '${e['id']}').toSet();
              if (sel.length == all.length) {
                sel.clear();
              } else {
                sel..clear()..addAll(all);
              }
            }), child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.select_all_rounded, color: p.ink2))),
        if (selecting) ...[
          Tap(onTap: () => _approveSelected(context), child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.check_circle_rounded, color: kBlue))),
          Tap(onTap: () => _deleteSelected(context), child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.delete_rounded, color: kRed))),
        ],
      ]),
      child: _live((c) {
        final l = smsTracker.review;
        sel.removeWhere((id) => !l.any((e) => e['id'] == id));
        if (l.isEmpty) { return Center(child: Text('لا توجد رسائل تحتاج مراجعة', style: TextStyle(color: p.ink2, fontSize: 16))); }
        return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), physics: const BouncingScrollPhysics(), children: [
          for (final e in l)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: () => _toggle('${e['id']}'),
              onTap: selecting ? () => _toggle('${e['id']}') : null,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: iosCard(p, r: 22).copyWith(border: Border.all(color: sel.contains('${e['id']}') ? kBlue : Colors.transparent, width: 2)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (selecting) Padding(padding: const EdgeInsetsDirectional.only(end: 10), child: Icon(sel.contains('${e['id']}') ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: sel.contains('${e['id']}') ? kBlue : p.ink2)),
                    Expanded(child: Text((e['minor'] as num) > 0 ? money((e['minor'] as num) / 100, '${e['cur']}') : '—', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: kBlue.withValues(alpha: .15), borderRadius: BorderRadius.circular(12)), child: Text(_reason('${e['reason']}'), style: TextStyle(fontSize: 12, color: kBlue))),
                  ]),
                  const SizedBox(height: 4),
                  Text('${kSmsKindTitle['${e['kind']}'] != null ? tl(kSmsKindTitle['${e['kind']}']!) : '؟'} · ${e['sender']} · ${dateLabel(DateTime.fromMillisecondsSinceEpoch((e['ts'] as num).toInt()))}', style: TextStyle(fontSize: 13, color: p.ink2)),
                  const SizedBox(height: 8),
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(12)), child: Text('${e['body']}', maxLines: 6, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.4))),
                  if (!selecting) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: Tap(onTap: () => _approve(c, e), child: Container(height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(20)), child: const Text('تسجيل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))))),
                      const SizedBox(width: 10),
                      Expanded(child: Tap(onTap: () => smsTracker.rejectReview('${e['id']}'), child: Container(height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(20)), child: const Text('تجاهل')))),
                    ]),
                  ],
                ]),
              ),
            ),
        ]);
      }),
    );
  }
}

/// نتيجة فحص الصندوق: كل الرسائل المالية وحالتها، وغير المسجّل يتسجّل من هنا.
class SmsScanPage extends StatefulWidget {
  const SmsScanPage({super.key});
  @override
  State<SmsScanPage> createState() => _SmsScanState();
}

class _SmsScanState extends State<SmsScanPage> {
  /// all | todo | done
  String filter = 'todo';

  Widget _stat(Pal p, String label, int n, Color c) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: c.withValues(alpha: .13), borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Text(toAr('$n'), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: c)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11.5, color: p.ink2)),
          ]),
        ),
      );

  Widget _chip(Pal p, String t, String v) => Tap(
        onTap: () => setState(() => filter = v),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: filter == v ? kBlue : p.field, borderRadius: BorderRadius.circular(18)),
          child: Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: filter == v ? Colors.white : p.ink2)),
        ),
      );

  (String, Color) _label(SmsStatus s) {
    switch (s) {
      case SmsStatus.registered:
        return ('مسجّلة', kGreen);
      case SmsStatus.pending:
        return ('في المراجعة', kBlue);
      case SmsStatus.ignored:
        return ('تم تجاهلها', const Color(0xFF8E8E93));
      case SmsStatus.fresh:
        return ('غير مسجّلة', kOrange);
    }
  }

  Future<void> _register(BuildContext c, ScanItem it) async {
    final e = smsTracker.review.firstWhere((x) => x['id'] == it.reviewId, orElse: () => <String, dynamic>{});
    if (e.isEmpty) return;
    await _approveItem(c, e);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: 'نتيجة الفحص',
      icon: Icons.manage_search_rounded,
      iconColor: kBlue,
      child: _live((c) {
        final r = smsTracker.lastScan;
        if (r == null) return Center(child: Text('لسه مفيش فحص. ارجع واضغط «فحص الرسائل».', style: TextStyle(color: p.ink2, fontSize: 16)));
        final st = {for (final it in r.items) it: smsTracker.statusOf(it)};
        final done = st.values.where((s) => s == SmsStatus.registered).length;
        final todo = st.values.where((s) => s == SmsStatus.fresh || s == SmsStatus.pending || s == SmsStatus.ignored).length;
        final shown = r.items.where((it) {
          final s = st[it]!;
          if (filter == 'todo') return s != SmsStatus.registered;
          if (filter == 'done') return s == SmsStatus.registered;
          return true;
        }).toList();
        return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), physics: const BouncingScrollPhysics(), children: [
          Row(children: [
            _stat(p, 'رسائل مفحوصة', r.scanned, p.ink2),
            const SizedBox(width: 8),
            _stat(p, 'مسجّلة', done, kGreen),
            const SizedBox(width: 8),
            _stat(p, 'غير مسجّلة', todo, kOrange),
            const SizedBox(width: 8),
            _stat(p, 'مستبعدة', r.excluded, kRed),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 14, 2, 4),
            child: Text('فحص آخر ${toAr('${r.days}')} يومًا · المستبعدة: رموز تحقق وإعلانات ورسائل غير مالية (ولا تُحفظ).', style: TextStyle(fontSize: 12.5, color: p.ink2, height: 1.4)),
          ),
          const SizedBox(height: 6),
          Row(children: [_chip(p, 'غير المسجّلة', 'todo'), const SizedBox(width: 8), _chip(p, 'المسجّلة', 'done'), const SizedBox(width: 8), _chip(p, 'الكل', 'all')]),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            Padding(padding: const EdgeInsets.only(top: 40), child: Center(child: Text(filter == 'todo' ? 'كل المعاملات مسجّلة ✓' : 'مفيش رسائل هنا', style: TextStyle(color: p.ink2, fontSize: 16)))),
          for (final it in shown)
            Builder(builder: (_) {
              final s = st[it]!;
              final lb = _label(s);
              final pr = it.parsed;
              final canReg = s == SmsStatus.fresh || s == SmsStatus.pending;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: iosCard(p, r: 22),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(pr.minor > 0 ? money(pr.amount, pr.currency) : '—', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700))),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: lb.$2.withValues(alpha: .16), borderRadius: BorderRadius.circular(12)), child: Text(lb.$1, style: TextStyle(fontSize: 12, color: lb.$2, fontWeight: FontWeight.w600))),
                  ]),
                  const SizedBox(height: 4),
                  Text('${kSmsKindTitle[pr.kind] != null ? tl(kSmsKindTitle[pr.kind]!) : '؟'} · ${it.sender} · ${dateLabel(DateTime.fromMillisecondsSinceEpoch(it.ts))} ${timeLabel(DateTime.fromMillisecondsSinceEpoch(it.ts))}', style: TextStyle(fontSize: 13, color: p.ink2)),
                  const SizedBox(height: 8),
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(12)), child: Text(it.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.4))),
                  if (canReg) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: Tap(onTap: () => _register(c, it), child: Container(height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(20)), child: const Text('تسجيل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))))),
                      const SizedBox(width: 10),
                      Expanded(child: Tap(onTap: () => smsTracker.rejectReview(it.reviewId), child: Container(height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(20)), child: const Text('تجاهل')))),
                    ]),
                  ],
                ]),
              );
            }),
        ]);
      }),
    );
  }
}

/// الكلمات المتتبَّعة + المستبعدة + تجربة رسالة.
class SmsWordsPage extends StatefulWidget {
  const SmsWordsPage({super.key});
  @override
  State<SmsWordsPage> createState() => _SmsWordsState();
}

class _SmsWordsState extends State<SmsWordsPage> {
  final sender = TextEditingController(text: 'CIB');
  final text = TextEditingController();
  ParsedSms? res;

  @override
  void dispose() {
    sender.dispose();
    text.dispose();
    super.dispose();
  }

  Widget _chip(Pal p, String w, VoidCallback onDel) => Tap(
        onTap: onDel,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Text(w, style: const TextStyle(fontSize: 14)), const SizedBox(width: 6), Icon(Icons.close_rounded, size: 14, color: p.ink2)]),
        ),
      );

  Widget _add(Pal p, VoidCallback f) => Tap(onTap: f, child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: kBlue.withValues(alpha: .15), borderRadius: BorderRadius.circular(18)), child: Text('+ إضافة', style: TextStyle(color: kBlue, fontSize: 14, fontWeight: FontWeight.w600))));

  Widget _result(Pal p, ParsedSms r) {
    String acc = '—';
    for (final a in repo.accList) {
      if (a.id == r.accId) acc = a.name;
    }
    final col = r.verdict == SmsVerdict.accept ? kGreen : r.verdict == SmsVerdict.review ? kOrange : kRed;
    final title = r.verdict == SmsVerdict.accept ? 'ستُسجَّل تلقائيًا' : r.verdict == SmsVerdict.review ? 'ستُرسل للمراجعة' : 'ستُستبعد';
    Widget line(String a, String b) => Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [Text(a, style: TextStyle(color: p.ink2, fontSize: 13)), const SizedBox(width: 8), Expanded(child: Text(b, style: const TextStyle(fontSize: 14)))]));
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: col.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: col, fontWeight: FontWeight.w700, fontSize: 16)),
        line('السبب', _reason(r.reason)),
        if (r.kind.isNotEmpty) line('النوع', tl(kSmsKindTitle[r.kind]!)),
        if (r.minor > 0) line('المبلغ', money(r.amount, r.currency)),
        if (r.last4.isNotEmpty) line('البطاقة', '•••• ${r.last4}'),
        if (r.merchant.isNotEmpty) line('التاجر', r.merchant),
        if (r.verdict != SmsVerdict.reject) line('الحساب', acc),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: 'الكلمات المتتبَّعة',
      icon: Icons.label_rounded,
      iconColor: kBlue,
      child: _live((c) {
        final t = smsTracker;
        final w = t.words;
        return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), physics: const BouncingScrollPhysics(), children: [
          Text('تُعدّ الرسالة عملية عندما تحتوي على إحدى هذه الكلمات. اضغط على كلمة لحذفها.', style: TextStyle(fontSize: 13, color: p.ink2, height: 1.5)),
          for (final k in kSmsKinds) ...[
            sectionLabel(p, kSmsKindTitle[k]!),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final x in w[k]!) _chip(p, x, () => t.removeWord(k, x)),
              _add(p, () async {
                final r = await _ask(c, kSmsKindTitle[k]!, hint: 'كلمة أو عبارة');
                if (r != null) t.addWord(k, r);
              }),
            ]),
          ],
          sectionLabel(p, 'تُستبعد دائمًا'),
          Text('لا تُسجَّل ولا تُحفظ الرسائل التي تحتوي على هذه الكلمات (رموز التحقق والعمليات الفاشلة).', style: TextStyle(fontSize: 13, color: p.ink2, height: 1.5)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final x in t.excluded) _chip(p, x, () => t.removeExcluded(x)),
            _add(p, () async {
              final r = await _ask(c, 'تُستبعد دائمًا', hint: 'كلمة أو عبارة');
              if (r != null) t.addExcluded(r);
            }),
          ]),
          const SizedBox(height: 10),
          Tap(onTap: () async {
            if (await confirmDialog(c, 'إعادة الكلمات الافتراضية', 'ستُحذف تعديلاتك على الكلمات المتتبَّعة والمستبعدة.', ok: 'إعادة')) { t.resetWords(); }
          }, child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('إعادة الكلمات الافتراضية', style: TextStyle(color: p.ink2, decoration: TextDecoration.underline)))),
          sectionLabel(p, 'جرّب رسالة'),
          Text('الصق رسالة بنك لترى كيف ستُقرأ. لا يُحفظ شيء.', style: TextStyle(fontSize: 13, color: p.ink2)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: iosCard(p, r: 18),
            child: Column(children: [
              TextField(controller: sender, decoration: InputDecoration(border: InputBorder.none, hintText: tl('اسم المرسل'), hintStyle: TextStyle(color: p.ink2))),
              hair(p),
              TextField(controller: text, minLines: 3, maxLines: 6, decoration: InputDecoration(border: InputBorder.none, hintText: tl('نص الرسالة'), hintStyle: TextStyle(color: p.ink2))),
            ]),
          ),
          const SizedBox(height: 12),
          Tap(onTap: () => setState(() => res = t.test(sender.text.trim(), text.text)), child: Container(height: 46, alignment: Alignment.center, decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(23)), child: Text('جرّب', style: TextStyle(color: p.bg, fontWeight: FontWeight.w700, fontSize: 16)))),
          if (res != null) _result(p, res!),
        ]);
      }),
    );
  }
}
