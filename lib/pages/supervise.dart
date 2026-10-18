import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../core/settings.dart';
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

  // رسم مسطّح: شخصان وبينهما إيصال يتحرك — بألوان الثيم فقط
  Widget _hero(Pal p) => Container(
        height: 170,
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(28), border: Border.all(color: p.line)),
        child: AnimatedBuilder(
          animation: c,
          builder: (_, __) {
            final t = c.value;
            return LayoutBuilder(builder: (ctx, bc) {
              final w = bc.maxWidth;
              final x = 74 + (w - 148) * Curves.easeInOut.transform(t);
              Widget node(IconData i, Color col) => Container(width: 64, height: 64, decoration: BoxDecoration(color: col.withValues(alpha: .15), shape: BoxShape.circle), child: Icon(i, size: 30, color: col));
              return Stack(children: [
                Positioned(left: 60, right: 60, top: 84, child: CustomPaint(size: const Size(double.infinity, 2), painter: DashPainter(p.line, 0))),
                Positioned(right: 20, top: 53, child: node(Icons.person_rounded, kBlue)),
                Positioned(left: 20, top: 53, child: node(Icons.person_outline_rounded, kGreen)),
                Positioned(left: x - 18, top: 66 + math.sin(t * math.pi * 2) * 4, child: Container(width: 36, height: 36, decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.receipt_long_rounded, size: 20, color: p.ink2))),
              ]);
            });
          },
        ),
      );

  Widget _card(Pal p, IconData i, Color col, String t, String s, VoidCallback f) => Expanded(
        child: Tap(
          onTap: f,
          child: Container(
            height: 150,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: p.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: col.withValues(alpha: .15), borderRadius: BorderRadius.circular(14)), child: Icon(i, color: col, size: 24)),
              const Spacer(),
              Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.3)),
              const SizedBox(height: 2),
              Text(s, style: TextStyle(color: p.ink2, fontSize: 13)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 16, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        Reveal(i: 0, child: const TopBar(title: 'الرقابة', sub: 'مَن يرى مَن', icon: Icons.verified_user_outlined, iconColor: kBlue)),
        const SizedBox(height: 16),
        Reveal(i: 1, child: _hero(p)),
        const SizedBox(height: 20),
        Reveal(i: 2, child: const Text('تابعوا مصاريف بعض', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
        const SizedBox(height: 8),
        Reveal(i: 3, child: Text('أب يتابع مصروف ابنه، أو شخصان يساعد أحدهما الآخر على الالتزام. المشرف يرى فقط ولا يعدّل شيئًا.', style: TextStyle(color: p.ink2, fontSize: 15, height: 1.7))),
        const SizedBox(height: 20),
        Reveal(
          i: 4,
          child: Row(children: [
            _card(p, Icons.visibility_rounded, kGreen, 'أريد متابعة شخص', 'معي كود دعوة', () => _enterCode(context)),
            const SizedBox(width: 12),
            _card(p, Icons.send_rounded, kBlue, 'أريد أن يتابعني شخص', 'أرسل دعوة', () => _invite(context)),
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
                Expanded(child: bigButton(p, 'مشاركة', kBlue, () => Share.share('تابع مصاريفي على CashU — كود الدعوة: $_code'))),
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
