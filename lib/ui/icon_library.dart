import 'dart:convert';
import 'package:flutter/material.dart' hide Text;
import 'loc_text.dart';
import '../core/fixed_icons.dart';
import '../core/icon_pick.dart';
import 'anim.dart';
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
  if (img.startsWith('http')) return ClipRRect(borderRadius: r, child: Image.network(img, width: size, height: size, fit: BoxFit.cover, errorBuilder: (c, e, s) => fb()));
  return fb();
}

/// مكتبة الأيقونات الموحّدة (نفس بانل «أقساطي» في كل التطبيق): أيقونات جاهزة + رفع من الجهاز + سحب من رابط.
/// ترجع النص الجديد للأيقونة، أو '' لو المستخدم اختار الرجوع للافتراضي، أو null لو قفل من غير اختيار.
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
    final maxH = MediaQuery.of(c).size.height * .78;
    return SheetFrame(
      title: title,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: ListView(
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 6,
              childAspectRatio: .82,
              children: [
                for (final f in kFixedIcons)
                  Tap(
                    scale: .92,
                    onTap: () => done('$kFixedPrefix${f.key}'),
                    child: Column(children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(color: f.color.withValues(alpha: .16), shape: BoxShape.circle, border: Border.all(color: current == '$kFixedPrefix${f.key}' ? f.color : Colors.transparent, width: 2)),
                        child: Icon(f.icon, color: f.color, size: 27),
                      ),
                      const SizedBox(height: 4),
                      Text(f.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
                    ]),
                  ),
              ],
            ),
            const SizedBox(height: 12),
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
      ),
    );
  });
  return result;
}
