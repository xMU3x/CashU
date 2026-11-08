# ربط Firebase (Crashlytics) بمشروع CashU

الحالي: **Crashlytics فقط** (تقارير الأعطال). مفيش Firebase Auth ولا Firestore — الحساب والمزامنة على Supabase.
التفعيل **اختياري** ومقفول افتراضيًا: لا يُرسل شيء إلا لو المستخدم فعّل «تقارير الأعطال» من الإعدادات.

## الخطوات
1. https://console.firebase.google.com → **Add project** (Analytics ممكن تقفله).
2. داخل المشروع → **Add app → Android**:
   - Android package name = محتوى `tool/APP_ID` (حاليًا `com.cashu.app`).
   - Register app → نزّل **google-services.json**.
3. فعّل Crashlytics: Build → **Crashlytics** → Enable.
4. **للبناء على GitHub (الموصى به):**
   ```bash
   gh secret set GOOGLE_SERVICES_JSON_BASE64 --body "$(base64 -w 0 google-services.json)"
   ```
   السكربت `tool/setup_android.sh` بيفك السر لـ `android/app/google-services.json` وبيطبّق plugins (`google-services` و`crashlytics`) تلقائيًا.
5. **بناء محلي:** `bash tool/setup_android.sh` أولًا، ثم ضع الملف في `android/app/google-services.json`، وأعد تشغيل `python3 tool/patch_gradle.py` (مع `APP_ID`)، ثم `flutter build apk`.
6. بدون الملف: البناء بينجح والتطبيق يشتغل عادي (الإعداد بيظهر «غير مفعّل في هذه النسخة»).

## ملاحظات
- لا تضف `google-services.json` للريبو (مضاف في `.gitignore`).
- تقارير الأعطال بتتعطّل في وضع debug.
- `flutterfire configure` **غير مطلوب** لأن Android بس وبنستخدم plugin Gradle. لو أضفت iOS لاحقًا استخدمه (`dart pub global activate flutterfire_cli && flutterfire configure`).
- لو حابب Sentry بدل Crashlytics: التغيير في `lib/core/crash.dart` فقط.
