# فلوسي — تطبيق ميزانية Flutter أصلي

بنفس هيكل تطبيق دُرَر: **تخزين محلي أولًا** + **مزامنة Supabase** (دخول بجوجل أو بريد) + **GitHub Actions** يبني APK موقّع تلقائيًا.
التطبيق شغّال كامل من غير حساب، والمزامنة اختيارية.

## الميزات (المرحلة 1)
- حسابات متعددة (بنكي/نقدي) بميزانية لكل حساب.
- معاملات: مصروف، دخل، تحويل بين حسابات، سلف.
- الرئيسية (كارت الميزانية + المتاح يوميًا) والإحصائيات (تصنيفات + 6 شهور).
- وضع فاتح/داكن/تلقائي، اهتزاز، RTL، خط IBM Plex Arabic مضمّن.

## الإعداد (مرة واحدة)

### 1) Supabase
1. أنشئ مشروع (أو استخدم نفس مشروع دُرَر) وشغّل `supabase/schema.sql` في SQL Editor.
2. **Authentication → Providers → Google**: فعّله وحط Client ID/Secret من Google Cloud (OAuth Web client، وعنوان الـ callback من Supabase).
3. **Authentication → URL Configuration → Redirect URLs**: ضيف `com.flousy.budget://auth`
4. من **Project Settings → API** خد `Project URL` و `anon / publishable key`.

### 2) مفتاح التوقيع (يفضل ثابت عشان التحديثات تنزل فوق بعض)
```bash
keytool -genkeypair -keystore release.jks -alias flousy -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 release.jks    # على ماك: base64 -i release.jks
```

### 3) GitHub → Settings → Secrets and variables → Actions
| السر | مطلوب؟ |
|---|---|
| `SUPABASE_URL` | نعم |
| `SUPABASE_ANON_KEY` | نعم |
| `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` | موصى به |

### 4) ارفع على GitHub
```bash
git init && git add . && git commit -m "init"
git branch -M main
git remote add origin https://github.com/USERNAME/REPO.git
git push -u origin main
```
بعد الـ push: تبويب **Actions** يبني الـ APK، وبعدها تلاقيه في **Releases → latest** (رابط تحميل دائم).

## بناء محلي
```bash
bash tool/setup_android.sh
flutter pub get && dart run flutter_launcher_icons
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## تفاصيل تقنية
- البيانات مخزّنة كسجلات `id → {..., u: وقت التعديل}`؛ الدمج بين الأجهزة: الأحدث يكسب، والحذف علامة `d` بتتزامن.
- لو جهاز اتسجّل عليه حساب تاني، بياناته المحلية بتتمسح قبل سحب بيانات الحساب الجديد (خصوصية).
- السلف: «ليّا فلوس» تنقص رصيد الحساب، «عليّا فلوس» تزوّده، ومش بتتحسب دخل/مصروف.
- العملة: جنيه فقط حاليًا.
