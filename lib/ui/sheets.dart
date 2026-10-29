import 'package:flutter/material.dart' hide Text;
import 'loc_text.dart';
import '../core/calc.dart';
import '../core/currency.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/i18n.dart';
import '../core/util.dart';
import 'anim.dart';
import 'theme.dart';
import 'ios.dart';
import 'widgets.dart';

// ================= الحاسبة =================
Future<double?> showCalc(BuildContext context, double initial, String cur) =>
    showSheet<double>(context, (c) => _CalcSheet(initial: initial, cur: cur));

class _CalcSheet extends StatefulWidget {
  final double initial;
  final String cur;
  const _CalcSheet({required this.initial, required this.cur});
  @override
  State<_CalcSheet> createState() => _CalcState();
}

class _CalcState extends State<_CalcSheet> {
  late String ex = widget.initial > 0 ? widget.initial.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '') : '';
  static const ops = ['+', '-', '×', '÷'];

  String _lastNum() => RegExp(r'[0-9.]*$').firstMatch(ex)?.group(0) ?? '';

  void _k(String k) {
    tick();
    setState(() {
      if (k == 'C') {
        ex = '';
      } else if (k == '⌫') {
        if (ex.isNotEmpty) ex = ex.substring(0, ex.length - 1);
      } else if (ops.contains(k)) {
        if (ex.isEmpty) {
          if (k == '-') ex = '-';
        } else if (ops.contains(ex[ex.length - 1])) {
          ex = ex.substring(0, ex.length - 1) + k;
        } else {
          ex += k;
        }
      } else if (k == '%') {
        if (ex.isNotEmpty && !ops.contains(ex[ex.length - 1]) && !ex.endsWith('%')) { ex += '%'; }
      } else if (k == '.') {
        if (!_lastNum().contains('.')) ex += _lastNum().isEmpty ? '0.' : '.';
      } else if (ex.length < 18) {
        ex += k;
      }
    });
  }

  Widget _key(String l, {Color? bg, Color? fg, Widget? child}) {
    final p = Pal.of(context);
    return Expanded(
        child: Tap(
          onTap: () => _k(l),
          child: Container(
            height: 62,
            margin: const EdgeInsets.all(5),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg ?? p.field, borderRadius: BorderRadius.circular(22), border: Border.all(color: p.line)),
            child: child ?? Text(l, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: fg ?? p.ink)),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final op = p.acc.withValues(alpha: .18);
    final res = evalExpr(ex);
    final hasOp = ex.contains(RegExp(r'[+\-×÷%]')) && !(ex.startsWith('-') && !ex.substring(1).contains(RegExp(r'[+\-×÷%]')));
    return SheetFrame(
      title: 'المبلغ',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: [
              Text(curOf(widget.cur).sym, style: TextStyle(fontSize: 22, color: p.ink2)),
              const SizedBox(width: 8),
              Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(ex.isEmpty ? '0' : ex, textDirection: TextDirection.ltr, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w600, color: p.ink)))),
            ]),
          ),
          SizedBox(height: 22, child: hasOp && res != null ? Align(alignment: AlignmentDirectional.centerStart, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('= ${fmt(res)}', style: TextStyle(color: p.ink2)))) : null),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 4,
                child: Column(children: [
                  Row(children: [_key('1'), _key('2'), _key('3'), _key('÷', bg: op)]),
                  Row(children: [_key('4'), _key('5'), _key('6'), _key('×', bg: op)]),
                  Row(children: [_key('7'), _key('8'), _key('9'), _key('-', bg: op)]),
                  Row(children: [
                    _key('.'),
                    _key('0'),
                    _key('⌫', child: Container(width: 40, height: 34, decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.close_rounded, color: p.bg, size: 20))),
                    _key('+', bg: op),
                  ]),
                ]),
              ),
              Expanded(
                child: Column(children: [
                  Row(children: [_key('C', bg: op)]),
                  Row(children: [_key('%', bg: op)]),
                  Row(children: [
                    Expanded(
                      child: Tap(
                        onTap: () => Navigator.of(context).pop(res ?? 0.0),
                        child: Container(
                          height: 62 * 2 + 20,
                          margin: const EdgeInsets.all(5),
                          decoration: BoxDecoration(color: p.acc, borderRadius: BorderRadius.circular(26)),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 38),
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ================= العملة =================
Future<String?> showCurrencySheet(BuildContext context, String selected) =>
    showSheet<String>(context, (c) => _CurSheet(selected: selected));

class _CurSheet extends StatefulWidget {
  final String selected;
  const _CurSheet({required this.selected});
  @override
  State<_CurSheet> createState() => _CurState();
}

class _CurState extends State<_CurSheet> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final base = S.cur;
    final list = kCurs.where((c) => q.isEmpty || c.name.contains(q) || c.code.toLowerCase().contains(q.toLowerCase())).toList();
    final conv = S.flag('conv', true);
    return SheetFrame(
      title: 'عملة هذه المعاملة',
      height: MediaQuery.of(context).size.height * .88,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 20), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(26)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('تحويل إلى عملتي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('أي عملة غير ${curOf(base).sym} تُحوَّل بسعر اليوم عند الحفظ.', style: TextStyle(color: p.ink2, fontSize: 14)),
              ]),
            ),
            Switch(
              value: conv,
              activeTrackColor: kBlue,
              activeThumbColor: Colors.white,
              onChanged: (v) {
                S.put('conv', v);
                setState(() {});
              },
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(22)),
          child: TextField(
            onChanged: (v) => setState(() => q = v.trim()),
            decoration: InputDecoration(border: InputBorder.none, hintText: 'بحث', hintStyle: TextStyle(color: p.ink2), icon: Icon(Icons.search_rounded, color: p.ink2)),
          ),
        ),
        const SizedBox(height: 12),
        for (final c in list)
          Tap(
            scale: .98,
            onTap: () => Navigator.of(context).pop(c.code),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: c.code == widget.selected ? p.line : p.field.withValues(alpha: .6), borderRadius: BorderRadius.circular(26)),
              child: Row(children: [
                Text(c.flag, style: const TextStyle(fontSize: 34)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(c.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      if (c.code == base) ...[const SizedBox(width: 8), Text('الأساسية', style: TextStyle(color: p.ink2, fontSize: 13))],
                    ]),
                    Text('${c.sym} · ${c.code}', style: TextStyle(color: p.ink2)),
                  ]),
                ),
                if (c.code == widget.selected) const Icon(Icons.check_rounded),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ================= اختيارات =================
Future<String?> showPickAccount(BuildContext context, String sel, {String title = 'اختر الحساب', String? exclude}) => showSheet<String>(
      context,
      (c) {
        final p = Pal.of(c);
        return SheetFrame(
          title: title,
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), children: [
            for (final a in repo.accList)
              if (a.id != exclude)
                Tap(
                  scale: .98,
                  onTap: () => Navigator.of(c).pop(a.id),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: a.id == sel ? p.line : p.field, borderRadius: BorderRadius.circular(22)),
                    child: Row(children: [
                      accIcon(a, size: 44),
                      const SizedBox(width: 14),
                      Expanded(child: Text(a.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                      Text(money(repo.bal(a.id)), style: TextStyle(color: p.ink2)),
                      if (a.id == sel) const Padding(padding: EdgeInsetsDirectional.only(end: 8), child: Icon(Icons.check_rounded)),
                    ]),
                  ),
                ),
          ]),
        );
      },
    );

// ================= اللغة (عام) =================
Future<void> showLanguageSheet(BuildContext context) => showSheet<void>(context, (c) => const _LangSheet());

class _LangSheet extends StatelessWidget {
  const _LangSheet();
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Widget opt(String code, String label) {
      final on = (isAr ? 'ar' : 'en') == code;
      return Tap(
        onTap: () {
          S.put('lang', code);
          Navigator.of(context).pop();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(20), border: Border.all(color: on ? p.acc : Colors.transparent, width: 2)),
          child: Row(children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
            if (on) Icon(Icons.check_circle_rounded, color: p.acc),
          ]),
        ),
      );
    }
    return SheetFrame(
      title: 'اللغة',
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 18), child: Column(mainAxisSize: MainAxisSize.min, children: [opt('ar', 'العربية'), opt('en', 'English')])),
    );
  }
}

