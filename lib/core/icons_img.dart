import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// مكتبة أيقونات الحسابات (تُخزَّن كـ `ic:<name>`).
const Map<String, (IconData, Color)> kAccIcons = {
  'bank': (Icons.account_balance_rounded, Color(0xFFFF9F0A)),
  'cash': (Icons.payments_rounded, Color(0xFF30D158)),
  'wallet': (Icons.account_balance_wallet_rounded, Color(0xFFFF453A)),
  'card': (Icons.credit_card_rounded, Color(0xFF0A84FF)),
  'savings': (Icons.savings_rounded, Color(0xFFFF6482)),
  'phone': (Icons.smartphone_rounded, Color(0xFF32ADE6)),
  'shop': (Icons.shopping_bag_rounded, Color(0xFFBF5AF2)),
  'home': (Icons.home_rounded, Color(0xFFB08A5A)),
  'car': (Icons.directions_car_rounded, Color(0xFF64D2FF)),
  'work': (Icons.work_rounded, Color(0xFF8E9AAF)),
  'gift': (Icons.card_giftcard_rounded, Color(0xFFFF375F)),
  'invest': (Icons.trending_up_rounded, Color(0xFF30D158)),
  'gold': (Icons.diamond_rounded, Color(0xFFFFD60A)),
  'travel': (Icons.flight_rounded, Color(0xFF5E5CE6)),
  'food': (Icons.restaurant_rounded, Color(0xFFFF9F0A)),
  'health': (Icons.medical_services_rounded, Color(0xFFFF453A)),
  'edu': (Icons.school_rounded, Color(0xFF0A84FF)),
  'game': (Icons.sports_esports_rounded, Color(0xFFBF5AF2)),
  'star': (Icons.star_rounded, Color(0xFFFFD60A)),
  'heart': (Icons.favorite_rounded, Color(0xFFFF375F)),
};

/// يصغّر الصورة إلى مربع صغير ويحوّلها إلى data URI (تُزامَن مع باقي بيانات الحساب).
Future<String?> shrinkToDataUri(Uint8List bytes, {int size = 112}) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: size);
    final fi = await codec.getNextFrame();
    final bd = await fi.image.toByteData(format: ui.ImageByteFormat.png);
    if (bd == null) return null;
    return 'data:image/png;base64,${base64Encode(bd.buffer.asUint8List())}';
  } catch (_) {
    return null;
  }
}

/// اختيار صورة من المعرض.
Future<String?> pickIconFromGallery() async {
  try {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (x == null) return null;
    return shrinkToDataUri(await x.readAsBytes());
  } catch (_) {
    return null;
  }
}

/// سحب صورة من رابط وتخزينها داخل التطبيق (تعمل بدون إنترنت بعد ذلك). null عند الفشل.
Future<String?> fetchIconFromUrl(String url) async {
  try {
    final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200 || r.bodyBytes.isEmpty) return null;
    return shrinkToDataUri(r.bodyBytes);
  } catch (_) {
    return null;
  }
}

final Map<String, Uint8List> _memCache = {};

/// بايتات أيقونة data URI (مع كاش).
Uint8List? iconBytes(String uri) {
  final hit = _memCache[uri];
  if (hit != null) return hit;
  final i = uri.indexOf(',');
  if (i < 0) return null;
  try {
    final b = base64Decode(uri.substring(i + 1));
    _memCache[uri] = b;
    return b;
  } catch (_) {
    return null;
  }
}
