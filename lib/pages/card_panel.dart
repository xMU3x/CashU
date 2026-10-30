import 'package:flutter/material.dart' hide Text;
import '../core/extras.dart';
import '../core/repo.dart';
import '../core/util.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/loc_text.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'installments_page.dart';

/// لوحة البطاقة الائتمانية: الحد، المتاح، المديونية الفعلية، إجمالي المستحق، المدفوع، المتبقي، القسط الشهري وموعده.
/// المديونية الفعلية (اللي اتسحب من البطاقة) غير الأقساط المحجوزة من الحد (مش مصروف مدفوع).
class CardPanel extends StatelessWidget {
  final String accId;
  const CardPanel({super.key, required this.accId});

  Widget _stat(Pal p, String label, Widget value) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: p.ink2)),
          const SizedBox(height: 3),
          value,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Live(b: (c) {
      final a = repo.account(accId);
      if (a == null || a.kind != 'credit') return const SizedBox.shrink();
      final s = extras.cardSummary(accId);
      if (s.limit <= 0 && s.plans == 0) return const SizedBox.shrink();
      final used = s.limit <= 0 ? 0.0 : ((s.totalDue) / s.limit).clamp(0.0, 1.0);
      final availCol = s.overLimit ? kRed : (used > .85 ? kOrange : kGreen);
      TextStyle v([Color? c]) => TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: c);
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(26)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.credit_score_rounded, color: kBlue, size: 22),
            const SizedBox(width: 8),
            const Expanded(child: Text('البطاقة الائتمانية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            if (s.plans > 0)
              Tap(onTap: () => Navigator.of(context).push(flowRoute(const InstPage())), child: Padding(padding: const EdgeInsets.all(4), child: Text('الأقساط (${toAr('${s.plans}')})', style: TextStyle(fontSize: 13.5, color: kBlue, fontWeight: FontWeight.w600)))),
          ]),
          const SizedBox(height: 10),
          Text('المتاح', style: TextStyle(fontSize: 13, color: p.ink2)),
          MoneyText(s.available, style: TextStyle(fontSize: 30, color: availCol)),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: used, minHeight: 7, backgroundColor: p.field, valueColor: AlwaysStoppedAnimation(availCol))),
          if (s.overLimit) Padding(padding: const EdgeInsets.only(top: 6), child: Text('تخطّيت الحد الائتماني', style: TextStyle(fontSize: 13, color: kRed, fontWeight: FontWeight.w600))),
          const SizedBox(height: 14),
          Row(children: [
            _stat(p, 'الحد الائتماني', MoneyText(s.limit, style: v())),
            _stat(p, 'المديونية الفعلية', MoneyText(s.posted, style: v(s.posted > 0 ? kRed : null))),
          ]),
          if (s.plans > 0) ...[
            const SizedBox(height: 12),
            Divider(color: p.line, height: 1),
            const SizedBox(height: 12),
            Row(children: [
              _stat(p, 'أقساط محجوزة من الحد', MoneyText(s.reserved, style: v(kOrange))),
              _stat(p, 'إجمالي المستحق', MoneyText(s.totalDue, style: v())),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _stat(p, 'المدفوع من الأقساط', MoneyText(s.planPaid, style: v(kGreen))),
              _stat(p, 'المتبقي', MoneyText(s.planLeft, style: v())),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _stat(p, 'القسط الشهري', MoneyText(s.monthly, style: v())),
              _stat(p, 'موعد الاستحقاق', Text(s.nextDue == null ? '—' : enDate(s.nextDue!), style: v())),
            ]),
            const SizedBox(height: 10),
            Text('المحجوز من الحد مش مصروف مدفوع؛ كل قسط بيتسجّل مصروف مرة واحدة من حسابك البنكي وبيفك نفس المبلغ من الحد.', style: TextStyle(fontSize: 12, color: p.ink2, height: 1.4)),
          ],
        ]),
      );
    });
  }
}