// ================= المظهر (فاتح / داكن / عصري) =================
Future<void> showAppearanceSheet(BuildContext context) => showSheet<void>(context, (c) => const _AppearanceSheet());

Widget _optRow(Pal p, IconData ic, String label, bool on, VoidCallback f, {String? sub}) => Tap(
      onTap: f,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(20), border: Border.all(color: on ? p.acc : Colors.transparent, width: 2)),
        child: Row(children: [
          Icon(ic, color: p.ink2),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), if (sub != null) Text(sub, style: TextStyle(fontSize: 12.5, color: p.ink2))])),
          if (on) Icon(Icons.check_circle_rounded, color: p.acc),
        ]),
      ),
    );

class _AppearanceSheet extends StatelessWidget {
  const _AppearanceSheet();
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final cur = Pal.mode();
    Widget opt(String m, IconData ic, String label) => _optRow(p, ic, label, cur == m, () {
          S.put('themeMode', m);
          S.put('dark', m != 'light'); // توافق مع الإعداد القديم
          Navigator.of(context).pop();
        });
    return SheetFrame(
      title: 'المظهر',
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 18), child: Column(mainAxisSize: MainAxisSize.min, children: [opt('light', Icons.light_mode_rounded, 'فاتح'), opt('dark', Icons.dark_mode_rounded, 'داكن'), opt('modern', Icons.auto_awesome_rounded, 'عصري')])),
    );
  }
}


