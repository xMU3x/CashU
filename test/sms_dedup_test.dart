import 'package:flutter_test/flutter_test.dart';
import 'package:cashu/sms/sms_dedup.dart';

/// اختبارات كشف التكرار بين الرسايل (SMS) وإشعارات التطبيقات (N:) — منطق نقي بلا تخزين.
/// القبول: إشعار إنستاباي + رسالة بنك لنفس التحويل = معاملة واحدة مهما كان ترتيب الوصول أو اختلاف المرجع أو تأخر الرسالة لحد ١٠ دقايق.
const _min = 60 * 1000;
final _t0 = DateTime(2026, 11, 21, 12, 0).millisecondsSinceEpoch;

DedupKey _k(String ch, int atMs, {int minor = 150000, String ref = '', String name = '', String l4 = '', bool income = false, String cur = 'EGP', String lang = 'a'}) =>
    DedupKey(minor: minor, ts: _t0 + atMs, cur: cur, income: income, ref: ref, last4: l4, name: name, lang: lang, ch: ch);

/// نموذج لترتيب العمليات في SmsTracker (نفس الترتيب: دفتر ← انتظار ← تسجيل) عشان نختبر سيناريوهات الوصول end-to-end بدون Flutter.
class _Model {
  final ledger = <Map<String, dynamic>>[];
  final hold = NotifHold();
  final recorded = <DedupKey>[];
  final reviewed = <DedupKey>[]; // «محتمل تكرار» ← مراجعة المستخدم (مش حذف صامت)
  int _n = 0;

  Map<String, dynamic> _row(DedupKey k) => {'minor': k.minor, 'ts': k.ts, 'cur': k.cur, 'in': k.income, 'ref': k.ref, 'l4': k.last4, 'name': k.name, 'lang': k.lang, 'ch': k.ch};

  void _record(DedupKey k) {
    final lv = ledgerDupLevel(k, ledger); // فحص التكرار بيتعاد وقت التسجيل (زي releaseHeld → _ingestCore)
    if (lv == DupLevel.sure) return;
    if (lv == DupLevel.maybe) {
      reviewed.add(k);
      return;
    }
    recorded.add(k);
    ledger.add(_row(k));
  }

  void sms(DedupKey k) {
    hold.takeDuplicatesOf(k); // أولوية للرسايل (متأكد بس بيتشال بصمت)
    final maybe = hold.takeMaybeDuplicatesOf(k); // محتمل ← مراجعة بعد ما الرسالة تتسجّل
    _record(k);
    reviewed.addAll(maybe.map((h) => h.key));
  }

  void notif(DedupKey k, int nowMs) {
    final lv = ledgerDupLevel(k, ledger);
    if (lv == DupLevel.sure) return; // معروفة بالفعل: مفيش انتظار
    if (lv == DupLevel.maybe) {
      reviewed.add(k); // محتمل تكرار: مفيش انتظار، بيروح للمراجعة علطول
      return;
    }
    hold.add(HeldNotif(id: 'h${_n++}', sender: 'N:app', body: 'b', recvMs: k.ts, dueAt: nowMs + kNotifHold.inMilliseconds, key: k));
  }

  void tick(int nowMs) {
    for (final h in hold.takeDue(nowMs)) {
      _record(h.key);
    }
  }
}

int _now(int atMs) => _t0 + atMs;

