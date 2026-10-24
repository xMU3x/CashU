import '../ui/motion.dart';
import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import '../core/cat_icons.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/sheets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const _subPalette = [Color(0xFF1E9BE8), Color(0xFFFFB800), Color(0xFFFF7A00), Color(0xFFFF3B4E), Color(0xFFB65FD6), Color(0xFF16A394), Color(0xFF28A745)];

/// شاشة التصنيفات: مصروفات / دخل، رئيسي + فرعي، بعدّاد معاملات، مع تعديل وإضافة وحذف وترتيب.
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});
  @override
  State<CategoriesPage> createState() => _CategoriesState();
}

class _CategoriesState extends State<CategoriesPage> {
  bool inc = false, edit = false;
  final sel = <String>{};
  final open = <String>{};

  Widget _bubble(IconData ic, Color c, {double size = 42}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(size * .28)),
        child: Icon(ic, color: Colors.white, size: size * .56),
      );

  Widget _count(int n) => Container(
        constraints: const BoxConstraints(minWidth: 52),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: n == 0 ? kRed : kBlue, borderRadius: BorderRadius.circular(16)),
        child: Text('$n', textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600)),
      );

  Widget _check(bool on) => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(shape: BoxShape.circle, color: on ? kBlue : Colors.transparent, border: Border.all(color: on ? kBlue : const Color(0xFF8E8E93), width: 1.8)),
        child: on ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
      );

  void _toggle(String id) => setState(() => sel.contains(id) ? sel.remove(id) : sel.add(id));

  Future<void> _deleteSelected() async {
    if (sel.isEmpty) return;
    var txs = 0;
    for (final id in sel) {
      final d = repo.catDef(id);
      if (d == null) continue;
      txs += repo.catCount(d.isSub ? d.parent : id, sub: d.isSub ? d.name : '');
    }
    final msg = txs > 0 ? 'سيتم حذف ${sel.length} تصنيف. المعاملات القديمة ($txs) هتفضل محفوظة ويظهر اسم التصنيف عليها.' : 'سيتم حذف ${sel.length} تصنيف.';
    if (!await confirmDialog(context, 'حذف التصنيفات', msg)) return;
    for (final id in sel.toList()) {
      repo.deleteCat(id);
    }
    setState(sel.clear);
  }

  void _openEditor({CatDef? def, String? parent}) {
    showSheet<void>(context, (c) => _CatEditSheet(def: def, inc: inc, parent: parent ?? def?.parent ?? ''));
  }

  // ---------- صفوف ----------
  Widget _mainRow(Pal p, CatDef d, {required int index}) {
    final ic = catIcon(d.id);
    final subs = repo.subDefs(d.id);
    final isOpen = open.contains(d.id);
    return Column(key: ValueKey('m_${d.id}'), children: [
      Tap(
        scale: .99,
        onTap: edit ? () => _toggle(d.id) : () => _openEditor(def: d),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(children: [
            if (edit) ...[_check(sel.contains(d.id)), const SizedBox(width: 12)],
            _bubble(ic.$1, ic.$2),
            const SizedBox(width: 14),
            Expanded(child: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500))),
            if (!edit) ...[
              _count(repo.catCount(d.id)),
              const SizedBox(width: 8),
              SizedBox(
                width: 34,
                child: subs.isEmpty
                    ? null
                    : Tap(
                        onTap: () => setState(() => isOpen ? open.remove(d.id) : open.add(d.id)),
                        child: AnimatedRotation(turns: isOpen ? (Directionality.of(context) == TextDirection.rtl ? -.25 : .25) : 0, duration: Motion.fade, child: Icon(Icons.chevron_right_rounded, color: p.ink2)),
                      ),
              ),
            ] else
              ReorderableDragStartListener(index: index, child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.drag_handle_rounded, color: p.ink2))),
          ]),
        ),
      ),
      if (!edit)
        AnimatedSize(
          duration: Motion.state,
          curve: Motion.standard,
          alignment: Alignment.topCenter,
          child: isOpen
              ? Column(children: [
                  for (var i = 0; i < subs.length; i++) _subRow(p, d, subs[i], i),
                  Tap(
                    scale: .99,
                    onTap: () => _openEditor(parent: d.id),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(40, 6, 14, 10),
                      child: Row(children: [
                        _bubble(Icons.add_rounded, p.ink2, size: 36),
                        const SizedBox(width: 14),
                        Text('إضافة تصنيف فرعي', style: TextStyle(fontSize: 15.5, color: kBlue)),
                      ]),
                    ),
                  ),
                ])
              : const SizedBox(width: double.infinity),
        ),
      hair(p, indent: 70),
    ]);
  }

  Widget _subRow(Pal p, CatDef parent, CatDef s, int i) {
    final base = catIcon(parent.id);
    final st = repo.catStyle(s.id);
    return Tap(
      scale: .99,
      onTap: () => _openEditor(def: s),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(40, 6, 14, 6),
        child: Row(children: [
          _bubble(st.$1 ?? base.$1, st.$2 ?? _subPalette[(parent.id.length + i) % _subPalette.length], size: 36),
          const SizedBox(width: 14),
          Expanded(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16))),
          _count(repo.catCount(parent.id, sub: s.name)),
          const SizedBox(width: 42),
        ]),
      ),
    );
  }

  Widget _segment(Pal p) {
    Widget tab(String t, bool on, VoidCallback f) => Expanded(
          child: Tap(
            scale: .97,
            onTap: f,
            child: AnimatedContainer(
              duration: Motion.fade,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: on ? p.field : Colors.transparent, borderRadius: BorderRadius.circular(20)),
              child: Text(t, style: TextStyle(fontSize: 15, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? p.ink : p.ink2)),
            ),
          ),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: p.line)),
      child: Row(children: [
        tab('المصروفات', !inc, () => setState(() {
              inc = false;
              sel.clear();
            })),
        tab('الدخل', inc, () => setState(() {
              inc = true;
              sel.clear();
            })),
      ]),
    );
  }

  Widget _toolbar(Pal p) => Row(mainAxisSize: MainAxisSize.min, children: [
        if (edit && sel.isNotEmpty) ...[
          Tap(onTap: _deleteSelected, child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.delete_outline_rounded, color: kRed, size: 26))),
        ],
        Tap(
          onTap: () => setState(() {
            edit = !edit;
            sel.clear();
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: edit ? kBlue : p.field, borderRadius: BorderRadius.circular(18)),
            child: Text(edit ? 'تم' : 'تعديل', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: edit ? Colors.white : p.ink)),
          ),
        ),
        const SizedBox(width: 8),
        Tap(onTap: () => _openEditor(), child: Container(width: 38, height: 38, decoration: BoxDecoration(color: p.field, shape: BoxShape.circle), child: Icon(Icons.add_rounded, color: p.ink, size: 24))),
      ]);

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Live(b: (c) {
      final mains = repo.mainDefs(inc);
      return PageShell(
        title: 'التصنيفات',
        trailing: _toolbar(p),
        child: Column(children: [
          _segment(p),
          Expanded(
            child: mains.isEmpty
                ? Center(child: Text('لا توجد تصنيفات. اضغط + لإضافة تصنيف.', style: TextStyle(color: p.ink2)))
                : Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    clipBehavior: Clip.antiAlias,
                    decoration: iosCard(p, r: 24),
                    child: edit
                        ? ReorderableListView(
                            buildDefaultDragHandles: false,
                            physics: const BouncingScrollPhysics(),
                            onReorder: (o, n) {
                              if (n > o) n--;
                              final ids = mains.map((e) => e.id).toList();
                              ids.insert(n, ids.removeAt(o));
                              repo.reorderCats(ids);
                            },
                            children: [for (var i = 0; i < mains.length; i++) _mainRow(p, mains[i], index: i)],
                          )
                        : ListView(physics: const BouncingScrollPhysics(), padding: EdgeInsets.zero, children: [for (var i = 0; i < mains.length; i++) _mainRow(p, mains[i], index: i)]),
                  ),
          ),
        ]),
      );
    });
  }
}

