import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../core/settings.dart';
import '../core/util.dart';
import '../ui/anim.dart';
import '../ui/sheets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class SupervisePage extends StatefulWidget {
  const SupervisePage({super.key});
  @override
  State<SupervisePage> createState() => _SuperviseState();
}

class _SuperviseState extends State<SupervisePage> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  String get _code {
    var k = S.str('invite', '');
    if (k.isEmpty) {
      const ch = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      final r = math.Random();
      k = List.generate(6, (_) => ch[r.nextInt(ch.length)]).join();
      S.put('invite', k);
    }
    return k;
  }

  Widget _hero(Pal p) => Container(
        height: 190,
        decoration: BoxDecoration(color: const Color(0xFFEAF5F2), borderRadius: BorderRadius.circular(32)),
        child: AnimatedBuilder(
          animation: c,
          builder: (_, __) {
            final t = c.value;
            return LayoutBuilder(builder: (ctx, bc) {
              final w = bc.maxWidth;
              final x = 60 + (w - 120) * Curves.easeInOut.transform(t);
              return Stack(children: [
                Positioned(left: 54, right: 54, top: 100, child: CustomPaint(size: const Size(double.infinity, 2), painter: DashPainter(const Color(0xFF4AA39B), 0))),
                Positioned(right: 26, top: 56, child: Container(width: 92, height: 92, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF4AA39B), width: 3)), child: const Icon(Icons.person_rounded, size: 46, color: Color(0xFF4AA39B)))),
                Positioned(left: 26, top: 56, child: Container(width: 84, height: 84, decoration: BoxDecoration(color: const Color(0xFFFBE8E0), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE0825E), width: 3)), child: const Icon(Icons.person_rounded, size: 42, color: Color(0xFFE0825E)))),
                Positioned(left: x - 22, top: 78 + math.sin(t * math.pi * 2) * 5, child: Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE0825E), width: 2)), child: const Icon(Icons.receipt_long_rounded, size: 22, color: Color(0xFFE0825E)))),
                Positioned(left: w / 2 - 17, top: 84, child: Transform.scale(scale: .9 + .15 * math.sin(t * math.pi * 2), child: Container(width: 34, height: 34, decoration: const BoxDecoration(color: Color(0xFFA9D8D2), shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: Color(0xFF2E7568), size: 20)))),
              ]);
            });
          },
        ),
      );

  Widget _card(Pal p, IconData i, Color bg, Color fg, String t, String s, VoidCallback f) => Expanded(
        child: Tap(
          onTap: f,
          child: Container(
            height: 190,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(i, color: fg, size: 32),
              const Spacer(),
              Text(t, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.3)),
              const SizedBox(height: 4),
              Text(s, style: TextStyle(color: fg, fontSize: 15)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 16, 130),
      physics: const BouncingScrollPhysics(),
      children: [
        Reveal(i: 0, child: const TopBar(back: false, title: 'الإشراف الذكي', sub: 'مَن يرى مَن', icon: Icons.volunteer_activism_rounded, iconColor: Color(0xFF5B8DEF))),
        const SizedBox(height: 18),
        Reveal(i: 1, child: _hero(p)),
        const SizedBox(height: 22),
        Reveal(i: 2, child: const Text('تابعوا مصاريف بعض', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800))),
        const SizedBox(height: 8),
        Reveal(i: 3, child: Text('أب يتابع مصروف ابنه، أو شخصان يساعد أحدهما الآخر على الالتزام. المشرف يرى فقط ولا يعدّل شيئًا.', style: TextStyle(color: p.ink2, fontSize: 17, height: 1.7))),
        const SizedBox(height: 22),
        Reveal(
          i: 4,
          child: Row(children: [
            _card(p, Icons.visibility_rounded, const Color(0xFFEAF5F2), const Color(0xFF2E7568), 'أريد متابعة شخص', 'معي كود دعوة', () => _enterCode(context)),
            const SizedBox(width: 12),
            _card(p, Icons.send_rounded, const Color(0xFFFBEFEA), const Color(0xFFC96A4A), 'أريد أن يتابعني شخص', 'أرسل دعوة', () => _invite(context)),
          ]),
        ),
      ],
    );
  }

  void _invite(BuildContext context) => showSheet<void>(context, (x) {
        final p = Pal.of(x);
        return SheetFrame(
          title: 'كود دعوتك',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 22), decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(24)), child: Center(child: Text(_code, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: 8)))),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: bigButton(p, 'نسخ', p.ink2, () {
                  Clipboard.setData(ClipboardData(text: _code));
                  toast(x, 'تم النسخ');
                })),
                const SizedBox(width: 10),
                Expanded(child: bigButton(p, 'مشاركة', const Color(0xFFC96A4A), () => Share.share('تابع مصاريفي على تيّار — كود الدعوة: $_code'))),
              ]),
            ]),
          ),
        );
      });

  void _enterCode(BuildContext context) async {
    final r = await promptText(context, 'أدخل كود الدعوة', hint: 'XXXXXX');
    if (r == null || r.isEmpty || !context.mounted) return;
    toast(context, 'ربط الحسابات يحتاج جدول مشاركة في السيرفر — لم يُفعَّل بعد');
  }
}
