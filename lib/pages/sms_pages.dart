import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/store.dart';
import '../core/util.dart';
import '../sms/sms_parser.dart';
import '../sms/sms_rules.dart';
import '../sms/sms_tracker.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/sheets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

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

Future<String?> _ask(BuildContext c, String title, {String hint = '', TextInputType? kb, int? maxLen}) {
  final ctl = TextEditingController();
  return showDialog<String>(
    context: c,
    builder: (x) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 18)),
      content: TextField(controller: ctl, autofocus: true, keyboardType: kb, maxLength: maxLen, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(x), child: const Text('إلغاء')),
        TextButton(onPressed: () => Navigator.pop(x, ctl.text.trim()), child: const Text('إضافة')),
      ],
    ),
  );
}

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
            if (trailing != null) trailing else if (onTap != null) Icon(isAr ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: p.ink2),
          ]),
        ),
      ),
      if (!last) hair(p, indent: 52),
    ]);

/// الشاشة الرئيسية: "تتبع رسائل البنك".
class SmsTrackingPage extends StatelessWidget {
  const SmsTrackingPage({super.key});

  String _accName(String id) {
    for (final a in repo.accList) {
      if (a.id == id) return a.name;
    }
    return '—';
  }

  Future<void> _toggle(BuildContext c, bool v) async {
    final ok = await smsTracker.setEnabled(v);
    if (!c.mounted) return;
    if (v && !ok) toast(c, 'لم تُمنح صلاحية الرسائل. إن كان التطبيق مثبّتًا من ملف APK: افتح معلومات التطبيق ← ⋮ ← «السماح بالإعدادات المقيّدة» ثم أعد المحاولة.');
  }

  Future<void> _addCard(BuildContext c) async {
    final l4 = await _ask(c, 'آخر ٤ أرقام من البطاقة', hint: '7748', kb: TextInputType.number, maxLen: 4);
    if (l4 == null || !RegExp(r'^\d{4}$').hasMatch(normDigits(l4))) {
      if (l4 != null && c.mounted) toast(c, 'اكتب ٤ أرقام بالضبط');
      return;
    }
    if (!c.mounted) return;
    final acc = await showPickAccount(c, repo.defaultAcc, title: 'اربط البطاقة بحساب');
    if (acc != null) smsTracker.linkCard(normDigits(l4), acc);
  }

  Future<void> _scan(BuildContext c) async {
    if (!smsTracker.enabled) {
      toast(c, 'فعّل قراءة رسائل البنك أولًا');
      return;
    }
    toast(c, 'جارٍ فحص رسائل آخر ٣٠ يومًا...');
    final n = await smsTracker.scanInbox(days: 30);
    if (c.mounted) toast(c, 'تم فحص ${toAr('$n')} رسالة');
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: 'تتبع رسائل البنك',
      icon: Icons.sms_rounded,
      iconColor: kBlue,
      child: _live((c) {
        final t = smsTracker;
        final rv = t.review.length;
        final cards = t.cards;
        return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), physics: const BouncingScrollPhysics(), children: [
          Container(
            decoration: iosCard(p, r: 22),
            child: _row(p, icon: Icons.mark_email_read_rounded, title: 'قراءة رسائل البنك', sub: 'تُقرأ الرسائل الجديدة من البنوك والمحافظ فقط', last: true,
                trailing: Switch(value: t.enabled, activeTrackColor: kBlue, activeThumbColor: Colors.white, onChanged: (v) => _toggle(c, v)), onTap: () => _toggle(c, !t.enabled)),
          ),
          sectionLabel(p, 'تحتاج مراجعة'),
          Container(
            decoration: iosCard(p, r: 22),
            child: Column(children: [
              _row(p, icon: Icons.fact_check_rounded, title: 'مراجعة الرسائل', sub: rv == 0 ? 'لا شيء للمراجعة' : '${toAr('$rv')} عملية',
                  trailing: rv == 0 ? null : Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(12)), child: Text(toAr('$rv'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                  onTap: () => Navigator.of(c).push(flowRoute(const SmsReviewPage()))),
              _row(p, icon: Icons.history_rounded, title: 'السجل', sub: 'ما سُجّل وما استُبعد', onTap: () => Navigator.of(c).push(flowRoute(const SmsLogPage()))),
              _row(p, icon: Icons.label_rounded, title: 'الكلمات المتتبَّعة', sub: '${toAr('${t.wordCount}')} كلمة — أضف كلماتك أو عدّل كلماتنا', onTap: () => Navigator.of(c).push(flowRoute(const SmsWordsPage()))),
              _row(p, icon: Icons.manage_search_rounded, title: 'فحص آخر ٣٠ يومًا', sub: 'يقرأ الصندوق مرة واحدة ويمنع التكرار تلقائيًا', onTap: () => _scan(c), last: true),
            ]),
          ),
          sectionLabel(p, 'البطاقات والحسابات'),
          Container(
            decoration: iosCard(p, r: 22),
            child: Column(children: [
              for (final e in cards.entries)
                _row(p, icon: Icons.account_balance_rounded, title: 'بطاقة •••• ${e.key}', sub: _accName(e.value),
                    trailing: Tap(onTap: () => smsTracker.unlinkCard(e.key), child: Icon(Icons.close_rounded, color: p.ink2)), onTap: null),
              _row(p, icon: Icons.add_card_rounded, title: 'إضافة بطاقة', onTap: () => _addCard(c), last: true),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 18, 8, 0),
            child: Text('الرسائل تُقرأ على هاتفك فقط ولا تُرسل نصًا إلى أي خادم. رسائل الأشخاص ورموز التحقق تُتجاهل ولا تُحفظ. نص الرسائل التي تحتاج مراجعة يُحذف بمجرد البتّ فيها.', style: TextStyle(fontSize: 13, color: p.ink2, height: 1.5)),
          ),
        ]);
      }),
    );
  }
}

