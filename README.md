# CashU — تطبيق تتبّع المصاريف (Flutter)

نظام بيانات CashU:
- **مشروع Supabase الجديد** `https://suxjvfyraqpcxplpvqzz.supabase.co` وجدول المزامنة `cash_sync (user_id, key, value jsonb, ts bigint)`. شغّل `supabase/schema.sql` مرة واحدة في SQL Editor.
- **المفتاح العام** (publishable/anon) يُمرَّر وقت البناء: Secret باسم `SUPABASE_ANON_KEY` أو `--dart-define=SUPABASE_ANON_KEY=...`. لا مفتاح افتراضي.
- **الترحيل**: `supabase/migrate_legacy_sync_to_cash_sync.sql` (نفس القاعدة). بين مشروعين: صدّر الجدول القديم (باسم `legacy_sync` بعد استيراده) من القديم (CSV) واستورده بعد مطابقة `user_id` بحسابات المشروع الجديد — معرّفات المستخدمين تختلف بين المشروعين. التطبيق نفسه يعيد رفع بياناته المحلية للمشروع الجديد تلقائيًا عند أول تسجيل دخول.
- محرّك المزامنة: تخزين محلي أولًا ← سحب ← دمج عند التعارض ← رفع upsert.
- مفاتيح جديدة داخل نفس الجدول (بادئة مفاتيح CashU: `cashu_`):
  `cashu_acc` الحسابات · `cashu_bud` الميزانيات · `cashu_tx` المعاملات · `cashu_loan` السلف · `cashu_goal` الأهداف · `cashu_cat` تصنيفات فرعية · `cashu_set` الإعدادات.
- الدمج بين جهازين على مستوى **السجل** (كل سجل له `u` = وقت آخر تعديل، الأحدث يفوز، والحذف ناعم `del`).

## التشغيل عبر GitHub
1. ارفع محتوى هذا المجلد كما هو إلى مستودع جديد (فرع `main`).
2. الـ workflow `.github/workflows/android-release.yml` يبني APK تلقائيًا ويضعه في Release باسم `latest`.
3. أسرار اختيارية: `SUPABASE_ANON_KEY`, `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.
   (المفتاح العام publishable موجود افتراضيًا في `lib/core/config.dart`.)

## تسجيل الدخول بجوجل
معرّف الحزمة `com.cashu.cashu` ورابط العودة `com.cashu.cashu://auth`.
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

## الاسم ومعرّف الحزمة
- اسم التطبيق: **CashU** · معرّف الحزمة: `com.cashu.cashu` · رابط العودة: `com.cashu.cashu://auth` (أضِفه في Supabase → Auth → URL Configuration).
- بادئة مفاتيح البيانات المحلية والمزامنة: `cashu:` / `cashu_*`. البيانات القديمة (بادئة `tyr`) بتتنقل تلقائيًا محليًا عند أول تشغيل، وللسيرفر شغّل آخر قسم في `supabase/migrate_legacy_sync_to_cash_sync.sql`.
- تغيير معرّف الحزمة يجعل النظام يعتبره تطبيقًا جديدًا: ثبّته بجانب القديم ولن يحدّثه.

## التوقيع الثابت (APK بنفس التوقيع في كل بناء)
الـ workflow يستخدم بالترتيب: (1) الأسرار `KEYSTORE_BASE64` / `KEYSTORE_PASSWORD` / `KEY_ALIAS` / `KEY_PASSWORD`، (2) أو يولّد مفتاحًا مرة واحدة ويحفظه تلقائيًا لو أضفت سر `SECRETS_BOOTSTRAP_TOKEN` (توكن بصلاحية Secrets: Read and write)، (3) وإلا مفتاح مؤقت مع تحذير.

## التنقل والحركة
- تبويبات حيّة (IndexedStack) بتلاشي Material 3 ومؤشر شريط سفلي متحرك، وانتقال Shared-axis بين الصفحات (دخول وخروج)، وحركة موحّدة للبانلات والحوارات.
- تذكيرات محلية (بدون إنترنت) قبل تجديد الاشتراك/القسط/الجمعية بمواعيدك، وبالضغط عليها يفتح التطبيق على الصفحة المناسبة.
