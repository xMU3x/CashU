import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// نتيجة تحليل الذكاء الاصطناعي لرسالة (اختيارية، بموافقة المستخدم فقط).
class AiVerdict {
  final bool financial;
  final String kind; // exp | inc | ''
  final double amount;
  final String merchant;
  final double confidence;
  const AiVerdict({required this.financial, this.kind = '', this.amount = 0, this.merchant = '', this.confidence = 0});
}

/// يخفي أرقام الحسابات/الهواتف الطويلة والروابط قبل الإرسال، ويُبقي المبلغ والتاجر.
String redactForAi(String body) {
  var s = body;
  s = s.replaceAll(RegExp(r'https?://\S+'), '[link]');
  // أرقام عربية-هندية → لاتينية
  const ar = '٠١٢٣٤٥٦٧٨٩';
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll(ar[i], '$i');
  }
  // 9 أرقام فأكثر متصلة (هاتف/حساب/كارت) → نخفي الكل عدا آخر 4
  s = s.replaceAllMapped(RegExp(r'\d[\d\- ]{7,}\d'), (m) {
    final d = m[0]!.replaceAll(RegExp(r'\D'), '');
    if (d.length < 9) return m[0]!;
    return '****${d.substring(d.length - 4)}';
  });
  return s;
}

/// تحليل عبر Supabase Edge Function `analyze-sms` (المفتاح على السيرفر فقط). يرجّع null عند أي فشل/مهلة/رفض
/// ← التطبيق يكمل بالمحلل المحلي. لا يُرسل شيء إلا بعد موافقة المستخدم (consent) ومع إخفاء الأرقام الطويلة.
Future<AiVerdict?> aiAnalyze(SupabaseClient? client, String sender, String body) async {
  if (client == null || client.auth.currentSession == null) return null;
  try {
    final res = await client.functions
        .invoke('analyze-sms', body: {'sender': sender, 'body': redactForAi(body), 'consent': true})
        .timeout(const Duration(seconds: 10));
    if (res.status != 200 || res.data is! Map) return null;
    final j = res.data as Map;
    return AiVerdict(
      financial: j['financial'] == true,
      kind: '${j['kind'] ?? ''}',
      amount: (j['amount'] as num?)?.toDouble() ?? 0,
      merchant: '${j['merchant'] ?? ''}',
      confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
    );
  } catch (_) {
    return null;
  }
}
