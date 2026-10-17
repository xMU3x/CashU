import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'extra_tabs.dart';
import 'profile.dart';
import 'settings_page.dart';
import 'sms_pages.dart';
import 'stats.dart';
import 'tools.dart';

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
        child,
        Positioned(top: top + 8, left: 12, child: GlassBtn(Icons.chevron_left_rounded, () => Navigator.of(context).maybePop(), size: 44)),
      ]),
    );
  }
}

/// تبويب «المزيد»: بوابة لباقي الأقسام (كل ما كان في الشريط القديم + الأدوات والإعدادات).
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
              Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: p.ink2),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final top = MediaQuery.of(context).padding.top;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, top + 20, 16, 130),
      children: [
        const Padding(padding: EdgeInsets.only(bottom: 16), child: Text('More', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800))),
        Reveal(i: 1, child: _row(context, p, Icons.pie_chart_rounded, kBlue, 'Reports', 'إحصائيات المصروفات والدخل', () => const SubPage(child: StatsPage()))),
        Reveal(i: 2, child: _row(context, p, Icons.autorenew_rounded, const Color(0xFF6D3FD0), 'Subscriptions', 'المعاملات المتكررة', () => const SubPage(child: ScheduledTab()))),
        Reveal(i: 3, child: _row(context, p, Icons.sms_rounded, const Color(0xFF2E7568), 'تتبع رسائل البنك', 'قراءة الرسائل ومراجعتها محليًا', () => const SmsTrackingPage())),
        Reveal(i: 4, child: _row(context, p, Icons.apps_rounded, kOrange, 'الأدوات', 'أهداف، سلف، أسعار صرف وغيرها', () => const ToolsPage())),
        Reveal(i: 5, child: _row(context, p, Icons.settings_rounded, const Color(0xFF6E6E73), 'Settings', 'المظهر واللغة والعملة والمزامنة', () => const SettingsPage())),
        Reveal(i: 6, child: Tap(onTap: () => showProfileSheet(context), child: Padding(padding: const EdgeInsets.only(top: 6), child: Center(child: Text('الحساب والمستخدم', style: TextStyle(color: kBlue, fontSize: 15)))))),
      ],
    );
  }
}
