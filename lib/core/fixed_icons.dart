import 'package:flutter/material.dart';

/// أيقونات ثابتة تُختار لخطة القسط (تُحفظ في الحقل img بالشكل `ic:<key>` فتتزامن مع باقي البيانات).
class FixedIcon {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const FixedIcon(this.key, this.label, this.icon, this.color);
}

const List<FixedIcon> kFixedIcons = [
  FixedIcon('phone', 'موبايل', Icons.smartphone_rounded, Color(0xFF0A84FF)),
  FixedIcon('laptop', 'لابتوب', Icons.laptop_mac_rounded, Color(0xFF5E5CE6)),
  FixedIcon('tv', 'تلفزيون', Icons.tv_rounded, Color(0xFF30B0C7)),
  FixedIcon('fridge', 'ثلاجة', Icons.kitchen_rounded, Color(0xFF32ADE6)),
  FixedIcon('washer', 'غسالة', Icons.local_laundry_service_rounded, Color(0xFF64D2FF)),
  FixedIcon('ac', 'تكييف', Icons.ac_unit_rounded, Color(0xFF00C7BE)),
  FixedIcon('car', 'عربية', Icons.directions_car_rounded, Color(0xFFFF9500)),
  FixedIcon('bike', 'موتوسيكل/عجلة', Icons.two_wheeler_rounded, Color(0xFFFF6B5E)),
  FixedIcon('home', 'شقة/بيت', Icons.home_rounded, Color(0xFF34C759)),
  FixedIcon('furniture', 'أثاث', Icons.chair_rounded, Color(0xFFA2845E)),
  FixedIcon('wedding', 'جواز/ذهب', Icons.diamond_rounded, Color(0xFFFF2D55)),
  FixedIcon('school', 'تعليم', Icons.school_rounded, Color(0xFFAF52DE)),
  FixedIcon('medical', 'علاج', Icons.medical_services_rounded, Color(0xFFFF3B30)),
  FixedIcon('travel', 'سفر', Icons.flight_takeoff_rounded, Color(0xFF007AFF)),
  FixedIcon('shopping', 'مشتريات', Icons.shopping_bag_rounded, Color(0xFFFF9F0A)),
  FixedIcon('game', 'ألعاب', Icons.sports_esports_rounded, Color(0xFF8E8E93)),
  FixedIcon('camera', 'كاميرا', Icons.photo_camera_rounded, Color(0xFF636366)),
  FixedIcon('watch', 'ساعة', Icons.watch_rounded, Color(0xFF30D158)),
  FixedIcon('fitness', 'جيم/رياضة', Icons.fitness_center_rounded, Color(0xFFFF453A)),
  FixedIcon('card', 'كارت/قرض', Icons.credit_card_rounded, Color(0xFF0A84FF)),
  FixedIcon('bank', 'بنك', Icons.account_balance_rounded, Color(0xFFFF9500)),
  FixedIcon('wallet', 'محفظة', Icons.account_balance_wallet_rounded, Color(0xFFFF453A)),
  FixedIcon('cash', 'كاش', Icons.payments_rounded, Color(0xFF34C759)),
  FixedIcon('savings', 'ادخار', Icons.savings_rounded, Color(0xFFFF2D55)),
  FixedIcon('group', 'جمعية/ناس', Icons.groups_rounded, Color(0xFF16A394)),
  FixedIcon('stream', 'بث/اشتراك', Icons.play_circle_rounded, Color(0xFFE5383B)),
  FixedIcon('music', 'موسيقى', Icons.music_note_rounded, Color(0xFF1DB954)),
  FixedIcon('cloud', 'سحابة/تخزين', Icons.cloud_rounded, Color(0xFF5AC8FA)),
  FixedIcon('wifi', 'إنترنت', Icons.wifi_rounded, Color(0xFF0A84FF)),
  FixedIcon('bolt', 'كهرباء', Icons.bolt_rounded, Color(0xFFFFCC00)),
  FixedIcon('water', 'مياه', Icons.water_drop_rounded, Color(0xFF32ADE6)),
  FixedIcon('food', 'أكل', Icons.restaurant_rounded, Color(0xFFFF9F0A)),
  FixedIcon('gift', 'هدية', Icons.card_giftcard_rounded, Color(0xFFBF5AF2)),
  FixedIcon('work', 'شغل', Icons.work_rounded, Color(0xFF8E8E93)),
  FixedIcon('pet', 'حيوان أليف', Icons.pets_rounded, Color(0xFFA2845E)),
];

const String kFixedPrefix = 'ic:';

FixedIcon? fixedIconOf(String img) {
  if (!img.startsWith(kFixedPrefix)) return null;
  final k = img.substring(kFixedPrefix.length);
  for (final f in kFixedIcons) {
    if (f.key == k) return f;
  }
  return null;
}
