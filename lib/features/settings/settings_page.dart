import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/store.dart';
import '../../core/sync.dart';
import '../../data/providers.dart';
import '../account/account_page.dart';
import '../inbox/inbox_page.dart';

String syncLabel(SyncService s) {
  if (!s.ready) return 'المزامنة مش مفعّلة في النسخة دي';
  if (s.user == null) return 'غير مسجّل — بياناتك على الجهاز بس';
  return switch (s.status) {
    SyncStatus.syncing => 'جارٍ المزامنة…',
    SyncStatus.ok => 'متزامن ✓',
    SyncStatus.offline => 'أوفلاين — هتتزامن لما النت يرجع',
    SyncStatus.error => 'تعذّرت المزامنة',
    SyncStatus.off => 'جاهز للمزامنة',
  };
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(storeProvider);
    final s = ref.watch(syncProvider);
    final mode = cfg.get('mode') as String;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(s.user?.email ?? 'حسابك'),
            subtitle: Text(syncLabel(s)),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountPage()),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.sms_outlined)),
            title: const Text('رسائل البنك والذكاء الاصطناعي'),
            subtitle: Text(dev.get('smsOn') == true ? 'التتبّع شغّال' : 'مقفول'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const InboxPage()),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('المظهر'),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'auto', label: Text('تلقائي')),
            ButtonSegment(value: 'light', label: Text('فاتح')),
            ButtonSegment(value: 'dark', label: Text('داكن')),
          ],
          selected: {mode},
          showSelectedIcon: false,
          onSelectionChanged: (v) => cfg.set('mode', v.first),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('الاهتزاز'),
          value: cfg.get('vibrate') == true,
          onChanged: (v) => cfg.set('vibrate', v),
        ),
      ],
    );
  }
}