/// مراجعة الرسائل الملتبسة.
class SmsReviewPage extends StatelessWidget {
  const SmsReviewPage({super.key});

  Future<void> _approve(BuildContext c, Map<String, dynamic> e) async {
    final minor = (e['minor'] as num).toInt();
    if (minor <= 0) {
      toast(c, 'لا يوجد مبلغ واضح في هذه الرسالة. يمكنك تجاهلها وإضافة المعاملة يدويًا.');
      return;
    }
    var kind = '${e['kind']}';
    if (kind.isEmpty) {
      final k = await showSelect(c, 'نوع العملية', [for (final k in kSmsKinds) (k, tl(kSmsKindTitle[k]!))], 'purchase');
      if (k == null) return;
      kind = k;
    }
    if (!c.mounted) return;
    final acc = await showPickAccount(c, repo.defaultAcc, title: 'سجّلها على أي حساب؟');
    if (acc == null) return;
    smsTracker.approve('${e['id']}', acc, kind: kind);
    if ('${e['reason']}' == 'unknown_sender' && c.mounted) {
      final trust = await confirmDialog(c, 'الثقة بالمرسل', 'هل تريد اعتبار "${e['sender']}" مرسلًا موثوقًا لباقي الرسائل؟', ok: 'نعم، ثق به');
      if (trust) smsTracker.trustSender('${e['sender']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: 'مراجعة الرسائل',
      icon: Icons.fact_check_rounded,
      iconColor: kOrange,
      child: _live((c) {
        final l = smsTracker.review;
        if (l.isEmpty) return Center(child: Text('لا توجد رسائل تحتاج مراجعة ✓', style: TextStyle(color: p.ink2, fontSize: 16)));
        return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), physics: const BouncingScrollPhysics(), children: [
          for (final e in l)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: iosCard(p, r: 22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text((e['minor'] as num) > 0 ? money((e['minor'] as num) / 100, '${e['cur']}') : '—', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: kOrange.withValues(alpha: .18), borderRadius: BorderRadius.circular(12)), child: Text(_reason('${e['reason']}'), style: const TextStyle(fontSize: 12, color: kOrange))),
                ]),
                const SizedBox(height: 4),
                Text('${kSmsKindTitle['${e['kind']}'] != null ? tl(kSmsKindTitle['${e['kind']}']!) : '؟'} · ${e['sender']} · ${dateLabel(DateTime.fromMillisecondsSinceEpoch((e['ts'] as num).toInt()))}', style: TextStyle(fontSize: 13, color: p.ink2)),
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(12)), child: Text('${e['body']}', maxLines: 6, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.4))),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: Tap(onTap: () => _approve(c, e), child: Container(height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(20)), child: const Text('تسجيل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))))),
                  const SizedBox(width: 10),
                  Expanded(child: Tap(onTap: () => smsTracker.rejectReview('${e['id']}'), child: Container(height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(20)), child: const Text('تجاهل')))),
                ]),
              ]),
            ),
        ]);
      }),
    );
  }
}

/// سجل ما سُجّل وما استُبعد (بلا نص الرسائل).
class SmsLogPage extends StatelessWidget {
  const SmsLogPage({super.key});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: 'السجل',
      icon: Icons.history_rounded,
      iconColor: kBlue,
      trailing: Tap(onTap: smsTracker.clearLog, child: Icon(Icons.delete_outline_rounded, color: p.ink2)),
      child: _live((c) {
        final l = smsTracker.log;
        if (l.isEmpty) return Center(child: Text('لا يوجد سجل بعد', style: TextStyle(color: p.ink2, fontSize: 16)));
        IconData ic(String v) => v == 'accept' ? Icons.check_circle_rounded : v == 'review' ? Icons.help_rounded : v == 'dup' ? Icons.content_copy_rounded : Icons.block_rounded;
        Color cl(String v) => v == 'accept' ? kGreen : v == 'review' ? kOrange : p.ink2;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          physics: const BouncingScrollPhysics(),
          itemCount: l.length,
          itemBuilder: (c, i) {
            final e = l[i];
            final v = '${e['v']}';
            final d = DateTime.fromMillisecondsSinceEpoch((e['t'] as num).toInt());
            final amt = (e['m'] as num) > 0 ? ' · ${money((e['m'] as num) / 100, '${e['c']}')}' : '';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: iosCard(p, r: 18),
              child: Row(children: [
                Icon(ic(v), color: cl(v)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(v == 'dup' ? tl('مكررة — تم تجاهلها') : _reason('${e['r']}'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text('${e['s']}$amt · ${dateLabel(d)} ${timeLabel(d)}', style: TextStyle(fontSize: 12.5, color: p.ink2)),
                ])),
              ]),
            );
          },
        );
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

  Widget _add(Pal p, VoidCallback f) => Tap(onTap: f, child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: kBlue.withValues(alpha: .15), borderRadius: BorderRadius.circular(18)), child: const Text('+ إضافة', style: TextStyle(color: kBlue, fontSize: 14, fontWeight: FontWeight.w600))));

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
            if (await confirmDialog(c, 'إعادة الكلمات الافتراضية', 'ستُحذف تعديلاتك على الكلمات المتتبَّعة والمستبعدة.', ok: 'إعادة')) t.resetWords();
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
