import 'package:flutter/material.dart' hide Text;
import '../ui/tr.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../ui/anim.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// المتجر: ثيمات تُشترى بالعملات التي تكسبها من التزامك اليومي بالتسجيل.
class ShopPage extends StatelessWidget {
  const ShopPage({super.key});
  @override
  Widget build(BuildContext context) => Live(b: (c) => _body(context, embedded: false));

  static Widget embedded() => Live(b: (c) => _body(c, embedded: true));

  static Widget _body(BuildContext context, {required bool embedded}) {
    final p = Pal.of(context);
    final owned = S.list('own');
    final cur = S.str('theme', 'terra');
    final coins = repo.coins;
    final grid = ListView(
      padding: EdgeInsets.fromLTRB(16, embedded ? MediaQuery.of(context).padding.top + 10 : 4, 16, embedded ? 130 : 40),
      physics: const BouncingScrollPhysics(),
      children: [
        if (embedded) const Padding(padding: EdgeInsets.only(bottom: 12), child: TopBar(back: false, title: 'المتجر', sub: 'ثيمات بعملات التزامك', icon: Icons.shopping_bag_rounded)),
        Reveal(
          i: 0,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: p.dark, borderRadius: BorderRadius.circular(28)),
            child: Row(children: [
              const Text('🪙', style: TextStyle(fontSize: 42)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [CountText(coins.toDouble(), dec: 0, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)), const Text('٥ عملات لكل يوم تسجّل فيه + ٢ لكل يوم في سلسلتك', style: TextStyle(color: Colors.white60, fontSize: 12))])),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < kThemes.length; i++)
          Reveal(
            i: i + 1,
            child: Builder(builder: (ctx) {
              final t = kThemes[i];
              final has = t.price == 0 || owned.contains(t.id);
              final on = cur == t.id;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(26), border: Border.all(color: on ? t.color : Colors.transparent, width: 2)),
                child: Row(children: [
                  Container(width: 74, height: 74, decoration: BoxDecoration(gradient: LinearGradient(colors: [t.color, Color.lerp(t.color, Colors.black, .35)!], begin: Alignment.topRight, end: Alignment.bottomLeft), borderRadius: BorderRadius.circular(22)), child: on ? const Icon(Icons.check_rounded, color: Colors.white, size: 34) : null),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)), Text(has ? (on ? 'مُفعّل' : 'مملوك') : '🪙 ${t.price}', style: TextStyle(color: p.ink2))])),
                  Tap(
                    onTap: () {
                      if (has) {
                        S.put('theme', t.id);
                      } else if (coins >= t.price) {
                        S.put('spent', S.num_('spent').toInt() + t.price);
                        S.put('own', [...owned, t.id]);
                        S.put('theme', t.id);
                        toast(ctx, 'تم الشراء 🎉');
                      } else {
                        toast(ctx, 'تحتاج ${t.price - coins} عملة إضافية');
                      }
                    },
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11), decoration: BoxDecoration(color: on ? p.field : t.color, borderRadius: BorderRadius.circular(20)), child: Text(on ? 'حالي' : has ? 'استخدم' : 'اشترِ', style: TextStyle(color: on ? p.ink2 : Colors.white, fontWeight: FontWeight.w700))),
                  ),
                ]),
              );
            }),
          ),
      ],
    );
    if (embedded) return grid;
    return PageShell(title: 'المتجر', sub: 'ثيمات بعملات التزامك', icon: Icons.shopping_bag_rounded, child: grid);
  }
}
