import 'package:flutter/material.dart' hide Text;
import '../ui/loc_text.dart';
import '../ui/anim.dart';
import '../core/repo.dart';
import '../core/sync.dart';
import '../core/util.dart';
import '../ui/sheets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'settings_page.dart';
import 'sms_pages.dart';

Future<void> showProfileSheet(BuildContext context) => showSheet<void>(context, (c) => const _ProfileSheet());

class _ProfileSheet extends StatelessWidget {
  const _ProfileSheet();
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return AnimatedBuilder(
      animation: sync,
      builder: (c, _) {
        final u = sync.user;
        final name = u == null ? 'ضيف' : ((u.userMetadata?['full_name'] ?? u.email ?? 'مستخدم') as String);
        Widget row(IconData i, String t, VoidCallback f, {Widget? tr}) => Tap(
              onTap: f,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Container(width: 54, height: 54, decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(18)), child: Icon(i, color: p.ink2)),
                  const SizedBox(width: 16),
                  Expanded(child: Text(t, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600))),
                  if (tr != null) tr,
                ]),
              ),
            );
        return SheetFrame(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(28), border: Border.all(color: p.line, width: 2)),
                child: Column(children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.line, width: 2)), child: CircleAvatar(radius: 28, backgroundColor: const Color(0xFFB5295F), child: Text(name.characters.first.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 26)))),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)), Text(u?.email ?? 'لم تسجّل الدخول', style: TextStyle(color: p.ink2))])),
                  ]),
                  const SizedBox(height: 14),
                  if (u != null)
                    Tap(onTap: () async {
                      await sync.logout();
                      if (context.mounted) Navigator.of(context).pop();
                    }, child: const Row(children: [Icon(Icons.logout_rounded, color: Color(0xFFC0392B)), SizedBox(width: 10), Text('تسجيل الخروج من هذا الحساب', style: TextStyle(color: Color(0xFFC0392B), fontSize: 17, fontWeight: FontWeight.w600))]))
                  else
                    Row(children: [
                      Expanded(child: bigButton(p, 'دخول بالبريد', p.acc, () => _emailLogin(context))),
                      const SizedBox(width: 10),
                      Expanded(child: bigButton(p, 'دخول بجوجل', const Color(0xFF3B6FD4), () async {
                        final e = await sync.google();
                        if (e != null && context.mounted) toast(context, e);
                      })),
                    ]),
                ]),
              ),
              const SizedBox(height: 12),
              Text(u == null ? 'سجّل الدخول لتتزامن بياناتك بين أجهزتك' : 'لا توجد حسابات أخرى بعد', style: TextStyle(color: p.ink2)),
              Divider(color: p.line, height: 28),
              row(Icons.sms_rounded, 'تتبع رسائل البنك', () {
                Navigator.of(context).pop();
                Navigator.of(context).push(flowRoute(const SmsTrackingPage()));
              }),
              row(Icons.settings_rounded, 'الإعدادات', () {
                Navigator.of(context).pop();
                Navigator.of(context).push(flowRoute(const SettingsPage()));
              }),
              row(Icons.person_add_alt_1_rounded, 'إضافة حساب جوجل آخر', () async {
                final e = await sync.google();
                if (e != null && context.mounted) toast(context, e);
              }),
            ]),
          ),
        );
      },
    );
  }

  void _emailLogin(BuildContext context) {
    final em = TextEditingController(), pw = TextEditingController();
    bool create = false, busy = false;
    showSheet<void>(context, (c) => StatefulBuilder(builder: (c, set) {
          final p = Pal.of(c);
          Widget f(TextEditingController t, String h, {bool obs = false}) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(20)), child: TextField(controller: t, obscureText: obs, textDirection: TextDirection.ltr, keyboardType: obs ? TextInputType.text : TextInputType.emailAddress, decoration: InputDecoration(border: InputBorder.none, hintText: h, hintStyle: TextStyle(color: p.ink2))));
          return SheetFrame(
            title: create ? 'إنشاء حساب' : 'تسجيل الدخول',
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                f(em, 'البريد الإلكتروني'),
                f(pw, 'كلمة المرور', obs: true),
                bigButton(p, busy ? '...' : (create ? 'إنشاء' : 'دخول'), p.acc, () async {
                  if (busy) return;
                  set(() => busy = true);
                  final r = await sync.email(em.text.trim(), pw.text, create);
                  set(() => busy = false);
                  if (!c.mounted) return;
                  if (r.error != null) {
                    toast(c, r.error!);
                  } else {
                    Navigator.of(c).pop();
                    if (r.needsConfirm) toast(context, 'تحقق من بريدك لتأكيد الحساب');
                  }
                }),
                Tap(onTap: () => set(() => create = !create), child: Padding(padding: const EdgeInsets.all(14), child: Text(create ? 'لدي حساب — تسجيل الدخول' : 'ليس لدي حساب — إنشاء حساب', style: TextStyle(color: p.ink2)))),
              ]),
            ),
          );
        }));
  }
}
