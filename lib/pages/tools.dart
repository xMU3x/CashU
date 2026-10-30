import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import '../ui/anim.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'more_pages.dart';

class _Tool {
  final String name;
  final IconData icon;
  final Color color;
  final Widget Function()? page;
  const _Tool(this.name, this.icon, this.color, [this.page]);
}

/// مجموعات الأدوات اللي بتظهر كصفوف مستقلة في تبويب «المزيد» (عنوان، وصف، أيقونة، لون).
const kToolGroupRows = <(String, String, IconData, Color)>[
  ('المتابعة والتحليل', 'أهداف، مدخرات، تحدي الإنفاق، أسعار الصرف', Icons.insights_rounded, Color(0xFF2E7568)),
  ('AI', 'Flow AI · Flow Live · اكتب اللي صرفته', Icons.auto_awesome_rounded, Color(0xFF6D3FD0)),
  ('البيانات والنسخ الاحتياطي', 'نسخ احتياطي Drive واستيراد', Icons.cloud_sync_rounded, Color(0xFFB07A4A)),
];

class ToolsPage extends StatefulWidget {
  /// لو اتحدد: الصفحة تعرض المجموعة دي بس (من تبويب المزيد).
  final String? group;
  const ToolsPage({super.key, this.group});
  @override
  State<ToolsPage> createState() => _ToolsState();
}

class _ToolsState extends State<ToolsPage> {
  String q = '';

  static final _t = <String, _Tool>{
    'goals': _Tool('أهدافي', Icons.track_changes_rounded, const Color(0xFF2E7568), () => const GoalsPage()),
    'loans': _Tool('مستحقاتي', Icons.people_alt_rounded, const Color(0xFFC96A4A), () => const LoansPage()),
    'rates': _Tool('أسعار الصرف', Icons.currency_exchange_rounded, const Color(0xFF3B8FA8), () => const RatesPage()),
    'flow': _Tool('Flow AI', Icons.auto_awesome_rounded, const Color(0xFF6D3FD0), () => const FlowAIPage()),
    'rec': _Tool('المصاريف المتكررة', Icons.autorenew_rounded, const Color(0xFF6D3FD0), () => const RecurringPage()),
    'safe': _Tool('مدخراتي', Icons.savings_rounded, const Color(0xFF6E6E73)),
    'chal': _Tool('تحدي الإنفاق', Icons.local_fire_department_rounded, const Color(0xFFC0392B)),
    'simple': _Tool('بكل بساطة', Icons.apps_rounded, const Color(0xFF6F9A4A)),
    'live': _Tool('Flow Live', Icons.graphic_eq_rounded, const Color(0xFF6D3FD0)),
    'write': _Tool('اكتب اللي صرفته', Icons.edit_note_rounded, const Color(0xFFC2306A)),
    'drive': _Tool('نسخ احتياطي Drive', Icons.cloud_upload_rounded, const Color(0xFF3B6FD4)),
    'import': _Tool('استيراد من تطبيق آخر', Icons.download_rounded, const Color(0xFFC96A4A)),
  };

  static const groups = [
    ('الأكثر استخداماً', ['goals', 'loans', 'rates', 'flow', 'rec']),
    ('المتابعة والتحليل', ['goals', 'safe', 'chal', 'rates', 'simple']),
    ('AI', ['flow', 'live', 'write']),
    ('البيانات والنسخ الاحتياطي', ['drive', 'import']),
  ];

  void _open(String k) {
    final t = _t[k]!;
    if (k == 'write') {
      showWriteSpent(context);
    } else if (t.page != null) {
      Navigator.of(context).push(flowRoute(t.page!()));
    } else {
      soon(context, t.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    var idx = 0;
    return PageShell(
      title: widget.group ?? 'الأدوات',
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), physics: const BouncingScrollPhysics(), children: [
        if (widget.group == null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(22)),
          child: TextField(onChanged: (v) => setState(() => q = v.trim()), decoration: InputDecoration(border: InputBorder.none, hintText: 'ابحث عن أداة...', hintStyle: TextStyle(color: p.ink2), icon: Icon(Icons.search_rounded, color: p.ink2))),
        ),
        for (final g in groups.where((g) => widget.group == null || g.$1 == widget.group)) ...[
          Builder(builder: (c) {
            final keys = g.$2.where((k) => q.isEmpty || _t[k]!.name.toLowerCase().contains(q.toLowerCase())).toList();
            if (keys.isEmpty) return const SizedBox();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 22, bottom: 14), child: Row(children: [Text(g.$1, style: TextStyle(color: p.ink2, fontSize: 15)), const SizedBox(width: 10), Expanded(child: Divider(color: p.line))])),
              Wrap(runSpacing: 16, children: [
                for (final k in keys)
                  Reveal(
                    i: idx++ ~/ 4,
                    child: SizedBox(
                      width: (MediaQuery.of(context).size.width - 32) / 4,
                      child: Tap(
                        onTap: () => _open(k),
                        child: Column(children: [
                          Container(width: 64, height: 64, decoration: BoxDecoration(color: _t[k]!.color.withValues(alpha: .13), borderRadius: BorderRadius.circular(22)), child: Icon(_t[k]!.icon, color: _t[k]!.color, size: 28)),
                          const SizedBox(height: 8),
                          Text(_t[k]!.name, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ]);
          }),
        ],
      ]),
    );
  }
}
