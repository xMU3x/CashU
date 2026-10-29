import 'package:flutter_test/flutter_test.dart';
import 'package:cashu/core/extras.dart';
import 'package:cashu/core/models.dart';
import 'package:cashu/core/util.dart';
import 'package:cashu/pages/obligations_page.dart';

void main() {
  test('limitWords: حد أقصى 6 كلمات', () {
    expect(limitWords('أ ب ج د هـ و'), 'أ ب ج د هـ و');
    expect(limitWords('أ ب ج د هـ و ز ح'), 'أ ب ج د هـ و…');
    expect(limitWords('  كلمة  '), 'كلمة');
  });

  test('Inst: JSON يحفظ links و hidden', () {
    final i = Inst(id: 'i', name: 'x', total: 1200, count: 12, first: 0, links: {'5': 'tx1'}, hidden: true);
    final r = Inst.fromJson(i.toJson());
    expect(r.links['5'], 'tx1');
    expect(r.hidden, true);
  });

  test('SubPay: tx المربوطة تُحفظ', () {
    final s = Sub(id: 's', name: 'n', amt: 10, first: 0)..pays.add(SubPay(1, 10, 'a', 'tx9'));
    expect(Sub.fromJson(s.toJson()).pays.single.tx, 'tx9');
  });

  test('الالتزامات تشمل المصاريف المتكررة داخل الفترة', () {
    final t = Tx(id: 't', type: 'exp', amt: 100, acc: 'a', ts: DateTime(2026, 1, 5).millisecondsSinceEpoch, rep: 'monthly', pay: 'إيجار');
    final out = buildObligations(DateTime(2026, 3), DateTime(2026, 4), insts: [], subs: [], loans: [], assocs: [], recurring: [t]);
    expect(out.length, 1);
    expect(out.single.kind, 'rec');
    expect(out.single.amt, 100);
    expect(out.single.when, DateTime(2026, 3, 5));
  });
}
