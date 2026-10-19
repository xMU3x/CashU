# تيّار — تطبيق تتبّع المصاريف (Flutter)

نفس نظام بيانات «دُرَر» بالظبط:
- **مشروع Supabase الجديد** `https://suxjvfyraqpcxplpvqzz.supabase.co` وجدول المزامنة `cash_sync (user_id, key, value jsonb, ts bigint)`. شغّل `supabase/schema.sql` مرة واحدة في SQL Editor.
- **المفتاح العام** (publishable/anon) يُمرَّر وقت البناء: Secret باسم `SUPABASE_ANON_KEY` أو `--dart-define=SUPABASE_ANON_KEY=...`. لا مفتاح افتراضي.
- **الترحيل**: `supabase/migrate_werd_sync_to_cash_sync.sql` (نفس القاعدة). بين مشروعين: صدّر `werd_sync` من القديم (CSV) واستورده بعد مطابقة `user_id` بحسابات المشروع الجديد — معرّفات المستخدمين تختلف بين المشروعين. التطبيق نفسه يعيد رفع بياناته المحلية للمشروع الجديد تلقائيًا عند أول تسجيل دخول.
- محرّك المزامنة: تخزين محلي أولًا ← سحب ← دمج عند التعارض ← رفع upsert.
- مفاتيح جديدة داخل نفس الجدول (لا تلمس مفاتيح دُرَر):
  `tyr_acc` الحسابات · `tyr_bud` الميزانيات · `tyr_tx` المعاملات · `tyr_loan` السلف · `tyr_goal` الأهداف · `tyr_cat` تصنيفات فرعية · `tyr_set` الإعدادات.
- الدمج بين جهازين على مستوى **السجل** (كل سجل له `u` = وقت آخر تعديل، الأحدث يفوز، والحذف ناعم `del`).

## التشغيل عبر GitHub
1. ارفع محتوى هذا المجلد كما هو إلى مستودع جديد (فرع `main`).
2. الـ workflow `.github/workflows/android-release.yml` يبني APK تلقائيًا ويضعه في Release باسم `latest`.
3. أسرار اختيارية (نفس أسماء دُرَر): `SUPABASE_ANON_KEY`, `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.
   (المفتاح العام publishable موجود افتراضيًا في `lib/core/config.dart`.)

## تسجيل الدخول بجوجل
معرّف الحزمة `com.werd.cashu` ورابط العودة `com.werd.cashu://auth`.
أضِف هذا الرابط في Supabase → Authentication → URL Configuration → Redirect URLs.
(الدخول بالبريد وكلمة المرور يعمل بدون هذه الخطوة.)

## واجهة MoneyWiz (جديدة)
- شريط سفلي زجاجي بخمس تبويبات: Accounts · Budgets · Scheduled · Reports · Settings.
- شاشة الحسابات: مجموعات ملوّنة، صافي الثروة والالتزامات، سحب لليمين (Edit/Reorder/Archive/Delete) ولليسار (Income/Expense)، وضع الترتيب (Done).
- كشف الحساب: أقسام شهرية بشرائح (Balance / مصروف / دخل)، ضغطة مطوّلة (Edit/Delete/Pending/Scheduled/Refund)، سحب Duplicate.
- إضافة معاملة: مصروف · دخل · تحويل · تسوية رصيد (=)، و«Options» للسلف ونقل/مشاركة معاملة.
- تعديل الحساب: Basic/Advanced + Custom URL للأيقونة.
- حقول جديدة بالـ JSON (متوافقة مع الإصدارات القديمة): الحساب `grp,info,icon,nw,gb,ac,arch` — المعاملة `pay,pend` ونوع `adj`.
- الأرقام والتسميات بالإنجليزية وLTR مثل الصور.

## ملاحظة رفع الملفات (مهم)
المجلدات والملفات اللي بتبدأ بنقطة (`.github/` و `.gitignore`) **مخفية**، وبتتخطّى لما ترفع المشروع بالسحب والإفلات على موقع GitHub أو من بعض تطبيقات الملفات.
- لو الـ workflow ما ظهرش عندك: في المستودع اضغط **Add file → Create new file**، اكتب في خانة الاسم `.github/workflows/android-release.yml` ثم الصق محتوى `github_workflows/android-release.yml` واعمل Commit.
- نفس الشيء لـ `.gitignore` (محتواه في `gitignore.txt`).
- أو ارفع بـ git من الكمبيوتر (`git add -A`) فيرفع الملفات المخفية تلقائيًا.
