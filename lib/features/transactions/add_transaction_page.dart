import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai_service.dart';
import '../../core/categories.dart';
import '../../core/sms_parser.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

class AddTransactionPage extends ConsumerStatefulWidget {
  const AddTransactionPage({super.key});
  @override
  ConsumerState<AddTransactionPage> createState() => _State();
}

class _State extends ConsumerState<AddTransactionPage> {
  TxType type = TxType.expense;
  final amount = TextEditingController();
  final note = TextEditingController();
  final person = TextEditingController();
  String? accountId, toAccountId, categoryId;
  bool iOwe = false, saving = false;
  DateTime date = DateTime.now();
  DateTime? due;
  final aiCtl = TextEditingController();
  bool aiBusy = false;

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    person.dispose();
    aiCtl.dispose();
    super.dispose();
  }

  Color get _color => switch (type) {
        TxType.expense => kExpense,
        TxType.income => kIncome,
        TxType.transfer => kTransfer,
        TxType.loan => kLoan,
      };

  void _msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() => date = DateTime(d.year, d.month, d.day, date.hour, date.minute));
    }
  }

  Future<void> _pickDue() async {
    final d = await showDatePicker(
      context: context,
      initialDate: due ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => due = d);
  }

  /// اكتب بالعامية («صرفت 200 على بنزين امبارح») أو الصق رسالة بنك، وهتتعبّى الخانات.
  Future<void> _ai() async {
    final text = aiCtl.text.trim();
    if (text.isEmpty) return;
    setState(() => aiBusy = true);
    Parsed? p = parseSms('me', text); // محلي وسريع أولًا
    if ((p == null || p.confidence < 0.8) && AiService.available) {
      final r = await AiService.parse(text, smsMode: false);
      if (r.parsed != null) p = p == null ? r.parsed : r.parsed!.fill(p);
    }
    if (!mounted) return;
    setState(() => aiBusy = false);
    if (p == null || p.amount == null) {
      return _msg(AiService.available
          ? 'ما قدرتش أفهم المبلغ، جرّب صياغة تانية'
          : 'ما فهمتش النص. سجّل الدخول عشان الذكاء الاصطناعي يساعد.');
    }
    final pr = p;
    final accs = ref.read(accountsProvider);
    setState(() {
      type = pr.type == 'income' ? TxType.income : TxType.expense;
      amount.text = pr.amount!.toString().replaceAll(RegExp(r'\.0$'), '');
      categoryId = pr.categoryId;
      final label = pr.merchant ?? pr.note ?? '';
      if (label.isNotEmpty) note.text = label;
      if (pr.date != null) date = pr.date!;
      for (final a in accs) {
        if (pr.last4 != null && a.last4 == pr.last4) accountId = a.id;
      }
    });
  }

  Future<void> _save({required bool another}) async {
    final v = parseAmount(amount.text);
    if (v == null || v <= 0) return _msg('اكتب مبلغ صحيح');
    if (accountId == null) return _msg('اختر حساب');
    if (type == TxType.transfer &&
        (toAccountId == null || toAccountId == accountId)) {
      return _msg('اختر حسابين مختلفين للتحويل');
    }
    final repo = ref.read(repoProvider);
    tick();
    setState(() => saving = true);
    await repo.addTx(Tx(
      id: '',
      type: type,
      amount: v,
      accountId: accountId!,
      toAccountId: type == TxType.transfer ? toAccountId : null,
      categoryId: (type == TxType.expense || type == TxType.income)
          ? (categoryId ?? (type == TxType.income ? 'other_in' : 'other'))
          : null,
      note: note.text.trim().isEmpty ? null : note.text.trim(),
      person: type == TxType.loan ? person.text.trim() : null,
      iOwe: iOwe,
      date: date,
      dueDate: type == TxType.loan ? due : null,
    ));
    if (!mounted) return;
    if (another) {
      amount.clear();
      note.clear();
      setState(() => saving = false);
      _msg('تم الحفظ');
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accs = ref.watch(accountsProvider);
    if (accs.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!accs.any((a) => a.id == accountId)) accountId = accs.first.id;
    if (type == TxType.transfer &&
        (toAccountId == null || !accs.any((a) => a.id == toAccountId))) {
      toAccountId = accs.firstWhere((a) => a.id != accountId,
          orElse: () => accs.first).id;
    }
    final cats = categories.where((c) => c.income == (type == TxType.income));

    DropdownButtonFormField<String> accDrop(
            String label, String? value, ValueChanged<String?> onChanged) =>
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(labelText: label),
          items: [
            for (final a in accs)
              DropdownMenuItem(value: a.id, child: Text(a.name)),
          ],
          onChanged: onChanged,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('إضافة معاملة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: aiCtl,
            onSubmitted: (_) => _ai(),
            decoration: InputDecoration(
              hintText: 'اكتب بالعامية: صرفت 200 على بنزين امبارح',
              prefixIcon: const Icon(Icons.auto_awesome),
              suffixIcon: aiBusy
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(icon: const Icon(Icons.send), onPressed: _ai),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<TxType>(
            segments: const [
              ButtonSegment(value: TxType.expense, label: Text('مصروف')),
              ButtonSegment(value: TxType.income, label: Text('دخل')),
              ButtonSegment(value: TxType.transfer, label: Text('تحويل')),
              ButtonSegment(value: TxType.loan, label: Text('سلف')),
            ],
            selected: {type},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              type = s.first;
              categoryId = null;
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(color: _color, fontWeight: FontWeight.w800),
            decoration: const InputDecoration(hintText: '0', suffixText: 'ج.م'),
          ),
          const SizedBox(height: 12),
          accDrop(type == TxType.transfer ? 'من حساب' : 'الحساب', accountId,
              (v) => setState(() => accountId = v)),
          if (type == TxType.transfer) ...[
            const SizedBox(height: 12),
            accDrop('إلى حساب', toAccountId, (v) => setState(() => toAccountId = v)),
            if (accs.length < 2)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('أضف حساب تاني من صفحة «حساباتي» الأول.'),
              ),
          ],
          if (type == TxType.expense || type == TxType.income) ...[
            const SizedBox(height: 16),
            const Text('التصنيف'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in cats)
                ChoiceChip(
                  label: Text('${c.emoji} ${c.label}'),
                  selected: categoryId == c.id,
                  onSelected: (_) => setState(() => categoryId = c.id),
                ),
            ]),
          ],
          if (type == TxType.loan) ...[
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('ليّا فلوس ↓')),
                ButtonSegment(value: true, label: Text('عليّا فلوس ↑')),
              ],
              selected: {iOwe},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => iOwe = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: person,
              decoration: const InputDecoration(
                  labelText: 'اسم الشخص', prefixIcon: Icon(Icons.person)),
            ),
            const SizedBox(height: 12),
            ListTile(
              onTap: _pickDue,
              leading: const Icon(Icons.event),
              title: const Text('تاريخ الاستحقاق'),
              subtitle: Text(due == null ? 'بدون موعد' : dayLabel(due!)),
            ),
            const Text(
              'السلفة بتتسجل في السجل، والمبلغ المستلَف مش بيتحسب دخل.',
              style: TextStyle(fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: note,
            decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
          ),
          const SizedBox(height: 12),
          ListTile(
            onTap: _pickDate,
            leading: const Icon(Icons.calendar_today),
            title: const Text('التاريخ'),
            subtitle: Text(dayLabel(date)),
          ),
          const SizedBox(height: 16),
          Row(children: [
            OutlinedButton(
              onPressed: saving ? null : () => _save(another: true),
              child: const Icon(Icons.add),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _color),
                onPressed: saving ? null : () => _save(another: false),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('حفظ'),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
