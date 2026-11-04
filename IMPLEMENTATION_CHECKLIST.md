# IMPLEMENTATION_CHECKLIST — تحويل CashU من Flutter إلى Kotlin + Jetpack Compose

> **الحالة الصادقة:** هذه الجلسة بنت **الأساس (Foundation)** فقط. التطبيق الأصلي ≈ **20,396 سطر Dart** في 73 ملفًا؛ أغلب الشاشات والمنطق **لم يُنقل بعد**.
> **لم يُشغَّل أي Gradle build ولا Lint ولا اختبار** (بيئة العمل لا تصل لـ Maven/Google ولا تحوي Android SDK). كل ما فوق مكتوب لكنه **غير مجرَّب** حتى يشتغل GitHub Actions.
> **Flutter/Dart لم يُحذف** (حسب طلبك: لا حذف قبل اكتمال الـparity). الـworkflow القديم صار يدويًا فقط.

رموز: `[x]` منقول ومتحقَّق منه · `[~]` مكتوب وغير مجرَّب · `[ ]` لم يبدأ

## 0) خطوة التحقق الأولى (أنت) — التفاصيل في START_HERE.md
- [ ] ادفع الفرع (بدون force) وشغّل `Build CashU (Kotlin Native)` وأرسل لي سجل الأخطاء لإصلاحها
- [ ] ضبط Secrets: `SUPABASE_ANON_KEY` (+ اختياري Keystore)

## 1) البنية والبناء
- [~] settings/build.gradle.kts + `gradle/libs.versions.toml` (AGP 8.7.3 · Kotlin 2.0.21 · Compose BOM 2024.12.01 · Room 2.6.1)
- [~] `.github/workflows/android-native.yml`: Ubuntu + JDK17 + Android SDK + Gradle 8.11.1 (بدون wrapper) · test → lint → assembleRelease + bundleRelease → توقيع APK → Artifacts (APK + AAB + تقارير)
- [ ] gradle wrapper داخل المستودع (يُولَّد على CI أو محليًا — غير متاح هنا)
- [ ] R8/shrink + ProGuard قواعد Room/Serialization
- [ ] إصدار GitHub Release تلقائي (موجود في workflow Flutter القديم — يُنقل بعد الـparity)
- [ ] updater داخل التطبيق (`core/updater.dart`)

## 2) الطبقات (Architecture)
- [~] Room: Account/Tx/Budget/Goal/CatDef/Loan + DAOs (upsert فقط، حذف ناعم، بدون destructive migration)
- [ ] كيانات ناقصة: subs (`tyr_sub`) · assoc (`tyr_assoc`) · inst (`tyr_inst`) · settings (`tyr_set`) · groups (`tyr_ctg`) · أصول (assets)
- [~] **ترحيل البيانات**: `FlutterImporter` يقرأ `FlutterSharedPreferences` (`flutter.tyr:*`) → Room مرة واحدة، لا يحذف ولا يكتب فوق الأحدث، ويحوّل xfer القديمة — يعمل فقط لو applicationId مطابق للنسخة القديمة (**تأكد منه** من APK القديم)
- [~] `Calc.kt`: bal/balAt/receivables/debts/accountsTotal/monthTotals/migrateLegacyTransfers + `CalcTest` — باقي repo.dart (الميزانيات، التصنيفات، السلة، الاستعادة، النسخ الاحتياطي، homeLiabilities) لم يُنقل
- [ ] `calc.dart` · `extras.dart` (المتاح/الأقساط/البطاقات) · `currency.dart` · `prices.dart` · `notify.dart` (إشعارات مجدولة عبر AlarmManager/WorkManager)
- [ ] Supabase sync (نقل `sync.dart`): Auth (email + Google OAuth عبر `com.werd.cashu://auth`) + upsert/pull على `cash_sync` + مزامنة بفاصل 2.5ث + `delete_my_account` RPC — دمج السجلات `Merge.kt` جاهز، العميل لم يُكتب
- [ ] Edge Function `analyze-sms` (AI اختياري بموافقة) — يبقى كما هو على السيرفر؛ العميل لم يُنقل

## 3) SMS والإشعارات (محلي/أوفلاين)
- [~] `SmsReceiver` · `SmsQueue` · `NotifListener` منقولة حرفيًا (تغيير package فقط) + `SmsQueueTest`
- [ ] ربط الطابور بـ Kotlin بدل MethodChannel (من `MainActivity.kt` القديم): طلب الأذونات، قراءة/ack
- [ ] `lib/sms/groq_ai.dart` (54 سطر)
- [ ] `lib/sms/sms_cat.dart` (44 سطر)
- [ ] `lib/sms/sms_parser.dart` (280 سطر)
- [ ] `lib/sms/sms_rules.dart` (89 سطر)
- [ ] `lib/sms/sms_text.dart` (152 سطر)
- [ ] `lib/sms/sms_tracker.dart` (788 سطر)

