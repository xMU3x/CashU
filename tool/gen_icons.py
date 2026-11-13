import re
names=set(open('/home/claude/icon_names.txt').read().split())
def ok(n): return (n+'_rounded') in names
S=[]
def sec(id,title,icon,color,items): S.append((id,title,icon,color,items))

sec('telecom','اتصالات','cell_tower','0xFF0A84FF',[
('wifi','إنترنت واي فاي'),('wifi_calling','اتصال واي فاي'),('phone','هاتف'),('phone_android','موبايل أندرويد'),('phone_iphone','موبايل آيفون'),('smartphone','سمارت فون'),
('call','مكالمة'),('sim_card','شريحة'),('router','راوتر'),('cell_tower','برج شبكة'),('signal_cellular_alt','إشارة'),('receipt_long','فاتورة'),
('dialpad','لوحة أرقام'),('contact_phone','جهة اتصال'),('sms','رسائل'),('mail','بريد'),('chat','دردشة'),('language','إنترنت'),('hub','شبكة'),('cable','كابل'),
('satellite_alt','قمر صناعي'),('settings_input_antenna','هوائي'),('phone_in_talk','مكالمة جارية'),('perm_phone_msg','خدمة عملاء'),('data_usage','باقة بيانات'),('network_cell','تغطية'),('wifi_tethering','نقطة اتصال'),('headset_mic','سماعة اتصال')])
sec('home','سكن وخدمات','home','0xFF34C759',[
('home','بيت'),('house','منزل'),('apartment','شقة'),('bed','غرفة نوم'),('bolt','كهرباء'),('water_drop','مياه'),
('local_fire_department','غاز'),('plumbing','سباكة'),('electrical_services','كهربائي'),('light','إضاءة'),('chair','أثاث'),('kitchen','مطبخ'),
('bathtub','حمام'),('weekend','أريكة'),('cleaning_services','نظافة'),('yard','حديقة'),('garage','جراج'),('roofing','سقف'),
('key','مفتاح'),('ac_unit','تكييف'),('thermostat','حرارة'),('handyman','صيانة'),('countertops','رخام'),('door_front_door','باب'),
('fence','سور'),('recycling','قمامة'),('window','شباك'),('deck','تراس'),('security','أمن'),('lightbulb','لمبة'),('doorbell','جرس'),('curtains','ستائر')])
sec('food','أكل وشراب','restaurant','0xFFFF9F0A',[
('restaurant','مطعم'),('local_cafe','قهوة'),('fastfood','وجبات سريعة'),('local_pizza','بيتزا'),('bakery_dining','مخبوزات'),('local_bar','مشروبات'),
('ramen_dining','شوربة'),('lunch_dining','ساندوتش'),('icecream','آيس كريم'),('cake','كيك'),('emoji_food_beverage','شاي'),('set_meal','سمك'),
('egg','بيض'),('kebab_dining','مشويات'),('liquor','عصير'),('wine_bar','مشروب'),('brunch_dining','فطار'),('dinner_dining','عشاء'),
('soup_kitchen','طبخ'),('nutrition','فاكهة'),('tapas','مقبلات'),('rice_bowl','أرز'),('coffee','فنجان'),('coffee_maker','ماكينة قهوة'),('sports_bar','كوب'),('takeout_dining','طلب خارجي'),('local_dining','أدوات مائدة'),('breakfast_dining','إفطار')])
sec('shop','تسوق','shopping_bag','0xFFFF375F',[
('shopping_cart','عربة'),('shopping_bag','شنطة'),('store','متجر'),('storefront','محل'),('local_mall','مول'),('sell','سعر'),
('redeem','هدية'),('checkroom','ملابس'),('diamond','مجوهرات'),('watch','ساعة'),('local_grocery_store','بقالة'),('inventory_2','مخزون'),
('point_of_sale','كاشير'),('receipt','إيصال'),('loyalty','عرض'),('style','موضة'),('local_offer','خصم'),('dry_cleaning','تنظيف جاف'),
('local_laundry_service','مغسلة'),('add_shopping_cart','إضافة للسلة'),('production_quantity_limits','كمية محدودة'),('shopping_basket','سلة'),('face_retouching_natural','تجميل'),('content_cut','حلاقة'),('local_florist','ورد'),('toys','ألعاب'),('stroller','مستلزمات أطفال'),('smartphone','أجهزة')])
sec('transport','مواصلات','directions_car','0xFFBF5AF2',[
('directions_car','عربية'),('directions_bus','أتوبيس'),('local_taxi','تاكسي'),('train','قطار'),('subway','مترو'),('tram','ترام'),
('flight','طيران'),('two_wheeler','موتوسيكل'),('pedal_bike','عجلة'),('local_gas_station','بنزين'),('ev_station','شحن كهربائي'),('local_parking','ركنة'),
('directions_boat','مركب'),('moped','سكوتر'),('electric_scooter','سكوتر كهربائي'),('commute','مشوار'),('airport_shuttle','ميكروباص'),('car_repair','ورشة'),
('traffic','إشارة مرور'),('toll','رسوم طريق'),('local_shipping','شحن'),('flight_takeoff','إقلاع'),('hail','تاكسي أوبر'),('minor_crash','حادث'),('tire_repair','كاوتش'),('car_rental','إيجار سيارة'),('directions_walk','مشي'),('electric_car','سيارة كهربائية')])
sec('health','صحة','medical_services','0xFFFF3B30',[
('medical_services','خدمات طبية'),('medication','أدوية'),('favorite','قلب'),('monitor_heart','فحص قلب'),('vaccines','تطعيم'),('local_hospital','مستشفى'),
('healing','علاج'),('health_and_safety','تأمين صحي'),('psychology','نفسي'),('spa','سبا'),('self_improvement','استرخاء'),('fitness_center','جيم'),
('sports_gymnastics','رياضة'),('bloodtype','تحاليل'),('masks','كمامة'),('accessible','إعاقة'),('hearing','سمع'),('visibility','نظارة'),
('pregnant_woman','حمل'),('child_care','أطفال'),('medication_liquid','شراب'),('local_pharmacy','صيدلية'),('emergency','طوارئ'),('science','معمل'),('sanitizer','معقم'),('thermostat','حرارة'),('personal_injury','إصابة'),('monitor_weight','وزن')])
sec('edu','تعليم','school','0xFFAF52DE',[
('school','مدرسة'),('menu_book','كتاب'),('auto_stories','قصص'),('edit','قلم'),('science','علوم'),('calculate','حاسبة'),
('library_books','مكتبة'),('class','فصل'),('cast_for_education','تعليم أونلاين'),('history_edu','شهادة'),('translate','ترجمة'),('backpack','شنطة مدرسة'),
('local_library','مكتبة عامة'),('quiz','اختبار'),('draw','رسم'),('palette','ألوان'),('brush','فرشاة'),('architecture','هندسة'),
('functions','رياضيات'),('lightbulb','فكرة'),('workspace_premium','تفوق'),('military_tech','ميدالية'),('abc','لغة'),('piano','موسيقى'),('record_voice_over','محاضرة'),('assignment','واجب'),('grading','درجات'),('podcasts','بودكاست')])
sec('fun','ترفيه','sports_esports','0xFFFFD60A',[
('movie','أفلام'),('sports_esports','ألعاب'),('music_note','موسيقى'),('theaters','سينما'),('headphones','سماعات'),('casino','كازينو'),
('celebration','احتفال'),('sports_soccer','كرة قدم'),('sports_basketball','كرة سلة'),('sports_tennis','تنس'),('pool','سباحة'),('beach_access','شاطئ'),
('park','حديقة عامة'),('camping','تخييم'),('hiking','رحلة جبلية'),('photo_camera','كاميرا'),('videocam','فيديو'),('smart_display','عرض'),
('live_tv','تلفزيون'),('mic','ميكروفون'),('nightlife','سهر'),('attractions','ملاهي'),('festival','مهرجان'),('piano','بيانو'),('sports_golf','جولف'),('surfing','ركمجة'),('kayaking','كاياك'),('sports_martial_arts','فنون قتالية'),('sports_handball','كرة يد'),('skateboarding','سكيت')])
sec('finance','مال وبنوك','account_balance','0xFF30D158',[
('account_balance','بنك'),('account_balance_wallet','محفظة'),('credit_card','بطاقة ائتمان'),('payments','كاش'),('savings','ادخار'),('attach_money','دولار'),
('trending_up','ربح'),('trending_down','خسارة'),('currency_exchange','صرف عملات'),('request_quote','طلب تمويل'),('price_check','سداد'),('paid','مدفوع'),
('monetization_on','عملة'),('atm','صراف'),('pie_chart','توزيع'),('bar_chart','تقرير'),('show_chart','رسم بياني'),('candlestick_chart','أسهم'),
('money_off','بدون مصاريف'),('euro','يورو'),('currency_pound','جنيه'),('currency_bitcoin','بيتكوين'),('handshake','اتفاق'),('real_estate_agent','عقارات'),('percent','نسبة'),('receipt_long','كشف حساب'),('credit_score','تقييم ائتماني'),('local_atm','سحب نقدي')])
sec('work','عمل وتقنية','work','0xFF5E5CE6',[
('work','شغل'),('business_center','أعمال'),('laptop_mac','لابتوب'),('computer','كمبيوتر'),('desktop_windows','مكتب'),('devices','أجهزة'),
('cloud','سحابة'),('storage','تخزين'),('memory','معالج'),('code','برمجة'),('terminal','سطر أوامر'),('build','أدوات'),
('engineering','هندسة'),('construction','إنشاءات'),('badge','بطاقة عمل'),('support_agent','دعم فني'),('smart_toy','ذكاء اصطناعي'),('print','طباعة'),
('keyboard','لوحة مفاتيح'),('mouse','ماوس'),('tablet_mac','تابلت'),('usb','فلاشة'),('lock','حماية'),('admin_panel_settings','إدارة'),('domain','شركة'),('analytics','تحليلات'),('folder','ملفات'),('inventory','جرد')])
sec('people','عائلة وناس','groups','0xFF16A394',[
('person','شخص'),('people','ناس'),('groups','مجموعة'),('family_restroom','عائلة'),('child_care','طفل'),('elderly','كبار السن'),
('pets','حيوان أليف'),('baby_changing_station','رضيع'),('face','وجه'),('diversity_3','أصدقاء'),('wc','دورة مياه'),('woman','سيدة'),
('man','رجل'),('boy','ولد'),('girl','بنت'),('person_add','شخص جديد'),('supervisor_account','مسؤول'),('escalator_warning','عائلة بأطفال'),('sentiment_satisfied','سعيد'),('volunteer_activism','تبرع'),('cruelty_free','حيوانات'),('emoji_people','تحية'),('elderly_woman','سيدة كبيرة'),('person_pin','هوية')])
sec('gifts','هدايا ومناسبات','card_giftcard','0xFFFF2D55',[
('card_giftcard','هدية'),('redeem','كوبون'),('celebration','حفلة'),('cake','عيد ميلاد'),('local_florist','ورد'),('diamond','خاتم'),
('church','كنيسة'),('mosque','مسجد'),('volunteer_activism','صدقة'),('favorite','حب'),('wine_bar','عزومة'),('festival','موسم'),
('emoji_events','كأس'),('auto_awesome','تميز'),('loyalty','مكافأة'),('mail','دعوة'),('child_friendly','مولود'),('crib','سرير أطفال'),('hotel_class','نجمة'),('stars','نجوم'),('mood','مناسبة سعيدة'),('sentiment_very_satisfied','فرحة')])
sec('subs','اشتراكات وبث','play_circle','0xFFE5383B',[
('play_circle','تشغيل'),('subscriptions','اشتراكات'),('live_tv','بث مباشر'),('smart_display','فيديو'),('podcasts','بودكاست'),('library_music','موسيقى'),
('newspaper','جريدة'),('article','مقالات'),('rss_feed','متابعة'),('queue_music','قائمة تشغيل'),('video_library','مكتبة فيديو'),('tv','تلفزيون'),
('radio','راديو'),('headphones','سماعات'),('apps','تطبيقات'),('widgets','أدوات'),('cloud','تخزين سحابي'),('sports_esports','ألعاب'),
('movie_filter','أفلام'),('music_video','فيديو كليب'),('audiotrack','مقطع صوتي'),('menu_book','كتب'),('auto_stories','قراءة'),('workspace_premium','بريميوم'),('verified','موثّق'),('shield','حماية')])
sec('travel','سفر وسياحة','luggage','0xFF007AFF',[
('flight_takeoff','سفر'),('luggage','شنطة سفر'),('hotel','فندق'),('beach_access','مصيف'),('map','خريطة'),('explore','استكشاف'),
('public','العالم'),('landscape','طبيعة'),('directions_boat','رحلة بحرية'),('tour','جولة'),('backpack','رحلة'),('museum','متحف'),
('camping','معسكر'),('terrain','جبل'),('location_on','موقع'),('train','قطار'),('flight_land','وصول'),('travel_explore','بحث رحلات'),('temple_buddhist','معبد'),('villa','فيلا'),('sailing','شراع'),('airplane_ticket','تذكرة'),('local_activity','تذاكر'),('badge','تأشيرة')])
sec('other','أخرى','category','0xFF8E9AAF',[
('category','تصنيف'),('help','سؤال'),('more_horiz','أخرى'),('star','نجمة'),('flag','علم'),('label','وسم'),
('bookmark','علامة'),('lightbulb','فكرة'),('tag','هاشتاج'),('folder','مجلد'),('event','موعد'),('schedule','وقت'),
('notifications','تنبيه'),('settings','إعدادات'),('info','معلومة'),('extension','إضافة'),('bug_report','مشكلة'),('savings','حصالة'),('layers','طبقات'),('bolt','طاقة'),('local_offer','عرض'),('pets','حيوان'),('eco','بيئة'),('recycling','تدوير'),('volunteer_activism','خير'),('gavel','قانون'),('balance','عدل'),('emoji_events','إنجاز')])

