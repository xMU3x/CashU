import 'dart:math' as math;
import 'package:material_ui/material_ui.dart' hide Text;
import '../ui/loc_text.dart';
import '../core/assets.dart';
import '../core/currency.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/util.dart';
import '../ui/ai_assistant.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/motion.dart';
import '../ui/pickers.dart';
import '../ui/sheets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'assets_page.dart';

// ======================= أهدافي (مُعاد بناؤها بلغة تصميم CashU) =======================
// القائمة ← إنشاء/تعديل هدف ← صفحة الهدف (إضافة/سحب مبلغ + رسم بياني + سجل) ← «احسب مدخراتي» من الأصول.

const List<String> _kGoalEmojis = [
  '🎯', '🏠', '🚗', '✈️', '💍', '🎓', '💻', '📱', '🏖️', '🛍️',
  '💰', '🏦', '🏥', '👶', '🎁', '🏋️', '📷', '🎮', '🛵', '⌚',
  '🧳', '🏕️', '🎸', '🐶', '🌱', '🕋', '📚', '🛋️', '⚽', '🍽️',
];

/// عدد الشهور المتبقية لحد تاريخ الهدف (٠ = بدون تاريخ / فات). أدنى قيمة ١ لو الهدف له تاريخ لسه جاي.
int _monthsLeft(Goal g) {
  if (g.due <= 0) return 0;
  final days = DateTime.fromMillisecondsSinceEpoch(g.due).difference(DateTime.now()).inDays;
  if (days < 0) return 0;
  return math.max(1, (days / 30).ceil());
}

String _monthYear(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${kMonths[d.month - 1]} ${d.year}';
}

/// جملة تحت اسم الهدف: المبلغ الشهري المطلوب للوصول في الموعد.
String _goalLine(Goal g) {
  final rem = math.max(0.0, g.target - g.saved);
  if (g.target > 0 && rem <= 0.004) return 'حققت هدفك 🎉';
  final m = _monthsLeft(g);
  if (g.due > 0 && m > 0) return 'ادّخر ${egp(rem / m)} شهريًا للوصول في ${_monthYear(g.due)}';
  if (g.due > 0) return 'فات موعد الهدف (${_monthYear(g.due)}) — المتبقي ${egp(rem)}';
  return 'المتبقي ${egp(rem)}';
}

double _frac(Goal g) => g.target <= 0 ? 0 : (g.saved / g.target).clamp(0.0, 1.0);

