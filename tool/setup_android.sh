#!/usr/bin/env bash
# يولّد مجلد android بأداة Flutter الحالية ثم يطبّق إعدادات التطبيق (المعرّف com.cashu.cashu + المانيفست + كود Kotlin للرسائل + JVM 17)
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -d android ]; then
  flutter create --platforms=android --org com.cashu --project-name cashu --no-pub .
fi
# Flutter may generate its stock widget_test.dart, which refers to MyApp.
# This project uses CashUApp and already has its own calc tests.
if [ -f test/widget_test.dart ] && grep -q "MyApp" test/widget_test.dart; then
  rm -f test/widget_test.dart
  echo "Removed generated Flutter template test referencing MyApp"
fi
cp android_overlay/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
python3 tool/patch_gradle.py
GH="${GRADLE_USER_HOME:-$HOME/.gradle}/init.d"
mkdir -p "$GH"
cp tool/gradle-jvm17.init.gradle "$GH/cashu-jvm17.gradle"
APPID=$(grep -R "applicationId" android/app/build.gradle* | head -1 || true)
echo "$APPID"
echo "$APPID" | grep -q "com.cashu.cashu" || { echo "معرّف الحزمة غير مطابق (المتوقع com.cashu.cashu)"; exit 1; }

# كود Android الخاص بتتبع رسائل البنك (يستبدل MainActivity ويضيف المستقبِل والطابور)
PKG="com.cashu.cashu"
KDIR="android/app/src/main/kotlin/$(echo "$PKG" | tr . /)"
mkdir -p "$KDIR"
for f in android_overlay/kotlin/*.kt; do
  sed "s/__PKG__/$PKG/g" "$f" > "$KDIR/$(basename "$f")"
done
echo "Kotlin SMS sources installed in $KDIR"