out=[]; dropped=[]
out.append("""import 'package:flutter/material.dart';

/// مكتبة الأيقونات الموحّدة للتطبيق كله: أقسام (اتصالات · سكن · أكل · …) وفي كل قسم أيقونات كتير.
/// المفتاح بيتخزّن في الحقل (للتصنيفات: المفتاح نفسه، وللحسابات/الاشتراكات/الأقساط: `ic:<key>`).
/// بدون إيموجي — كل الأيقونات من Material Icons (Rounded).
/// ملف مولَّد: لا تعدّله يدويًا (راجع tool/gen_icons.py).
class IconEntry {
  final String key, label;
  final IconData icon;
  const IconEntry(this.key, this.label, this.icon);
}

class IconSection {
  final String id, title;
  final IconData icon;
  final Color color;
  final List<IconEntry> items;
  const IconSection(this.id, this.title, this.icon, this.color, this.items);
}

const List<IconSection> kIconSections = [""")
total=0
for (id,title,icon,color,items) in S:
    if not ok(icon): print("SECTION ICON MISSING",icon)
    out.append(f"  IconSection('{id}', '{title}', Icons.{icon}_rounded, Color({color}), [")
    seen=set()
    for (n,l) in items:
        if n in seen: continue
        seen.add(n)
        if not ok(n): dropped.append((id,n)); continue
        out.append(f"    IconEntry('g_{n}', '{l}', Icons.{n}_rounded),"); total+=1
    out.append("  ]),")
out.append("];")
out.append("""
Map<String, (IconEntry, IconSection)>? _idx;

/// بحث سريع بالمفتاح في كل الأقسام.
(IconEntry, IconSection)? catalogEntry(String key) {
  _idx ??= {
    for (final s in kIconSections)
      for (final e in s.items) e.key: (e, s),
  };
  return _idx![key];
}

IconData? catalogIcon(String key) => catalogEntry(key)?.$1.icon;
""")
open('/home/claude/proj/CashU.0.1/lib/core/icon_catalog.dart','w',encoding='utf-8').write("\n".join(out))
print("total icons",total,"sections",len(S))
print("dropped",dropped)
