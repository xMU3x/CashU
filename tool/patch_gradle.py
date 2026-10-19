#!/usr/bin/env python3
"""يفعّل core library desugaring في مشروع android المُولَّد. توحيد JVM 17 يتم عبر tool/gradle-jvm17.init.gradle."""
import pathlib
import re
import sys

app = pathlib.Path("android/app")
kts, groovy = app / "build.gradle.kts", app / "build.gradle"
DESUGAR = "2.1.4"
APP_ID = "com.cashu.cashu"

if kts.exists():
    f = kts
    s = f.read_text(encoding="utf8")
    if "isCoreLibraryDesugaringEnabled" not in s:
        s, n = re.subn(r"(compileOptions\s*\{)", r"\1\n        isCoreLibraryDesugaringEnabled = true", s, count=1)
        if n != 1:
            sys.exit("patch_gradle: compileOptions غير موجود في build.gradle.kts")
    if "coreLibraryDesugaring(" not in s:
        s += f'\ndependencies {{\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:{DESUGAR}")\n}}\n'
elif groovy.exists():
    f = groovy
    s = f.read_text(encoding="utf8")
    if "coreLibraryDesugaringEnabled" not in s:
        s, n = re.subn(r"(compileOptions\s*\{)", r"\1\n        coreLibraryDesugaringEnabled true", s, count=1)
        if n != 1:
            sys.exit("patch_gradle: compileOptions غير موجود في build.gradle")
    if "coreLibraryDesugaring '" not in s:
        s += f"\ndependencies {{\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:{DESUGAR}'\n}}\n"
else:
    sys.exit("patch_gradle: لم يُعثر على android/app/build.gradle(.kts) — شغّل tool/setup_android.sh أولًا")

# R8 يكسر تسلسل Gson داخل flutter_local_notifications فلا تعمل الإشعارات المجدولة في نسخة release
if "isMinifyEnabled" not in s and "minifyEnabled" not in s:
    if f.suffix == ".kts":
        s = re.sub(r"(buildTypes\s*\{\s*(?:getByName\(\"release\"\)|release)\s*\{)", r"\1\n            isMinifyEnabled = false\n            isShrinkResources = false", s, count=1)
    else:
        s = re.sub(r"(buildTypes\s*\{\s*release\s*\{)", r"\1\n            minifyEnabled false\n            shrinkResources false", s, count=1)

# تثبيت معرّف التطبيق والـ namespace صراحةً (com.cashu.cashu) حتى لو تغيّر قالب flutter create
if f.suffix == ".kts":
    s = re.sub(r'namespace\s*=\s*"[^"]*"', f'namespace = "{APP_ID}"', s)
    s = re.sub(r'applicationId\s*=\s*"[^"]*"', f'applicationId = "{APP_ID}"', s)
else:
    s = re.sub(r'namespace\s*=?\s*["\'][^"\']*["\']', f'namespace "{APP_ID}"', s)
    s = re.sub(r'applicationId\s*=?\s*["\'][^"\']*["\']', f'applicationId "{APP_ID}"', s)

f.write_text(s, encoding="utf8")

print(f"patched {f} (desugaring + applicationId/namespace = {APP_ID})")
