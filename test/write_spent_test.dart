import 'package:flutter_test/flutter_test.dart';
import 'package:cashu/pages/more_pages.dart';

void main() {
  group('splitSpent', () {
    test('items joined by و', () {
      expect(splitSpent('500 اكل و 200 مواصلات و 100 قهوة'), ['500 اكل', '200 مواصلات', '100 قهوة']);
    });
    test('one item per line', () {
      expect(splitSpent('500 اكل\n200 مواصلات\nقهوة 100').length, 3);
    });
    test('ignores lines without numbers', () {
      expect(splitSpent('مصاريف النهارده\n50 قهوة'), ['50 قهوة']);
    });
  });
}