/// نافذة إضافة/تعديل تصنيف (اسم · رئيسي/فرعي · أيقونة · لون).
class _CatEditSheet extends StatefulWidget {
  final CatDef? def;
  final bool inc;
  final String parent;
  const _CatEditSheet({this.def, required this.inc, this.parent = ''});
  @override
  State<_CatEditSheet> createState() => _CatEditSheetState();
}

class _CatEditSheetState extends State<_CatEditSheet> {
  late final TextEditingController name = TextEditingController(text: widget.def?.name ?? '');
  late String parent = widget.parent;
  late String icon = widget.def?.icon ?? '';
  late int color = widget.def?.color ?? 0;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.def != null;
  bool get _hasSubs => _isEdit && !widget.def!.isSub && repo.subDefs(widget.def!.id).isNotEmpty;

  void _save() {
    final n = name.text.trim();
    if (n.isEmpty) {
      toast(context, 'اكتب اسم التصنيف');
      return;
    }
    final kind = (widget.def?.kind ?? (widget.inc ? 'inc' : 'exp'));
    // منع تكرار نفس الاسم في نفس المستوى
    final dup = (parent.isEmpty ? repo.mainDefs(kind == 'inc') : repo.subDefs(parent)).any((x) => x.name == n && x.id != widget.def?.id);
    if (dup) {
      toast(context, 'التصنيف ده موجود بالفعل');
      return;
    }
    if (_isEdit) {
      final d = widget.def!;
      if (d.isSub && d.parent == parent) {
        repo.renameSub(d, n); // بيحدّث العمليات القديمة بالاسم الجديد
      } else {
        d.name = n;
      }
      d.parent = parent;
      d.icon = icon;
      d.color = color;
      repo.saveCat(d);
    } else {
      final order = parent.isEmpty ? repo.mainDefs(kind == 'inc').length : repo.subDefs(parent).length;
      repo.saveCat(CatDef(id: 'c_${DateTime.now().millisecondsSinceEpoch}', kind: kind, name: n, parent: parent, icon: icon, color: color, ord: order));
    }
    Navigator.of(context).pop();
  }

