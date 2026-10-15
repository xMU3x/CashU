import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync.dart';
import '../../data/providers.dart';
import '../settings/settings_page.dart' show syncLabel;

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});
  @override
  ConsumerState<AccountPage> createState() => _State();
}

class _State extends ConsumerState<AccountPage> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool create = false, busy = false;
  String? msg;

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> _google() async {
    setState(() => busy = true);
    final e = await sync.google();
    if (mounted) setState(() {
      busy = false;
      msg = e;
    });
  }

  Future<void> _email() async {
    if (email.text.trim().isEmpty || pass.text.length < 6) {
      setState(() => msg = 'اكتب البريد وكلمة مرور 6 حروف على الأقل');
      return;
    }
    setState(() {
      busy = true;
      msg = null;
    });
    final r = await sync.email(email.text.trim(), pass.text, create);
    if (!mounted) return;
    setState(() {
      busy = false;
      msg = r.error ??
          (r.needsConfirm ? 'بعتنا لك رسالة تأكيد على بريدك. أكّدها وارجع.' : null);
    });
  }

  Future<void> _deleteCloud() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('مسح البيانات السحابية؟'),
        content: const Text(
            'هتتمسح نسختك على السيرفر. البيانات اللي على جهازك هتفضل.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('مسح')),
        ],
      ),
    );
    if (ok != true) return;
    final done = await sync.deleteCloud();
    if (mounted) {
      setState(() => msg = done ? 'تم مسح البيانات السحابية' : 'تعذّر المسح');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(syncProvider);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('الحساب والمزامنة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(syncLabel(s), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          if (!s.ready)
            const Text(
                'النسخة دي اتبنت من غير إعدادات Supabase، فالتطبيق شغال محليًا بس.')
          else if (s.user != null) ...[
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: Text(s.user!.email ?? ''),
            ),
            FilledButton.icon(
              onPressed: s.status == SyncStatus.syncing ? null : sync.run,
              icon: const Icon(Icons.sync),
              label: const Text('زامن الآن'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: sync.logout, child: const Text('تسجيل الخروج')),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _deleteCloud,
              child: Text('مسح بياناتي السحابية',
                  style: TextStyle(color: cs.error)),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: busy ? null : _google,
              icon: const Icon(Icons.login),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('الدخول بحساب جوجل'),
              ),
            ),
            const SizedBox(height: 20),
            const Center(child: Text('أو بالبريد وكلمة المرور')),
            const SizedBox(height: 12),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'كلمة المرور'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy ? null : _email,
              child: Text(create ? 'إنشاء حساب' : 'دخول'),
            ),
            TextButton(
              onPressed: () => setState(() => create = !create),
              child: Text(create ? 'عندي حساب بالفعل' : 'إنشاء حساب جديد'),
            ),
          ],
          if (msg != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(msg!, style: TextStyle(color: cs.error)),
            ),
        ],
      ),
    );
  }
}