// ---------------------------------------------------------------------------------------------
// القائمة
// ---------------------------------------------------------------------------------------------
class GoalsPage extends StatelessWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      underBar: true,
      title: 'أهدافي',
      icon: Icons.flag_rounded,
      iconColor: kGreen,
      trailing: Tap(
        onTap: () => Navigator.of(context).push(sheetRoute(const GoalFormPage())),
        child: Container(width: 40, height: 40, decoration: BoxDecoration(color: p.acc, shape: BoxShape.circle), child: const Icon(Icons.add_rounded, color: Colors.white, size: 24)),
      ),
      child: Live(b: (c) {
        final list = repo.goalList;
        if (list.isEmpty) {
          return ListView(padding: EdgeInsets.fromLTRB(16, barTop(context) + 40, 16, 40), children: [emptyState(p, Icons.flag_rounded, 'أضف هدفك الأول واستمر في التوفير نحوه.')]);
        }
        return ListView(padding: EdgeInsets.fromLTRB(16, barTop(context) + 6, 16, 40), physics: const BouncingScrollPhysics(), children: [
          for (var i = 0; i < list.length; i++) Reveal(key: ValueKey('goal_${list[i].id}'), i: i, child: _card(context, p, list[i])),
        ]);
      }),
    );
  }

  Widget _card(BuildContext context, Pal p, Goal g) {
    final f = _frac(g);
    return Tap(
      scale: .985,
      onTap: () => Navigator.of(context).push(flowRoute(GoalDetailPage(id: g.id))),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(16),
        decoration: cardDeco(p, r: 24),
        child: Row(children: [
          SizedBox(
            width: 64,
            height: 64,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: f),
              duration: CashUMotion.fill,
              curve: CashUMotion.curve,
              builder: (c, v, _) => CustomPaint(painter: _RingPainter(v, p.field, kGreen, 7), child: Center(child: Text(g.emoji.isEmpty ? '🎯' : g.emoji, style: const TextStyle(fontSize: 26)))),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('${egp(g.saved)} من ${egp(g.target)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: p.ink2)),
              if (g.due > 0) Text(_monthYear(g.due), style: TextStyle(fontSize: 12, color: p.ink2)),
            ]),
          ),
          Text('${toAr('${(f * 100).round()}')}٪', style: TextStyle(fontWeight: FontWeight.w800, color: kGreen)),
        ]),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color track, color;
  final double stroke;
  _RingPainter(this.progress, this.track, this.color, this.stroke);
  @override
  void paint(Canvas canvas, Size s) {
    final r = Rect.fromLTWH(stroke / 2, stroke / 2, s.width - stroke, s.height - stroke);
    canvas.drawArc(r, 0, math.pi * 2, false, Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..color = track);
    if (progress > 0.001) {
      canvas.drawArc(r, -math.pi / 2, math.pi * 2 * progress, false, Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.progress != progress || o.track != track || o.color != color;
}

// ---------------------------------------------------------------------------------------------
// إنشاء / تعديل هدف
// ---------------------------------------------------------------------------------------------
class GoalFormPage extends StatefulWidget {
  final Goal? edit;
  const GoalFormPage({super.key, this.edit});
  @override
  State<GoalFormPage> createState() => _GoalFormState();
}

class _GoalFormState extends State<GoalFormPage> {
  final nameC = TextEditingController();
  String emoji = '🎯';
  double target = 0;
  DateTime? due;
  bool bad = false;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      nameC.text = e.name;
      emoji = e.emoji.isEmpty ? '🎯' : e.emoji;
      target = e.target;
      due = e.due > 0 ? DateTime.fromMillisecondsSinceEpoch(e.due) : null;
    }
  }

  @override
  void dispose() {
    nameC.dispose();
    super.dispose();
  }

  void _save() {
    final name = nameC.text.trim();
    if (name.isEmpty || target <= 0) {
      setState(() => bad = true);
      return;
    }
    final e = widget.edit;
    if (e == null) {
      repo.saveGoal(Goal(id: uid(), name: name, emoji: emoji, target: target, due: due?.millisecondsSinceEpoch ?? 0));
    } else {
      e
        ..name = name
        ..emoji = emoji
        ..target = target
        ..due = due?.millisecondsSinceEpoch ?? 0;
      repo.saveGoal(e);
    }
    Navigator.of(context).pop();
  }

  Future<void> _pickEmoji() async {
    final r = await showSheet<String>(context, (c) {
      final p = Pal.of(c);
      return SheetFrame(
        title: 'اختار أيقونة الهدف',
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Wrap(spacing: 10, runSpacing: 10, children: [
            for (final e in _kGoalEmojis)
              Tap(
                onTap: () => Navigator.of(c).pop(e),
                child: Container(width: 54, height: 54, alignment: Alignment.center, decoration: BoxDecoration(color: e == emoji ? p.acc.withValues(alpha: .2) : p.field, borderRadius: BorderRadius.circular(16), border: e == emoji ? Border.all(color: p.acc) : null), child: Text(e, style: const TextStyle(fontSize: 26))),
              ),
          ]),
        ),
      );
    });
    if (r != null && mounted) setState(() => emoji = r);
  }

  Widget _card(Pal p, String title, Widget child, {String? foot}) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(28)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          child,
          if (foot != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(foot, style: TextStyle(fontSize: 13, color: p.ink2, height: 1.4))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final editing = widget.edit != null;
    final m = due == null ? 0 : math.max(1, (due!.difference(DateTime.now()).inDays / 30).ceil());
    final already = widget.edit?.saved ?? 0;
    final per = (due != null && target > 0 && m > 0) ? math.max(0.0, target - already) / m : 0.0;
    return Scaffold(
      backgroundColor: p.bg,
      body: SheetPage(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(children: [
              RoundBtn(Icons.close_rounded, () => Navigator.of(context).pop(), size: 46),
              Expanded(child: Center(child: Text(editing ? 'تعديل الهدف' : 'هدف جديد', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)))),
              Tap(onTap: _save, child: Container(width: 46, height: 46, decoration: BoxDecoration(color: p.acc, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: Colors.white, size: 26))),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 30), physics: const BouncingScrollPhysics(), children: [
              Center(
                child: Tap(
                  onTap: _pickEmoji,
                  child: SizedBox(
                    width: 124,
                    height: 124,
                    child: Stack(alignment: Alignment.center, children: [
                      Container(width: 118, height: 118, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.line, width: 2)), child: Text(emoji, style: const TextStyle(fontSize: 56))),
                      PositionedDirectional(bottom: 4, start: 4, child: Container(width: 34, height: 34, decoration: BoxDecoration(color: p.field, shape: BoxShape.circle, border: Border.all(color: p.bg, width: 3)), child: Icon(Icons.edit_rounded, size: 16, color: p.ink))),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: nameC,
                textAlign: TextAlign.center,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                decoration: InputDecoration(border: InputBorder.none, hintText: 'اكتب اسم الهدف', hintStyle: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: bad && nameC.text.trim().isEmpty ? kRed : p.ink2.withValues(alpha: .6))),
              ),
              const SizedBox(height: 22),
              _card(
                p,
                'المبلغ المستهدف',
                Tap(
                  onTap: () async {
                    final r = await showCalc(context, target, S.cur);
                    if (r != null) setState(() => target = r < 0 ? 0 : r);
                  },
                  child: Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(20), border: bad && target <= 0 ? Border.all(color: kRed, width: 1.4) : null),
                    child: Row(children: [
                      Expanded(child: Text(target <= 0 ? '40,000' : fmt(target), style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: target <= 0 ? p.ink2.withValues(alpha: .6) : p.ink))),
                      Text(curOf(S.cur).sym, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
              _card(
                p,
                'تاريخ الهدف',
                Row(children: [
                  Expanded(
                    child: Tap(
                      onTap: () async {
                        final now = DateTime.now();
                        final d = await showDateSheet(context, due ?? now.add(const Duration(days: 180)), first: DateTime(now.year, now.month, now.day), title: 'تاريخ الهدف');
                        if (d != null && mounted) setState(() => due = d);
                      },
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(18)),
                        child: Row(children: [
                          Expanded(child: Text(due == null ? 'بدون تاريخ' : enDate(due!), style: TextStyle(fontSize: 17, color: due == null ? p.ink2 : p.ink, fontWeight: due == null ? FontWeight.w400 : FontWeight.w700))),
                          Icon(Icons.keyboard_arrow_down_rounded, color: p.ink2),
                        ]),
                      ),
                    ),
                  ),
                  if (due != null) ...[const SizedBox(width: 8), RoundBtn(Icons.close_rounded, () => setState(() => due = null), size: 46)],
                ]),
                foot: per > 0 ? 'محتاج تخصص حوالي ${egp(per)} كل شهر.' : 'نحسب لك المبلغ الذي تخصصه كل شهر.',
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// صفحة الهدف
// ---------------------------------------------------------------------------------------------
class GoalDetailPage extends StatefulWidget {
  final String id;
  const GoalDetailPage({super.key, required this.id});
  @override
  State<GoalDetailPage> createState() => _GoalDetailState();
}

class _GoalDetailState extends State<GoalDetailPage> {
  Goal? get _g {
    for (final g in repo.goalList) {
      if (g.id == widget.id) return g;
    }
    return null;
  }

  Widget _statCell(Pal p, String label, String value, Color c) => Expanded(
        child: Column(children: [
          Text(label, style: TextStyle(fontSize: 13, color: p.ink2)),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c))),
        ]),
      );

  Widget _btn(Pal p, String label, IconData ic, bool primary, VoidCallback f) => Expanded(
        child: Tap(
          onTap: f,
          child: Container(
            height: 54,
            decoration: BoxDecoration(color: primary ? Colors.white : p.card, borderRadius: BorderRadius.circular(27)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: primary ? Colors.black : p.ink)),
              const SizedBox(width: 8),
              Icon(ic, size: 20, color: primary ? Colors.black : p.ink),
            ]),
          ),
        ),
      );

  Future<void> _deleteEntry(Goal g, int i) async {
    final e = g.entries[i];
    if (!await confirmDialog(context, 'حذف الحركة', 'هتتشال من سجل الهدف ويتعدّل المدخر.')) return;
    g.entries.removeAt(i);
    g.saved = math.max(0, g.saved - e.amt);
    if (e.tx.isNotEmpty) repo.delTx(e.tx);
    repo.saveGoal(g);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: Live(b: (c) {
        final g = _g;
        if (g == null) {
          return SafeArea(child: Column(children: [Padding(padding: const EdgeInsets.all(16), child: Row(children: [GlassBtn(Icons.chevron_left_rounded, () => Navigator.of(context).maybePop(), size: 46)])), Expanded(child: emptyState(p, Icons.flag_rounded, 'الهدف ده اتحذف'))]));
        }
        final done = g.target > 0 && g.saved >= g.target - .004;
        return BlurEdges(
          top: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(children: [
              GlassBtn(Icons.chevron_left_rounded, () => Navigator.of(context).maybePop(), size: 46),
              const Spacer(),
              Glass(
                radius: 26,
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Tap(onTap: () => openAiChat(context, prompt: 'ساعدني أوصل لهدفي «${g.name}» (المستهدف ${fmt(g.target)}، المدخر ${fmt(g.saved)}). اقترح خطة ادخار واقعية بناءً على دخلي ومصاريفي.'), child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.auto_awesome_rounded, color: p.ink, size: 22))),
                  Tap(onTap: () => Navigator.of(context).push(sheetRoute(GoalFormPage(edit: g))), child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.edit_outlined, color: p.ink, size: 22))),
                  Tap(
                    onTap: () async {
                      if (!await confirmDialog(context, 'حذف الهدف', 'هيتحذف «${g.name}» وسجله. المعاملات اللي اتسجلت على الحسابات هتفضل زي ما هي.')) return;
                      g.del = true;
                      repo.saveGoal(g);
                      if (context.mounted) Navigator.of(context).maybePop();
                    },
                    child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.delete_outline_rounded, color: kRed, size: 22)),
                  ),
                ]),
              ),
            ]),
          ),
          body: (c2, inset) => ListView(padding: EdgeInsets.fromLTRB(16, inset.top + 14, 16, 40), physics: const BouncingScrollPhysics(), children: [
            Center(
              child: SizedBox(
                width: 210,
                height: 210,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: _frac(g)),
                  duration: CashUMotion.fill,
                  curve: CashUMotion.curve,
                  builder: (c, v, _) => CustomPaint(
                    painter: _RingPainter(v, p.card, kGreen, 14),
                    child: Center(child: Container(width: 156, height: 156, alignment: Alignment.center, decoration: BoxDecoration(color: p.field.withValues(alpha: .6), shape: BoxShape.circle), child: Text(g.emoji.isEmpty ? '🎯' : g.emoji, style: const TextStyle(fontSize: 70)))),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(child: Text(g.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800))),
            const SizedBox(height: 6),
            Center(child: Text(_goalLine(g), textAlign: TextAlign.center, style: TextStyle(fontSize: 14.5, color: done ? kGreen : p.ink2, height: 1.4))),
            const SizedBox(height: 22),
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _statCell(p, 'المدخر', egp(g.saved), kGreen),
                VerticalDivider(color: p.line, width: 1, thickness: 1.2),
                _statCell(p, 'المستهدف', egp(g.target), p.ink),
              ]),
            ),
            const SizedBox(height: 22),
            if (g.entries.length >= 2) ...[
              SizedBox(height: 170, child: _GoalChart(g: g, line: kGreen, grid: p.line, text: p.ink2)),
              const SizedBox(height: 18),
            ],
            if (g.entries.isEmpty)
              Row(children: [_btn(p, 'إضافة مبلغ', Icons.south_west_rounded, true, () => _open(context, g, false))])
            else
              Row(children: [
                _btn(p, 'إضافة مبلغ', Icons.south_west_rounded, true, () => _open(context, g, false)),
                const SizedBox(width: 10),
                _btn(p, 'سحب مبلغ', Icons.north_east_rounded, false, () => _open(context, g, true)),
              ]),
            sectionLabel(p, 'مدخرات تملكها بالفعل'),
            Tap(
              scale: .985,
              onTap: () => Navigator.of(context).push(flowRoute(GoalCalcPage(id: g.id))),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(26)),
                child: Row(children: [
                  Expanded(child: Text('احسب استثمارًا أو ذهبًا أو عقارًا', style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600))),
                  Icon(Icons.chevron_left_rounded, color: p.ink2),
                ]),
              ),
            ),
            sectionLabel(p, 'الإضافات'),
            Container(
              decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(26)),
              child: g.entries.isEmpty
                  ? Padding(padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18), child: Center(child: Text('المبالغ التي تضيفها ستظهر هنا.', style: TextStyle(color: p.ink2, fontSize: 15))))
                  : Column(children: [
                      for (var k = g.entries.length - 1; k >= 0; k--) _entryRow(p, g, k, k == 0),
                    ]),
            ),
          ]),
        );
      }),
    );
  }

  Widget _entryRow(Pal p, Goal g, int i, bool last) {
    final e = g.entries[i];
    final add = e.amt >= 0;
    final col = add ? kGreen : kRed;
    final d = DateTime.fromMillisecondsSinceEpoch(e.ts);
    return Tap(
      scale: .99,
      onTap: () => _deleteEntry(g, i),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: p.line.withValues(alpha: .6)))),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: col.withValues(alpha: .16), shape: BoxShape.circle), child: Icon(add ? Icons.add_rounded : Icons.remove_rounded, color: col, size: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.note.isNotEmpty ? e.note : (add ? 'أضفت' : 'سحبت'), style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
              Text('${d.day} ${kMonths[d.month - 1]}', style: TextStyle(fontSize: 13, color: p.ink2)),
            ]),
          ),
          Text(egp(e.amt.abs()), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: col)),
        ]),
      ),
    );
  }

  void _open(BuildContext context, Goal g, bool withdraw) => Navigator.of(context).push(sheetRoute(GoalAmountPage(id: g.id, withdraw: withdraw)));
}

