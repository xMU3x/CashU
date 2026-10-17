import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashu/sms/sms_parser.dart';
import 'package:cashu/sms/sms_text.dart';

void main() {
  final cfg = const SmsConfig(cardAcc: {'7748': 'acc1'});
  final recv = DateTime(2026, 10, 15, 14, 40).millisecondsSinceEpoch;
  final cases = (jsonDecode(File('test/sms_vectors.json').readAsStringSync())['cases'] as List).cast<Map<String, dynamic>>();

  group('sms vectors', () {
    for (final c in cases) {
      test(c['n'] as String, () {
        final r = parseSms(c['s'] as String, c['b'] as String, recv, cfg);
        expect(r.verdict.name, c['v']);
        if (c.containsKey('r')) expect(r.reason, c['r']);
        if (c.containsKey('k')) expect(r.kind, c['k']);
        if (c.containsKey('m')) expect(r.minor, c['m']);
        if (c.containsKey('c')) expect(r.currency, c['c']);
        if (c.containsKey('l4')) expect(r.last4, c['l4']);
      });
    }
  });

  group('text utils', () {
    test('arabic digits', () => expect(asciiDigits('٣٥٠٫٧٥ ۱۲'), '350.75 12'));
    test('parseMinor', () {
      expect(parseMinor('1,234.50'), 123450);
      expect(parseMinor('1.234,50'), 123450);
      expect(parseMinor('1,250'), 125000);
      expect(parseMinor('50,25'), 5025);
      expect(parseMinor('abc'), isNull);
      expect(parseMinor('1.234'), 123400); // ثلاث خانات بعد الفاصلة = آلاف
    });
    test('mask', () => expect(maskSensitive('acct 1234567890'), 'acct •••7890'));
    test('fingerprint stable', () => expect(fingerprint('a'), fingerprint('a')));
  });

  group('dedupe keys', () {
    test('same body same fingerprint', () {
      expect(bodyFingerprint('CIB', 'Purchase EGP 5 card ending 7748'), bodyFingerprint('cib', 'purchase egp 5  card ending 7748 '));
    });
    test('date from message', () {
      final r = parseSms('CIB', 'Purchase EGP 10 at X card ending 7748 on 15/10/2026 14:32', recv, cfg);
      expect(r.ts, DateTime(2026, 10, 15, 14, 32).millisecondsSinceEpoch);
    });
    test('absurd date falls back to received time', () {
      final r = parseSms('CIB', 'Purchase EGP 10 at X card ending 7748 on 01/01/2030', recv, cfg);
      expect(r.ts, recv);
    });
  });
}
