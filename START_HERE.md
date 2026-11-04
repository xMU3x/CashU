# CashU (Kotlin Native) — الترتيب المظبوط للرفع

## قبل ما ترفع (مرة واحدة)
1. Settings → Secrets and variables → Actions → تأكد من وجود:
   - `SUPABASE_ANON_KEY` (مطلوب للمزامنة)
   - `KEYSTORE_BASE64` · `KEYSTORE_PASSWORD` · `KEY_ALIAS` · `KEY_PASSWORD` — **نفس الـKeystore اللي بتبني بيه نسخة Flutter**.
     لو ما اتضبطوش، الـAPK بيتوقّع بمفتاح مؤقت ومش هيتثبّت فوق نسخة Flutter الحالية (هيطلب حذفها = ضياع بياناتها المحلية).

## الرفع
2. ارفع محتوى المجلد كله على المستودع (Commit عادي — بدون Force).
3. افتح `.github/workflows/GITHUB_WORKFLOW.yml` في GitHub وتأكد إن أول سطر فيه `name: Build CashU (Kotlin Native)`.
   لو لسه `Flousy`: اضغط القلم → احذف الكل → الصق محتوى الملف `GITHUB_WORKFLOW.yml` المرفق معاك → Commit.
4. Actions → «Build CashU (Kotlin Native)» → هيشتغل تلقائيًا بعد الـpush (أو Run workflow).
5. بعد النجاح: Artifacts → `CashU` (APK + AAB) و`reports` (تقارير الاختبارات/Lint).

## التثبيت
6. ثبّت الـAPK **فوق** نسخة Flutter (نفس التوقيع) → التطبيق ينقل بياناتك تلقائيًا أول تشغيل.
7. سجّل الدخول من تبويب «حسابي» → المزامنة تسحب بياناتك من Supabase وتدمجها.

## لو ظهر خطأ
أرسل لي صورة/نص أول خطأ أحمر من سجل الخطوة الفاشلة (Unit tests / Lint / Assemble).
