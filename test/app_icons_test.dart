import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashu/ui/app_icons.dart';

/// يضمن إن قائمة الأيقونات في Dart متطابقة مع المانيفست (activity-alias) وكود Kotlin وأصول الأيقونات.
void main() {
  final manifest = File('android_overlay/AndroidManifest.xml').readAsStringSync();
  final kotlin = File('android_overlay/kotlin/MainActivity.kt').readAsStringSync();

  String aliasOf(String id) {
    final m = RegExp('"$id" to "(\\w+)"').firstMatch(kotlin);
    expect(m, isNotNull, reason: 'Kotlin mapping missing for $id');
    return m!.group(1)!;
  }

  test('ten icons with unique ids and black as the primary', () {
    expect(kAppIcons.length, 10);
    expect(kAppIcons.map((e) => e.id).toSet().length, 10);
    expect(kPrimaryAppIconId, 'black');
    expect(kAppIcons.any((e) => e.id == kPrimaryAppIconId), true);
    expect(appIconById('unknown-id').id, kPrimaryAppIconId); // أي معرّف غريب يرجع للأساسية
    expect(AppIconService.selected.value, kPrimaryAppIconId);
  });

  test('every icon has a manifest alias with its own mipmap and a Kotlin mapping', () {
    expect('<activity-alias'.allMatches(manifest).length, kAppIcons.length);
    for (final e in kAppIcons) {
      final alias = aliasOf(e.id);
      final block = RegExp('<activity-alias[^>]*android:name="\\.$alias"[^>]*>', dotAll: true).firstMatch(manifest);
      expect(block, isNotNull, reason: 'manifest alias missing for ${e.id} (.$alias)');
      expect(block!.group(0)!.contains('@mipmap/ic_launcher_${e.id}"'), true, reason: 'wrong icon on alias ${e.id}');
    }
  });

  test('manifest enables only the primary alias; Kotlin default matches', () {
    expect('android:enabled="true"'.allMatches(manifest).length, 1);
    expect(RegExp(r'android:enabled="false"').allMatches(manifest).length, kAppIcons.length - 1);
    final primaryAlias = aliasOf(kPrimaryAppIconId);
    final primary = RegExp('<activity-alias[^>]*android:name="\\.$primaryAlias"[^>]*>', dotAll: true).firstMatch(manifest)!.group(0)!;
    expect(primary.contains('android:enabled="true"'), true);
    expect(kotlin.contains('DEFAULT_ICON = "$kPrimaryAppIconId"'), true);
  });

  test('Kotlin verifies the switch and no longer uses the Flutter-reserved "route" extra for writing', () {
    expect(kotlin.contains('verify failed'), true);
    expect(kotlin.contains('putExtra(ROUTE_EXTRA, route)'), true);
    expect(kotlin.contains('putExtra("route"'), false);
  });

  test('default launcher icon assets exist', () {
    for (final f in ['app_icon.png', 'app_icon_bg.png', 'app_icon_fg.png', 'app_icon_mono.png']) {
      expect(File('assets/brand/$f').existsSync(), true, reason: f);
    }
    expect(File('android_overlay/res/drawable-nodpi/cashu_ic_mono.png').existsSync(), true);
  });

  test('resources exist for each icon', () {
    for (final e in kAppIcons) {
      expect(File('android_overlay/res/mipmap-anydpi-v26/ic_launcher_${e.id}.xml').existsSync(), true, reason: e.id);
      expect(File('android_overlay/res/drawable-nodpi/cashu_ic_bg_${e.id}.png').existsSync(), true, reason: e.id);
      expect(File('android_overlay/res/drawable-nodpi/cashu_ic_fg_${e.id}.png').existsSync(), true, reason: e.id);
      for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
        expect(File('android_overlay/res/mipmap-$d/ic_launcher_${e.id}.png').existsSync(), true, reason: '${e.id} $d');
      }
    }
  });
}
