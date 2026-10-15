#!/usr/bin/env bash
# يولّد مجلد android بواسطة أداة Flutter الحالية (لتتوافق إعدادات Gradle/AGP/Kotlin مع إصدار Flutter المثبّت)
# ثم يطبّق إعدادات التطبيق: معرّف الحزمة com.flousy.budget ومانيفست الأذونات ورابط تسجيل الدخول.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -d android ]; then
  flutter create --platforms=android --org com.flousy --project-name budget --no-pub .
fi

cp android_overlay/AndroidManifest.xml android/app/src/main/AndroidManifest.xml

# كود أندرويد الأصلي: MainActivity (قناة الرسائل) + SmsReceiver + SmsQueue
KT=android/app/src/main/kotlin/com/flousy/budget
mkdir -p "$KT"
rm -f android/app/src/main/java/com/flousy/budget/MainActivity.java 2>/dev/null || true
cp android_overlay/kotlin/*.kt "$KT"/
python3 tool/patch_gradle.py

# توحيد JVM 17 لكل الوحدات (يُحمَّل تلقائيًا من GRADLE_USER_HOME/init.d)
GH="${GRADLE_USER_HOME:-$HOME/.gradle}/init.d"
mkdir -p "$GH"
cp tool/gradle-jvm17.init.gradle "$GH/flousy-jvm17.gradle"
echo "installed init script -> $GH/flousy-jvm17.gradle"

APPID=$(grep -R "applicationId" android/app/build.gradle* | head -1 || true)
echo "$APPID"
echo "$APPID" | grep -q "com.flousy.budget" || { echo "معرّف الحزمة غير مطابق (المتوقع com.flousy.budget)"; exit 1; }
