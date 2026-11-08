import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashu/core/config.dart';

/// يضمن إن معرّف الحزمة واحد في كل مكان، وإن مفيش أثر لأسماء المشاريع القديمة.
void main() {
  final appId = File('tool/APP_ID').readAsStringSync().trim();

  test('tool/APP_ID is a valid, CashU-based package id', () {
    expect(RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$').hasMatch(appId), isTrue);
    expect(appId.contains('cashu'), isTrue);
  });

  test('auth redirect scheme matches APP_ID', () {
    expect(kNativeRedirect, '$appId://auth');
  });

  test('manifest uses the APP_ID placeholder, not a hardcoded id', () {
    final m = File('android_overlay/AndroidManifest.xml').readAsStringSync();
    expect(m.contains('android:scheme="__APP_ID__"'), isTrue);
  });

  test('no legacy project names outside the historical SQL migration', () {
    final legacy = RegExp('flousy|werd', caseSensitive: false);
    final roots = ['lib', 'test', 'tool', 'android_overlay', '.github', 'docs', 'pubspec.yaml'];
    final bad = <String>[];
    for (final r in roots) {
      final t = FileSystemEntity.typeSync(r);
      final files = t == FileSystemEntityType.directory
          ? Directory(r).listSync(recursive: true).whereType<File>()
          : (t == FileSystemEntityType.file ? [File(r)] : <File>[]);
      for (final f in files) {
        final n = f.path.replaceAll('\\', '/');
        if (n.endsWith('test/app_id_test.dart')) continue;
        if (!RegExp(r'\.(dart|yml|yaml|sh|py|kt|xml|md|gradle|txt)$').hasMatch(n) && !n.endsWith('APP_ID')) continue;
        if (legacy.hasMatch(f.readAsStringSync())) bad.add(n);
      }
    }
    expect(bad, isEmpty);
  });
}