void main() {
  group('sameAmount (سماحية رسوم إنستاباي)', () {
    test('المطابقة بالمليم دايمًا', () {
      expect(sameAmount(150000, 150000, cur: 'EGP', income: false, crossChannel: false), isTrue);
      expect(sameAmount(150000, 150001, cur: 'EGP', income: false, crossChannel: false), isFalse);
    });
    test('قناتين مختلفتين + مصروف + جنيه: الفرق ≤ رسوم إنستاباي مقبول (١٠٠٠ ج ← رسوم ١ ج)', () {
      expect(sameAmount(100000, 100100, cur: 'EGP', income: false, crossChannel: true), isTrue);
      expect(sameAmount(100100, 100000, cur: 'EGP', income: false, crossChannel: true), isTrue);
      expect(sameAmount(100000, 100101, cur: 'EGP', income: false, crossChannel: true), isFalse);
    });
    test('الحد الأدنى للرسوم ٠٫٥ والأقصى ٢٠ جنيه', () {
      expect(sameAmount(10000, 10050, cur: 'EGP', income: false, crossChannel: true), isTrue); // ١٠٠ ج: رسوم ٠٫١ ← الأدنى ٠٫٥
      expect(sameAmount(10000, 10051, cur: 'EGP', income: false, crossChannel: true), isFalse);
      expect(sameAmount(5000000, 5002000, cur: 'EGP', income: false, crossChannel: true), isTrue); // ٥٠٬٠٠٠ ج: رسوم ٥٠ ← الأقصى ٢٠
      expect(sameAmount(5000000, 5002001, cur: 'EGP', income: false, crossChannel: true), isFalse);
    });
    test('مفيش سماحية: نفس القناة / دخل / عملة غير الجنيه', () {
      expect(sameAmount(100000, 100100, cur: 'EGP', income: false, crossChannel: false), isFalse);
      expect(sameAmount(100000, 100100, cur: 'EGP', income: true, crossChannel: true), isFalse);
      expect(sameAmount(100000, 100100, cur: 'USD', income: false, crossChannel: true), isFalse);
    });
  });

  group('crossMatch / crossMatchLevel', () {
    test('نفس القناة: مرجعين مختلفين = عمليتين', () {
      expect(crossMatch(ts: _t0, otherTs: _t0 + _min, name: 'Ahmed', otherName: 'Ahmed', crossChannel: false, ref: 'A1', otherRef: 'B2'), isFalse);
    });
    test('قناتين مختلفتين: المرجع المختلف ميلغيش المطابقة (الاسم المتشابه = متأكد)', () {
      expect(crossMatchLevel(ts: _t0, otherTs: _t0 + _min, name: 'Ahmed', otherName: 'Ahmed Ali', crossChannel: true, ref: 'A1', otherRef: 'B2'), DupLevel.sure);
    });
    test('قناتين مختلفتين بدون اسم: النافذة ١٠ دقايق بالظبط = مش متأكد (مراجعة)، وبعدها لأ', () {
      expect(crossMatchLevel(ts: _t0, otherTs: _t0 + 10 * _min, name: '', otherName: '', crossChannel: true), DupLevel.maybe);
      expect(crossMatchLevel(ts: _t0, otherTs: _t0 + 10 * _min + 1, name: '', otherName: '', crossChannel: true), DupLevel.none);
      expect(crossMatch(ts: _t0, otherTs: _t0 + _min, name: '', otherName: '', crossChannel: true), isFalse); // «مش متأكد» مش تكرار
    });
    test('قناتين مختلفتين: الاسم المختلف (إشعار باسم المستلم ↔ رسالة بنص تاني) = مش متأكد مش حذف', () {
      expect(crossMatchLevel(ts: _t0, otherTs: _t0 + 4 * _min, name: 'Mohamed', otherName: 'IPN TRANSFER', crossChannel: true), DupLevel.maybe);
    });
    test('نفس المرجع: متأكد في أي قناة خلال ١٠ دقايق', () {
      expect(crossMatchLevel(ts: _t0, otherTs: _t0 + 9 * _min, name: 'x', otherName: 'y', crossChannel: true, ref: 'R9', otherRef: 'R9'), DupLevel.sure);
      expect(crossMatch(ts: _t0, otherTs: _t0 + 9 * _min, name: 'x', otherName: 'y', crossChannel: false, ref: 'R9', otherRef: 'R9'), isTrue);
      expect(crossMatchLevel(ts: _t0, otherTs: _t0 + 11 * _min, name: 'x', otherName: 'y', crossChannel: true, ref: 'R9', otherRef: 'R9'), DupLevel.none);
    });
    test('نفس القناة: السلوك القديم (نفس الاسم ٣ دقايق، بدون اسم ٥ دقايق، اسمين مختلفين = لا)', () {
      expect(crossMatch(ts: _t0, otherTs: _t0 + 2 * _min, name: 'Carrefour', otherName: 'Carrefour', crossChannel: false), isTrue);
      expect(crossMatch(ts: _t0, otherTs: _t0 + 4 * _min, name: 'Carrefour', otherName: 'Carrefour', crossChannel: false), isFalse);
      expect(crossMatch(ts: _t0, otherTs: _t0 + 4 * _min, name: '', otherName: 'Carrefour', crossChannel: false), isTrue);
      expect(crossMatch(ts: _t0, otherTs: _t0 + 1 * _min, name: 'Carrefour', otherName: 'Spinneys', crossChannel: false), isFalse);
    });
  });

  group('dupLevel / isDuplicateOp / ledgerDup (مستويين: متأكد ↔ مش متأكد)', () {
    test('إشعار + رسالة باسمين متشابهين (ومرجعين مختلفين) = متأكد في الاتجاهين', () {
      final n = _k('n', 0, name: 'Ahmed', ref: 'IPN-77');
      final s = _k('s', 3 * _min, name: 'Ahmed Ali', ref: '9988123');
      expect(dupLevel(s, n), DupLevel.sure);
      expect(dupLevel(n, s), DupLevel.sure);
      expect(isDuplicateOp(s, n), isTrue);
    });
    test('إشعار + رسالة باسمين مختلفين ومرجعين مختلفين = مش متأكد (مراجعة، مش حذف صامت)', () {
      final n = _k('n', 0, name: 'Ahmed', ref: 'IPN-77');
      final s = _k('s', 3 * _min, name: 'ACME BANK TRF', ref: '9988123');
      expect(dupLevel(s, n), DupLevel.maybe);
      expect(dupLevel(n, s), DupLevel.maybe);
      expect(isDuplicateOp(s, n), isFalse);
    });
    test('مرجع متطابق = متأكد حتى لو الاسمين مختلفين', () {
      expect(dupLevel(_k('s', _min, name: 'x', ref: 'SAME-1'), _k('n', 0, name: 'y', ref: 'SAME-1')), DupLevel.sure);
    });
    test('نفس القناة + مرجعين مختلفين = عمليتين حتى لو نفس المبلغ والاسم', () {
      expect(dupLevel(_k('s', 60 * 1000, name: 'Ahmed', ref: 'B2'), _k('s', 0, name: 'Ahmed', ref: 'A1')), DupLevel.none);
    });
    test('نفس القناة بدون مرجع: نفس الاسم ≤ ٣ دقايق = متأكد، بعدها لأ', () {
      expect(isDuplicateOp(_k('s', 2 * _min, name: 'Carrefour'), _k('s', 0, name: 'Carrefour')), isTrue);
      expect(dupLevel(_k('s', 4 * _min, name: 'Carrefour'), _k('s', 0, name: 'Carrefour')), DupLevel.none);
    });
    test('نسخة بلغة تانية بدون اسم خلال ٩٠ ثانية (نفس القناة)', () {
      expect(isDuplicateOp(_k('s', 60 * 1000, lang: 'e'), _k('s', 0, lang: 'a')), isTrue);
      expect(dupLevel(_k('s', 100 * 1000, lang: 'e'), _k('s', 0, lang: 'a')), DupLevel.none);
    });
    test('قناتين مختلفتين بدون اسم/مرجع: نافذة ١٠ دقايق (مش ٣) = مش متأكد، وبعدها لأ', () {
      expect(dupLevel(_k('s', 9 * _min + 30 * 1000), _k('n', 0)), DupLevel.maybe);
      expect(dupLevel(_k('s', 10 * _min + 1), _k('n', 0)), DupLevel.none);
    });
    test('آخر ٤ أرقام: مختلفة = عمليتين، متطابقة = متأكد، ناقصة من طرف = مش متأكد', () {
      expect(dupLevel(_k('s', _min, l4: '7748'), _k('n', 0, l4: '1234')), DupLevel.none);
      expect(dupLevel(_k('s', _min, l4: '7748'), _k('n', 0, l4: '7748')), DupLevel.sure);
      expect(dupLevel(_k('s', _min, l4: '7748'), _k('n', 0)), DupLevel.maybe); // الإشعار غالبًا بدون رقم بطاقة
    });
    test('اختلاف المبلغ/العملة/الاتجاه = عمليتين', () {
      expect(dupLevel(_k('s', _min, minor: 160000), _k('n', 0)), DupLevel.none);
      expect(dupLevel(_k('s', _min, cur: 'USD'), _k('n', 0)), DupLevel.none);
      expect(dupLevel(_k('s', _min, income: true), _k('n', 0)), DupLevel.none);
    });
    test('سماحية الرسوم: تحويل صادر بالجنيه بين قناتين فقط (والمستوى حسب الاسم/المرجع)', () {
      expect(dupLevel(_k('s', _min, minor: 100100), _k('n', 0, minor: 100000)), DupLevel.maybe);
      expect(dupLevel(_k('s', _min, minor: 100100, name: 'Ahmed'), _k('n', 0, minor: 100000, name: 'Ahmed')), DupLevel.sure);
      expect(dupLevel(_k('s', _min, minor: 100100), _k('s', 0, minor: 100000)), DupLevel.none);
    });
    test('تحويلين بنفس المبلغ ورا بعض (إشعار لكل واحد) ← مش متأكد، مش بيتمسح واحد منهم بصمت', () {
      // رسالة واحدة وصلت للتحويل الأول: الإشعار التاني مش بنفس الاسم ومفيش مرجع ← مراجعة.
      expect(dupLevel(_k('s', 0, minor: 10000), _k('n', 2 * _min, minor: 10000)), DupLevel.maybe);
    });
    test('ledgerDup (متأكد) / ledgerDupLevel (أعلى مستوى) بيدوّروا في كل الإدخالات', () {
      final led = [
        {'minor': 5000, 'ts': _t0, 'cur': 'EGP', 'in': false, 'ref': '', 'l4': '', 'name': '', 'lang': 'a', 'ch': 's'},
        {'minor': 150000, 'ts': _t0, 'cur': 'EGP', 'in': false, 'ref': 'IPN-1', 'l4': '', 'name': 'Ahmed', 'lang': 'a', 'ch': 'n'},
      ];
      expect(ledgerDup(_k('s', 5 * _min, ref: 'BANK-9', name: 'Ahmed'), led), isTrue);
      expect(ledgerDup(_k('s', 5 * _min, ref: 'BANK-9', name: 'x'), led), isFalse);
      expect(ledgerDupLevel(_k('s', 5 * _min, ref: 'BANK-9', name: 'x'), led), DupLevel.maybe);
      expect(ledgerDupLevel(_k('s', 5 * _min, minor: 777), led), DupLevel.none);
    });
  });

  group('NotifHold (طابور الانتظار)', () {
    test('مدة الانتظار بين ٦٠ و٩٠ ثانية', () {
      expect(kNotifHold.inSeconds, inInclusiveRange(kNotifHoldMinSeconds, kNotifHoldMaxSeconds));
      expect(kNotifHoldMinSeconds, 60);
      expect(kNotifHoldMaxSeconds, 90);
    });
    test('رسالة لنفس العملية بتأكيد (اسم متشابه / مرجع) بتشيل الإشعار من الانتظار', () {
      final q = NotifHold();
      q.add(HeldNotif(id: '1', sender: 'N:instapay', body: 'b', recvMs: _t0, dueAt: _t0 + kNotifHold.inMilliseconds, key: _k('n', 0, ref: 'IPN-1', name: 'Ahmed')));
      expect(q.takeDuplicatesOf(_k('s', 20 * 1000, ref: 'BANK-5', name: 'Ahmed Ali')).length, 1);
      expect(q.isEmpty, isTrue);
    });
    test('رسالة بنفس المبلغ بدون اسم ولا مرجع مايتشالش الإشعار بصمت: takeDuplicatesOf فاضي و takeMaybeDuplicatesOf بيرجّعه', () {
      final q = NotifHold();
      q.add(HeldNotif(id: '1', sender: 'N:instapay', body: 'b', recvMs: _t0, dueAt: _t0 + kNotifHold.inMilliseconds, key: _k('n', 0, ref: 'IPN-1')));
      final sms = _k('s', 20 * 1000, ref: 'BANK-5');
      expect(q.takeDuplicatesOf(sms), isEmpty);
      expect(q.length, 1);
      final maybe = q.takeMaybeDuplicatesOf(sms);
      expect(maybe.length, 1);
      expect(q.isEmpty, isTrue);
    });
    test('رسالة لعملية تانية (مبلغ مختلف) مابتشيلش الإشعار ولا بتعلّمه «محتمل»', () {
      final q = NotifHold();
      q.add(HeldNotif(id: '1', sender: 'N:instapay', body: 'b', recvMs: _t0, dueAt: _t0 + kNotifHold.inMilliseconds, key: _k('n', 0)));
      expect(q.takeDuplicatesOf(_k('s', 20 * 1000, minor: 99900)), isEmpty);
      expect(q.takeMaybeDuplicatesOf(_k('s', 20 * 1000, minor: 99900)), isEmpty);
      expect(q.length, 1);
    });
    test('takeDue بيرجّع اللي خلصت مدته فقط وبترتيب الوصول', () {
      final q = NotifHold();
      q.add(HeldNotif(id: 'b', sender: 'N:a', body: '', recvMs: _t0 + 10, dueAt: _t0 + 75000, key: _k('n', 10, minor: 2)));
      q.add(HeldNotif(id: 'a', sender: 'N:a', body: '', recvMs: _t0, dueAt: _t0 + 74000, key: _k('n', 0, minor: 1)));
      q.add(HeldNotif(id: 'c', sender: 'N:a', body: '', recvMs: _t0 + 20, dueAt: _t0 + 999000, key: _k('n', 20, minor: 3)));
      expect(q.nextDue, _t0 + 74000);
      expect(q.takeDue(_t0 + 60000), isEmpty);
      final due = q.takeDue(_t0 + 80000);
      expect([for (final h in due) h.id].join(), 'ab');
      expect(q.length, 1);
    });
    test('takeDue(1<<62) = تفريغ الكل (اللي بيعمله releaseHeld(all: true) عند قفل تتبع الرسايل)', () {
      final q = NotifHold();
      q.add(HeldNotif(id: 'a', sender: 'N:a', body: '', recvMs: _t0, dueAt: _t0 + 999000, key: _k('n', 0, minor: 1)));
      q.add(HeldNotif(id: 'b', sender: 'N:a', body: '', recvMs: _t0 + 1, dueAt: _t0 + 888000, key: _k('n', 1, minor: 2)));
      expect(q.takeDue(1 << 62).length, 2);
      expect(q.isEmpty, isTrue);
    });
    test('التحويل لـ JSON والرجوع بيحفظ كل حاجة (عشان الإشعار ما يضيعش لو التطبيق اتقفل)', () {
      final q = NotifHold();
      q.add(HeldNotif(id: 'x', sender: 'N:instapay', body: 'تحويل ١٥٠٠ ج', recvMs: _t0, dueAt: _t0 + 75000, key: _k('n', 0, ref: 'IPN-1', name: 'Ahmed', l4: '1234')));
      final r = NotifHold.fromJson(q.toJson());
      expect(r.length, 1);
      final h = r.items.first;
      expect(h.sender, 'N:instapay');
      expect(h.body, 'تحويل ١٥٠٠ ج');
      expect(h.dueAt, _t0 + 75000);
      expect(h.key.minor, 150000);
      expect(h.key.ref, 'IPN-1');
      expect(h.key.ch, 'n');
      expect(h.key.last4, '1234');
    });
  });

  group('سيناريوهات الوصول (إشعار إنستاباي + رسالة بنك)', () {
    // اسمين متشابهين = متأكد ← معاملة واحدة بدون أي أثر. اسمين مختلفين بدون مرجع متطابق = معاملة + عنصر مراجعة.
    final n = _k('n', 0, name: 'Ahmed', ref: 'IPN-77');
    DedupKey sSure(int atMs) => _k('s', atMs, name: 'Ahmed Ali', ref: '9988123');
    DedupKey sUnsure(int atMs) => _k('s', atMs, name: 'ACME BANK TRF', ref: '9988123');

    test('متأكد: إشعار ثم رسالة خلال فترة الانتظار ← معاملة واحدة (من الرسالة) ولا مراجعة', () {
      final m = _Model();
      m.notif(n, _now(0));
      m.sms(sSure(30 * 1000));
      m.tick(_now(120 * 1000));
      expect(m.recorded.length, 1);
      expect(m.recorded.first.ch, 's');
      expect(m.reviewed, isEmpty);
    });
    test('مش متأكد: إشعار ثم رسالة خلال الانتظار ← معاملة الرسالة + الإشعار في المراجعة (مش اتمسح بصمت)', () {
      final m = _Model();
      m.notif(n, _now(0));
      m.sms(sUnsure(30 * 1000));
      m.tick(_now(120 * 1000));
      expect(m.recorded.length, 1);
      expect(m.recorded.first.ch, 's');
      expect(m.reviewed.length, 1);
      expect(m.reviewed.first.ch, 'n');
      expect(m.hold.isEmpty, isTrue);
    });
    test('متأكد: إشعار ثم رسالة بعد انتهاء الانتظار (٣ دقايق) ← معاملة واحدة', () {
      final m = _Model();
      m.notif(n, _now(0));
      m.tick(_now(80 * 1000));
      expect(m.recorded.length, 1);
      expect(m.recorded.first.ch, 'n');
      m.sms(sSure(3 * _min));
      expect(m.recorded.length, 1);
      expect(m.reviewed, isEmpty);
    });
    test('مش متأكد: إشعار اتسجّل ثم رسالة بعد ٣ دقايق ← الرسالة للمراجعة (مش حذف صامت)', () {
      final m = _Model();
      m.notif(n, _now(0));
      m.tick(_now(80 * 1000));
      m.sms(sUnsure(3 * _min));
      expect(m.recorded.length, 1);
      expect(m.reviewed.length, 1);
      expect(m.reviewed.first.ch, 's');
    });
    test('متأكد: إشعار ثم رسالة متأخرة لحد ١٠ دقايق ← معاملة واحدة', () {
      final m = _Model();
      m.notif(n, _now(0));
      m.tick(_now(80 * 1000));
      m.sms(sSure(9 * _min + 55 * 1000));
      expect(m.recorded.length, 1);
      expect(m.reviewed, isEmpty);
    });
    test('متأكد: رسالة ثم إشعار (مرجعين مختلفين) ← معاملة واحدة والإشعار مايتحجزش', () {
      final m = _Model();
      m.sms(sSure(0));
      m.notif(_k('n', 20 * 1000, name: 'Ahmed', ref: 'IPN-77'), _now(20 * 1000));
      expect(m.hold.isEmpty, isTrue);
      m.tick(_now(200 * 1000));
      expect(m.recorded.length, 1);
      expect(m.reviewed, isEmpty);
    });
    test('مش متأكد: رسالة ثم إشعار باسم مختلف ← الإشعار يروح للمراجعة علطول (مايتحجزش ومايتمسحش)', () {
      final m = _Model();
      m.sms(sUnsure(0));
      m.notif(_k('n', 20 * 1000, name: 'Ahmed', ref: 'IPN-77'), _now(20 * 1000));
      expect(m.hold.isEmpty, isTrue);
      expect(m.recorded.length, 1);
      expect(m.reviewed.length, 1);
    });
    test('متأكد: رسالة ثم إشعار بعد ٨ دقايق ← معاملة واحدة', () {
      final m = _Model();
      m.sms(sSure(0));
      m.notif(_k('n', 8 * _min, name: 'Ahmed', ref: 'IPN-77'), _now(8 * _min));
      m.tick(_now(10 * _min));
      expect(m.recorded.length, 1);
      expect(m.reviewed, isEmpty);
    });
    test('إشعار بدون رسالة خالص ← يتسجّل عادي بعد المدة', () {
      final m = _Model();
      m.notif(n, _now(0));
      m.tick(_now(74 * 1000));
      expect(m.recorded, isEmpty); // لسه منتظر
      m.tick(_now(76 * 1000));
      expect(m.recorded.length, 1);
      expect(m.reviewed, isEmpty);
    });
    test('سماحية الرسوم: إشعار ١٠٠٠ ج + رسالة ١٠٠١ ج باسم متشابه ← معاملة واحدة', () {
      final m = _Model();
      m.notif(_k('n', 0, minor: 100000, name: 'Ahmed'), _now(0));
      m.tick(_now(80 * 1000));
      m.sms(_k('s', 2 * _min, minor: 100100, name: 'Ahmed Ali'));
      expect(m.recorded.length, 1);
      expect(m.reviewed, isEmpty);
    });
    test('عمليتين حقيقيتين بنفس المبلغ بينهم أكتر من ١٠ دقايق ← معاملتين', () {
      final m = _Model();
      m.notif(n, _now(0));
      m.tick(_now(80 * 1000));
      m.sms(sSure(11 * _min));
      expect(m.recorded.length, 2);
      expect(m.reviewed, isEmpty);
    });
    test('رسالتين بنفس القناة بمرجعين مختلفين ← عمليتين', () {
      final m = _Model();
      m.sms(_k('s', 0, ref: 'A1', name: 'Ahmed'));
      m.sms(_k('s', 30 * 1000, ref: 'B2', name: 'Ahmed'));
      expect(m.recorded.length, 2);
      expect(m.reviewed, isEmpty);
    });
    test('إشعارين متتاليين لنفس العملية ثم رسالة بنفس الاسم ← معاملة واحدة', () {
      final m = _Model();
      m.notif(n, _now(0));
      m.notif(_k('n', 5 * 1000, name: 'Ahmed', ref: 'IPN-77'), _now(5 * 1000));
      m.sms(sSure(40 * 1000));
      m.tick(_now(200 * 1000));
      expect(m.recorded.length, 1);
      expect(m.reviewed, isEmpty);
    });
  });
}
