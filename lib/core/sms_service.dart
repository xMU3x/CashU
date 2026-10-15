import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../data/suggestion.dart';
import 'ai_service.dart';
import 'sms_channel.dart';
import 'sms_parser.dart';
import 'store.dart';

String _fnv(String s) {
  var h = 0x811c9dc5;
  for (final u in s.codeUnits) {
    h ^= u;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h.toRadixString(16);
}

/// خط الأنابيب: طابور الرسائل (من أندرويد) → تحليل بالقواعد → (اختياري) الذكاء الاصطناعي
/// → معاملة مقترحة (أو إضافة تلقائية لو مفعّلة والثقة عالية).
class SmsService {
  final _repo = Repo();
  bool _busy = false;

  bool get enabled => dev.get('smsOn') == true;

  List<Suggestion> pending() {
    final l = store
        .peekMap('inbox')
        .values
        .whereType<Map>()
        .map((m) => Suggestion.fromMap(Map<String, dynamic>.from(m)))
        .toList();
    l.sort((a, b) => b.ts.compareTo(a.ts));
    return l;
  }

  /// نفس الرسالة (المُرسل + النص + اليوم) = نفس المعرّف، عشان الاستيراد ما يكرّرش اللي اتلقط لايف.
  String idOf(String sender, String body, int ts) =>
      _fnv('${sender.toLowerCase()}|$body|${ts ~/ 86400000}');

  Future<int> poll() async {
    if (!enabled || _busy) return 0;
    _busy = true;
    try {
      return await _handleAll(await SmsChannel.drain());
    } finally {
      _busy = false;
    }
  }

  Future<int> importHistory(int days) async {
    if (_busy) return 0;
    _busy = true;
    try {
      return await _handleAll(await SmsChannel.readInbox(days));
    } finally {
      _busy = false;
    }
  }

  Future<int> _handleAll(List<Map<String, dynamic>> msgs) async {
    var added = 0;
    for (final m in msgs) {
      try {
        if (await _handle(m['sender'] ?? '', m['body'] ?? '',
            (m['ts'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch)) {
          added++;
        }
      } catch (e) {
        debugPrint('sms handle: $e');
      }
    }
    return added;
  }

  String? _guessAccount(String? last4) {
    final accs = _repo.accounts();
    if (last4 != null) {
      for (final a in accs) {
        if (a.last4 == last4) return a.id;
      }
    }
    return accs.length == 1 ? accs.first.id : null;
  }

  Future<bool> _handle(String sender, String body, int ts) async {
    final id = idOf(sender, body, ts);
    final seen = store.getMap('inbox_seen');
    if (seen.containsKey(id)) return false;

    var p = parseSms(sender, body);
    if (p == null) {
      _markSeen(id, ts);
      return false;
    }
    if (p.confidence < 0.7 && dev.get('smsAi') == true && AiService.available) {
      final r = await AiService.parse('$sender: $body', smsMode: true);
      if (r.notTransaction) {
        _markSeen(id, ts);
        return false;
      }
      if (r.parsed != null) p = r.parsed!.fill(p);
    }

    final acc = _guessAccount(p.last4);
    // إضافة تلقائية: بس لو الثقة عالية، وبالجنيه، والحساب معروف بالظبط
    if (dev.get('smsAuto') == true &&
        p.confidence >= 0.8 &&
        p.type != null &&
        (p.amount ?? 0) > 0 &&
        p.currency == 'EGP' &&
        acc != null) {
      await _repo.addTx(_toTx(p, acc, DateTime.fromMillisecondsSinceEpoch(ts)));
      _markSeen(id, ts);
      return true;
    }

    final s = Suggestion(id: id, sender: sender, body: body, ts: ts, p: p, accountId: acc);
    store.upd('inbox', (m) => m[id] = s.toMap());
    _markSeen(id, ts);
    return true;
  }

  void _markSeen(String id, int ts) {
    store.upd('inbox_seen', (m) {
      m[id] = ts;
      if (m.length > 3000) {
        final keys = m.keys.toList()
          ..sort((a, b) => (m[a] as num).compareTo(m[b] as num));
        for (final k in keys.take(m.length - 2500)) {
          m.remove(k);
        }
      }
    });
  }

  Tx _toTx(Parsed p, String accountId, DateTime date,
      {double? amount, String? type, String? categoryId, String? note}) {
    final t = type ?? p.type ?? 'expense';
    final income = t == 'income';
    return Tx(
      id: '',
      type: income ? TxType.income : TxType.expense,
      amount: amount ?? p.amount ?? 0,
      accountId: accountId,
      categoryId: categoryId ?? p.categoryId ?? (income ? 'other_in' : 'other'),
      note: note ?? p.merchant,
      date: date,
    );
  }

  Future<void> accept(Suggestion s,
      {double? amount,
      String? type,
      String? categoryId,
      String? accountId,
      String? note}) async {
    final acc = accountId ?? s.accountId;
    final amt = amount ?? s.amountEgp;
    if (acc == null || amt == null || amt <= 0) return;
    await _repo.addTx(_toTx(
      s.p,
      acc,
      DateTime.fromMillisecondsSinceEpoch(s.ts),
      amount: amt,
      type: type,
      categoryId: categoryId,
      note: note,
    ));
    store.upd('inbox', (m) => m.remove(s.id));
  }

  void dismiss(String id) => store.upd('inbox', (m) => m.remove(id));

  /// تأكيد كل المقترحات الجاهزة (نوع + مبلغ + حساب معروفين).
  Future<int> acceptReady() async {
    var n = 0;
    for (final s in pending()) {
      if (s.ready && s.p.confidence >= 0.7) {
        await accept(s);
        n++;
      }
    }
    return n;
  }
}

final SmsService smsService = SmsService();
