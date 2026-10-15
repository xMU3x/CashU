import 'package:flutter/material.dart';
import '../core/calc.dart';
import '../core/currency.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/util.dart';
import 'anim.dart';
import 'theme.dart';
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
        if (ex.isNotEmpty && !ops.contains(ex[ex.length - 1]) && !ex.endsWith('%')) ex += '%';
      } else if (k == '.') {
        if (!_lastNum().contains('.')) ex += _lastNum().isEmpty ? '0.' : '.';
      } else if (ex.length < 18) {
        ex += k;
      }
    });
  }

  Widget _key(String l, {Color? bg, Color? fg, Widget? child}) => Expanded(
        child: Tap(
          onTap: () => _k(l),
          child: Container(
            height: 62,
            margin: const EdgeInsets.all(5),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg ?? const Color(0xFFEEEFF5), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE2E4F2))),
            child: child ?? Text(l, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: fg ?? const Color(0xFF2B2F45))),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    const op = Color(0xFFEDEEFB);
    final res = evalExpr(ex);
    final hasOp = ex.contains(RegExp(r'[+\-×÷%]')) && !(ex.startsWith('-') && !ex.substring(1).contains(RegExp(r'[+\-×÷%]')));
    return SheetFrame(
      bg: const Color(0xFFF3F4FA),
      title: 'المبلغ',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: [
              Text(curOf(widget.cur).sym, style: const TextStyle(fontSize: 22, color: Color(0xFF55586B))),
              const SizedBox(width: 8),
              Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(ex.isEmpty ? '0' : ex, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600, color: Color(0xFF2B2F45))))),
            ]),
          ),
          SizedBox(height: 22, child: hasOp && res != null ? Align(alignment: AlignmentDirectional.centerStart, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('= ${fmt(res)}', style: const TextStyle(color: Color(0xFF7A7D92))))) : null),
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
                    _key('⌫', child: Container(width: 40, height: 34, decoration: BoxDecoration(color: const Color(0xFF2B2F45), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.close_rounded, color: Colors.white, size: 20))),
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
                          decoration: BoxDecoration(color: const Color(0xFF5B8DEF), borderRadius: BorderRadius.circular(26)),
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
              activeTrackColor: const Color(0xFFE0A93B),
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
                      bankIcon(a.kind),
                      const SizedBox(width: 14),
                      Expanded(child: Text(a.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                      Text(money(repo.bal(a.id)), style: TextStyle(color: p.ink2)),
                      if (a.id == sel) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.check_rounded)),
                    ]),
                  ),
                ),
          ]),
        );
      },
    );

Widget bankIcon(String kind, {double size = 48}) {
  final ic = kind == 'cash' ? Icons.payments_rounded : kind == 'wallet' ? Icons.account_balance_wallet_rounded : Icons.account_balance_rounded;
  return Container(width: size, height: size, decoration: BoxDecoration(color: const Color(0xFFE4EAF4), borderRadius: BorderRadius.circular(size * .3)), child: Icon(ic, color: const Color(0xFF4A6FA5), size: size * .5));
}

Future<Cat?> showPickCat(BuildContext context, bool inc, String sel) => showSheet<Cat>(context, (c) {
      final p = Pal.of(c);
      final cats = inc ? kIncCats : kExpCats;
      return SheetFrame(
        title: 'اختر التصنيف',
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.15,
          children: [
            for (final k in cats)
              Tap(
                onTap: () => Navigator.of(c).pop(k),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(color: k.id == sel ? p.line : p.field, borderRadius: BorderRadius.circular(22)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(k.emoji, style: const TextStyle(fontSize: 30)), const SizedBox(height: 6), Text(k.name, style: const TextStyle(fontWeight: FontWeight.w600))]),
                ),
              ),
          ],
        ),
      );
    });

Future<Tx?> showPickTx(BuildContext context, {String? accId}) => showSheet<Tx>(context, (c) {
      final list = repo.allTx.where((t) => t.type != 'xfer' && (accId == null || t.acc == accId)).take(60).toList();
      return SheetFrame(
        title: 'اختر العملية',
        height: MediaQuery.of(context).size.height * .7,
        child: list.isEmpty
            ? emptyState(Pal.of(c), '🫥', 'لا توجد عمليات في هذا الحساب')
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
