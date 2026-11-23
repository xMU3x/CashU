export 'loans_page.dart' show LoansPage;
export 'goals_page.dart' show GoalsPage;
import '../ui/motion.dart';
import 'dart:async';
import 'package:material_ui/material_ui.dart' hide Text;
import '../ui/loc_text.dart';
import 'package:share_plus/share_plus.dart';
import '../core/currency.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/util.dart';
import '../ui/anim.dart';
import '../ui/sheets.dart';
import '../ui/ios.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'add_tx.dart';
import '../ui/pay_widgets.dart';
import '../core/extras.dart';
import '../ui/ai_assistant.dart' show AiEntry, aiParseEntries, aiResolveAccount;

// ======================= كشف / عرض الكل (السحب بين الشهور) =======================
class TxListPage extends StatefulWidget {
  final String? accId;
  final String title;
  const TxListPage({super.key, this.accId, this.title = 'كل المعاملات'});
  @override
  State<TxListPage> createState() => _TxListState();
}

class _TxListState extends State<TxListPage> {
  final pc = PageController();
  int back = 0;
  DateTime _m(int b) => DateTime(DateTime.now().year, DateTime.now().month - b);

  @override
  void dispose() {
    pc.dispose();
    super.dispose();
  }

  void _share() {
    final m = _m(back);
    final list = repo.inMonth(m.year, m.month, acc: widget.accId).toList();
    final b = StringBuffer('كشف ${widget.title} — ${kMonths[m.month - 1]} ${toAr('${m.year}')}\n');
    for (final t in list) {
      b.writeln('${dateLabel(t.date)} | ${txTitle(t)} | ${t.type == 'inc' ? '+' : '-'}${fmt(t.amt)} ${curOf(t.cur).sym}');
    }
    b.writeln('المصروف: ${money(repo.spent(m.year, m.month, acc: widget.accId))}  الدخل: ${money(repo.income(m.year, m.month, acc: widget.accId))}');
    Share.share(b.toString());
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final m = _m(back);
    return PageShell(
      title: widget.title,
      sub: '${kMonths[m.month - 1]} ${toAr('${m.year}')} · اسحب للتنقل بين الشهور',
      swipeBack: false,
      trailing: RoundBtn(Icons.ios_share_rounded, _share),
      child: Live(b: (c) => PageView.builder(
            reverse: true,
            controller: pc,
            itemCount: 24,
            onPageChanged: (i) => setState(() => back = i),
            itemBuilder: (c, i) {
              final mm = _m(i);
              final list = repo.inMonth(mm.year, mm.month, acc: widget.accId).toList();
              if (list.isEmpty) { return ListView(children: [emptyState(p, Icons.calendar_month_rounded, 'لا معاملات في هذا الشهر')]); }
              final groups = <String, List<Tx>>{};
              for (final t in list) {
                groups.putIfAbsent('${t.date.day}', () => []).add(t);
              }
              return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), physics: const BouncingScrollPhysics(), children: [
                Row(children: [
                  Expanded(child: Container(padding: const EdgeInsets.all(14), decoration: cardDeco(p, r: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('المصروف', style: TextStyle(color: p.ink2)), CountText(repo.spent(mm.year, mm.month, acc: widget.accId), dec: 0, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700))]))),
                  const SizedBox(width: 10),
                  Expanded(child: Container(padding: const EdgeInsets.all(14), decoration: cardDeco(p, r: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('الدخل', style: TextStyle(color: p.ink2)), CountText(repo.income(mm.year, mm.month, acc: widget.accId), dec: 0, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: kInc))]))),
                ]),
                for (final g in groups.entries) ...[
                  sectionLabel(p, dayLabel(g.value.first.date)),
                  for (var k = 0; k < g.value.length; k++) Reveal(i: k, child: SwipeTx(g.value[k], showAcc: widget.accId == null, onEdit: (t) => Navigator.of(context).push(flowRoute(AddTxPage(edit: t))))),
                ],
              ]);
            },
          )),
    );
  }
}

