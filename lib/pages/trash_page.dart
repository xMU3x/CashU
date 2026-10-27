import 'package:flutter/material.dart' hide Text;
import '../core/currency.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/loc_text.dart';
import '../ui/sheets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// مدة الاحتفاظ بالمحذوفات (أيام) — يحددها المستخدم.
int get trashDays => S.num_('trashDays', 30).toInt().clamp(1, 365);

/// سلة المهملات: المعاملات المحذوفة مؤقتًا مع استرجاعها، ومدة الاحتفاظ قابلة للتغيير.
class TrashPage extends StatelessWidget {
  const TrashPage({super.key});

  Future<void> _pickDays(BuildContext context) async {
    final r = await showSelect(context, 'مدة الاحتفاظ بالمحذوفات', const [('7', 'أسبوع'), ('14', 'أسبوعين'), ('30', 'شهر'), ('60', 'شهرين'), ('90', '٣ شهور')], '$trashDays');
    if (r != null) S.put('trashDays', int.parse(r));
  }

  String _age(Tx t) {
    final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(t.u)).inDays;
    final left = (trashDays - d).clamp(0, 999);
    return d == 0 ? 'اتحذفت النهارده · باقي $left يوم' : 'اتحذفت من $d يوم · باقي $left يوم';
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: 'سلة المهملات',
      icon: Icons.delete_outline_rounded,
      iconColor: kRed,
      trailing: Tap(
        onTap: () => _pickDays(context),
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(18)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.timer_outlined, size: 18, color: p.ink2), const SizedBox(width: 6), Text('$trashDays يوم', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))])),
      ),
      child: Live(b: (c) {
        final l = repo.trashed(trashDays);
        if (l.isEmpty) return ListView(children: [emptyState(p, Icons.delete_outline_rounded, 'السلة فاضية')]);
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
            child: Row(children: [
              Expanded(child: Text('المعاملات هنا بتفضل ${trashDays} يوم وبعدها بتختفي من السلة.', style: TextStyle(fontSize: 13, color: p.ink2))),
              Tap(onTap: () {
                for (final t in l) {
                  repo.restoreTx(t.id);
                }
                toast(context, 'تم استرجاع ${l.length} معاملة');
              }, child: Padding(padding: const EdgeInsets.all(6), child: Text('استرجاع الكل', style: TextStyle(fontSize: 14, color: kBlue, fontWeight: FontWeight.w700)))),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              itemCount: l.length,
              itemBuilder: (c, i) {
                final t = l[i];
                final ic = txIcon(t);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    iconBubble(p, ic.$1, size: 44, color: ic.$2),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(txTitle(t), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(_age(t), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: p.ink2)),
                    ])),
                    MoneyText(t.amt, cur: t.cur, style: TextStyle(fontSize: 15, color: t.type == 'inc' ? kGreen : (t.type == 'exp' ? kRed : p.ink))),
                    Tap(onTap: () {
                      repo.restoreTx(t.id);
                      toast(context, 'تم استرجاع المعاملة');
                    }, child: Padding(padding: const EdgeInsets.all(10), child: Icon(Icons.restore_from_trash_rounded, color: kBlue))),
                  ]),
                );
              },
            ),
          ),
        ]);
      }),
    );
  }
}
