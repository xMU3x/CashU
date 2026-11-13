import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashu/ui/app_icons.dart';

/// يضمن إن قائمة الأيقونات في Dart متطابقة مع المانيفست (activity-alias) وكود Kotlin وأصول الأيقونات.
void main() {
  final manifest = File('android_overlay/AndroidManifest.xml').readAsStringSync();
  final kotlin = File('android_overlay/kotlin/MainActivity.kt').readAsStringSync();

  test('ten icons with unique ids', () {
    expect(kAppIcons.length, 10);
    expect(kAppIcons.map((e) => e.id).toSet().length, 10);
    expect(kAppIcons.first.id, 'navy'); // الأساسية
  });

  test('every icon has a manifest alias and Kotlin mapping', () {
    expect('<activity-alias'.allMatches(manifest).length, kAppIcons.length);
    for (final e in kAppIcons) {
      expect(kotlin.contains('"${e.id}" to "'), true, reason: 'Kotlin mapping missing for ${e.id}');
    }
    // المانيفست: navy مفعّلة افتراضيًا والباقي معطّل
    expect('android:enabled="true"'.allMatches(manifest).length, 1);
    expect(RegExp(r'android:enabled="false"').allMatches(manifest).length, kAppIcons.length - 1);
  });

  test('resources exist for each alternate icon', () {
    for (final e in kAppIcons.where((e) => e.id != 'navy')) {
      expect(File('android_overlay/res/mipmap-anydpi-v26/ic_launcher_${e.id}.xml').existsSync(), true, reason: e.id);
      expect(File('android_overlay/res/drawable/cashu_ic_fg_${e.id}.xml').existsSync(), true, reason: e.id);
      for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
        expect(File('android_overlay/res/mipmap-$d/ic_launcher_${e.id}.png').existsSync(), true, reason: '${e.id} $d');
      }
    }
  });
}
