#!/usr/bin/env python3
"""يطبّق إعدادات CashU على مشروع android المُولَّد:
  1) core library desugaring + تعطيل R8 (الإشعارات المجدولة).
  2) applicationId و namespace من متغيّر APP_ID (المصدر: tool/APP_ID).
  3) Firebase Crashlytics — فقط لو android/app/google-services.json موجود (وإلا يُتخطّى والتطبيق يعمل بدونه).
توحيد JVM 17 يتم عبر tool/gradle-jvm17.init.gradle."""
import os
import pathlib
import re
import sys

android = pathlib.Path("android")
app = android / "app"
kts, groovy = app / "build.gradle.kts", app / "build.gradle"
DESUGAR = "2.1.4"
GMS_PLUGIN = "4.4.2"  # com.google.gms.google-services
CRASH_PLUGIN = "3.0.2"  # com.google.firebase.crashlytics

APP_ID = os.environ.get("APP_ID", "").strip()
if not APP_ID:
    sys.exit("patch_gradle: متغيّر APP_ID مطلوب (شغّل tool/setup_android.sh)")

if kts.exists():
    f, is_kts = kts, True
elif groovy.exists():
    f, is_kts = groovy, False
else:
    sys.exit("patch_gradle: لم يُعثر على android/app/build.gradle(.kts) — شغّل tool/setup_android.sh أولًا")

s = f.read_text(encoding="utf8")

# ───────── 1) desugaring + R8 ─────────
if is_kts:
    if "isCoreLibraryDesugaringEnabled" not in s:
        s, n = re.subn(r"(compileOptions\s*\{)", r"\1\n        isCoreLibraryDesugaringEnabled = true", s, count=1)
        if n != 1:
            sys.exit("patch_gradle: compileOptions غير موجود في build.gradle.kts")
    if "coreLibraryDesugaring(" not in s:
        s += f'\ndependencies {{\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:{DESUGAR}")\n}}\n'
else:
    if "coreLibraryDesugaringEnabled" not in s:
        s, n = re.subn(r"(compileOptions\s*\{)", r"\1\n        coreLibraryDesugaringEnabled true", s, count=1)
        if n != 1:
            sys.exit("patch_gradle: compileOptions غير موجود في build.gradle")
    if "coreLibraryDesugaring '" not in s:
        s += f"\ndependencies {{\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:{DESUGAR}'\n}}\n"

# R8 يكسر تسلسل Gson داخل flutter_local_notifications فلا تعمل الإشعارات المجدولة في نسخة release
if "isMinifyEnabled" not in s and "minifyEnabled" not in s:
    if is_kts:
        s = re.sub(r"(buildTypes\s*\{\s*(?:getByName\(\"release\"\)|release)\s*\{)", r"\1\n            isMinifyEnabled = false\n            isShrinkResources = false", s, count=1)
    else:
        s = re.sub(r"(buildTypes\s*\{\s*release\s*\{)", r"\1\n            minifyEnabled false\n            shrinkResources false", s, count=1)

# ───────── 2) applicationId / namespace ─────────
def set_id(text: str, key: str) -> str:
    pat = re.compile(rf'(\b{key}\s*=?\s*)"[^"]*"')
    if not pat.search(text):
        sys.exit(f"patch_gradle: لم يُعثر على {key} في {f.name}")
    return pat.sub(lambda m: f'{m.group(1)}"{APP_ID}"', text, count=1)

s = set_id(s, "namespace")
s = set_id(s, "applicationId")

# ───────── 3) Firebase Crashlytics (اختياري) ─────────
def add_plugin_after_android_app(text: str, path: pathlib.Path, ids, with_version: bool) -> str:
    """يضيف سطور plugins بعد سطر com.android.application بنفس الإزاحة والأسلوب."""
    pat = re.compile(r'^([ \t]*)id\s*\(?\s*"com\.android\.application"\s*\)?[^\n]*$', re.M)
    m = pat.search(text)
    if not m:
        sys.exit(f"patch_gradle: لم يُعثر على plugin com.android.application في {path} — قالب Gradle قديم؟ ثبّت Firebase يدويًا (docs/FIREBASE_SETUP.md)")
    indent, kts_style = m.group(1), "(" in m.group(0)
    lines = []
    for pid, ver in ids:
        if pid in text:
            continue
        if kts_style:
            ln = f'{indent}id("{pid}")' + (f' version "{ver}" apply false' if with_version else "")
        else:
            ln = f'{indent}id "{pid}"' + (f' version "{ver}" apply false' if with_version else "")
        lines.append(ln)
    if not lines:
        return text
    return text[: m.end()] + "\n" + "\n".join(lines) + text[m.end():]

gs = app / "google-services.json"
firebase = gs.exists()
if firebase:
    settings = next((p for p in (android / "settings.gradle.kts", android / "settings.gradle") if p.exists()), None)
    if settings is None:
        sys.exit("patch_gradle: android/settings.gradle(.kts) غير موجود")
    st = settings.read_text(encoding="utf8")
    st = add_plugin_after_android_app(st, settings, [("com.google.gms.google-services", GMS_PLUGIN), ("com.google.firebase.crashlytics", CRASH_PLUGIN)], True)
    settings.write_text(st, encoding="utf8")
    s = add_plugin_after_android_app(s, f, [("com.google.gms.google-services", None), ("com.google.firebase.crashlytics", None)], False)
    print("Firebase: google-services + crashlytics plugins applied")
else:
    print("Firebase: android/app/google-services.json غير موجود — تخطّي (التطبيق يعمل بدون Crashlytics)")

f.write_text(s, encoding="utf8")
print(f"patched {f}")
