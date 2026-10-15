import '../core/sms_parser.dart';

/// معاملة مقترحة جاية من رسالة أو من نص حر، لسه محتاجة تأكيد.
/// بتتخزّن على الجهاز بس (مش بتتزامن) عشان نص الرسائل ما يتبعتش للسحابة.
class Suggestion {
  final String id, sender, body;
  final int ts;
  final Parsed p;
  final String? accountId;

  /// مبلغ بالجنيه يكتبه المستخدم لو العملة أجنبية.
  final double? egpOverride;

  const Suggestion({
    required this.id,
    required this.sender,
    required this.body,
    required this.ts,
    required this.p,
    this.accountId,
    this.egpOverride,
  });

  bool get foreign => p.currency != 'EGP';
  double? get amountEgp => foreign ? egpOverride : p.amount;
  bool get ready =>
      p.type != null && (amountEgp ?? 0) > 0 && accountId != null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'sender': sender,
        'body': body,
        'ts': ts,
        'p': p.toMap(),
        'accountId': accountId,
        'egp': egpOverride,
      };

  factory Suggestion.fromMap(Map<String, dynamic> m) => Suggestion(
        id: m['id'],
        sender: m['sender'] ?? '',
        body: m['body'] ?? '',
        ts: (m['ts'] as num).toInt(),
        p: Parsed.fromMap(Map<String, dynamic>.from(m['p'])),
        accountId: m['accountId'],
        egpOverride: (m['egp'] as num?)?.toDouble(),
      );
}
