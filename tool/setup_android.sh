#!/usr/bin/env bash
# يولّد مجلد android بأداة Flutter الحالية ثم يطبّق إعدادات CashU (المعرّف com.cashu.cashu + المانيفست + كود Kotlin لتتبع الرسائل + JVM 17)
set -euo pipefail
cd "$(dirname "$0")/.."
PKG=com.cashu.cashu
if [ ! -d android ]; then
  flutter create --platforms=android --org com.cashu --project-name cashu --no-pub .
fi
if [ -f test/widget_test.dart ] && grep -q "MyApp" test/widget_test.dart; then
  rm -f test/widget_test.dart
  echo "Removed generated Flutter template test referencing MyApp"
fi
cp android_overlay/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
# كود Kotlin الخاص بتتبع رسائل البنك (يستبدل MainActivity المولَّد)
KDIR=android/app/src/main/kotlin/$(echo "$PKG" | tr . /)
mkdir -p "$KDIR"
find android/app/src/main -name 'MainActivity.*' -delete
for f in MainActivity SmsEngine SmsReceiver; do
  sed "s/__PKG__/$PKG/g" "android_overlay/kotlin/$f.kt" > "$KDIR/$f.kt"
done
python3 tool/patch_gradle.py
GH="${GRADLE_USER_HOME:-$HOME/.gradle}/init.d"
mkdir -p "$GH"
cp tool/gradle-jvm17.init.gradle "$GH/cashu-jvm17.gradle"
APPID=$(grep -R "applicationId" android/app/build.gradle* | head -1 || true)
echo "$APPID"
echo "$APPID" | grep -q "$PKG" || { echo "معرّف الحزمة غير مطابق (المتوقع $PKG)"; exit 1; }
