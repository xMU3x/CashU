import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'extra_tabs.dart';
import 'categories_page.dart';
import 'sms_pages.dart';
import 'stats.dart';
import 'tools.dart';
import 'archived_accounts.dart';
import 'assoc_inst.dart';
import 'subs_page.dart';
import 'more_pages.dart';
import 'supervise.dart';

/// غلاف صفحة فرعية لمحتوى كان تبويبًا (من غير Scaffold) مع زر رجوع.
class SubPage extends StatelessWidget {
  final Widget child;
  const SubPage({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(children: [
        Padding(padding: EdgeInsets.only(top: 0), child: child),
      ]),
    );
  }
}

/// تبويب «المزيد»: مربعات الالتزامات فوق، وتحتها القائمة بالترتيب المطلوب.
class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  Widget _row(BuildContext context, Pal p, IconData ic, Color c, String title, String sub, Widget Function() page) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Tap(
          scale: .98,
          onTap: () => Navigator.of(context).push(flowRoute(page())),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: iosCard(p, r: 20),
            child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: c.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)), child: Icon(ic, color: c, size: 24)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600)),
                  Text(sub, style: TextStyle(fontSize: 12.5, color: p.ink2)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: p.ink2),
            ]),
          ),
        ),
      );

  Widget _square(BuildContext context, Pal p, IconData ic, Color c, String title, VoidCallback onTap) => Tap(
        scale: .96,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(color: c.withValues(alpha: .13), borderRadius: BorderRadius.circular(22)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(ic, color: c, size: 30),
            const SizedBox(height: 8),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(title, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final top = MediaQuery.of(context).padding.top;
    void push(Widget w) => Navigator.of(context).push(flowRoute(w));
    // الترتيب مطلوب بالظبط: اشتراكاتي، الجمعيات، أقساطي، السلف والديون، المصاريف المتكررة.
    final squares = <(IconData, Color, String, VoidCallback)>[
      (Icons.widgets_rounded, const Color(0xFFB07A4A), 'اشتراكاتي', () => push(const SubscriptionsPage())),
      (Icons.groups_rounded, const Color(0xFF2E7568), 'الجمعيات', () => push(const AssocPage())),
      (Icons.more_horiz_rounded, const Color(0xFF3B6FD4), 'أقساطي', () => push(const InstPage())),
      (Icons.people_alt_rounded, const Color(0xFFC96A4A), 'السلف والديون', () => push(const LoansPage())),
      (Icons.autorenew_rounded, const Color(0xFF6D3FD0), 'المصاريف المتكررة', () => push(const RecurringPage())),
    ];
    final w = (MediaQuery.of(context).size.width - 32 - 20) / 3;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, top + 20, 16, 130),
      children: [
        const Padding(padding: EdgeInsets.only(bottom: 16), child: Text('المزيد', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800))),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (var i = 0; i < squares.length; i++)
            Reveal(i: i, child: SizedBox(width: w, height: w, child: _square(context, p, squares[i].$1, squares[i].$2, squares[i].$3, squares[i].$4))),
        ]),
        const SizedBox(height: 20),
        // ترتيب القائمة: تتبع رسائل البنك، التصنيفات، التقارير، الميزانيات، AI، المتابعة والتحليل، (الرقابة)، البيانات والنسخ الاحتياطي، الحسابات المؤرشفة
        Reveal(i: 5, child: _row(context, p, Icons.sms_rounded, const Color(0xFF2E7568), 'تتبع رسائل البنك', 'قراءة الرسائل ومراجعتها محليًا', () => const SmsTrackingPage())),
        Reveal(i: 6, child: _row(context, p, Icons.category_rounded, const Color(0xFFE5383B), 'التصنيفات', 'تصنيفات المصروفات والدخل (تعديل وإضافة)', () => const CategoriesPage())),
        Reveal(i: 7, child: _row(context, p, Icons.pie_chart_rounded, kBlue, 'التقارير', 'إحصائيات المصروفات والدخل', () => const SubPage(child: StatsPage()))),
        Reveal(i: 8, child: _row(context, p, Icons.donut_large_rounded, const Color(0xFF6D3FD0), 'الميزانيات', 'حدود الصرف الشهرية', () => const SubPage(child: BudgetsTab()))),
        _toolRow(context, p, 'AI', 9),
        _toolRow(context, p, 'المتابعة والتحليل', 10),
        Reveal(i: 11, child: _row(context, p, Icons.verified_user_outlined, kBlue, 'الرقابة', 'مَن يرى مَن', () => const Scaffold(body: SafeArea(child: SupervisePage())))),
        _toolRow(context, p, 'البيانات والنسخ الاحتياطي', 12),
        Reveal(i: 13, child: _row(context, p, Icons.inventory_2_outlined, const Color(0xFF6E6E73), 'الحسابات المؤرشفة', 'استرجاع أي حساب بنفس بياناته', () => const ArchivedAccountsPage())),
      ],
    );
  }

  Widget _toolRow(BuildContext context, Pal p, String group, int i) {
    final g = kToolGroupRows.firstWhere((e) => e.$1 == group);
    return Reveal(i: i, child: _row(context, p, g.$3, g.$4, g.$1, g.$2, () => ToolsPage(group: g.$1)));
  }
}