// ======================= المصاريف المتكررة =======================
/// المتكرر ما بيتسجّل في المعاملات غير لما تدفعه فعلًا. كل تكرار مستحق ليه: دفع (بانل الدفع الموحّدة) · تخطّي · تعديل · إيقاف.
class RecurringPage extends StatelessWidget {
  const RecurringPage({super.key});

  void _pay(BuildContext context, Tx t) {
    final due = DateTime.fromMillisecondsSinceEpoch(repo.recurringDue(t));
    showPayPanel(
      context,
      title: 'دفع مصروف متكرر',
      subtitle: txTitle(t),
      amount: t.amt,
      acc: t.acc.isEmpty ? repo.defaultAcc : t.acc,
      amountLabel: 'المبلغ',
      date: due.isAfter(DateTime.now()) ? DateTime.now() : due,
      saveLabel: 'ادفع',
      onSave: (r) {
        final err = repo.payRecurring(t.id, amt: r.amt, acc: r.acc, ts: r.date.millisecondsSinceEpoch);
        if (err == null) toast(context, 'اتسجّل الدفع في المعاملات');
        return err;
      },
      onSkip: (r) {
        repo.skipRecurring(t.id);
        toast(context, 'اتخطّى التكرار ده من غير تسجيل');
      },
      onLink: (panel) async {
        final nav = Navigator.of(panel);
        final x = await pickTxToLink(panel, (x) => !extras.isLinked(x.id) && x.src != t.id);
        if (x == null) return;
        repo.skipRecurring(t.id); // المعاملة القديمة هي الدفع؛ نقدّم الميعاد من غير معاملة جديدة
        nav.pop();
        if (context.mounted) toast(context, 'تم ربط المعاملة وتقديم الميعاد');
      },
    );
  }

  void _menu(BuildContext context, Tx t) => showPillMenu(context, [
        ('تعديل', () => Navigator.of(context).push(sheetRoute(AddTxPage(edit: t)))),
        ('تخطّي التكرار الجاي', () => repo.skipRecurring(t.id)),
        ('إيقاف التكرار', () {
          repo.saveTx(t.clone()..rep = 'none');
          toast(context, 'اتوقف التكرار', actionLabel: 'تراجع', onAction: () => repo.saveTx(t.clone()));
        }),
        ('حذف', () {
          repo.delTx(t.id);
          toast(context, 'تم حذف المعاملة', actionLabel: 'تراجع', onAction: () => repo.restoreTx(t.id));
        }),
      ], danger: {'حذف', 'إيقاف التكرار'});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: 'المصاريف المتكررة',
      icon: Icons.autorenew_rounded,
      trailing: Tap(onTap: () => Navigator.of(context).push(sheetRoute(const AddTxPage())), child: Container(width: 40, height: 40, decoration: BoxDecoration(color: p.acc, shape: BoxShape.circle), child: const Icon(Icons.add_rounded, color: Colors.white, size: 24))),
      child: Live(b: (c) {
        final list = repo.recurring..sort((a, b) => repo.recurringDue(a).compareTo(repo.recurringDue(b)));
        if (list.isEmpty) { return ListView(children: [emptyState(p, Icons.autorenew_rounded, 'لا توجد معاملات متكررة.\nعند إضافة مصروف اختر «تكرار المعاملة».')]); }
        final now = DateTime.now().millisecondsSinceEpoch;
        return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 110), physics: const BouncingScrollPhysics(), children: [
          for (var i = 0; i < list.length; i++)
            Builder(builder: (_) {
              final t = list[i];
              final dueMs = repo.recurringDue(t);
              final late = dueMs <= now;
              final days = DateTime.fromMillisecondsSinceEpoch(dueMs).difference(DateTime.now()).inDays;
              final status = late ? 'مستحق · ${dateLabel(DateTime.fromMillisecondsSinceEpoch(dueMs))}' : 'التالي ${dateLabel(DateTime.fromMillisecondsSinceEpoch(dueMs))} · بعد ${toAr('$days')} يوم';
              final ic = txIcon(t);
              return Reveal(
                i: i,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  decoration: BoxDecoration(color: late ? kOrange.withValues(alpha: .10) : p.card, borderRadius: BorderRadius.circular(22), border: late ? Border.all(color: kOrange.withValues(alpha: .4)) : null),
                  child: Row(children: [
                    iconBubble(p, ic.$1, color: ic.$2),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(txTitle(t), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${repName(t.rep)} · $status', maxLines: 2, style: TextStyle(color: late ? kOrange : p.ink2, fontSize: 12.5)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${fmt(t.amt)} ${curOf(t.cur).sym}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Tap(
                        scale: .94,
                        onTap: () => _pay(context, t),
                        child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: late ? kBlue : kBlue.withValues(alpha: .15), borderRadius: BorderRadius.circular(16)), child: Text('ادفع', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: late ? Colors.white : kBlue))),
                      ),
                    ]),
                    Tap(onTap: () => _menu(context, t), child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.more_vert_rounded, color: p.ink2, size: 20))),
                  ]),
                ),
              );
            }),
          Center(child: Padding(padding: const EdgeInsets.only(top: 8), child: Text('المتكرر بيتسجّل في المعاملات لما تدفعه بس.', style: TextStyle(color: p.ink2.withValues(alpha: .7), fontSize: 12)))),
        ]);
      }),
    );
  }
}