Widget bankIcon(String kind, {double size = 48, BuildContext? context}) {
  final ic = kind == 'cash' ? Icons.payments_rounded : kind == 'wallet' ? Icons.account_balance_wallet_rounded : Icons.account_balance_rounded;
  return Container(width: size, height: size, decoration: BoxDecoration(color: kBlue.withValues(alpha: .16), borderRadius: BorderRadius.circular(size * .3)), child: Icon(ic, color: kBlue, size: size * .5));
}

/// اختيار التصنيف: قائمة هرمية (تصنيف رئيسي ← فرعي) مع بحث، زي شاشة Category.
/// بيرجّع (التصنيف الرئيسي، الفرعي) — الفرعي فاضي لو اخترت الرئيسي نفسه.
Future<(Cat, String)?> showPickCat(BuildContext context, bool inc, String sel, {String selSub = ''}) => showSheet<(Cat, String)>(context, (c) => _CatPicker(inc: inc, sel: sel, selSub: selSub));

class _CatPicker extends StatefulWidget {
  final bool inc;
  final String sel, selSub;
  const _CatPicker({required this.inc, required this.sel, required this.selSub});
  @override
  State<_CatPicker> createState() => _CatPickerState();
}

class _CatPickerState extends State<_CatPicker> {
  final q = TextEditingController();
  late final Set<String> open = {widget.sel};
  static const _subColors = [Color(0xFF1E9BE8), Color(0xFFFFB800), Color(0xFFFF7A00), Color(0xFFFF3B4E), Color(0xFFB65FD6), Color(0xFF16A394), Color(0xFF28A745)];

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  Widget _bubble(IconData ic, Color col, {double size = 40}) => Container(width: size, height: size, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(size * .3)), child: Icon(ic, color: Colors.white, size: size * .55));

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final cats = repo.cats(widget.inc);
    final f = q.text.trim().toLowerCase();
    final rows = <Widget>[];
    for (final k in cats) {
      final subs = repo.subsOf(k);
      final matchSubs = f.isEmpty ? subs : subs.where((s) => s.toLowerCase().contains(f)).toList();
      final selfMatch = f.isEmpty || k.name.toLowerCase().contains(f);
      if (!selfMatch && matchSubs.isEmpty) continue;
      final isOpen = f.isNotEmpty ? true : open.contains(k.id);
      final ic = catIcon(k.id);
      rows.add(Tap(
        scale: .99,
        onTap: () {
          if (subs.isEmpty) {
            Navigator.of(context).pop((k, ''));
          } else {
            setState(() => open.contains(k.id) ? open.remove(k.id) : open.add(k.id));
          }
        },
        onLongPress: () => Navigator.of(context).pop((k, '')), // ضغطة مطولة = اختيار التصنيف الرئيسي نفسه
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(children: [
            _bubble(ic.$1, ic.$2),
            const SizedBox(width: 14),
            Expanded(child: Text(k.name, style: TextStyle(fontSize: 17, fontWeight: k.id == widget.sel ? FontWeight.w700 : FontWeight.w500))),
            if (k.id == widget.sel && widget.selSub.isEmpty) Padding(padding: EdgeInsetsDirectional.only(end: 8), child: Icon(Icons.check_rounded, color: kBlue, size: 20)),
            if (subs.isNotEmpty) AnimatedRotation(turns: isOpen ? (isAr ? -.25 : .25) : 0, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic, child: Icon(Icons.chevron_right_rounded, color: p.ink2)),
          ]),
        ),
      ));
      if (subs.isNotEmpty) {
        rows.add(AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: isOpen
              ? Column(children: [
                  for (var i = 0; i < matchSubs.length; i++)
                    Tap(
                      scale: .99,
                      onTap: () => Navigator.of(context).pop((k, matchSubs[i])),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(40, 7, 14, 7),
                        child: Row(children: [
                          _bubble(ic.$1, _subColors[(k.id.length + i) % _subColors.length], size: 36),
                          const SizedBox(width: 14),
                          Expanded(child: Text(matchSubs[i], style: const TextStyle(fontSize: 16))),
                          if (k.id == widget.sel && matchSubs[i] == widget.selSub) Icon(Icons.check_rounded, color: kBlue, size: 20),
                        ]),
                      ),
                    ),
                  Tap(
                    scale: .99,
                    onTap: () => Navigator.of(context).pop((k, '')),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(40, 7, 14, 10),
                      child: Row(children: [
                        _bubble(Icons.more_horiz_rounded, p.ink2, size: 36),
                        const SizedBox(width: 14),
                        const Expanded(child: Text('Others', style: TextStyle(fontSize: 16))),
                      ]),
                    ),
                  ),
                ])
              : const SizedBox(width: double.infinity),
        ));
      }
      rows.add(hair(p, indent: 68));
    }
    return SheetFrame(
      title: 'Category',
      height: MediaQuery.of(context).size.height * .88,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(23)),
            child: Row(children: [
              Icon(Icons.search_rounded, color: p.ink2),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: q, onChanged: (_) => setState(() {}), decoration: InputDecoration(border: InputBorder.none, isDense: true, hintText: tl('Search'), hintStyle: TextStyle(color: p.ink2)))),
              if (q.text.isNotEmpty) Tap(onTap: () => setState(q.clear), child: Icon(Icons.cancel_rounded, color: p.ink2, size: 18)),
            ]),
          ),
        ),
        Expanded(child: rows.isEmpty ? emptyState(p, Icons.search_off_rounded, 'No results') : Container(margin: const EdgeInsets.fromLTRB(12, 0, 12, 12), clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: p.field.withValues(alpha: .45), borderRadius: BorderRadius.circular(22)), child: ListView(padding: EdgeInsets.zero, physics: const BouncingScrollPhysics(), children: rows))),
      ]),
    );
  }
}

