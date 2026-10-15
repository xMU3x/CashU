import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/store.dart';
import '../data/providers.dart';
import '../features/inbox/inbox_page.dart';

/// على الرئيسية: لو في معاملات مقترحة من الرسائل يظهر عددها، ولو التتبّع مش مفعّل يعرض تفعيله.
class InboxBanner extends ConsumerWidget {
  const InboxBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(storeProvider);
    final n = ref.watch(inboxProvider).length;
    final on = dev.get('smsOn') == true;
    if (n == 0 && on) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ListTile(
        tileColor: n > 0 ? cs.primaryContainer : cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(n > 0 ? Icons.mark_email_unread_outlined : Icons.sms_outlined),
        title: Text(n > 0
            ? '$n معاملة مقترحة من رسائلك'
            : 'سجّل مصاريفك تلقائيًا من رسائل البنك'),
        subtitle: Text(n > 0 ? 'راجعها وأكّدها بضغطة' : 'فعّل التتبّع والذكاء الاصطناعي'),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const InboxPage())),
      ),
    );
  }
}
