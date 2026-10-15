# تيّار — تطبيق تتبّع المصاريف (Flutter)

نفس نظام بيانات «دُرَر» بالظبط:
- **نفس مشروع Supabase** ونفس الجدول `werd_sync (user_id, key, value jsonb, ts bigint)` — **بدون أي تغيير في السيرفر** (`supabase/schema.sql` هو نفسه).
- نفس محرّك المزامنة: تخزين محلي أولًا ← سحب ← دمج عند التعارض ← رفع upsert.
- مفاتيح جديدة داخل نفس الجدول (لا تلمس مفاتيح دُرَر):
  `tyr_acc` الحسابات · `tyr_bud` الميزانيات · `tyr_tx` المعاملات · `tyr_loan` السلف · `tyr_goal` الأهداف · `tyr_cat` تصنيفات فرعية · `tyr_set` الإعدادات.
- الدمج بين جهازين على مستوى **السجل** (كل سجل له `u` = وقت آخر تعديل، الأحدث يفوز، والحذف ناعم `del`).

## التشغيل عبر GitHub
1. ارفع محتوى هذا المجلد كما هو إلى مستودع جديد (فرع `main`).
2. الـ workflow `.github/workflows/android-release.yml` يبني APK تلقائيًا ويضعه في Release باسم `latest`.
3. أسرار اختيارية (نفس أسماء دُرَر): `SUPABASE_ANON_KEY`, `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.
   (المفتاح العام publishable موجود افتراضيًا في `lib/core/config.dart`.)

## تسجيل الدخول بجوجل
معرّف الحزمة `com.werd.tayyar` ورابط العودة `com.werd.tayyar://auth`.
أضِف هذا الرابط في Supabase → Authentication → URL Configuration → Redirect URLs.
(الدخول بالبريد وكلمة المرور يعمل بدون هذه الخطوة.)