// ======================= أسعار الصرف =======================
class RatesPage extends StatelessWidget {
  const RatesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(underBar: true, 
      title: 'أسعار الصرف',
      sub: 'مقابل ${curOf(S.cur).name}',
      icon: Icons.currency_exchange_rounded,
      trailing: AnimatedBuilder(animation: rates, builder: (c, _) => rates.loading ? const SizedBox(width: 44, height: 44, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2.5))) : RoundBtn(Icons.refresh_rounded, rates.refresh)),
      child: AnimatedBuilder(
        animation: rates,
        builder: (c, _) => ListView(padding: EdgeInsets.fromLTRB(16, barTop(context) + 4, 16, 40), children: [
          for (var i = 0; i < kCurs.length; i++)
            if (kCurs[i].code != S.cur)
              Reveal(
                i: i ~/ 2,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: cardDeco(p, r: 20),
                  child: Row(children: [
                    Text(kCurs[i].flag, style: const TextStyle(fontSize: 30)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(kCurs[i].name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
                    Text('1 ${kCurs[i].code} = ${fmt(rates.rate(kCurs[i].code, S.cur), dec: 3)} ${curOf(S.cur).sym}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
          Center(child: Text(rates.updated == 0 ? 'أسعار تقريبية — اضغط تحديث' : 'آخر تحديث: ${dateLabel(DateTime.fromMillisecondsSinceEpoch(rates.updated))}', style: TextStyle(color: p.ink2, fontSize: 12))),
        ]),
      ),
    );
  }
}

// ======================= حسّاب (رؤى ذكية محلية) =======================
class FlowAIPage extends StatefulWidget {
  const FlowAIPage({super.key});
  @override
  State<FlowAIPage> createState() => _FlowAIState();
}

class _FlowAIState extends State<FlowAIPage> {
  List<String> get _insights {
    final now = DateTime.now();
    final y = now.year, m = now.month;
    final spent = repo.spent(y, m), prev = repo.spent(m == 1 ? y - 1 : y, m == 1 ? 12 : m - 1);
    final out = <String>[];
    if (spent == 0) {
      out.add('لم تسجّل مصروفات هذا الشهر بعد. ابدأ بإضافة أول مصروف وسأحلل عاداتك.');
      return out;
    }
    final proj = spent / now.day * daysIn(y, m);
    out.add('بمعدلك الحالي سينتهي الشهر بإنفاق ≈ ${money(proj)}.');
    final cats = repo.byCat(y, m);
    if (cats.isNotEmpty) { out.add('أكبر بند عندك: ${catOf(cats.first.key).name} بنسبة ${toAr('${(cats.first.value / spent * 100).round()}')}٪ من مصروفك.'); }
    if (prev > 0) {
      final ch = (spent - prev) / prev * 100;
      out.add(ch > 0 ? 'أنفقت أكثر من الشهر الماضي بنسبة ${toAr('${ch.round()}')}٪' : 'أنفقت أقل من الشهر الماضي بنسبة ${toAr('${(-ch).round()}')}٪');
    }
    final daily = repo.daily(y, m);
    final zero = daily.take(now.day).where((v) => v == 0).length;
    out.add('عدد الأيام بلا إنفاق: ${toAr('$zero')} من ${toAr('${now.day}')}.');
    final a = repo.accList.first;
    final al = repo.allowance(a, now);
    if (repo.budgetFor(a).limit > 0) { out.add(al >= 0 ? 'تقدر تصرف ${fmt(al, dec: 0)} يومياً حتى آخر الشهر بدون تجاوز الميزانية.' : 'تجاوزت الميزانية — حاول تأجيل المصروفات غير الضرورية.'); }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final ins = _insights;
    return PageShell(underBar: true, 
      title: 'حسّاب',
      sub: 'رؤى ذكية من بياناتك',
      icon: Icons.auto_awesome_rounded,
      iconColor: const Color(0xFF6D3FD0),
      child: ListView(padding: EdgeInsets.fromLTRB(16, barTop(context) + 8, 16, 40), children: [
        for (var i = 0; i < ins.length; i++)
          Reveal(
            i: i * 3,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF6D3FD0).withValues(alpha: .18))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6D3FD0), size: 22),
                const SizedBox(width: 12),
                Expanded(child: _Typewriter(ins[i], delay: CashUMotion.typeLine * i)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _Typewriter extends StatefulWidget {
  final String text;
  final Duration delay;
  const _Typewriter(this.text, {this.delay = Duration.zero});
  @override
  State<_Typewriter> createState() => _TypewriterState();
}

class _TypewriterState extends State<_Typewriter> {
  int n = 0;
  Timer? t;
  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (!mounted) return;
      t = Timer.periodic(CashUMotion.typeStep, (tm) {
        if (n >= widget.text.length) {
          tm.cancel();
        } else if (mounted) {
          setState(() => n++);
        }
      });
    });
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        Opacity(opacity: 0, child: Text(widget.text, style: const TextStyle(fontSize: 16, height: 1.6))),
        Text(widget.text.substring(0, n), style: const TextStyle(fontSize: 16, height: 1.6)),
      ]);
}

// ======================= تحدث / دوّن: إدخال ذكي =======================
({double amt, String cur, bool inc, String cat}) parseSmart(String raw) {
  final s = normDigits(raw);
  final m = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(s);
  final amt = m == null ? 0.0 : double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0.0;
  var cur = S.cur;
  if (RegExp(r'دولار|\$|usd').hasMatch(s.toLowerCase())) cur = 'USD';
  if (RegExp(r'يورو|€').hasMatch(s)) cur = 'EUR';
  if (RegExp(r'ريال سعودي').hasMatch(s)) cur = 'SAR';
  if (RegExp(r'درهم').hasMatch(s)) cur = 'AED';
  final inc = RegExp(r'استلمت|قبضت|دخل|مرتب|راتب|ربحت|جاني|جالي|حوّلولي|حولولي').hasMatch(s);
  const kw = {
    'bills': 'فاتورة|كهرباء|مياه|غاز|انترنت|إنترنت|نت ',
    'food': 'اكل|أكل|غداء|عشاء|فطار|قهوة|مطعم|بقالة|سوبر|شاي|عصير',
    'transport': 'بنزين|اوبر|أوبر|تاكسي|مواصلات|ميكروباص|مترو|سولار',
    'shop': 'ملابس|هدوم|جزمة|تسوق|شراء',
    'health': 'دواء|دوا|دكتور|صيدلية|كشف|علاج',
    'fun': 'سينما|فيلم|لعبة|خروجة|رحلة',
    'edu': 'كورس|مدرسة|جامعة|كتاب|دروس',
    'home': 'ايجار|إيجار|صيانة|اثاث|أثاث',
  };
  var cat = inc ? 'other_i' : 'other';
  if (!inc) {
    for (final e in kw.entries) {
      if (RegExp(e.value).hasMatch(s)) {
        cat = e.key;
        break;
      }
    }
  } else if (RegExp(r'راتب|مرتب').hasMatch(s)) {
    cat = 'salary';
  }
  return (amt: amt, cur: cur, inc: inc, cat: cat);
}

Future<void> showSmartEntry(BuildContext context, {bool quick = false}) => showSheet<void>(context, (c) => _SmartSheet(quick: quick));

class _SmartSheet extends StatefulWidget {
  final bool quick;
  const _SmartSheet({required this.quick});
  @override
  State<_SmartSheet> createState() => _SmartState();
}

class _SmartState extends State<_SmartSheet> {
  final ctl = TextEditingController();
  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final r = parseSmart(ctl.text);
    final ok = r.amt > 0;
    return SheetFrame(
      title: widget.quick ? 'دوّن' : 'تحدث',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.quick ? 'اكتب سطرًا واحدًا وأنا أرتّبه: «قهوة 45»' : 'اكتب أو أملِ بالميكروفون في الكيبورد: «دفعت 120 جنيه على الغداء»', textAlign: TextAlign.center, style: TextStyle(color: p.ink2, height: 1.6)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(24)),
            child: TextField(controller: ctl, autofocus: true, minLines: 1, maxLines: 3, onChanged: (_) => setState(() {}), decoration: InputDecoration(border: InputBorder.none, hintText: 'مثال: استلمت راتب 8000', hintStyle: TextStyle(color: p.ink2.withValues(alpha: .6)))),
          ),
          AnimatedSize(
            duration: CashUMotion.expand,
            curve: CashUMotion.curve,
            child: ok
                ? Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: (r.inc ? kInc : p.acc).withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      Icon(catIcon(r.cat).$1, size: 28, color: catIcon(r.cat).$2),
                      const SizedBox(width: 12),
                      Expanded(child: Text('${r.inc ? 'دخل' : 'مصروف'} · ${catOf(r.cat).name}', style: const TextStyle(fontWeight: FontWeight.w700))),
                      Text('${fmt(r.amt)} ${curOf(r.cur).sym}', style: TextStyle(fontWeight: FontWeight.w800, color: r.inc ? kInc : p.acc)),
                    ]),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 14),
          bigButton(p, 'حفظ', ok ? (r.inc ? kInc : p.acc) : p.ink2, () {
            if (!ok) return;
            final note = ctl.text.replaceAll(RegExp(r'[0-9٠-٩.,]+'), '').replaceAll(RegExp(r'(دفعت|جنيه|ج\.م|على|دولار|يورو|استلمت|قبضت)'), '').trim();
            repo.saveTx(Tx(
              id: uid(), type: r.inc ? 'inc' : 'exp', amt: r.amt, cur: r.cur, rate: r.cur == S.cur ? 1 : rates.rate(r.cur, S.cur),
              acc: repo.defaultAcc, cat: r.cat, note: note, ts: DateTime.now().millisecondsSinceEpoch,
            ));
            Navigator.of(context).pop();
            toast(context, 'تم الحفظ ✓');
          }),
        ]),
      ),
    );
  }
}