/// رسم بياني لتراكم المدخر مع الوقت (مساحة ملوّنة تحت الخط).
class _GoalChart extends StatelessWidget {
  final Goal g;
  final Color line, grid, text;
  const _GoalChart({required this.g, required this.line, required this.grid, required this.text});

  List<List<double>> _pts() {
    final es = [...g.entries]..sort((a, b) => a.ts.compareTo(b.ts));
    var run = g.saved - es.fold(0.0, (s, e) => s + e.amt); // رصيد البداية قبل أول حركة (لو الهدف اتبدأ برصيد)
    final out = <List<double>>[[es.first.ts.toDouble() - 1, run.clamp(0.0, double.infinity)]];
    for (final e in es) {
      run += e.amt;
      out.add([e.ts.toDouble(), run.clamp(0.0, double.infinity)]);
    }
    out.add([DateTime.now().millisecondsSinceEpoch.toDouble().clamp(out.last[0], double.infinity), out.last[1]]);
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final pts = _pts();
    final hi = pts.map((e) => e[1]).reduce(math.max);
    final lo = pts.map((e) => e[1]).reduce(math.min);
    String d(double ms) {
      final x = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
      return '${x.day} ${kMonths[x.month - 1]}';
    }

    return Column(children: [
      Expanded(
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _ChartPainter(pts, line, grid))),
          PositionedDirectional(end: 0, top: 0, child: Text('الأعلى ${fmt(hi)}', style: TextStyle(fontSize: 11.5, color: text))),
          PositionedDirectional(end: 0, bottom: 0, child: Text('الأدنى ${fmt(lo)}', style: TextStyle(fontSize: 11.5, color: text))),
        ]),
      ),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(d(pts.first[0]), style: TextStyle(fontSize: 12, color: text)), Text(d(pts.last[0]), style: TextStyle(fontSize: 12, color: text))]),
    ]);
  }
}