## 4) الواجهة (Material 3 Expressive)
- [~] Theme: Dynamic Color (Android 12+) + fallback + خط Ping AR + RTL دائم
- [~] Motion مركزي: أزرار 100ms · أيقونات 130 · صغير 140 · تبويب 170 · شاشة 200 · حوار 165 · sheet 200 · expand 180
- [ ] Spring/Shape Morphing/Shared Element/Predictive back — لم تُنفَّذ بعد
- [ ] Haptics موحّد (استُخدم مرة واحدة في زر الإضافة فقط)
- [~] AppNav: شريط سفلي (الرئيسية/المعاملات/الحسابات) + NavHost بانتقالات `Motion`
- [ ] Lint حاليًا `abortOnError=false` (لا يوقف البناء) — شدّده بعد أول تشغيل ناجح
- [ ] `lib/ui/acc_menu.dart` (100 سطر)
- [ ] `lib/ui/anim.dart` (353 سطر)
- [ ] `lib/ui/cached_img.dart` (128 سطر)
- [ ] `lib/ui/icon_library.dart` (196 سطر)
- [ ] `lib/ui/ios.dart` (602 سطر)
- [ ] `lib/ui/loc_text.dart` (28 سطر)
- [~] `lib/ui/motion.dart` (53 سطر) — Motion.kt (مدد/easing مركزية)
- [ ] `lib/ui/pay_widgets.dart` (279 سطر)
- [ ] `lib/ui/pickers.dart` (149 سطر)
- [ ] `lib/ui/seg_toggle.dart` (86 سطر)
- [ ] `lib/ui/sheets.dart` (855 سطر)
- [ ] `lib/ui/shell_scope.dart` (248 سطر)
- [ ] `lib/ui/sort_btn.dart` (70 سطر)
- [~] `lib/ui/theme.dart` (162 سطر) — Theme.kt (Dynamic Color + Ping + RTL) — الألوان/الأشكال التفصيلية من theme.dart لم تُطابَق بعد
- [ ] `lib/ui/widgets.dart` (520 سطر)

## 5) الشاشات (lib/pages) — النقل الفعلي
**المنقول جزئيًا (حقيقي على Room، غير مجرَّب):**
- `HomeScreen`: مجموع الحسابات + لك/عليك (ديون) + دخل/مصروف الشهر (التحويلات مستثناة)
- `TransactionsScreen`: قائمة + بحث + إضافة (مصروف/دخل/تحويل = معاملتين مربوطتين `xf`) + حذف ناعم (حذف طرفي التحويل معًا)
- `AccountsScreen`: قائمة بالرصيد الحالي (`Calc.bal`) + إضافة + حذف ناعم
- ناقص في الثلاثة: التصنيفات، العملات، التكرار، التعليق (pend)، التعديل، الترتيب/الفلاتر، بطاقات الائتمان (`cardEffBal`)، الأصول/الأقساط في صافي الثروة
- [ ] `lib/pages/acc_edit.dart` (414 سطر)
- [ ] `lib/pages/acc_tx.dart` (918 سطر)
- [ ] `lib/pages/accounts.dart` (201 سطر)
- [ ] `lib/pages/accounts_home.dart` (529 سطر)
- [ ] `lib/pages/add_tx.dart` (847 سطر)
- [ ] `lib/pages/archived_accounts.dart` (52 سطر)
- [ ] `lib/pages/assets_page.dart` (770 سطر)
- [ ] `lib/pages/assoc_inst.dart` (722 سطر)
- [ ] `lib/pages/card_panel.dart` (85 سطر)
- [ ] `lib/pages/categories_page.dart` (362 سطر)
- [ ] `lib/pages/extra_tabs.dart` (119 سطر)
- [ ] `lib/pages/group_edit.dart` (154 سطر)
- [ ] `lib/pages/home.dart` (282 سطر)
- [ ] `lib/pages/installments_page.dart` (751 سطر)
- [ ] `lib/pages/loans_page.dart` (813 سطر)
- [ ] `lib/pages/more_pages.dart` (607 سطر)
- [ ] `lib/pages/more_tab.dart` (120 سطر)
- [ ] `lib/pages/nav_items.dart` (197 سطر)
- [ ] `lib/pages/notif_bell.dart` (43 سطر)
- [ ] `lib/pages/obligations_page.dart` (264 سطر)
- [ ] `lib/pages/profile.dart` (130 سطر)
- [ ] `lib/pages/settings_page.dart` (153 سطر)
- [ ] `lib/pages/shop.dart` (79 سطر)
- [ ] `lib/pages/sms_pages.dart` (766 سطر)
- [ ] `lib/pages/stats.dart` (355 سطر)
- [ ] `lib/pages/subs_page.dart` (960 سطر)
- [ ] `lib/pages/supervise.dart` (132 سطر)
- [ ] `lib/pages/tools.dart` (109 سطر)
- [ ] `lib/pages/trash_page.dart` (109 سطر)