// ======================= اكتب اللي صرفته (عدة بنود دفعة واحدة) =======================
/// يقسّم النص إلى بنود: سطر جديد، «،»، «؛»، أو «و» قبل رقم ("500 اكل و 200 مواصلات").
List<String> splitSpent(String raw) {
  final s = normDigits(raw);
  return s
      .split(RegExp(r'[\n\r]+|[،؛;]+|(?:^|\s)و\s*(?=\d)|\s\+\s'))
      .map((e) => e.trim())
      .where((e) => RegExp(r'\d').hasMatch(e))
      .toList();
}

Future<void> showWriteSpent(BuildContext context) => showSheet<void>(context, (c) => const _WriteSpentSheet());

class _WriteSpentSheet extends StatefulWidget {
  const _WriteSpentSheet();
  @override
  State<_WriteSpentSheet> createState() => _WriteSpentState();
}

/// «اكتب اللي صرفته»: الذكاء الاصطناعي بيحلل النص (بنود، تصنيف، والحساب من كلام المستخدم نفسه: «50 سجق كاش» ← أكل من حساب الكاش)
/// قبل أي حفظ. مفيش حساب افتراضي: البند اللي حسابه مش واضح بيتعلّم والمستخدم يختاره. لو الـ AI مش متاح بيتحلل محليًا.
class _WriteSpentState extends State<_WriteSpentSheet> {
  final ctl = TextEditingController();
  List<AiEntry> items = [];
  bool analyzing = false, analyzed = false;

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  String _note(String line) => line
      .replaceAll(RegExp(r'[0-9.,]+'), '')
      .replaceAll(RegExp(r'(دفعت|جنيه|ج\.م|على|دولار|يورو|استلمت|قبضت)'), '')
      .replaceAll(RegExp(r'(^|\s)(كاش|نقدي|نقدا|نقد|cash)(?=\s|$)', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// تحليل محلي احتياطي (أوفلاين أو الدالة قديمة): نفس المنطق القديم + استنتاج الحساب من كلمات السطر.
  List<AiEntry> _local(String text) => [
        for (final l in splitSpent(text))
          if (parseSmart(l).amt > 0)
            () {
              final r = parseSmart(l);
              return AiEntry(inc: r.inc, amt: r.amt, cat: r.cat, note: _note(l), cur: r.cur, acc: aiResolveAccount('', line: l) ?? '');
            }(),
      ];

  Future<void> _analyze() async {
    final text = ctl.text.trim();
    if (text.isEmpty || analyzing) return;
    setState(() => analyzing = true);
    final ai = await aiParseEntries(context, text);
    if (!mounted) return;
    final res = ai ?? _local(text);
    setState(() {
      items = res;
      analyzing = false;
      analyzed = true;
    });
    if (ai == null) toast(context, 'اتحلّل على الجهاز — الذكاء الاصطناعي مش متاح دلوقتي');
  }

  Future<void> _pick(AiEntry e) async {
    final r = await showPickAccount(context, e.acc);
    if (r != null && mounted) setState(() => e.acc = r);
  }

  Future<void> _pickAllUnset() async {
    final r = await showPickAccount(context, '');
    if (r == null || !mounted) return;
    setState(() {
      for (final e in items) {
        if (e.acc.isEmpty) e.acc = r;
      }
    });
  }

  void _save() {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < items.length; i++) {
      final e = items[i];
      repo.saveTx(Tx(
        id: uid(), type: e.inc ? 'inc' : 'exp', amt: e.amt, cur: e.cur, rate: e.cur == S.cur ? 1 : rates.rate(e.cur, S.cur),
        acc: e.acc, cat: e.cat, note: e.note, ts: now - i, src: 'write',
      ));
    }
    Navigator.of(context).pop();
    toast(context, 'تم تسجيل ${toAr('${items.length}')} معاملة');
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final unset = items.where((e) => e.acc.isEmpty).length;
    final total = items.fold(0.0, (a, e) => a + (e.inc ? 0 : e.amt));
    final canSave = analyzed && items.isNotEmpty && unset == 0;
    return SheetFrame(
      title: 'اكتب اللي صرفته',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('اكتب كل مصاريفك مرة واحدة بأي شكل: «50 سجق كاش و 200 مواصلات CIB». الذكاء الاصطناعي بيفصل كل بند ويحدد التصنيف والحساب من كلامك قبل ما يتسجّل أي حاجة.', textAlign: TextAlign.center, style: TextStyle(color: p.ink2, height: 1.6, fontSize: 14)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(20)),
            child: TextField(
              controller: ctl,
              autofocus: true,
              minLines: 5,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              onChanged: (_) {
                if (analyzed) {
                  setState(() {
                    analyzed = false;
                    items = [];
                  });
                }
              },
              decoration: InputDecoration(border: InputBorder.none, hintText: '50 سجق كاش\n200 مواصلات\n100 قهوة فودافون كاش', hintStyle: TextStyle(color: p.ink2.withValues(alpha: .7))),
            ),
          ),
          AnimatedSize(
            duration: CashUMotion.expand,
            curve: CashUMotion.curve,
            child: items.isEmpty
                ? SizedBox(
                    width: double.infinity,
                    child: analyzed ? Padding(padding: const EdgeInsets.only(top: 12), child: Text('مقدرتش ألاقي بنود فيها مبلغ. جرّب تكتبها بشكل تاني.', textAlign: TextAlign.center, style: TextStyle(color: p.ink2))) : null,
                  )
                : Column(children: [
                    const SizedBox(height: 10),
                    for (final e in items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          iconBubble(p, catIcon(e.cat).$1, size: 38, color: catIcon(e.cat).$2),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(e.note.isEmpty ? catOf(e.cat).name : e.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Tap(
                                onTap: () => _pick(e),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Flexible(child: Text('${catOf(e.cat).name} · ${e.acc.isEmpty ? 'اختر الحساب' : (repo.account(e.acc)?.name ?? 'اختر الحساب')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: e.acc.isEmpty ? p.acc : p.ink2, fontWeight: e.acc.isEmpty ? FontWeight.w700 : FontWeight.w400))),
                                  const SizedBox(width: 4),
                                  Icon(Icons.expand_more_rounded, size: 16, color: e.acc.isEmpty ? p.acc : p.ink2),
                                ]),
                              ),
                            ]),
                          ),
                          Text('${e.inc ? '+' : '-'}${fmt(e.amt)} ${curOf(e.cur).sym}', style: TextStyle(fontWeight: FontWeight.w700, color: e.inc ? kInc : p.ink)),
                          Tap(onTap: () => setState(() => items.remove(e)), child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.close_rounded, size: 18, color: p.ink2))),
                        ]),
                      ),
                    if (unset >= 2)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Tap(
                          onTap: _pickAllUnset,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: p.acc.withValues(alpha: .5))),
                            child: Text('حدّد حساب لـ ${toAr('$unset')} بنود مش واضح حسابها', style: TextStyle(color: p.acc, fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                        ),
                      ),
                  ]),
          ),
          const SizedBox(height: 12),
          if (!analyzed)
            bigButton(p, analyzing ? 'بحلّل…' : 'حلّل بالذكاء الاصطناعي', ctl.text.trim().isEmpty || analyzing ? p.ink2 : p.acc, _analyze)
          else
            bigButton(p, items.isEmpty ? 'حفظ' : (unset > 0 ? 'اختر حساب البنود المعلّمة الأول' : 'حفظ ${toAr('${items.length}')} معاملة (${fmt(total)})'), canSave ? p.acc : p.ink2, () {
              if (canSave) _save();
            }),
        ]),
      ),
    );
  }
}
