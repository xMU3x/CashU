import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import '../core/currency.dart';
import '../core/groups.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/sheets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// إنشاء/تعديل مجموعة: الاسم + العملة + اللون + نقل الحسابات إليها (مثل صورة Edit Group).
class GroupEditPage extends StatefulWidget {
  /// اسم المجموعة الحالية؛ null = مجموعة جديدة.
  final String? name;
  final Color? color;
  const GroupEditPage({super.key, this.name, this.color});
  @override
  State<GroupEditPage> createState() => _GroupEditState();
}

class _GroupEditState extends State<GroupEditPage> {
  late final TextEditingController nameC;
  late Color color;
  late String cur;
  final members = <String>{};

  bool get _editing => widget.name != null;

  @override
  void initState() {
    super.initState();
    nameC = TextEditingController(text: widget.name ?? '');
    color = groupColorOf(widget.name ?? '') ?? widget.color ?? kGroupPalette[4];
    cur = groupCurOf(widget.name ?? '');
    if (_editing) {
      for (final a in repo.accList) {
        if (a.group == widget.name) members.add(a.id);
      }
    }
  }

  @override
  void dispose() {
    nameC.dispose();
    super.dispose();
  }

  void _save() {
    final ok = saveGroup(old: widget.name, name: nameC.text, color: color, cur: cur, members: members);
    if (!ok) {
      toast(context, nameC.text.trim().isEmpty ? 'Enter a group name' : 'A group with this name already exists');
      return;
    }
    Navigator.of(context).pop(true);
  }

  Widget _nameCard(Pal p) => Container(
        decoration: iosCard(p, r: 22),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox(
              height: 54,
              child: Row(children: [
                Icon(Icons.text_fields_rounded, color: p.ink2, size: 22),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: nameC, onChanged: (_) => setState(() {}), style: const TextStyle(fontSize: 17), decoration: const InputDecoration(border: InputBorder.none, isDense: true))),
                if (nameC.text.isNotEmpty) Tap(onTap: () => setState(nameC.clear), child: Icon(Icons.cancel_rounded, color: p.ink2, size: 20)),
                const SizedBox(width: 12),
                Tap(
                  onTap: () async {
                    final r = await showCurrencySheet(context, cur);
                    if (r != null) setState(() => cur = r);
                  },
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(curOf(cur).sym, style: TextStyle(fontSize: 16, color: kBlue)),
                    Icon(Icons.unfold_more_rounded, color: kBlue, size: 18),
                  ]),
                ),
              ]),
            ),
          ),
          hair(p),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              for (final c in kGroupPalette)
                Tap(
                  onTap: () => setState(() => color = c),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: color == c ? p.ink : Colors.transparent, width: 2.5)),
                  ),
                ),
            ]),
          ),
        ]),
      );

  Widget _accRow(Pal p, Account a, bool last) {
    final on = members.contains(a.id);
    return Tap(
      scale: .99,
      onTap: () => setState(() => on ? members.remove(a.id) : members.add(a.id)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
          child: Row(children: [
            accIcon(a, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(egp(repo.bal(a.id)), style: TextStyle(fontSize: 14, color: repo.bal(a.id) < 0 ? kRed : kGreen)),
              ]),
            ),
            Icon(on ? Icons.check_rounded : null, color: kBlue, size: 24),
          ]),
        ),
        if (!last) hair(p, indent: 66),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final accs = repo.accList;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SheetPage(
        child: ListView(padding: EdgeInsets.fromLTRB(16, 16, 16, 30 + MediaQuery.of(context).viewInsets.bottom), children: [
          Row(children: [
            GlassBtn(Icons.close_rounded, () => Navigator.of(context).pop(), size: 46),
            const Spacer(),
            Tap(onTap: _save, child: Glass(radius: 23, height: 46, padding: const EdgeInsets.symmetric(horizontal: 22), child: const Center(child: Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))))),
          ]),
          const SizedBox(height: 14),
          Padding(padding: const EdgeInsets.only(left: 4, bottom: 14), child: Text(_editing ? 'Edit Group' : 'New Group', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800))),
          _nameCard(p),
          Padding(padding: const EdgeInsets.fromLTRB(8, 18, 8, 10), child: Center(child: Text('Move the following accounts into the group:', textAlign: TextAlign.center, style: TextStyle(fontSize: 14.5, color: p.ink2)))),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: iosCard(p, r: 22),
            child: Column(children: [for (var i = 0; i < accs.length; i++) _accRow(p, accs[i], i == accs.length - 1)]),
          ),
        ]),
      ),
    );
  }
}