  Future<void> _pickParent() async {
    final kind = widget.def?.kind ?? (widget.inc ? 'inc' : 'exp');
    final opts = <(String, String)>[('', 'تصنيف رئيسي'), for (final m in repo.mainDefs(kind == 'inc')) if (m.id != widget.def?.id) (m.id, m.name)];
    final r = await showSelect(context, 'يتبع لـ', opts, parent);
    if (r != null) setState(() => parent = r);
  }

  Future<void> _delete() async {
    final d = widget.def!;
    final n = repo.catCount(d.isSub ? d.parent : d.id, sub: d.isSub ? d.name : '');
    final msg = n > 0 ? 'التصنيف عليه $n معاملة. هتفضل محفوظة ويظهر اسم التصنيف عليها.' : 'سيتم حذف "${d.name}".';
    if (!await confirmDialog(context, 'حذف التصنيف', msg)) return;
    repo.deleteCat(d.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final defIc = widget.def != null ? catIcon(widget.def!.isSub ? widget.def!.parent : widget.def!.id) : catIcon('other');
    final curIc = catIconByKey(icon) ?? defIc.$1;
    final curCol = color == 0 ? defIc.$2 : Color(color);
    return SheetFrame(
      title: _isEdit ? 'تعديل التصنيف' : 'تصنيف جديد',
      height: MediaQuery.of(context).size.height * .86,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), physics: const BouncingScrollPhysics(), children: [
        Row(children: [
          Container(width: 54, height: 54, decoration: BoxDecoration(color: curCol, borderRadius: BorderRadius.circular(16)), child: Icon(curIc, color: Colors.white, size: 30)),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(18)),
              child: TextField(controller: name, autofocus: !_isEdit, textInputAction: TextInputAction.done, decoration: InputDecoration(border: InputBorder.none, hintText: 'اسم التصنيف', hintStyle: TextStyle(color: p.ink2))),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        if (!_hasSubs)
          Tap(
            onTap: _pickParent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                Text('النوع', style: TextStyle(color: p.ink2)),
                const Spacer(),
                Text(parent.isEmpty ? 'تصنيف رئيسي' : 'فرعي من ${catOf(parent).name}', style: const TextStyle(fontWeight: FontWeight.w600)),
                Icon(Icons.chevron_right_rounded, color: p.ink2),
              ]),
            ),
          ),
        sectionLabel(p, 'اللون'),
        Wrap(spacing: 10, runSpacing: 10, children: [
          Tap(
            onTap: () => setState(() => color = 0),
            child: Container(width: 38, height: 38, decoration: BoxDecoration(color: p.field, shape: BoxShape.circle, border: Border.all(color: color == 0 ? kBlue : Colors.transparent, width: 2.5)), child: Icon(Icons.auto_awesome_rounded, size: 18, color: p.ink2)),
          ),
          for (final c in kCatColors)
            Tap(
              onTap: () => setState(() => color = c.toARGB32()),
              child: Container(width: 38, height: 38, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: color == c.toARGB32() ? p.ink : Colors.transparent, width: 2.5))),
            ),
        ]),
        sectionLabel(p, 'الأيقونة'),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final e in kCatIconPalette.entries)
            Tap(
              onTap: () => setState(() => icon = e.key),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: icon == e.key ? curCol : p.field, borderRadius: BorderRadius.circular(14)),
                child: Icon(e.value, size: 25, color: icon == e.key ? Colors.white : p.ink2),
              ),
            ),
        ]),
        const SizedBox(height: 22),
        Tap(
          onTap: _save,
          child: Container(height: 52, alignment: Alignment.center, decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(26)), child: const Text('حفظ', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700))),
        ),
        if (_isEdit) ...[
          const SizedBox(height: 10),
          Tap(
            onTap: _delete,
            child: Container(height: 50, alignment: Alignment.center, decoration: BoxDecoration(color: kRed.withValues(alpha: .14), borderRadius: BorderRadius.circular(25)), child: Text('حذف التصنيف', style: TextStyle(color: kRed, fontSize: 16, fontWeight: FontWeight.w600))),
          ),
        ],
      ]),
    );
  }
}