Future<Tx?> showPickTx(BuildContext context, {String? accId}) => showSheet<Tx>(context, (c) {
      final list = repo.allTx.where((t) => t.type != 'xfer' && (accId == null || t.acc == accId)).take(60).toList();
      return SheetFrame(
        title: 'اختر العملية',
        height: MediaQuery.of(context).size.height * .7,
        child: list.isEmpty
            ? emptyState(Pal.of(c), Icons.inbox_rounded, 'لا توجد عمليات في هذا الحساب')
            : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), children: [for (final t in list) Tap(scale: .98, onTap: () => Navigator.of(c).pop(t), child: TxTile(t))]),
      );
    });

Future<String?> showSelect(BuildContext context, String title, List<(String, String)> opts, String sel) => showSheet<String>(context, (c) {
      final p = Pal.of(c);
      return SheetFrame(
        title: title,
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), children: [
          for (final o in opts)
            Tap(
              scale: .98,
              onTap: () => Navigator.of(c).pop(o.$1),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: o.$1 == sel ? p.line : p.field, borderRadius: BorderRadius.circular(22)),
                child: Row(children: [Expanded(child: Text(o.$2, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))), if (o.$1 == sel) const Icon(Icons.check_rounded)]),
              ),
            ),
        ]),
      );
    });

