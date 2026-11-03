import 'dart:convert';
import 'package:flutter/material.dart' hide Text;
import 'loc_text.dart';
import '../core/fixed_icons.dart';
import '../core/icon_pick.dart';
import 'anim.dart';
import 'motion.dart';
import 'cached_img.dart';
import 'sheets.dart' show promptText;
import 'theme.dart';
import 'widgets.dart';

/// أفاتار موحّد للأيقونة: `ic:<key>` (مكتبة) · data-URI (مرفوعة) · رابط · وإلا حرف أول الاسم بلون [color].
Widget iconAvatar(String img, {String name = '', double size = 48, Color color = const Color(0xFF1E9BE8), bool circle = true}) {
  final r = circle ? BorderRadius.circular(size) : BorderRadius.circular(size * .28);
  Widget fb() => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withValues(alpha: .18), borderRadius: r),
        child: Text(name.trim().isEmpty ? '؟' : name.trim().characters.first.toUpperCase(), style: TextStyle(fontSize: size * .42, fontWeight: FontWeight.w700, color: color)),
      );
  final fx = fixedIconOf(img);
  if (fx != null) {
    return Container(width: size, height: size, alignment: Alignment.center, decoration: BoxDecoration(color: fx.color.withValues(alpha: .18), borderRadius: r), child: Icon(fx.icon, size: size * .52, color: fx.color));
  }
  if (img.startsWith('data:image')) {
    try {
      return ClipRRect(borderRadius: r, child: Image.memory(base64Decode(img.substring(img.indexOf(',') + 1)), width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (c, e, s) => fb()));
    } catch (_) {
      return fb();
    }
  }
  if (img.startsWith('http')) return ClipRRect(borderRadius: r, child: CachedImg(img, width: size, height: size, fit: BoxFit.cover, fallback: fb()));
  return fb();
}

/// شبكة أيقونات موحّدة (٧ في الصف) مقسّمة أقسام (اتصالات · سكن · أكل · …) مع بحث وشريط أقسام.
/// بتتحط جوه أي ListView/Sheet (من غير تمرير داخلي). [onPick] بيرجّع مفتاح الأيقونة (g_*).
class IconGrid extends StatefulWidget {
  final String selected;
  final Color? tint;
  final ValueChanged<String> onPick;
  const IconGrid({super.key, this.selected = '', this.tint, required this.onPick});
  @override
  State<IconGrid> createState() => _IconGridState();
}

class _IconGridState extends State<IconGrid> {
  String sec = 'all';
  final q = TextEditingController();

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  Widget _chip(Pal p, String t, IconData? ic, bool on, VoidCallback f) => Tap(
        scale: .95,
        onTap: f,
        child: AnimatedContainer(
          duration: CashUMotion.small,
          margin: const EdgeInsetsDirectional.only(end: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          height: 36,
          decoration: BoxDecoration(color: on ? kBlue : p.field, borderRadius: BorderRadius.circular(18)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (ic != null) ...[Icon(ic, size: 16, color: on ? Colors.white : p.ink2), const SizedBox(width: 5)],
            Text(t, style: TextStyle(fontSize: 13.5, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? Colors.white : p.ink2)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final f = q.text.trim().toLowerCase();
    final secs = [for (final s in kIconSections) if (sec == 'all' || s.id == sec) s];
    final blocks = <Widget>[];
    for (final s in secs) {
      final items = [for (final e in s.items) if (f.isEmpty || e.label.toLowerCase().contains(f) || e.key.contains(f)) e];
      if (items.isEmpty) continue;
      final c = widget.tint ?? s.color;
      blocks.add(Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Row(children: [
          Icon(s.icon, size: 18, color: s.color),
          const SizedBox(width: 8),
          Text(s.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Text('${items.length}', style: TextStyle(fontSize: 12.5, color: p.ink2)),
        ]),
      ));
      blocks.add(GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 7,
        crossAxisSpacing: 7,
        children: [
          for (final e in items)
            Tap(
              scale: .9,
              onTap: () => widget.onPick(e.key),
              child: AnimatedContainer(
                duration: CashUMotion.small,
                decoration: BoxDecoration(color: c.withValues(alpha: e.key == widget.selected ? .3 : .13), borderRadius: BorderRadius.circular(13), border: Border.all(color: e.key == widget.selected ? c : Colors.transparent, width: 2)),
                child: Icon(e.icon, color: c, size: 23),
              ),
            ),
        ],
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(21)),
        child: Row(children: [
          Icon(Icons.search_rounded, size: 20, color: p.ink2),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: q, onChanged: (_) => setState(() {}), style: const TextStyle(fontSize: 15), decoration: InputDecoration(border: InputBorder.none, isDense: true, hintText: 'ابحث عن أيقونة', hintStyle: TextStyle(color: p.ink2)))),
          if (q.text.isNotEmpty) Tap(onTap: () => setState(q.clear), child: Icon(Icons.cancel_rounded, size: 18, color: p.ink2)),
        ]),
      ),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _chip(p, 'الكل', Icons.apps_rounded, sec == 'all', () => setState(() => sec = 'all')),
          for (final s in kIconSections) _chip(p, s.title, s.icon, sec == s.id, () => setState(() => sec = s.id)),
        ]),
      ),
      if (blocks.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 30), child: Center(child: Text('لا توجد نتائج', style: TextStyle(color: p.ink2)))) else ...blocks,
    ]);
  }
}

/// مكتبة الأيقونات الموحّدة (نفس الشبكة في كل التطبيق): أقسام + بحث + رفع من الجهاز + سحب من رابط.
/// ترجع النص الجديد للأيقونة (`ic:g_*` أو data-URI)، أو '' لو المستخدم اختار الرجوع للافتراضي، أو null لو قفل من غير اختيار.
Future<String?> showIconLibrary(BuildContext context, {String current = '', String title = 'اختيار أيقونة', String resetLabel = 'استخدام الافتراضي'}) async {
  String? result;
  await showSheet<void>(context, (c) {
    final p = Pal.of(c);
    void done(String v) {
      result = v;
      Navigator.of(c).pop();
    }

    Widget row(IconData ic, String t, Future<void> Function() f) => Tap(
          onTap: f,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(22)),
            child: Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: kBlue.withValues(alpha: .16), borderRadius: BorderRadius.circular(13)), child: Icon(ic, color: kBlue, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
            ]),
          ),
        );
    return SheetFrame(
      title: title,
      height: MediaQuery.of(c).size.height * .88,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          IconGrid(selected: current.startsWith(kFixedPrefix) ? current.substring(kFixedPrefix.length) : '', onPick: (k) => done('$kFixedPrefix$k')),
          const SizedBox(height: 16),
          row(Icons.photo_library_rounded, 'رفع من الجهاز', () async {
            final r = await pickIconFromGallery();
            if (r != null) done(r);
          }),
          row(Icons.link_rounded, 'سحب من رابط صورة', () async {
            final u = await promptText(c, 'رابط الصورة', hint: 'https://...');
            if (u == null || u.trim().isEmpty) return;
            if (c.mounted) toast(c, 'جارٍ تحميل الصورة...');
            final r = await iconFromUrl(u);
            if (!c.mounted) return;
            if (r == null) {
              toast(c, 'تعذّر تحميل الصورة من الرابط');
            } else {
              done(r);
            }
          }),
          row(Icons.restart_alt_rounded, resetLabel, () async => done('')),
        ],
      ),
    );
  });
  return result;
}
