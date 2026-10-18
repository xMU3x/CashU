import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import '../ui/anim.dart';
import '../core/currency.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../core/sync.dart';
import '../core/i18n.dart';
import '../core/util.dart';
import '../ui/sheets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'profile.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Widget _head(Pal p, String t) => Padding(padding: const EdgeInsets.fromLTRB(6, 22, 6, 8), child: Text(t, style: TextStyle(color: p.ink2, fontSize: 14)));

  Widget _row(Pal p, IconData i, String t, {String? sub, Widget? trailing, VoidCallback? onTap, Color? c, bool soonTag = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Tap(
          onTap: onTap,
          scale: .98,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: cardDeco(p, r: 20),
            child: Row(children: [
              Icon(i, color: c ?? p.ink2),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c)), if (sub != null) Text(sub, style: TextStyle(color: p.ink2, fontSize: 13))])),
              if (soonTag) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(10)), child: Text('قريباً', style: TextStyle(color: p.ink2, fontSize: 12))),
              if (trailing != null) trailing,
            ]),
          ),
        ),
      );

  /// حجم الواجهة: 4 أيقونات Aa بأحجام متدرجة بدل النسبة المئوية.
  static const _sizeSteps = [.80, .88, .94, 1.0];
  Widget _sizeRow(Pal p) {
    final cur = S.num_('uiScale', .88).toDouble();
    var sel = _sizeSteps.indexWhere((x) => (x - cur).abs() < .02);
    if (sel < 0) sel = 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: cardDeco(p, r: 20),
        child: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFFFFC400), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.text_fields_rounded, color: Colors.white, size: 22)),
          const SizedBox(width: 14),
          const Expanded(child: Text('حجم الواجهة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(22)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < _sizeSteps.length; i++)
                Tap(
                  scale: .94,
                  onTap: () => S.put('uiScale', _sizeSteps[i]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    width: 42,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: i == sel ? p.ink.withValues(alpha: .16) : Colors.transparent, borderRadius: BorderRadius.circular(18)),
                    child: Text('Aa', textDirection: TextDirection.ltr, style: TextStyle(fontSize: 12.5 + i * 2.6, fontWeight: FontWeight.w600, color: i == sel ? p.ink : p.ink2)),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _sw(Pal p, IconData i, String t, String key, bool def, {String? sub, Color? on}) => _row(p, i, t, sub: sub, trailing: Switch(value: S.flag(key, def), activeTrackColor: on ?? p.acc, activeThumbColor: Colors.white, onChanged: (v) => S.put(key, v)), onTap: () => S.put(key, !S.flag(key, def)));

  Future<bool> _confirm(BuildContext c, String t, String m) async =>
      await showDialog<bool>(context: c, builder: (x) => AlertDialog(title: Text(t), content: Text(m), actions: [TextButton(onPressed: () => Navigator.pop(x, false), child: const Text('إلغاء')), TextButton(onPressed: () => Navigator.pop(x, true), child: const Text('تأكيد', style: TextStyle(color: Color(0xFFC0392B))))])) ?? false;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PageShell(
      title: 'الإعدادات',
      icon: Icons.settings_rounded,
      iconColor: const Color(0xFF5B8DEF),
      child: Live(b: (c) {
        final u = sync.user;
        final cur = curOf(S.cur);
        return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), physics: const BouncingScrollPhysics(), children: [
          Tap(
            onTap: () => showProfileSheet(context),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(24)),
              child: Row(children: [
                const CircleAvatar(radius: 26, backgroundColor: Color(0xFFB5295F), child: Icon(Icons.person_rounded, color: Colors.white)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(u == null ? 'غير مسجّل' : ((u.userMetadata?['full_name'] ?? u.email ?? '') as String), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), Text(u?.email ?? 'سجّل الدخول لمزامنة بياناتك', style: TextStyle(color: p.ink2, fontSize: 13))])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: kBlue.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)), child: const Text('ترقية', style: TextStyle(color: kBlue, fontSize: 13, fontWeight: FontWeight.w700))),
              ]),
            ),
          ),
          _head(p, 'عام'),
          _row(p, Icons.payments_rounded, 'العملة', trailing: Text('${cur.flag} ${cur.name}', style: const TextStyle(fontWeight: FontWeight.w600)), onTap: () async {
            final r = await showCurrencySheet(context, S.cur);
            if (r != null) S.put('cur', r);
          }),
          _row(p, Icons.language_rounded, 'اللغة', trailing: Text(isAr ? 'العربية' : 'English', style: const TextStyle(fontWeight: FontWeight.w600)), onTap: () => showLanguageSheet(context)),
          _row(p, Icons.report_rounded, 'التقارير اليومية', sub: 'موعد الإشعار وتقاريرك الأخيرة', soonTag: true),
          _sw(p, Icons.notifications_active_rounded, 'تنبيهات الميزانية', 'budgetAlerts', true, sub: 'تحذير على الرئيسية عند بلوغ ٨٠٪ من الميزانية', on: kBlue),
          _sw(p, Icons.vibration_rounded, 'اهتزاز اللمس', 'haptic', true),
          _row(p, Icons.mic_rounded, 'مراجعة المصاريف الصوتية', sub: 'مراجعة وتعديل المصاريف قبل الحفظ', soonTag: true),
          _head(p, 'الخصوصية'),
          _row(p, Icons.devices_rounded, 'الأجهزة المسجّل الدخول عليها', sub: 'أين حسابك مفتوح الآن', soonTag: true),
          _head(p, 'المظهر'),
          _sw(p, Icons.dark_mode_rounded, 'الوضع الداكن', 'dark', true, on: const Color(0xFF5B8DEF)),
          _sizeRow(p),
          _sw(p, Icons.volume_up_rounded, 'صوت الإضافة', 'sound', true, on: const Color(0xFF2E7568)),
          _sw(p, Icons.sort_rounded, 'التصنيف قبل الملاحظة', 'catFirst', true, sub: 'ترتيب خانتي التصنيف والملاحظة عند الإضافة', on: const Color(0xFF5B8DEF)),
          _head(p, 'حول'),
          _row(p, Icons.shield_rounded, 'سياسة الخصوصية', soonTag: true),
          _row(p, Icons.star_rounded, 'تقييم التطبيق', soonTag: true),
          _head(p, 'منطقة الخطر'),
          _row(p, Icons.delete_sweep_rounded, 'حذف البيانات', sub: 'مسح كل العمليات', c: const Color(0xFFC0392B), onTap: () async {
            if (await _confirm(context, 'حذف كل العمليات؟', 'سيتم مسح كل المعاملات والسلف (وعلى باقي أجهزتك عند المزامنة).')) {
              repo.wipeData();
              toast(context, 'تم المسح');
            }
          }),
          if (u != null)
            _row(p, Icons.person_off_rounded, 'حذف الحساب نهائياً', sub: 'حذف الحساب والبيانات من السيرفر', c: const Color(0xFFC0392B), onTap: () async {
              if (await _confirm(context, 'حذف الحساب نهائياً؟', 'لا يمكن التراجع عن هذه الخطوة.')) {
                final ok = await sync.deleteAccount();
                if (context.mounted) { toast(context, ok ? 'تم حذف الحساب' : 'تعذّر الحذف'); }
              }
            }),
          const SizedBox(height: 10),
          if (u != null)
            bigButton(p, 'تسجيل الخروج', const Color(0xFFC0392B), () async {
              await sync.logout();
              if (context.mounted) toast(context, 'تم تسجيل الخروج');
            }),
        ]);
      }),
    );
  }
}