// ================= نص / رقم =================
Future<String?> promptText(BuildContext context, String title, {String hint = '', String initial = '', bool number = false}) {
  final ctl = TextEditingController(text: initial);
  return showSheet<String>(context, (c) {
    final p = Pal.of(c);
    return SheetFrame(
      title: title,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(20)),
            child: TextField(controller: ctl, autofocus: true, keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, decoration: InputDecoration(border: InputBorder.none, hintText: hint, hintStyle: TextStyle(color: p.ink2))),
          ),
          const SizedBox(height: 14),
          bigButton(p, 'حفظ', p.acc, () => Navigator.of(c).pop(ctl.text.trim())),
        ]),
      ),
    );
  });
}

Widget bigButton(Pal p, String label, Color color, VoidCallback f, {Key? key}) => Tap(
      onTap: f,
      child: Container(key: key, height: 58, alignment: Alignment.center, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(29), boxShadow: [BoxShadow(color: color.withValues(alpha: .35), blurRadius: 16, offset: const Offset(0, 6))]), child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
    );

Future<void> showBudgetSheet(BuildContext context, Budget b) async {
  final r = await promptText(context, 'ميزانية شهرية (${curOf(S.cur).sym})', hint: 'مثال: 5000', initial: b.limit > 0 ? fmt(b.limit).replaceAll(',', '') : '', number: true);
  if (r == null) return;
  final v = double.tryParse(normDigits(r));
  if (v == null || v < 0) return;
  b.limit = v;
  repo.saveBudget(b);
}

// ================= حساب (إضافة/تعديل) =================
Future<void> showAccountSheet(BuildContext context, {Account? edit}) => showSheet<void>(context, (c) => _AccSheet(edit: edit));

class _AccSheet extends StatefulWidget {
  final Account? edit;
  const _AccSheet({this.edit});
  @override
  State<_AccSheet> createState() => _AccState();
}

class _AccState extends State<_AccSheet> {
  late final name = TextEditingController(text: widget.edit?.name ?? '');
  late final last4 = TextEditingController(text: widget.edit?.last4 ?? '');
  late final start = TextEditingController(text: widget.edit == null || widget.edit!.start == 0 ? '' : fmt(widget.edit!.start).replaceAll(',', ''));
  late String kind = widget.edit?.kind ?? 'bank';

  Widget _f(Pal p, TextEditingController c, String h, {bool num = false, int? max}) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(20)),
        child: TextField(controller: c, maxLength: max, keyboardType: num ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text, decoration: InputDecoration(border: InputBorder.none, counterText: '', hintText: h, hintStyle: TextStyle(color: p.ink2))),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return SheetFrame(
      title: widget.edit == null ? 'حساب جديد' : 'تعديل الحساب',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            for (final k in [('bank', 'حساب بنكي'), ('cash', 'نقدي'), ('wallet', 'محفظة')]) ...[Expanded(child: pill(p, k.$2, kind == k.$1, () => setState(() => kind = k.$1), color: p.acc)), const SizedBox(width: 8)],
          ]),
          const SizedBox(height: 14),
          _f(p, name, 'اسم الحساب'),
          _f(p, last4, 'آخر 4 أرقام من البطاقة (اختياري)', num: true, max: 4),
          _f(p, start, 'الرصيد الابتدائي', num: true),
          const SizedBox(height: 6),
          bigButton(p, 'حفظ', p.acc, () {
            if (name.text.trim().isEmpty) return;
            final a = widget.edit ?? Account(id: uid(), name: '');
            a.name = name.text.trim();
            a.kind = kind;
            a.last4 = normDigits(last4.text.trim());
            a.start = double.tryParse(normDigits(start.text.trim())) ?? 0;
            repo.saveAccount(a);
            Navigator.of(context).pop();
          }),
        ]),
      ),
    );
  }
}

