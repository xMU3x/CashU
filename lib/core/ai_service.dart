import 'package:flutter/foundation.dart';
import '../core/categories.dart';
import 'sms_parser.dart';
import 'sync.dart';

class AiResult {
  final Parsed? parsed;
  final bool notTransaction, failed;
  const AiResult({this.parsed, this.notTransaction = false, this.failed = false});
}

/// الذكاء الاصطناعي بيمر عبر دالة Supabase (`parse-sms`) اللي بتكلّم Claude.
/// مفتاح Anthropic على السيرفر بس؛ التطبيق بيبعت نص الرسالة بعد إخفاء الأرقام الطويلة.
class AiService {
  static bool get available => sync.ready && sync.user != null;

  /// إخفاء أي رقم من 8 خانات فأكتر (أرقام كروت/حسابات/موبايلات).
  static String mask(String s) =>
      toAsciiDigits(s).replaceAll(RegExp(r'\d{8,}'), '••••');

  static Future<AiResult> parse(String text,
      {required bool smsMode, DateTime? now}) async {
    if (!available) return const AiResult(failed: true);
    final d = now ?? DateTime.now();
    try {
      final r = await sync.client!.functions.invoke('parse-sms', body: {
        'mode': smsMode ? 'sms' : 'text',
        'text': mask(text),
        'today':
            '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      });
      final m = r.data;
      if (m is! Map) return const AiResult(failed: true);
      if (m['is_transaction'] != true) return const AiResult(notTransaction: true);

      final type = m['type'] == 'income' ? 'income' : 'expense';
      final amount = (m['amount'] as num?)?.toDouble();
      if (amount == null || amount <= 0) return const AiResult(notTransaction: true);

      var cat = m['category'] as String?;
      final c = catById(cat);
      if (c == null || c.income != (type == 'income')) {
        cat = type == 'income' ? 'other_in' : 'other';
      }
      DateTime? date;
      final ds = m['date'];
      if (ds is String) date = DateTime.tryParse(ds);

      return AiResult(
        parsed: Parsed(
          type: type,
          amount: amount,
          currency: (m['currency'] as String?) ?? 'EGP',
          merchant: m['merchant'] as String?,
          categoryId: cat,
          last4: m['last4'] as String?,
          note: m['note'] as String?,
          confidence: 0.9,
          source: 'ai',
          date: date,
        ),
      );
    } catch (e) {
      debugPrint('ai parse: $e');
      return const AiResult(failed: true);
    }
  }
}
