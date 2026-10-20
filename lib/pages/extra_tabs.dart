import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/sheets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// عنوان الصفحة داخل بانل واحدة، وزر الرجوع (لو موجود) جزء من نفس البانل بدل ما يكون زر عائم لوحده.
Widget _bigTitle(String t, String sub, Pal p, {VoidCallback? back}) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: iosCard(p, r: 22),
        child: Row(children: [
          if (back != null) ...[
            Tap(onTap: back, child: Container(width: 40, height: 40, decoration: BoxDecoration(color: p.field, shape: BoxShape.circle), child: Icon(Icons.chevron_left_rounded, color: p.ink))),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              Text(sub, style: TextStyle(fontSize: 13, color: p.ink2)),
            ]),
          ),
        ]),
      ),
    );

/// تبويب الميزانيات.
class BudgetsTab extends StatelessWidget {
  final bool embedded;
  const BudgetsTab({super.key, this.embedded = false});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final top = MediaQuery.of(context).padding.top;
    return Live(b: (c) {
      final seen = <String>{};
      final list = <Budget>[];
      for (final a in repo.accList) {
        final b = repo.budgetFor(a);
        if (seen.add(b.id)) list.add(b);
      }
      final now = DateTime.now();
      return ListView(padding: EdgeInsets.fromLTRB(16, top + 20, 16, 130), physics: const BouncingScrollPhysics(), children: [
        _bigTitle('Budgets', '${monthEn(now.month)} ${now.year}', p, back: !embedded ? () => Navigator.of(context).maybePop() : null),
        for (final b in list)
          () {
            final spent = repo.budgetSpent(b.id, now.year, now.month);
            final frac = b.limit > 0 ? (spent / b.limit).clamp(0.0, 1.0) : 0.0;
            final over = b.limit > 0 && spent > b.limit;
            return Reveal(
              i: 1,
              child: Tap(
                scale: .98,
                onTap: () => showBudgetSheet(context, b),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: iosCard(p, r: 22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(width: 40, height: 40, decoration: BoxDecoration(color: kBlue.withValues(alpha: .18), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.inbox_rounded, color: kBlue, size: 22)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(b.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
                      Text(b.limit > 0 ? egp(b.limit - spent) : 'No limit', style: TextStyle(fontSize: 15, color: over ? kRed : kGreen)),
                    ]),
                    const SizedBox(height: 14),
                    ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: frac, minHeight: 8, backgroundColor: p.field, valueColor: AlwaysStoppedAnimation(over ? kRed : (frac > .8 ? kOrange : kBlue)))),
                    const SizedBox(height: 8),
                    Text('المصروف ${egp(spent)}${b.limit > 0 ? ' من ${egp(b.limit)}' : ' · اضغط لتحديد حد شهري'}', style: TextStyle(fontSize: 13, color: p.ink2)),
                  ]),
                ),
              ),
            );
          }(),
      ]);
    });
  }
}
