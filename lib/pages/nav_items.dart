import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import '../ui/anim.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../core/settings.dart';
import 'assoc_inst.dart';
import 'categories_page.dart';
import 'extra_tabs.dart';
import 'more_pages.dart';
import 'more_tab.dart' show SubPage;
import 'sms_pages.dart';
import 'stats.dart';

/// عنصر قابل للإضافة في الشريط السفلي.
/// [tab] = 0..3 لو يفتح تبويبًا داخل الـ Shell (الحسابات/المعاملات/الاشتراكات/المزيد)، وإلا يفتح صفحة فوق التبويب الحالي.
class NavItem {
  final String id, label;
  final IconData icon;
  final int? tab;
  final Widget Function()? page;
  const NavItem(this.id, this.label, this.icon, {this.tab, this.page});
}

final List<NavItem> kNavItems = [
  const NavItem('accounts', 'الحسابات', Icons.account_balance_wallet_rounded, tab: 0),
  const NavItem('tx', 'المعاملات', Icons.format_list_bulleted_rounded, tab: 1),
  const NavItem('subs', 'الاشتراكات', Icons.widgets_rounded, tab: 2),
  const NavItem('more', 'المزيد', Icons.grid_view_rounded, tab: 3),
  NavItem('assoc', 'الجمعيات', Icons.groups_rounded, page: () => const AssocPage()),
  NavItem('inst', 'الأقساط', Icons.payments_rounded, page: () => const InstPage()),
  NavItem('loans', 'السلف والديون', Icons.people_alt_rounded, page: () => const LoansPage()),
  NavItem('recurring', 'المتكررة', Icons.autorenew_rounded, page: () => const RecurringPage()),
  NavItem('budgets', 'الميزانيات', Icons.donut_large_rounded, page: () => const SubPage(child: BudgetsTab())),
  NavItem('stats', 'التقارير', Icons.pie_chart_rounded, page: () => const SubPage(child: StatsPage())),
  NavItem('categories', 'التصنيفات', Icons.category_rounded, page: () => const CategoriesPage()),
  NavItem('sms', 'تتبع الرسائل', Icons.sms_rounded, page: () => const SmsTrackingPage()),
];

const int kNavMax = 6, kNavMin = 2;
const List<String> kNavDefault = ['accounts', 'tx', 'subs', 'more'];

NavItem? navById(String id) {
  for (final n in kNavItems) {
    if (n.id == id) return n;
  }
  return null;
}

/// العناصر المختارة بالترتيب (مع تجاهل أي معرّف قديم/محذوف، والتأكد من وجود «المزيد»/«الحسابات» الافتراضي لو القائمة فاضية).
List<NavItem> currentNavItems() {
  final saved = S.list('navItems');
  final ids = saved.isEmpty ? kNavDefault : saved;
  final out = <NavItem>[];
  for (final id in ids) {
    final n = navById(id);
    if (n != null && !out.contains(n)) out.add(n);
  }
  if (out.length < kNavMin) return [for (final id in kNavDefault) navById(id)!];
  return out.take(kNavMax).toList();
}

/// صفحة «تخصيص الشريط السفلي»: ترتيب بالسحب، حذف، إضافة حتى ٦.
class NavCustomizePage extends StatefulWidget {
  const NavCustomizePage({super.key});
  @override
  State<NavCustomizePage> createState() => _NavCustomizeState();
}

class _NavCustomizeState extends State<NavCustomizePage> {
  late List<String> ids = currentNavItems().map((e) => e.id).toList();

  void _save() => S.put('navItems', ids);

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final avail = kNavItems.where((n) => !ids.contains(n.id)).toList();
    return PageShell(
      title: 'تخصيص الشريط السفلي',
      icon: Icons.dock_rounded,
      iconColor: kBlue,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), physics: const BouncingScrollPhysics(), children: [
        Padding(padding: const EdgeInsets.fromLTRB(6, 6, 6, 10), child: Text('اختر من $kNavMin إلى $kNavMax أدوات تظهر في الشريط السفلي. اسحب لإعادة الترتيب.', style: TextStyle(color: p.ink2, height: 1.5))),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorder: (o, n) {
            if (n > o) n--;
            setState(() => ids.insert(n, ids.removeAt(o)));
            _save();
          },
          children: [
            for (var i = 0; i < ids.length; i++)
              Container(
                key: ValueKey('n_${ids[i]}'),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: cardDeco(p, r: 18),
                child: Row(children: [
                  Icon(navById(ids[i])!.icon, color: kBlue),
                  const SizedBox(width: 14),
                  Expanded(child: Text(navById(ids[i])!.label, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600))),
                  if (ids.length > kNavMin)
                    Tap(
                      onTap: () {
                        setState(() => ids.removeAt(i));
                        _save();
                      },
                      child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.remove_circle_rounded, color: kRed, size: 22)),
                    ),
                  ReorderableDragStartListener(index: i, child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.drag_handle_rounded, color: p.ink2))),
                ]),
              ),
          ],
        ),
        sectionLabel(p, ids.length >= kNavMax ? 'وصلت للحد الأقصى ($kNavMax)' : 'أدوات متاحة للإضافة'),
        for (final n in avail)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Tap(
              scale: .98,
              onTap: ids.length >= kNavMax
                  ? () => toast(context, 'الحد الأقصى ٦ أيقونات')
                  : () {
                      setState(() => ids.add(n.id));
                      _save();
                    },
              child: Opacity(
                opacity: ids.length >= kNavMax ? .45 : 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: cardDeco(p, r: 18),
                  child: Row(children: [
                    Icon(n.icon, color: p.ink2),
                    const SizedBox(width: 14),
                    Expanded(child: Text(n.label, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600))),
                    const Icon(Icons.add_circle_rounded, color: kGreen, size: 22),
                  ]),
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        Tap(
          onTap: () {
            setState(() => ids = List.of(kNavDefault));
            _save();
          },
          child: Center(child: Padding(padding: const EdgeInsets.all(12), child: Text('استعادة الافتراضي', style: TextStyle(color: p.ink2)))),
        ),
      ]),
    );
  }
}
