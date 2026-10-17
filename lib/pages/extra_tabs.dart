import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/util.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/sheets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'add_tx.dart';

Widget _bigTitle(String t, String sub, Pal p) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
        Text(sub, style: TextStyle(fontSize: 13, color: p.ink2)),
      ]),
    );

/// تبويب الميزانيات.
class BudgetsTab extends StatelessWidget {
  const BudgetsTab({super.key});
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
        _bigTitle('Budgets', '${monthEn(now.month)} ${now.year}', p),
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
                    Text('Spent ${egp(spent)}${b.limit > 0 ? ' of ${egp(b.limit)}' : ' · tap to set a monthly limit'}', style: TextStyle(fontSize: 13, color: p.ink2)),
                  ]),
                ),
              ),
            );
          }(),
      ]);
    });
  }
}

/// تبويب المعاملات المجدولة (المتكررة).
class ScheduledTab extends StatelessWidget {
  const ScheduledTab({super.key});
  static const _names = {'daily': 'Daily', 'weekly': 'Weekly', 'monthly': 'Monthly'};
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final top = MediaQuery.of(context).padding.top;
    return Live(b: (c) {
      final list = repo.recurring;
      return ListView(padding: EdgeInsets.fromLTRB(16, top + 20, 16, 130), physics: const BouncingScrollPhysics(), children: [
        _bigTitle('Subscriptions', '${list.length} repeating transaction${list.length == 1 ? '' : 's'}', p),
        if (list.isEmpty)
          emptyState(p, Icons.autorenew_rounded, 'No scheduled transactions.\nOpen a transaction and choose Make Scheduled.')
        else
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: iosCard(p, r: 22),
            child: Column(children: [
              for (var i = 0; i < list.length; i++)
                SwipeRow(
                  key: ValueKey(list[i].id),
                  bg: p.bg,
                  leftW: 90,
                  leftActions: swipeCircle(Icons.stop_circle_outlined, 'Stop', kRed, () => repo.saveTx(list[i].clone()..rep = 'none')),
                  child: Tap(
                    scale: .99,
                    onTap: () => Navigator.of(context).push(sheetRoute(AddTxPage(edit: list[i]))),
                    child: Container(
                      color: p.card,
                      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                      child: Row(children: [
                        Container(width: 42, height: 42, decoration: BoxDecoration(color: p.field.withValues(alpha: .55), borderRadius: BorderRadius.circular(11)), child: Icon(txIcon(list[i]).$1, color: txIcon(list[i]).$2, size: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(txTitle(list[i]), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w500)),
                            Text('${_names[list[i].rep] ?? ''} · Next ${enDate(DateTime.fromMillisecondsSinceEpoch(list[i].nx))}', style: TextStyle(fontSize: 13, color: p.ink2)),
                          ]),
                        ),
                        Text(fixed2(list[i].amt), style: TextStyle(fontSize: 16.5, color: list[i].type == 'inc' ? kGreen : kRed)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
      ]);
    });
  }
}
