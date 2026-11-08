#!/usr/bin/env bash
# يولّد مجلد android بأداة Flutter الحالية ثم يطبّق إعدادات CashU:
# المعرّف (من tool/APP_ID) + المانيفست + كود Kotlin للرسائل + JVM 17 + (اختياري) Firebase Crashlytics.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_ID="$(tr -d '[:space:]' < tool/APP_ID)"
echo "$APP_ID" | grep -Eq '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$' || { echo "tool/APP_ID غير صالح: '$APP_ID'"; exit 1; }
export APP_ID

if [ ! -d android ]; then
  flutter create --platforms=android --org com.cashu --project-name cashu --no-pub .
fi

# Flutter may generate its stock widget_test.dart, which refers to MyApp.
# This project uses CashUApp and already has its own tests.
if [ -f test/widget_test.dart ] && grep -q "MyApp" test/widget_test.dart; then
  rm -f test/widget_test.dart
  echo "Removed generated Flutter template test referencing MyApp"
fi

# المانيفست: نستبدل الـ placeholder بالمعرّف الحقيقي (رابط العودة بعد تسجيل الدخول).
sed "s/__APP_ID__/$APP_ID/g" android_overlay/AndroidManifest.xml > android/app/src/main/AndroidManifest.xml
grep -q 'android:label="CashU"' android/app/src/main/AndroidManifest.xml || { echo "اسم التطبيق في المانيفست غير CashU"; exit 1; }
grep -q '__APP_ID__' android/app/src/main/AndroidManifest.xml && { echo "placeholder __APP_ID__ لم يُستبدل"; exit 1; }

# Firebase (اختياري): الملف يأتي من سر CI أو يوضع يدويًا في android/app/google-services.json — لا يُرفع للريبو.
if [ -n "${GOOGLE_SERVICES_JSON_BASE64:-}" ]; then
  echo "$GOOGLE_SERVICES_JSON_BASE64" | base64 -d > android/app/google-services.json
  echo "google-services.json written from CI secret"
fi

python3 tool/patch_gradle.py

GH="${GRADLE_USER_HOME:-$HOME/.gradle}/init.d"
mkdir -p "$GH"
cp tool/gradle-jvm17.init.gradle "$GH/cashu-jvm17.gradle"

grep -R "applicationId" android/app/build.gradle* | head -1
grep -R "applicationId" android/app/build.gradle* | head -1 | grep -q "\"$APP_ID\"" || { echo "معرّف الحزمة غير مطابق (المتوقع $APP_ID)"; exit 1; }

# كود Android الخاص بتتبع رسائل البنك (يستبدل MainActivity ويضيف المستقبِل والطابور).
# نمسح MainActivity المولّد تلقائيًا (حزمة مختلفة) كي لا يبقى كود يتيم.
rm -rf android/app/src/main/kotlin android/app/src/main/java
KDIR="android/app/src/main/kotlin/$(echo "$APP_ID" | tr . /)"
mkdir -p "$KDIR"
for f in android_overlay/kotlin/*.kt; do
  sed "s/__PKG__/$APP_ID/g" "$f" > "$KDIR/$(basename "$f")"
done
echo "Kotlin SMS sources installed in $KDIR"