class _ChartPainter extends CustomPainter {
  final List<List<double>> pts;
  final Color line, grid;
  _ChartPainter(this.pts, this.line, this.grid);
  @override
  void paint(Canvas canvas, Size s) {
    final t0 = pts.first[0], t1 = pts.last[0];
    final hi = pts.map((e) => e[1]).reduce(math.max), lo = pts.map((e) => e[1]).reduce(math.min);
    final span = (hi - lo).abs() < 0.0001 ? 1.0 : hi - lo;
    const padY = 14.0;
    Offset pt(List<double> e) => Offset(t1 == t0 ? 0 : (e[0] - t0) / (t1 - t0) * s.width, padY + (1 - (e[1] - lo) / span) * (s.height - padY * 2));
    final dash = Paint()..color = grid..strokeWidth = 1;
    for (final y in [padY, s.height - padY]) {
      for (double x = 0; x < s.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, s.width), y), dash);
      }
    }
    final path = Path();
    final o = [for (final e in pts) pt(e)];
    path.moveTo(o.first.dx, o.first.dy);
    for (var i = 1; i < o.length; i++) {
      final mx = (o[i - 1].dx + o[i].dx) / 2; // انحناء ناعم بين النقاط
      path.cubicTo(mx, o[i - 1].dy, mx, o[i].dy, o[i].dx, o[i].dy);
    }
    final fill = Path.from(path)..lineTo(o.last.dx, s.height)..lineTo(o.first.dx, s.height)..close();
    canvas.drawPath(fill, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [line.withValues(alpha: .45), line.withValues(alpha: 0)]).createShader(Offset.zero & s));
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round..color = line);
  }

  @override
  bool shouldRepaint(_ChartPainter o) => o.pts != pts || o.line != line;
}

