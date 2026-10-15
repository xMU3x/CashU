import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai_service.dart';
import '../../core/categories.dart';
import '../../core/sms_channel.dart';
import '../../core/sms_service.dart';
import '../../core/store.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/suggestion.dart';

class InboxPage extends ConsumerStatefulWidget {
  const InboxPage({super.key});
  @override
  ConsumerState<InboxPage> createState() => _State();
}

class _State extends ConsumerState<InboxPage> {
  bool busy = false;

  void _msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _toggleSms(bool on) async {
    if (!on) {
      dev.set('smsOn', false);
      return;
    }
    final ok = await SmsChannel.requestPermission();
    if (ok) {
      dev.set('smsOn', true);
      _msg('تم التفعيل. أي رسالة مالية جديدة هتظهر هنا.');
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('الصلاحية مش متاحة'),
        content: const Text(
          'لو التطبيق منزّل من خارج المتجر (APK)، أندرويد 13+ بيقفل صلاحية الرسائل.\n\n'
          '1) افتح إعدادات التطبيق\n'
          '2) اضغط ⋮ (فوق على اليمين)\n'
          '3) اختار «السماح بالإعدادات المقيّدة»\n'
          '4) ارجع وفعّل التتبّع تاني',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('إغلاق')),
          FilledButton(
            onPressed: () {
              Navigator.pop(c);
              SmsChannel.openSettings();
            },
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }

  Future<void> _import() async {
    setState(() => busy = true);
    final n = await smsService.importHistory(30);
    if (!mounted) return;
    setState(() => busy = false);
    _msg(n == 0 ? 'مفيش معاملات جديدة في آخر 30 يوم' : 'اتضاف $n مقترح للمراجعة');
  }

  Future<void> _edit(Suggestion s) async {
    final accs = ref.read(accountsProvider);
    if (accs.isEmpty) return;
    var type = s.p.type ?? 'expense';
    var cat = s.p.categoryId ?? (type == 'income' ? 'other_in' : 'other');
    var acc = accs.any((a) => a.id == s.accountId) ? s.accountId! : accs.first.id;
    final amount = TextEditingController(
        text: (s.amountEgp ?? '').toString().replaceAll(RegExp(r'\.0$'), ''));
    final note = TextEditingController(text: s.p.merchant ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(c).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (s.foreign)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                        'العملة الأصلية: ${s.p.amount} ${s.p.currency} — اكتب المبلغ بالجنيه.',
                        style: TextStyle(color: kLoan)),
                  ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'expense', label: Text('مصروف')),
                    ButtonSegment(value: 'income', label: Text('دخل')),
                  ],
                  selected: {type},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => setS(() {
                    type = v.first;
                    cat = type == 'income' ? 'other_in' : 'other';
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'المبلغ', suffixText: 'ج.م'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: acc,
                  decoration: const InputDecoration(labelText: 'الحساب'),
                  items: [
                    for (final a in accs)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => setS(() => acc = v ?? acc),
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final k
                      in categories.where((x) => x.income == (type == 'income')))
                    ChoiceChip(
                      label: Text('${k.emoji} ${k.label}'),
                      selected: cat == k.id,
                      onSelected: (_) => setS(() => cat = k.id),
                    ),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'ملاحظة'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final v = parseAmount(amount.text);
                    if (v == null || v <= 0) return;
                    Navigator.pop(c);
                    await smsService.accept(s,
                        amount: v,
                        type: type,
                        categoryId: cat,
                        accountId: acc,
                        note: note.text.trim());
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('تأكيد وإضافة'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(storeProvider);
    final list = ref.watch(inboxProvider);
    final accs = ref.watch(accountsProvider);
    final sy = ref.watch(syncProvider);
    final aiOk = AiService.available && sy.user != null;
    final ready = list.where((s) => s.ready && s.p.confidence >= 0.7).length;

    return Scaffold(
      appBar: AppBar(title: const Text('رسائل البنك والذكاء الاصطناعي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('تتبّع رسائل البنك'),
            subtitle: const Text(
                'بنقرأ الرسائل المالية بس (مش رموز التحقق ولا رسائل الأشخاص) وبتتحلّل على جهازك.'),
            value: dev.get('smsOn') == true,
            onChanged: _toggleSms,
          ),
          SwitchListTile(
            title: const Text('ذكاء اصطناعي للرسائل الغامضة'),
            subtitle: Text(aiOk
                ? 'بنبعت نص الرسالة بعد إخفاء الأرقام الطويلة للسيرفر عشان Claude يفهمها.'
                : 'محتاج تسجيل دخول (من الإعدادات ← الحساب).'),
            value: dev.get('smsAi') == true && aiOk,
            onChanged: aiOk ? (v) => dev.set('smsAi', v) : null,
          ),
          SwitchListTile(
            title: const Text('إضافة تلقائية للرسائل الواضحة'),
            subtitle: const Text(
                'لو الرسالة واضحة والحساب معروف (من آخر 4 أرقام البطاقة) بتتسجّل من غير تأكيد.'),
            value: dev.get('smsAuto') == true,
            onChanged: (v) => dev.set('smsAuto', v),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: OutlinedButton.icon(
              onPressed: busy || dev.get('smsOn') != true ? null : _import,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.history),
              label: const Text('استيراد رسائل آخر 30 يوم'),
            ),
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Text('معاملات مقترحة (${list.length})',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              if (ready > 0)
                FilledButton.tonal(
                  onPressed: () async {
                    final n = await smsService.acceptReady();
                    if (mounted) _msg('اتأكدت $n معاملة');
                  },
                  child: Text('تأكيد الواضح ($ready)'),
                ),
            ],
          ),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('مفيش مقترحات حاليًا')),
            ),
          for (final s in list) _Card(s: s, accs: accs, onEdit: () => _edit(s)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.s, required this.accs, required this.onEdit});
  final Suggestion s;
  final List<Account> accs;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final income = s.p.type == 'income';
    final c = catById(s.p.categoryId);
    final color = s.p.type == null ? kLoan : (income ? kIncome : kExpense);
    final amt = s.p.amount == null
        ? '—'
        : '${income ? '+' : s.p.type == null ? '' : '-'}${money(s.p.amount!)}'
            '${s.foreign ? ' (${s.p.currency})' : ''}';
    final accName = accs
        .where((a) => a.id == s.accountId)
        .map((a) => a.name)
        .firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(child: Text(c?.emoji ?? '❓')),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.p.merchant ?? s.sender,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      [
                        dayLabel(DateTime.fromMillisecondsSinceEpoch(s.ts)),
                        accName ?? 'اختار الحساب',
                        if (s.p.source == 'ai') '✨ AI',
                      ].join(' · '),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(amt,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 8),
            Text(s.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => smsService.dismiss(s.id),
                  child: const Text('تجاهل'),
                ),
                TextButton(onPressed: onEdit, child: const Text('تعديل')),
                FilledButton(
                  onPressed: s.ready ? () => smsService.accept(s) : onEdit,
                  child: Text(s.ready ? 'تأكيد' : 'راجع'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
