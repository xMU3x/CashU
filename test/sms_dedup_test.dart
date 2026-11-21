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
  int _n = 0;

  Map<String, dynamic> _row(DedupKey k) => {'minor': k.minor, 'ts': k.ts, 'cur': k.cur, 'in': k.income, 'ref': k.ref, 'l4': k.last4, 'name': k.name, 'lang': k.lang, 'ch': k.ch};

  void _record(DedupKey k) {
    if (ledgerDup(k, ledger)) return; // فحص التكرار بيتعاد وقت التسجيل (زي releaseHeld → _ingestCore)
    recorded.add(k);
    ledger.add(_row(k));
  }

  void sms(DedupKey k) {
    hold.takeDuplicatesOf(k); // أولوية للرسايل
    _record(k);
  }

  void notif(DedupKey k, int nowMs) {
    if (ledgerDup(k, ledger)) return; // معروفة بالفعل: مفيش انتظار
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

  group('crossMatch', () {
    test('نفس القناة: مرجعين مختلفين = عمليتين', () {
      expect(crossMatch(ts: _t0, otherTs: _t0 + _min, name: 'Ahmed', otherName: 'Ahmed', crossChannel: false, ref: 'A1', otherRef: 'B2'), isFalse);
    });
    test('قناتين مختلفتين: المرجع المختلف ميلغيش المطابقة', () {
      expect(crossMatch(ts: _t0, otherTs: _t0 + _min, name: 'Ahmed', otherName: 'Ahmed Ali', crossChannel: true, ref: 'A1', otherRef: 'B2'), isTrue);
    });
    test('قناتين مختلفتين: النافذة ١٠ دقايق بالظبط', () {
      expect(crossMatch(ts: _t0, otherTs: _t0 + 10 * _min, name: '', otherName: '', crossChannel: true), isTrue);
      expect(crossMatch(ts: _t0, otherTs: _t0 + 10 * _min + 1, name: '', otherName: '', crossChannel: true), isFalse);
    });
    test('قناتين مختلفتين: الاسم المختلف مش مانع (إشعار باسم المستلم ↔ رسالة بنص تاني)', () {
      expect(crossMatch(ts: _t0, otherTs: _t0 + 4 * _min, name: 'Mohamed', otherName: 'IPN TRANSFER', crossChannel: true), isTrue);
    });
    test('نفس القناة: السلوك القديم (نفس الاسم ٣ دقايق، بدون اسم ٥ دقايق، اسمين مختلفين = لا)', () {
      expect(crossMatch(ts: _t0, otherTs: _t0 + 2 * _min, name: 'Carrefour', otherName: 'Carrefour', crossChannel: false), isTrue);
      expect(crossMatch(ts: _t0, otherTs: _t0 + 4 * _min, name: 'Carrefour', otherName: 'Carrefour', crossChannel: false), isFalse);
      expect(crossMatch(ts: _t0, otherTs: _t0 + 4 * _min, name: '', otherName: 'Carrefour', crossChannel: false), isTrue);
      expect(crossMatch(ts: _t0, otherTs: _t0 + 1 * _min, name: 'Carrefour', otherName: 'Spinneys', crossChannel: false), isFalse);
    });
    test('نفس المرجع: تكرار في أي قناة خلال ١٠ دقايق', () {
      expect(crossMatch(ts: _t0, otherTs: _t0 + 9 * _min, name: 'x', otherName: 'y', crossChannel: false, ref: 'R9', otherRef: 'R9'), isTrue);
    });
  });

  group('isDuplicateOp / ledgerDup', () {
    test('إشعار إنستاباي + رسالة بنك (مرجعين مختلفين، اسمين مختلفين) = نفس العملية', () {
      final n = _k('n', 0, name: 'Ahmed', ref: 'IPN-77');
      final s = _k('s', 3 * _min, name: 'ACME BANK TRF', ref: '9988123');
      expect(isDuplicateOp(s, n), isTrue);
      expect(isDuplicateOp(n, s), isTrue);
    });
    test('نفس القناة + مرجعين مختلفين = عمليتين حتى لو نفس المبلغ والاسم', () {
      expect(isDuplicateOp(_k('s', 60 * 1000, name: 'Ahmed', ref: 'B2'), _k('s', 0, name: 'Ahmed', ref: 'A1')), isFalse);
    });
    test('نفس القناة بدون مرجع: نفس الاسم ≤ ٣ دقايق = تكرار، بعدها لأ', () {
      expect(isDuplicateOp(_k('s', 2 * _min, name: 'Carrefour'), _k('s', 0, name: 'Carrefour')), isTrue);
      expect(isDuplicateOp(_k('s', 4 * _min, name: 'Carrefour'), _k('s', 0, name: 'Carrefour')), isFalse);
    });
    test('نسخة بلغة تانية بدون اسم خلال ٩٠ ثانية (نفس القناة)', () {
      expect(isDuplicateOp(_k('s', 60 * 1000, lang: 'e'), _k('s', 0, lang: 'a')), isTrue);
      expect(isDuplicateOp(_k('s', 100 * 1000, lang: 'e'), _k('s', 0, lang: 'a')), isFalse);
    });
    test('قناتين مختلفتين: نافذة ١٠ دقايق (مش ٣)', () {
      expect(isDuplicateOp(_k('s', 9 * _min + 30 * 1000), _k('n', 0)), isTrue);
      expect(isDuplicateOp(_k('s', 10 * _min + 1), _k('n', 0)), isFalse);
    });
    test('بطاقتين مختلفتين (آخر ٤ أرقام) = عمليتين حتى بين القناتين', () {
      expect(isDuplicateOp(_k('s', _min, l4: '7748'), _k('n', 0, l4: '1234')), isFalse);
      expect(isDuplicateOp(_k('s', _min, l4: '7748'), _k('n', 0)), isTrue); // الإشعار غالبًا بدون رقم بطاقة
    });
    test('اختلاف المبلغ/العملة/الاتجاه = عمليتين', () {
      expect(isDuplicateOp(_k('s', _min, minor: 160000), _k('n', 0)), isFalse);
      expect(isDuplicateOp(_k('s', _min, cur: 'USD'), _k('n', 0)), isFalse);
      expect(isDuplicateOp(_k('s', _min, income: true), _k('n', 0)), isFalse);
    });
    test('سماحية الرسوم: تحويل صادر بالجنيه بين قناتين فقط', () {
      expect(isDuplicateOp(_k('s', _min, minor: 100100), _k('n', 0, minor: 100000)), isTrue);
      expect(isDuplicateOp(_k('s', _min, minor: 100100), _k('s', 0, minor: 100000)), isFalse);
    });
    test('ledgerDup بيدوّر في كل الإدخالات', () {
      final led = [
        {'minor': 5000, 'ts': _t0, 'cur': 'EGP', 'in': false, 'ref': '', 'l4': '', 'name': '', 'lang': 'a', 'ch': 's'},
        {'minor': 150000, 'ts': _t0, 'cur': 'EGP', 'in': false, 'ref': 'IPN-1', 'l4': '', 'name': 'Ahmed', 'lang': 'a', 'ch': 'n'},
      ];
      expect(ledgerDup(_k('s', 5 * _min, ref: 'BANK-9', name: 'x'), led), isTrue);
      expect(ledgerDup(_k('s', 5 * _min, minor: 777), led), isFalse);
    });
  });

  group('NotifHold (طابور الانتظار)', () {
    test('مدة الانتظار بين ٦٠ و٩٠ ثانية', () {
      expect(kNotifHold.inSeconds, inInclusiveRange(kNotifHoldMinSeconds, kNotifHoldMaxSeconds));
      expect(kNotifHoldMinSeconds, 60);
      expect(kNotifHoldMaxSeconds, 90);
    });
    test('رسالة لنفس العملية بتشيل الإشعار من الانتظار (حتى بمرجع مختلف)', () {
      final q = NotifHold();
      q.add(HeldNotif(id: '1', sender: 'N:instapay', body: 'b', recvMs: _t0, dueAt: _t0 + kNotifHold.inMilliseconds, key: _k('n', 0, ref: 'IPN-1')));
      expect(q.takeDuplicatesOf(_k('s', 20 * 1000, ref: 'BANK-5')).length, 1);
      expect(q.isEmpty, isTrue);
    });
    test('رسالة لعملية تانية (مبلغ مختلف) مابتشيلش الإشعار', () {
      final q = NotifHold();
      q.add(HeldNotif(id: '1', sender: 'N:instapay', body: 'b', recvMs: _t0, dueAt: _t0 + kNotifHold.inMilliseconds, key: _k('n', 0)));
      expect(q.takeDuplicatesOf(_k('s', 20 * 1000, minor: 99900)), isEmpty);
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

  group('سيناريوهات الوصول (إشعار إنستاباي + رسالة بنك = معاملة واحدة)', () {
    final n = _k('n', 0, name: 'Ahmed', ref: 'IPN-77');
    DedupKey s(int atMs) => _k('s', atMs, name: 'ACME BANK TRF', ref: '9988123');

    test('إشعار ثم رسالة خلال فترة الانتظار ← معاملة واحدة (من الرسالة)', () {
      final m = _Model();
      m.notif(n, _now(0));
      m.sms(s(30 * 1000));
      m.tick(_now(120 * 1000));
      expect(m.recorded.length, 1);
      expect(m.recorded.first.ch, 's');
    });
    test('إشعار ثم رسالة بعد انتهاء الانتظار (٣ دقايق) ← معاملة واحدة', () {
      final m = _Model();
      m.notif(n, _now(0));
      m.tick(_now(80 * 1000));
      expect(m.recorded.length, 1);
      expect(m.recorded.first.ch, 'n');
      m.sms(s(3 * _min));
      expect(m.recorded.length, 1);
    });
    test('إشعار ثم رسالة متأخرة لحد ١٠ دقايق ← معاملة واحدة', () {
      final m = _Model();
      m.notif(n, _now(0));
      m.tick(_now(80 * 1000));
      m.sms(s(9 * _min + 55 * 1000));
      expect(m.recorded.length, 1);
    });
    test('رسالة ثم إشعار (مرجعين مختلفين) ← معاملة واحدة والإشعار مايتحجزش', () {
      final m = _Model();
      m.sms(s(0));
      m.notif(_k('n', 20 * 1000, name: 'Ahmed', ref: 'IPN-77'), _now(20 * 1000));
      expect(m.hold.isEmpty, isTrue);
      m.tick(_now(200 * 1000));
      expect(m.recorded.length, 1);
    });
    test('رسالة ثم إشعار بعد ٨ دقايق ← معاملة واحدة', () {
      final m = _Model();
      m.sms(s(0));
      m.notif(_k('n', 8 * _min, name: 'Ahmed', ref: 'IPN-77'), _now(8 * _min));
      m.tick(_now(10 * _min));
      expect(m.recorded.length, 1);
    });
    test('إشعار بدون رسالة خالص ← يتسجّل عادي بعد المدة', () {
      final m = _Model();
      m.notif(n, _now(0));
      m.tick(_now(74 * 1000));
      expect(m.recorded, isEmpty); // لسه منتظر
      m.tick(_now(76 * 1000));
      expect(m.recorded.length, 1);
    });
    test('سماحية الرسوم: إشعار ١٠٠٠ ج + رسالة ١٠٠١ ج ← معاملة واحدة', () {
      final m = _Model();
      m.notif(_k('n', 0, minor: 100000, name: 'Ahmed'), _now(0));
      m.tick(_now(80 * 1000));
      m.sms(_k('s', 2 * _min, minor: 100100, name: 'ACME'));
      expect(m.recorded.length, 1);
    });
    test('عمليتين حقيقيتين بنفس المبلغ بينهم أكتر من ١٠ دقايق ← معاملتين', () {
      final m = _Model();
      m.notif(n, _now(0));
      m.tick(_now(80 * 1000));
      m.sms(s(11 * _min));
      expect(m.recorded.length, 2);
    });
    test('رسالتين بنفس القناة بمرجعين مختلفين ← عمليتين', () {
      final m = _Model();
      m.sms(_k('s', 0, ref: 'A1', name: 'Ahmed'));
      m.sms(_k('s', 30 * 1000, ref: 'B2', name: 'Ahmed'));
      expect(m.recorded.length, 2);
    });
    test('إشعارين متتاليين لنفس العملية ثم رسالة ← معاملة واحدة', () {
      final m = _Model();
      m.notif(n, _now(0));
      m.notif(_k('n', 5 * 1000, name: 'Ahmed', ref: 'IPN-77'), _now(5 * 1000));
      m.sms(s(40 * 1000));
      m.tick(_now(200 * 1000));
      expect(m.recorded.length, 1);
    });
  });
}
