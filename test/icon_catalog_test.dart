import 'package:flutter_test/flutter_test.dart';
import 'package:cashu/core/cat_icons.dart';
import 'package:cashu/core/fixed_icons.dart';
import 'package:cashu/core/icon_catalog.dart';

void main() {
  test('كل أيقونات المكتبة بتتحلّ بالمفتاح وبتدعم الاستخدام كأيقونة ثابتة وكتصنيف', () {
    expect(kIconSections.length, greaterThanOrEqualTo(10));
    for (final s in kIconSections) {
      expect(s.items.length, greaterThanOrEqualTo(10), reason: s.title);
      for (final e in s.items) {
        expect(e.key.startsWith('g_'), isTrue);
        expect(catalogIcon(e.key), isNotNull);
        expect(catIconByKey(e.key), isNotNull);
        expect(fixedIconOf('$kFixedPrefix${e.key}'), isNotNull);
      }
    }
  });

  test('المفاتيح القديمة لسه شغالة', () {
    expect(catIconByKey('cart'), isNotNull);
    expect(fixedIconOf('${kFixedPrefix}phone'), isNotNull);
  });
}
