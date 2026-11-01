import 'package:flutter/cupertino.dart' show CupertinoDatePicker, CupertinoDatePickerMode, CupertinoTextThemeData, CupertinoTheme, CupertinoThemeData;
import 'package:flutter/material.dart' hide Text;
import '../core/i18n.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import 'anim.dart';
import 'ios.dart';
import 'loc_text.dart';
import 'sheets.dart';
import 'theme.dart';
import 'widgets.dart';

/// منتقي التاريخ كبانل سفلية مدمجة (نفس شكل لوحة المبلغ) بدل الحوار العائم.
Future<DateTime?> showDateSheet(BuildContext context, DateTime initial, {DateTime? first, DateTime? last, String title = 'التاريخ'}) =>
    showSheet<DateTime>(context, (c) => _DateSheet(initial: initial, first: first ?? DateTime(2000), last: last ?? DateTime(2100), title: title));

class _DateSheet extends StatefulWidget {
  final DateTime initial, first, last;
  final String title;
  const _DateSheet({required this.initial, required this.first, required this.last, required this.title});
  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  late DateTime sel = widget.initial;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final base = Theme.of(context);
    final init = widget.initial.isBefore(widget.first) ? widget.first : (widget.initial.isAfter(widget.last) ? widget.last : widget.initial);
    return SheetFrame(
      title: widget.title,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Theme(
            data: base.copyWith(colorScheme: base.colorScheme.copyWith(primary: kBlue, onPrimary: Colors.white, surface: p.card, onSurface: p.ink)),
            child: CalendarDatePicker(initialDate: init, firstDate: widget.first, lastDate: widget.last, onDateChanged: (d) => sel = d),
          ),
          const SizedBox(height: 8),
          bigButton(p, 'تأكيد', kBlue, () => Navigator.of(context).pop(DateTime(sel.year, sel.month, sel.day, widget.initial.hour, widget.initial.minute))),
        ]),
      ),
    );
  }
}

/// منتقي الوقت كبانل سفلية مدمجة.
Future<DateTime?> showTimeSheet(BuildContext context, DateTime initial) => showSheet<DateTime>(context, (c) => _TimeSheet(initial: initial));

class _TimeSheet extends StatefulWidget {
  final DateTime initial;
  const _TimeSheet({required this.initial});
  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late DateTime sel = widget.initial;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final dark = p.bg.computeLuminance() < .3;
    return SheetFrame(
      title: 'الوقت',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: 210,
            child: CupertinoTheme(
              data: CupertinoThemeData(brightness: dark ? Brightness.dark : Brightness.light, textTheme: CupertinoTextThemeData(dateTimePickerTextStyle: TextStyle(color: p.ink, fontSize: 22))),
              child: CupertinoDatePicker(mode: CupertinoDatePickerMode.time, initialDateTime: widget.initial, onDateTimeChanged: (d) => sel = d),
            ),
          ),
          const SizedBox(height: 8),
          bigButton(p, 'تأكيد', kBlue, () => Navigator.of(context).pop(DateTime(widget.initial.year, widget.initial.month, widget.initial.day, sel.hour, sel.minute))),
        ]),
      ),
    );
  }
}

/// الوسوم: تُحفظ وتظهر كاقتراحات من كل المعاملات السابقة (زي المستفيد).
Future<String?> showTagsSheet(BuildContext context, String current) => showSheet<String>(context, (c) => _TagsSheet(current: current));

List<String> splitTags(String s) => s.split(RegExp(r'[,،]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

class _TagsSheet extends StatefulWidget {
  final String current;
  const _TagsSheet({required this.current});
  @override
  State<_TagsSheet> createState() => _TagsSheetState();
}

class _TagsSheetState extends State<_TagsSheet> {
  late final Set<String> sel = splitTags(widget.current).toSet();
  final ctl = TextEditingController();
  late final List<String> all = () {
    final s = <String>{...sel, ...S.list('savedTags')};
    for (final t in repo.allTx) {
      s.addAll(splitTags(t.tags));
    }
    return s.toList()..sort();
  }();

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  void _add() {
    final v = ctl.text.trim();
    if (v.isEmpty) return;
    setState(() {
      if (!all.contains(v)) all.add(v);
      sel.add(v);
      ctl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return SheetFrame(
      title: 'الوسوم',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              Expanded(child: TextField(controller: ctl, onSubmitted: (_) => _add(), decoration: InputDecoration(border: InputBorder.none, hintText: tl('وسم جديد'), hintStyle: TextStyle(color: p.ink2)))),
              Tap(onTap: _add, child: Icon(Icons.add_circle_rounded, color: kBlue)),
            ]),
          ),
          const SizedBox(height: 14),
          if (all.isEmpty) Text('لا توجد وسوم بعد', style: TextStyle(color: p.ink2)),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final t in all) smallChip(t, sel.contains(t), () => setState(() => sel.contains(t) ? sel.remove(t) : sel.add(t)))]),
          const SizedBox(height: 16),
          bigButton(p, 'تأكيد', kBlue, () => Navigator.of(context).pop(sel.join(', '))),
        ]),
      ),
    );
  }
}