// ================= اختيار الشهر =================
Future<DateTime?> showMonthSheet(BuildContext context, DateTime cur) => showSheet<DateTime>(context, (c) {
      final p = Pal.of(c);
      final now = DateTime.now();
      return SheetFrame(
        title: 'اختر الشهر',
        child: SizedBox(
          height: 250,
          child: PageView.builder(
            reverse: true,
            itemCount: 6,
            itemBuilder: (ctx, i) {
              final y = now.year - i;
              return Column(children: [
                Text(toAr('$y'), style: TextStyle(color: p.ink2, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    for (var m = 1; m <= 12; m++)
                      if (y < now.year || m <= now.month) pill(p, kMonths[m - 1], cur.year == y && cur.month == m, () => Navigator.of(c).pop(DateTime(y, m)), color: p.acc),
                  ]),
                ),
              ]);
            },
          ),
        ),
      );
    });


// ================= المستفيد (من البيانات القديمة) =================
Future<String?> showPayeeSheet(BuildContext context, String current) => showSheet<String>(context, (c) => _PayeeSheet(current: current));

class _PayeeSheet extends StatefulWidget {
  final String current;
  const _PayeeSheet({required this.current});
  @override
  State<_PayeeSheet> createState() => _PayeeState();
}

class _PayeeState extends State<_PayeeSheet> {
  late final ctl = TextEditingController(text: widget.current);
  late final List<String> all = () {
    final seen = <String>{}, out = <String>[];
    for (final n in S.list('savedPayees')) {
      if (n.trim().isNotEmpty && seen.add(n.toLowerCase())) out.add(n);
    }
    for (final t in repo.allTx) {
      final n = t.pay.trim();
      if (n.isNotEmpty && seen.add(n.toLowerCase())) out.add(n);
    }
    return out;
  }();

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final q = ctl.text.trim().toLowerCase();
    final list = all.where((n) => q.isEmpty || n.toLowerCase().contains(q)).take(40).toList();
    return SheetFrame(
      title: 'Payee',
      height: MediaQuery.of(context).size.height * .7,
      child: Column(children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            Icon(Icons.search_rounded, color: p.ink2),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: ctl, autofocus: true, onChanged: (_) => setState(() {}), onSubmitted: (v) => Navigator.of(context).pop(v.trim()), decoration: InputDecoration(border: InputBorder.none, hintText: 'اكتب اسم المستفيد أو اختر من السابقين', hintStyle: TextStyle(color: p.ink2)))),
          ]),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
            if (ctl.text.trim().isNotEmpty && !all.any((n) => n.toLowerCase() == q))
              Tap(onTap: () => Navigator.of(context).pop(ctl.text.trim()), child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [Icon(Icons.add_circle_outline_rounded, color: p.acc), const SizedBox(width: 12), Expanded(child: Text('إضافة "${ctl.text.trim()}"', style: TextStyle(color: p.acc, fontWeight: FontWeight.w600)))]))),
            for (final n in list)
              Tap(onTap: () => Navigator.of(context).pop(n), child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [Icon(Icons.history_rounded, color: p.ink2, size: 20), const SizedBox(width: 12), Expanded(child: Text(n, style: const TextStyle(fontSize: 16)))]))),
            if (widget.current.isNotEmpty) Tap(onTap: () => Navigator.of(context).pop(''), child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [Icon(Icons.close_rounded, color: kRed, size: 20), const SizedBox(width: 12), Text('بدون مستفيد', style: TextStyle(color: p.ink2))]))),
          ]),
        ),
      ]),
    );
  }
}

// ================= تقسيم معاملة على أكثر من حساب =================
Future<List<(String, double)>?> showSplitSheet(BuildContext context, double total, String cur, String firstAcc, List<(String, double)> init) =>
    showSheet<List<(String, double)>>(context, (c) => _SplitSheet(total: total, cur: cur, firstAcc: firstAcc, init: init));

class _SplitSheet extends StatefulWidget {
  final double total;
  final String cur, firstAcc;
  final List<(String, double)> init;
  const _SplitSheet({required this.total, required this.cur, required this.firstAcc, required this.init});
  @override
  State<_SplitSheet> createState() => _SplitState();
}

class _SplitState extends State<_SplitSheet> {
  late final List<(String, double)> rows = widget.init.length > 1 ? List.of(widget.init) : [(widget.firstAcc, widget.total)];

