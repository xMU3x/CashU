# إعداد الـ CI والـ Release (مرة واحدة)

## 1) الملفات
- `ci.yml` — format · analyze · test · build على كل PR وكل push لغير `main`.
- `android-release.yml` — على كل push في `main`: يستدعي `ci.yml` أولًا، وبعدها بناء + توقيع + Release باسم `vMAJOR.MINOR.N`.
- `format.yml` — تشغيل يدوي لتنسيق الكود (`dart format lib test`) وعمل commit.
- معرّف الحزمة في مكان واحد: `tool/APP_ID`.

## 2) مفتاح التوقيع (يدوي — مرة واحدة فقط)
> الـ workflow القديم كان بيولّد المفتاح ويحفظه في الأسرار عن طريق توكن (`SECRETS_BOOTSTRAP_TOKEN`). اتشال خلاص. المفتاح لازم يتعمل يدويًا ويتحفظ في مكان آمن (نسخة خارج GitHub كمان).

```bash
keytool -genkeypair -keystore release.jks -alias cashu \
  -keyalg RSA -keysize 3072 -validity 10000 \
  -dname "CN=CashU,O=CashU,C=EG"
```

> لو عندك بالفعل أسرار `KEYSTORE_BASE64` و`KEYSTORE_PASSWORD` و`KEY_ALIAS` و`KEY_PASSWORD` من التشغيلات القديمة، **سيبها زي ما هي** وماتولّدش مفتاح جديد؛ المفتاح الجديد = توقيع مختلف = مفيش تحديث فوق النسخ المثبتة.

إضافة الأسرار (من جهازك، بعد `gh auth login`):
```bash
gh secret set KEYSTORE_BASE64 --body "$(base64 -w 0 release.jks)"
gh secret set KEYSTORE_PASSWORD
gh secret set KEY_ALIAS --body "cashu"
gh secret set KEY_PASSWORD
```
أو من: Repo → Settings → Secrets and variables → Actions.

## 3) متغيّرات Supabase (Variables وليست Secrets)
`SUPABASE_URL` و`SUPABASE_ANON_KEY` (المفتاح العام publishable/anon فقط — **ممنوع** service_role).

## 4) شيل التوكن القديم
- GitHub → Settings → Developer settings → Personal access tokens → احذف التوكن المستخدم في `SECRETS_BOOTSTRAP_TOKEN`.
- Repo → Settings → Secrets → احذف `SECRETS_BOOTSTRAP_TOKEN`.

## 5) معرّف الحزمة الجديد (مهم)
المعرّف الحالي في `tool/APP_ID`. تغييره عن المعرّف القديم معناه إن التطبيق بيتثبّت **كتطبيق منفصل** ومش بيحدّث القديم، والبيانات المحلية القديمة مش بتنتقل تلقائيًا.
قبل ما تنتقل: سجّل دخول في النسخة القديمة وخلّي المزامنة تخلص. **تنبيه:** «الأصول» مخزّنة محليًا فقط (مش داخل المزامنة) — صدّرها أو سجّلها يدويًا قبل حذف القديم.
وفي Supabase → Authentication → URL Configuration → Redirect URLs أضف: `com.cashu.app://auth` (أو قيمة `tool/APP_ID` + `://auth` لو غيّرتها).

## 6) منع الدمج عند فشل الـ CI (Branch protection)
Repo → Settings → Branches → Add rule على `main`:
- ✅ Require a pull request before merging
- ✅ Require status checks to pass → اختر **verify (format · analyze · test · build)**
- (اختياري) ✅ Do not allow bypassing

## 7) التسمية والإصدارات
- Tag/Release: `v1.0.N` (N = رقم تشغيل الـ workflow). غيّر `1.0` من `pubspec.yaml` (`version: 1.1.0+1` → `v1.1.N`).
- `versionCode` = `1000 + N`.
- أحدث 10 إصدارات (بصيغة `vX.Y.Z` فقط) محفوظة، والأقدم بيتحذف تلقائيًا مع الـ tag.
- كل Release فيه: `CashU-<ver>.apk` و`CashU-<ver>.apk.sha256`.
- الإصدار «latest» القديم (pre-release) ممكن تحذفه يدويًا من صفحة Releases.

## 8) تشغيل أول مرة
1. ارفع محتويات المشروع (الملفات في جذر الريبو، مش داخل مجلد).
2. على branch جانبي شغّل **CashU Format** مرة، ثم افتح PR.
3. لو CI فشل: انسخ سجل الخطأ كما هو وابعته.
