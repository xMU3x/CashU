export 'loans_page.dart' show LoansPage;
import '../ui/motion.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
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
class RecurringPage extends StatelessWidget {
  const RecurringPage({super.key});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    const names = {'daily': 'يومياً', 'weekly': 'أسبوعياً', 'monthly': 'شهرياً'};
    return PageShell(
      title: 'المصاريف المتكررة',
      icon: Icons.autorenew_rounded,
      trailing: Tap(onTap: () => Navigator.of(context).push(sheetRoute(const AddTxPage())), child: Container(width: 40, height: 40, decoration: BoxDecoration(color: p.acc, shape: BoxShape.circle), child: const Icon(Icons.add_rounded, color: Colors.white, size: 24))),
      child: Stack(fit: StackFit.expand, children: [Live(b: (c) {
        final list = repo.recurring;
        if (list.isEmpty) { return ListView(children: [emptyState(p, Icons.autorenew_rounded, 'لا توجد معاملات متكررة.\nعند إضافة مصروف اختر «تكرار المعاملة».')]); }
        return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 110), children: [
          for (var i = 0; i < list.length; i++)
            Reveal(
              i: i,
              child: Dismissible(
                key: ValueKey(list[i].id),
                background: Container(margin: const EdgeInsets.symmetric(vertical: 5), alignment: AlignmentDirectional.centerStart, padding: const EdgeInsets.symmetric(horizontal: 24), decoration: BoxDecoration(color: const Color(0xFFC0392B), borderRadius: BorderRadius.circular(22)), child: const Icon(Icons.stop_circle_rounded, color: Colors.white)),
                onDismissed: (_) {
                  final t = list[i].clone()..rep = 'none';
                  repo.saveTx(t);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  padding: const EdgeInsets.all(14),
                  decoration: cardDeco(p, r: 22),
                  child: Row(children: [
                    iconBubble(p, txIcon(list[i]).$1, color: txIcon(list[i]).$2),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(txTitle(list[i]), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), Text('${names[list[i].rep] ?? ''} · التالي ${dateLabel(DateTime.fromMillisecondsSinceEpoch(list[i].nx))}', style: TextStyle(color: p.ink2, fontSize: 13))])),
                    Text('${fmt(list[i].amt)} ${curOf(list[i].cur).sym}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            ),
          Center(child: Text('اسحب لإيقاف التكرار', style: TextStyle(color: p.ink2.withValues(alpha: .7), fontSize: 12))),
        ]);
      }),
      ]),
    );
  }
}

// ======================= أسعار الصرف =======================
class RatesPage extends StatelessWidget {
  const RatesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: 'أسعار الصرف',
      sub: 'مقابل ${curOf(S.cur).name}',
      icon: Icons.currency_exchange_rounded,
      trailing: AnimatedBuilder(animation: rates, builder: (c, _) => rates.loading ? const SizedBox(width: 44, height: 44, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2.5))) : RoundBtn(Icons.refresh_rounded, rates.refresh)),
      child: AnimatedBuilder(
        animation: rates,
        builder: (c, _) => ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
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

// ======================= أهدافي =======================
class GoalsPage extends StatelessWidget {
  const GoalsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: 'أهدافي',
      icon: Icons.track_changes_rounded,
      trailing: RoundBtn(Icons.add_rounded, () async {
        final n = await promptText(context, 'اسم الهدف', hint: 'مثال: لابتوب جديد');
        if (n == null || n.isEmpty) return;
        final t = await promptText(context, 'المبلغ المستهدف', hint: '0', number: true);
        final v = double.tryParse(normDigits(t ?? ''));
        if (v == null || v <= 0) return;
        repo.saveGoal(Goal(id: uid(), name: n, target: v));
      }),
      child: Live(b: (c) {
        final list = repo.goalList;
        if (list.isEmpty) { return ListView(children: [emptyState(p, Icons.flag_rounded, 'أضف هدفك الأول واستمر في التوفير نحوه.')]); }
        return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
          for (var i = 0; i < list.length; i++)
            Reveal(
              i: i,
              child: Dismissible(
                key: ValueKey(list[i].id),
                onDismissed: (_) {
                  final g = list[i]..del = true;
                  repo.saveGoal(g);
                },
                background: Container(margin: const EdgeInsets.symmetric(vertical: 5), decoration: BoxDecoration(color: const Color(0xFFC0392B), borderRadius: BorderRadius.circular(24))),
                child: Tap(
                  scale: .98,
                  onTap: () async {
                    final r = await promptText(context, 'إضافة مبلغ إلى «${list[i].name}»', hint: '0', number: true);
                    final v = double.tryParse(normDigits(r ?? ''));
                    if (v == null) return;
                    list[i].saved = math.max(0, list[i].saved + v);
                    repo.saveGoal(list[i]);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(18),
                    decoration: cardDeco(p, r: 24),
                    child: Row(children: [
                      SizedBox(
                        width: 74,
                        height: 74,
                        child: SpringValue(
                          value: (list[i].saved / list[i].target).clamp(0.0, 1.0),
                          builder: (c, v) => Stack(alignment: Alignment.center, children: [
                            CircularProgressIndicator(value: v, strokeWidth: 8, strokeCap: StrokeCap.round, backgroundColor: p.field, valueColor: const AlwaysStoppedAnimation(kInc)),
                            Icon(Icons.flag_rounded, size: 26, color: kBlue),
                          ]),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(list[i].name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)), Text('${fmt(list[i].saved, dec: 0)} من ${fmt(list[i].target, dec: 0)}', style: TextStyle(color: p.ink2))])),
                      Text('${toAr('${(list[i].saved / list[i].target * 100).clamp(0, 999).round()}')}٪', style: const TextStyle(fontWeight: FontWeight.w800, color: kInc)),
                    ]),
                  ),
                ),
              ),
            ),
          Center(child: Text('اضغط لإضافة مبلغ · اسحب للحذف', style: TextStyle(color: p.ink2.withValues(alpha: .7), fontSize: 12))),
        ]);
      }),
    );
  }
}