// ---------------------------------------------------------------------------------------------
// إضافة / سحب مبلغ
// ---------------------------------------------------------------------------------------------
class GoalAmountPage extends StatefulWidget {
  final String id;
  final bool withdraw;
  const GoalAmountPage({super.key, required this.id, this.withdraw = false});
  @override
  State<GoalAmountPage> createState() => _GoalAmountState();
}

class _GoalAmountState extends State<GoalAmountPage> {
  double amt = 0;
  bool deduct = false;
  String acc = repo.defaultAcc;
  bool bad = false;

  Goal? get _g {
    for (final g in repo.goalList) {
      if (g.id == widget.id) return g;
    }
    return null;
  }

  void _save(Goal g) {
    final w = widget.withdraw;
    if (amt <= 0 || (w && amt > g.saved + .004)) {
      setState(() => bad = true);
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    var tx = '';
    final useAcc = deduct && acc.isNotEmpty;
    if (useAcc) {
      // إضافة = خصم من الحساب (مصروف)، سحب = إرجاع للحساب (دخل). من غير التفعيل: بيسجّل مبلغ مخصّص بالفعل وأرصدة الحسابات تفضل زي ما هي.
      tx = 'gl_${g.id}_${g.entries.length}_$now';
      repo.saveTx(Tx(id: tx, type: w ? 'inc' : 'exp', amt: amt, acc: acc, note: w ? 'سحب من هدف: ${g.name}' : 'ادخار لهدف: ${g.name}', ts: now));
    }
    g.entries.add(GoalEntry(now, w ? -amt : amt, acc: useAcc ? acc : '', tx: tx));
    g.saved = math.max(0, g.saved + (w ? -amt : amt));
    repo.saveGoal(g);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final g = _g;
    final w = widget.withdraw;
    if (g == null) return Scaffold(backgroundColor: p.bg, body: SafeArea(child: emptyState(p, Icons.flag_rounded, 'الهدف ده اتحذف')));
    final a = repo.account(acc);
    final f = _frac(g);
    return Scaffold(
      backgroundColor: p.bg,
      body: SheetPage(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(children: [
              RoundBtn(Icons.close_rounded, () => Navigator.of(context).pop(), size: 46),
              Expanded(child: Center(child: Text(w ? 'سحب مبلغ' : 'إضافة مبلغ', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)))),
              const SizedBox(width: 46),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 20), physics: const BouncingScrollPhysics(), children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(28)),
                child: Row(children: [
                  SizedBox(width: 62, height: 62, child: CustomPaint(painter: _RingPainter(f, p.field, kGreen, 4), child: Center(child: Text(g.emoji.isEmpty ? '🎯' : g.emoji, style: const TextStyle(fontSize: 26))))),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(g.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), Text('المدخر ${egp(g.saved)}', style: TextStyle(fontSize: 14, color: p.ink2))])),
                ]),
              ),
              if (w) Padding(padding: const EdgeInsets.fromLTRB(6, 14, 6, 0), child: Text('يمكنك سحب ${egp(g.saved)} من ${g.name}.', style: TextStyle(fontSize: 15, color: p.ink2))),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(28)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Tap(
                    onTap: () async {
                      final r = await showCalc(context, amt, S.cur);
                      if (r != null) setState(() => amt = r < 0 ? 0 : r);
                    },
                    child: Container(
                      height: 72,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(22), border: bad && (amt <= 0 || (w && amt > g.saved)) ? Border.all(color: kRed, width: 1.4) : null),
                      child: Row(children: [
                        Expanded(child: Text(amt <= 0 ? '0' : fmt(amt), style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: amt <= 0 ? p.ink2.withValues(alpha: .6) : p.ink))),
                        Text(curOf(S.cur).sym, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                  if (!w) Padding(padding: const EdgeInsets.only(top: 12), child: Text('يسجل هذا مبلغًا خصصته بالفعل. أرصدة حساباتك تظل كما هي.', style: TextStyle(fontSize: 13.5, color: p.ink2, height: 1.45))),
                ]),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(28)),
                child: Column(children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(w ? 'أعد المبلغ إلى حساب' : 'اخصم المبلغ من حساب الآن', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(w ? 'إذا كان المبلغ مسجلًا في حساب، أعده إليه. لن يُحتسب كدخل.' : 'فقط إذا كنت تحوّل المبلغ الآن. اتركه مغلقًا إذا كان المبلغ ضمن مدخراتك بالفعل.', style: TextStyle(fontSize: 13.5, color: p.ink2, height: 1.45)),
                      ]),
                    ),
                    Switch(value: deduct, onChanged: (v) => setState(() => deduct = v), activeThumbColor: Colors.white, activeTrackColor: kGreen),
                  ]),
                  if (deduct) ...[
                    const SizedBox(height: 12),
                    Tap(
                      onTap: () async {
                        final r = await showPickAccount(context, acc, title: 'اختر الحساب');
                        if (r != null && mounted) setState(() => acc = r);
                      },
                      child: Container(
                        height: 62,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(20)),
                        child: Row(children: [
                          if (a != null) ...[accIcon(a, size: 38), const SizedBox(width: 12)],
                          Expanded(child: Text(a?.name ?? 'اختر حسابًا', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
                          Icon(Icons.keyboard_arrow_down_rounded, color: p.ink2),
                        ]),
                      ),
                    ),
                  ],
                ]),
              ),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 16), child: bigButton(p, w ? (amt > 0 ? 'اسحب ${egp(amt)}' : 'اسحب') : 'أضف', p.acc, () => _save(g))),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// احسب مدخراتي (من الأصول المسجّلة)
