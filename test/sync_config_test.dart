import 'package:flutter_test/flutter_test.dart';
import 'package:cashu/core/config.dart';
import 'package:cashu/core/merge.dart';

void main() {
  test('config points to new project and cash_sync', () {
    expect(kSupabaseUrl, 'https://suxjvfyraqpcxplpvqzz.supabase.co');
    expect(kSyncTable, 'cash_sync');
  });

  group('keyLooksValid', () {
    test('publishable ok', () => expect(keyLooksValid('sb_publishable_abcdefghijklmnopqrstuvwxyz0123'), isTrue));
    test('empty rejected', () => expect(keyLooksValid(''), isFalse));
    test('secret rejected', () => expect(keyLooksValid('sb_secret_abcdefghijklmnopqrstuvwxyz0123'), isFalse));
    test('garbage rejected', () => expect(keyLooksValid('hello'), isFalse));
  });

  group('mergeFlow CRUD (no data loss)', () {
    Map<String, dynamic> r(String id, int u, {bool del = false, num amt = 1}) => {'id': id, 'u': u, 'del': del, 'amt': amt};
    test('create: union of both sides', () {
      final m = mergeFlow({'a': r('a', 1)}, {'b': r('b', 2)}) as Map;
      expect(m.keys.toSet(), {'a', 'b'});
    });
    test('update: newer wins', () {
      final m = mergeFlow({'a': r('a', 1, amt: 5)}, {'a': r('a', 2, amt: 9)}) as Map;
      expect(m['a']['amt'], 9);
    });
    test('update: older remote does not overwrite', () {
      final m = mergeFlow({'a': r('a', 5, amt: 5)}, {'a': r('a', 2, amt: 9)}) as Map;
      expect(m['a']['amt'], 5);
    });
    test('delete is soft and propagates', () {
      final m = mergeFlow({'a': r('a', 1)}, {'a': r('a', 3, del: true)}) as Map;
      expect(m['a']['del'], true);
      expect(m.containsKey('a'), isTrue);
    });
  });
}
