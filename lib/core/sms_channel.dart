import 'dart:convert';
import 'package:flutter/services.dart';

/// جسر لكود أندرويد الأصلي (SmsReceiver / MainActivity). على أي منصة تانية بيرجّع قيم فاضية.
class SmsChannel {
  static const _c = MethodChannel('budget/sms');

  static Future<bool> hasPermission() async {
    try {
      return await _c.invokeMethod<bool>('hasPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestPermission() async {
    try {
      return await _c.invokeMethod<bool>('requestPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openSettings() async {
    try {
      await _c.invokeMethod('openSettings');
    } catch (_) {}
  }

  /// الرسائل المالية اللي استقبلها الـ Receiver من آخر مرة (وبيفضّي الطابور).
  static Future<List<Map<String, dynamic>>> drain() => _list('drainQueue');

  /// قراءة صندوق الوارد لآخر [days] يوم (للاستيراد الأولي).
  static Future<List<Map<String, dynamic>>> readInbox(int days) =>
      _list('readInbox', {'days': days});

  static Future<List<Map<String, dynamic>>> _list(String m,
      [Map<String, dynamic>? args]) async {
    try {
      final s = await _c.invokeMethod<String>(m, args);
      if (s == null || s.isEmpty) return [];
      return (jsonDecode(s) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
