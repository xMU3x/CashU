import 'package:flutter/material.dart' hide Text;
import '../core/repo.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/loc_text.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// الحسابات المؤرشفة: تظهر هنا بنفس بياناتها ومعاملاتها، ويمكن استرجاعها بضغطة.
class ArchivedAccountsPage extends StatelessWidget {
  const ArchivedAccountsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: 'الحسابات المؤرشفة',
      sub: 'المعاملات تفضل محفوظة كما هي',
      icon: Icons.inventory_2_outlined,
      iconColor: kBlue,
      child: Live(b: (c) {
        final list = repo.archivedList;
        if (list.isEmpty) return emptyState(p, Icons.inventory_2_outlined, 'لا توجد حسابات مؤرشفة.');
        return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), physics: const BouncingScrollPhysics(), children: [
          for (final a in list)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: iosCard(p, r: 20),
              child: Row(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(14)), child: Icon(Icons.account_balance_wallet_rounded, color: p.ink2, size: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600)),
                    Text('${repo.txOf(a.id).length} معاملة', style: TextStyle(fontSize: 12.5, color: p.ink2)),
                  ]),
                ),
                Tap(
                  onTap: () {
                    repo.restoreAccount(a.id);
                    toast(context, 'تم استرجاع "${a.name}"');
                  },
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9), decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(20)), child: const Text('استرجاع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                ),
              ]),
            ),
        ]);
      }),
    );
  }
}
