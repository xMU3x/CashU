import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/sheets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../core/util.dart' show toAr;
import 'obligations_page.dart' show monthCommitments, Commitment;

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
      final commits = monthCommitments(now);
      double committedOf(Budget b) => commits.where((x) => repo.budgetFor(repo.account(x.acc) ?? repo.account(repo.defaultAcc) ?? repo.accList.first).id == b.id).fold(0.0, (s, x) => s + x.amt);
      return ListView(padding: EdgeInsets.fromLTRB(16, top + 20, 16, 130), physics: const BouncingScrollPhysics(), children: [
        _bigTitle('Budgets', '${monthEn(now.month)} ${now.year}', p, back: !embedded ? () => Navigator.of(context).maybePop() : null),
        for (final b in list)
          () {
            final spent0 = repo.budgetSpent(b.id, now.year, now.month);
            final comm = committedOf(b);
            final spent = spent0 + comm; // المصروف + الالتزامات اللي لسه ما اتسجلتش
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
                      Container(width: 40, height: 40, decoration: BoxDecoration(color: kBlue.withValues(alpha: .18), borderRadius: BorderRadius.circular(11)), child: Icon(Icons.inbox_rounded, color: kBlue, size: 22)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(b.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
                      Text(b.limit > 0 ? egp(b.limit - spent) : 'No limit', style: TextStyle(fontSize: 15, color: over ? kRed : kGreen)),
                    ]),
                    const SizedBox(height: 14),
                    ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: frac, minHeight: 8, backgroundColor: p.field, valueColor: AlwaysStoppedAnimation(over ? kRed : (frac > .8 ? kOrange : kBlue)))),
                    const SizedBox(height: 8),
                    Text('المصروف ${egp(spent0)}${comm > 0 ? ' + التزامات ${egp(comm)}' : ''}${b.limit > 0 ? ' من ${egp(b.limit)}' : ' · اضغط لتحديد حد شهري'}', style: TextStyle(fontSize: 13, color: p.ink2)),
                  ]),
                ),
              ),
            );
          }(),
        if (commits.isNotEmpty)
          Reveal(
            i: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: iosCard(p, r: 22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.event_note_rounded, color: kOrange, size: 22),
                  const SizedBox(width: 10),
                  Expanded(child: Text('التزامات الشهر (لسه ما اتسجلتش)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  Text(egp(commits.fold(0.0, (s, x) => s + x.amt)), style: TextStyle(fontWeight: FontWeight.w700, color: kOrange)),
                ]),
                const SizedBox(height: 10),
                for (final x in commits)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Container(width: 34, height: 34, decoration: BoxDecoration(color: x.color.withValues(alpha: .18), borderRadius: BorderRadius.circular(10)), child: Icon(x.icon, color: x.color, size: 19)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(x.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                        Text('${x.sub}${x.when == null ? '' : ' · ${toAr('${x.when!.day}')}/${toAr('${x.when!.month}')}'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.ink2)),
                      ])),
                      Text(egp(x.amt), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                    ]),
                  ),
              ]),
            ),
          ),
      ]);
    });
  }
}
