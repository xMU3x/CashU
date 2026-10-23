import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

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

/// تحليل عبر Groq (OpenAI-compatible). يرجّع null عند أي فشل/مهلة ← التطبيق يكمل بالمحلل المحلي.
Future<AiVerdict?> groqAnalyze(String apiKey, String sender, String body, {String model = 'llama-3.3-70b-versatile'}) async {
  if (apiKey.trim().isEmpty) return null;
  try {
    final res = await http
        .post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {'Authorization': 'Bearer ${apiKey.trim()}', 'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': model,
            'temperature': 0,
            'response_format': {'type': 'json_object'},
            'messages': [
              {
                'role': 'system',
                'content': 'You classify Egyptian bank/wallet SMS. Reply ONLY JSON: {"financial":bool,"kind":"exp"|"inc"|"","amount":number,"merchant":string,"confidence":0..1}. '
                    'financial=false for OTPs, ads, promotions, balance-only or failed transactions. exp = money left the account, inc = money received.'
              },
              {'role': 'user', 'content': 'Sender: $sender\nMessage: ${redactForAi(body)}'},
            ],
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    final txt = (jsonDecode(utf8.decode(res.bodyBytes))['choices'][0]['message']['content'] ?? '') as String;
    final j = jsonDecode(txt) as Map;
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