## 6) core (منطق العمل)
- [ ] `lib/core/assets.dart` (132 سطر)
- [ ] `lib/core/calc.dart` (66 سطر)
- [ ] `lib/core/cat_icons.dart` (65 سطر)
- [~] `lib/core/config.dart` (41 سطر) — SyncConfig.kt (keyLooksValid + المفاتيح) — URL/المفتاح عبر BuildConfig
- [ ] `lib/core/currency.dart` (88 سطر)
- [ ] `lib/core/extras.dart` (807 سطر)
- [ ] `lib/core/fixed_icons.dart` (63 سطر)
- [ ] `lib/core/groups.dart` (88 سطر)
- [ ] `lib/core/i18n.dart` (93 سطر)
- [ ] `lib/core/icon_catalog.dart` (472 سطر)
- [ ] `lib/core/icon_pick.dart` (51 سطر)
- [~] `lib/core/merge.dart` (42 سطر) — Merge.kt + MergeTest (لم يُشغَّل)
- [~] `lib/core/models.dart` (171 سطر) — Models.kt + Room entities + ModelsTest (لم يُشغَّل) — Cat/kExpCats الثابتة لم تُنقل بعد
- [ ] `lib/core/notify.dart` (187 سطر)
- [ ] `lib/core/prices.dart` (160 سطر)
- [ ] `lib/core/repo.dart` (762 سطر)
- [ ] `lib/core/settings.dart` (16 سطر)
- [ ] `lib/core/store.dart` (102 سطر)
- [ ] `lib/core/sync.dart` (201 سطر)
- [ ] `lib/core/updater.dart` (53 سطر)
- [ ] `lib/core/util.dart` (64 سطر)

## 7) الاختبارات (Dart الحالية = مرجع التكافؤ)
أي اختبار Dart يجب أن يُنقل إلى JUnit بنفس الحالات قبل حذف Flutter. كتبتُ حتى الآن: `MergeTest` · `SyncConfigTest` · `ModelsTest` · `SmsQueueTest` · `CalcTest` (غير مشغّلة).
- [ ] `test/assets_test.dart` (41 سطر)
- [ ] `test/assoc_calc_test.dart` (99 سطر)
- [ ] `test/calc_test.dart` (19 سطر)
- [ ] `test/card_installment_test.dart` (106 سطر)
- [ ] `test/clean_message_test.dart` (23 سطر)
- [ ] `test/extras_test.dart` (54 سطر)
- [ ] `test/groq_redact_test.dart` (15 سطر)
- [ ] `test/icon_catalog_test.dart` (24 سطر)
- [ ] `test/links_and_obligations_test.dart` (34 سطر)
- [ ] `test/notify_test.dart` (67 سطر)
- [ ] `test/session_changes_test.dart` (81 سطر)
- [ ] `test/sms_cat_test.dart` (23 سطر)
- [ ] `test/sms_parser_test.dart` (68 سطر)
- [ ] `test/sync_config_test.dart` (38 سطر)
- [ ] `test/updater_test.dart` (12 سطر)
- [ ] `test/wallet_and_trash_test.dart` (33 سطر)
- [ ] `test/write_spent_test.dart` (16 سطر)

## 8) تنظيف Flutter (لا يُنفَّذ إلا بعد الـparity والتحقق)
- [ ] حذف `lib/` · `pubspec.yaml` · `test/*.dart` · `analysis_options.yaml` · `android_overlay/` · `tool/*` · workflow Flutter
- [ ] حذف `CHECKLIST.md` القديم بعد دمج بنوده المفتوحة هنا

## 9) قواعد التنفيذ المتفق عليها
- لا Force Push ولا حذف مستودع ولا Push نهائي دون إذن صريح
- لا Mock Data ولا شاشات شكلية: شاشة لا تظهر في AppNav حتى تكتمل فعليًا
- لا يُعتبر شيء `[x]` إلا بعد نجاح CI فعليًا