// ======================= فلو (رؤى ذكية محلية) =======================
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
      out.add(ch > 0 ? 'أنفقت أكثر من الشهر الماضي بنسبة ${toAr('${ch.round()}')}٪' : 'أنفقت أقل من الشهر الماضي بنسبة ${toAr('${(-ch).round()}')}٪ 👏');
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
    return PageShell(
      title: 'فلو',
      sub: 'رؤى ذكية من بياناتك',
      icon: Icons.auto_awesome_rounded,
      iconColor: const Color(0xFF6D3FD0),
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
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
                Expanded(child: _Typewriter(ins[i], delay: i * 450)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _Typewriter extends StatefulWidget {
  final String text;
  final int delay;
  const _Typewriter(this.text, {this.delay = 0});
  @override
  State<_Typewriter> createState() => _TypewriterState();
}

class _TypewriterState extends State<_Typewriter> {
  int n = 0;
  Timer? t;
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (!mounted) return;
      t = Timer.periodic(const Duration(milliseconds: 22), (tm) {
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
            duration: Motion.state,
            curve: Motion.standard,
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

class _WriteSpentState extends State<_WriteSpentSheet> {
  final ctl = TextEditingController();
  String acc = repo.defaultAcc;

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  String _note(String line) => line.replaceAll(RegExp(r'[0-9.,]+'), '').replaceAll(RegExp(r'(دفعت|جنيه|ج\.م|على|دولار|يورو|استلمت|قبضت)'), '').trim();

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final items = [for (final l in splitSpent(ctl.text)) (line: l, r: parseSmart(l))].where((e) => e.r.amt > 0).toList();
    final total = items.fold(0.0, (a, e) => a + (e.r.inc ? 0 : e.r.amt));
    return SheetFrame(
      title: 'اكتب اللي صرفته',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('اكتب كل مصاريفك مرة واحدة: «500 اكل و 200 مواصلات و 100 قهوة» أو كل بند في سطر — وكل بند يتسجّل معاملة منفصلة.', textAlign: TextAlign.center, style: TextStyle(color: p.ink2, height: 1.6, fontSize: 14)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(20)),
            child: TextField(controller: ctl, autofocus: true, minLines: 5, maxLines: 8, keyboardType: TextInputType.multiline, onChanged: (_) => setState(() {}), decoration: InputDecoration(border: InputBorder.none, hintText: '500 اكل\n200 مواصلات\n100 قهوة', hintStyle: TextStyle(color: p.ink2.withValues(alpha: .7)))),
          ),
          const SizedBox(height: 10),
          Tap(
            onTap: () async {
              final r = await showPickAccount(context, acc);
              if (r != null) setState(() => acc = r);
            },
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(16)), child: Row(children: [Icon(Icons.credit_card_rounded, color: p.ink2, size: 20), const SizedBox(width: 10), Expanded(child: Text(repo.account(acc)?.name ?? '—', style: const TextStyle(fontWeight: FontWeight.w600))), Icon(Icons.expand_more_rounded, color: p.ink2)])),
          ),
          AnimatedSize(
            duration: Motion.state,
            curve: Motion.standard,
            child: items.isEmpty
                ? const SizedBox(width: double.infinity)
                : Column(children: [
                    const SizedBox(height: 10),
                    for (final e in items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          iconBubble(p, catIcon(e.r.cat).$1, size: 36, color: catIcon(e.r.cat).$2),
                          const SizedBox(width: 10),
                          Expanded(child: Text('${catOf(e.r.cat).name}${_note(e.line).isEmpty ? '' : ' · ${_note(e.line)}'}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Text('${e.r.inc ? '+' : '-'}${fmt(e.r.amt)} ${curOf(e.r.cur).sym}', style: TextStyle(fontWeight: FontWeight.w700, color: e.r.inc ? kInc : p.ink)),
                        ]),
                      ),
                  ]),
          ),
          const SizedBox(height: 12),
          bigButton(p, items.isEmpty ? 'حفظ' : 'حفظ ${toAr('${items.length}')} معاملة (${fmt(total)})', items.isEmpty ? p.ink2 : p.acc, () {
            if (items.isEmpty) return;
            final now = DateTime.now().millisecondsSinceEpoch;
            for (var i = 0; i < items.length; i++) {
              final r = items[i].r;
              repo.saveTx(Tx(
                id: uid(), type: r.inc ? 'inc' : 'exp', amt: r.amt, cur: r.cur, rate: r.cur == S.cur ? 1 : rates.rate(r.cur, S.cur),
                acc: acc, cat: r.cat, note: _note(items[i].line), ts: now - i, src: 'write',
              ));
            }
            Navigator.of(context).pop();
            toast(context, 'تم تسجيل ${toAr('${items.length}')} معاملة');
          }),
        ]),
      ),
    );
  }
}
