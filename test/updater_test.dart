import 'package:flutter_test/flutter_test.dart';
import 'package:cashu/core/updater.dart';

void main() {
  test('version compare', () {
    expect(isNewerVersion('v1.0.12', '1.0.9'), true);
    expect(isNewerVersion('v1.0.9', '1.0.9'), false);
    expect(isNewerVersion('1.0.8', '1.0.9'), false);
    expect(isNewerVersion('v1.1.0', '1.0.99'), true);
    expect(isNewerVersion('2.0', '1.9.9'), true);
  });
}