// ---------------------------------------------------------------------------------------------
class GoalCalcPage extends StatefulWidget {
  final String id;
  const GoalCalcPage({super.key, required this.id});
  @override
  State<GoalCalcPage> createState() => _GoalCalcState();
}

class _GoalCalcState extends State<GoalCalcPage> {
  final sel = <String>{};

  double _base(Asset a) => a.cur == S.cur ? a.value : a.value * rates.rate(a.cur, S.cur);

  static const _groups = <(String, IconData, Color, List<String>, String)>[
    ('استثمارات', Icons.trending_up_rounded, Color(0xFF6C63D9), ['stock', 'currency', 'business'], 'ضيف استثمار أو صندوق أو عقار'),
    ('دهب وفضة', Icons.diamond_rounded, Color(0xFFC49A2C), ['gold', 'silver'], 'أضف ذهب أمتلكه'),
    ('عقارات وأصول أخرى', Icons.home_rounded, Color(0xFF6B7A90), ['realestate', 'car', 'other'], 'أضف شهادة بنكية أو أصل آخر'),
  ];

  void _apply() {
    Goal? g;
    for (final x in repo.goalList) {
      if (x.id == widget.id) g = x;
    }
    if (g == null) return;
    final items = [for (final a in assetsRepo.list) if (sel.contains(a.id)) a];
    final total = items.fold(0.0, (s, a) => s + _base(a));
    if (total <= 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    g.entries.add(GoalEntry(now, total, note: 'من الأصول: ${items.map((a) => a.name.isEmpty ? a.symbol : a.name).where((x) => x.isNotEmpty).join('، ')}'));
    g.saved += total;
    repo.saveGoal(g);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final all = assetsRepo.list;
    final total = all.where((a) => sel.contains(a.id)).fold(0.0, (s, a) => s + _base(a));
    return PageShell(
      underBar: true,
      title: 'احسب مدخراتي',
      icon: Icons.calculate_rounded,
      iconColor: kGreen,
      child: Stack(children: [
        ListView(padding: EdgeInsets.fromLTRB(16, barTop(context) + 4, 16, 130), physics: const BouncingScrollPhysics(), children: [
          Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 6), child: Text('اختار الأصول اللي تملكها بالفعل ونضيف قيمتها اليوم كمبلغ مدخر في الهدف.', style: TextStyle(fontSize: 15, color: p.ink2, height: 1.5))),
          for (final g in _groups) ...[
            sectionLabel(p, g.$1),
            Container(
              decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(26)),
              child: Column(children: [
                for (final a in all.where((a) => g.$4.contains(a.type)))
                  Tap(
                    onTap: () => setState(() => sel.contains(a.id) ? sel.remove(a.id) : sel.add(a.id)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(children: [
                        Icon(sel.contains(a.id) ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: sel.contains(a.id) ? kGreen : p.ink2),
                        const SizedBox(width: 12),
                        Expanded(child: Text(a.name.isEmpty ? a.symbol : a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600))),
                        Text(egp(_base(a)), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                Tap(
                  scale: .985,
                  onTap: () async {
                    await Navigator.of(context).push(flowRoute(const AssetsPage()));
                    if (mounted) setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(children: [
                      Container(width: 40, height: 40, decoration: BoxDecoration(color: g.$3.withValues(alpha: .16), shape: BoxShape.circle), child: Icon(Icons.add_rounded, color: g.$3)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(g.$5, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: g.$3))),
                      Icon(Icons.chevron_left_rounded, color: p.ink2),
                    ]),
                  ),
                ),
              ]),
            ),
          ],
        ]),
        PositionedDirectional(
          start: 16,
          end: 16,
          bottom: 16,
          child: Opacity(opacity: total > 0 ? 1 : .45, child: bigButton(p, total > 0 ? 'احسبه · ${egp(total)}' : 'احسبه', p.acc, () {
            if (total > 0) _apply();
          })),
        ),
      ]),
    );
  }
}