  double get sum => rows.fold(0.0, (a, r) => a + r.$2);
  double get left => double.parse((widget.total - sum).toStringAsFixed(2));

  /// حساب تلقائي: لما تكتب مبلغ على حساب، الباقي يتخصم/يتضاف على الحساب الأول (أو الأخير لو عدّلت الأول).
  void _rebalance(int edited) {
    if (rows.length < 2) return;
    final t = edited == 0 ? rows.length - 1 : 0;
    var others = 0.0;
    for (var k = 0; k < rows.length; k++) {
      if (k != t) others += rows[k].$2;
    }
    final v = double.parse((widget.total - others).toStringAsFixed(2));
    rows[t] = (rows[t].$1, v < 0 ? 0 : v);
  }

  void _equal() => setState(() {
        final n = rows.length;
        final share = double.parse((widget.total / n).toStringAsFixed(2));
        for (var i = 0; i < n; i++) {
          rows[i] = (rows[i].$1, i == n - 1 ? double.parse((widget.total - share * (n - 1)).toStringAsFixed(2)) : share);
        }
      });

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final ok = left.abs() < 0.005 && rows.length > 1 && rows.every((r) => r.$2 > 0);
    final used = rows.map((r) => r.$1).toSet();
    return SheetFrame(
      title: 'Split',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(alignment: AlignmentDirectional.centerStart, child: Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('الإجمالي: ${fmt(widget.total)} ${widget.cur}', style: TextStyle(color: p.ink2)))),
          for (var i = 0; i < rows.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                Expanded(
                  child: Tap(
                    onTap: () async {
                      final r = await showPickAccount(context, rows[i].$1);
                      if (r != null) setState(() => rows[i] = (r, rows[i].$2));
                    },
                    child: Text(repo.account(rows[i].$1)?.name ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                Tap(
                  onTap: () async {
                    final r = await showCalc(context, rows[i].$2, widget.cur);
                    if (r != null && r >= 0) { setState(() { rows[i] = (rows[i].$1, r); _rebalance(i); }); }
                  },
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(14)), child: Text(fmt(rows[i].$2), style: TextStyle(color: p.acc, fontWeight: FontWeight.w700))),
                ),
                if (rows.length > 1) Tap(onTap: () => setState(() { rows.removeAt(i); if (rows.length == 1) { rows[0] = (rows[0].$1, widget.total); } else { _rebalance(rows.length - 1); } }), child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.close_rounded, color: p.ink2, size: 20))),
              ]),
            ),
          Row(children: [
            Expanded(
              child: Tap(
                onTap: () {
                  final free = repo.accList.where((a) => !used.contains(a.id)).toList();
                  if (free.isEmpty) return;
                  setState(() => rows.add((free.first.id, left > 0 ? left : 0)));
                },
                child: Container(height: 44, alignment: Alignment.center, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: p.line, width: 1.4)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_rounded, color: p.acc), const SizedBox(width: 6), Text('إضافة حساب', style: TextStyle(color: p.acc, fontWeight: FontWeight.w600))])),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Tap(onTap: _equal, child: Container(height: 44, alignment: Alignment.center, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: p.line, width: 1.4)), child: Text('بالتساوي', style: TextStyle(color: p.ink, fontWeight: FontWeight.w600))))),
          ]),
          const SizedBox(height: 10),
          Text(left.abs() < 0.005 ? 'تم توزيع المبلغ بالكامل' : (left > 0 ? 'متبقي ${fmt(left)} ${widget.cur}' : 'زيادة ${fmt(-left)} ${widget.cur}'), style: TextStyle(color: left.abs() < 0.005 ? kGreen : kRed, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Tap(
            onTap: ok ? () => Navigator.of(context).pop(rows) : null,
            child: Container(width: double.infinity, height: 50, alignment: Alignment.center, decoration: BoxDecoration(color: ok ? p.acc : p.field, borderRadius: BorderRadius.circular(25)), child: Text('تأكيد التقسيم', style: TextStyle(color: ok ? Colors.white : p.ink2, fontWeight: FontWeight.w700, fontSize: 16))),
          ),
        ]),
      ),
    );
  }
}
