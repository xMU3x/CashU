#!/usr/bin/env bash
# يولّد مجلد android بأداة Flutter الحالية ثم يطبّق إعدادات التطبيق (المعرّف com.werd.tayyar + المانيفست + JVM 17)
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -d android ]; then
  flutter create --platforms=android --org com.werd --project-name tayyar --no-pub .
fi
cp android_overlay/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
python3 tool/patch_gradle.py
GH="${GRADLE_USER_HOME:-$HOME/.gradle}/init.d"
mkdir -p "$GH"
cp tool/gradle-jvm17.init.gradle "$GH/tayyar-jvm17.gradle"
APPID=$(grep -R "applicationId" android/app/build.gradle* | head -1 || true)
echo "$APPID"
echo "$APPID" | grep -q "com.werd.tayyar" || { echo "معرّف الحزمة غير مطابق (المتوقع com.werd.tayyar)"; exit 1; }
