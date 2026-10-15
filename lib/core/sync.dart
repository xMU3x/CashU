import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';
import 'merge.dart';
import 'store.dart';

enum SyncStatus { off, syncing, ok, error, offline }

/// تسجيل الدخول والمزامنة مع جدول `werd_sync` الحالي (user_id, key, value jsonb, ts bigint).
/// المنطق مطابق لـ js/sync.js: سحب ثم دمج عند التعارض ثم رفع (upsert) دون حذف أي بيانات.
class SyncService extends ChangeNotifier {
  SupabaseClient? client;
  User? user;
  SyncStatus status = SyncStatus.off;
  String err = '';
  int last = 0;
  bool _busy = false, _again = false;
  Timer? _debounce;

  bool get ready => client != null;

  void _set(SyncStatus s, [String e = '']) {
    status = s;
    err = e;
    notifyListeners();
  }

  Future<void> init() async {
    last = store.readIntMap('__last_map')['v'] ?? 0;
    if (kSupabaseUrl.isEmpty || kSupabaseKey.isEmpty) {
      _set(SyncStatus.off);
      return;
    }
    await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseKey);
    client = Supabase.instance.client;
    user = client!.auth.currentUser;
    client!.auth.onAuthStateChange.listen((s) {
      final was = user?.id;
      user = s.session?.user;
      notifyListeners();
      if (user != null && user!.id != was) run();
      if (user == null) _set(SyncStatus.off);
    });
    store.changes.listen((k) {
      if (user != null && kSyncKeys.contains(k)) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 2500), run);
      }
    });
    if (user != null) run();
  }

  /// عند عودة التطبيق للواجهة.
  void onResume() {
    if (user != null && DateTime.now().millisecondsSinceEpoch - last > 60000) run();
  }

  Future<String?> google() async {
    if (client == null) return 'لم يتم ضبط Supabase بعد (SUPABASE_ANON_KEY).';
    try {
      await client!.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kNativeRedirect,
        authScreenLaunchMode: LaunchMode.externalApplication,
        queryParams: {'prompt': 'select_account'},
      );
      return null;
    } catch (_) {
      return 'تعذّر بدء تسجيل الدخول بجوجل';
    }
  }

  /// يرجع رسالة الخطأ أو null عند النجاح. [needsConfirm] يصبح true عند إنشاء حساب يحتاج تأكيد البريد.
  Future<({String? error, bool needsConfirm})> email(String email, String password, bool create) async {
    if (client == null) return (error: 'no-client', needsConfirm: false);
    try {
      if (create) {
        final r = await client!.auth.signUp(email: email, password: password, emailRedirectTo: kNativeRedirect);
        return (error: null, needsConfirm: r.session == null);
      }
      await client!.auth.signInWithPassword(email: email, password: password);
      return (error: null, needsConfirm: false);
    } on AuthException catch (e) {
      return (error: e.message, needsConfirm: false);
    } catch (_) {
      return (error: 'network', needsConfirm: false);
    }
  }

  Future<void> logout() async {
    await client?.auth.signOut();
    user = null;
    _set(SyncStatus.off);
  }

  Future<bool> deleteAccount() async {
    if (client == null || user == null) return false;
    try {
      await client!.rpc('delete_my_account');
    } catch (_) {
      return false;
    }
    await logout();
    await store.clearAll();
    return true;
  }

  Future<void> run() async {
    if (client == null || user == null) return;
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    _set(SyncStatus.syncing);
    try {
      await _pull();
      await _push();
      last = DateTime.now().millisecondsSinceEpoch;
      store.writeIntMap('__last_map', {'v': last});
      _set(SyncStatus.ok);
    } catch (e) {
      final offline = e.toString().contains('SocketException') || e.toString().contains('ClientException');
      _set(offline ? SyncStatus.offline : SyncStatus.error, e.toString());
      Timer(const Duration(seconds: 30), () {
        if (user != null) run();
      });
    } finally {
      _busy = false;
      if (_again) {
        _again = false;
        Timer(const Duration(milliseconds: 500), run);
      }
    }
  }

  Future<void> _pull() async {
    final rows = await client!.from('werd_sync').select('key,value,ts').eq('user_id', user!.id) as List;
    final pushed = store.readIntMap('__pushed'), pulled = store.readIntMap('__pulled');
    for (final r in rows) {
      final key = r['key'] as String;
      if (!kSyncKeys.contains(key)) continue;
      final ts = (r['ts'] as num).toInt();
      final lt = store.meta[key] ?? 0;
      final unsynced = lt > (pushed[key] ?? 0);
      final has = store.has(key);
      if (!has || (ts > lt && !unsynced)) {
        store.applyRemote(key, r['value'], ts);
      } else if (unsynced && ts > (pulled[key] ?? 0) && ts != lt) {
        store.set(key, mergeFlow(store.get(key), r['value'])); // تعارض حقيقي → دمج ثم رفع
      }
      pulled[key] = ts;
    }
    store.writeIntMap('__pulled', pulled);
  }

  Future<void> _push() async {
    final pushed = store.readIntMap('__pushed');
    final rows = <Map<String, dynamic>>[];
    for (final k in kSyncKeys) {
      final t = store.meta[k] ?? 0;
      if (t > (pushed[k] ?? 0) && store.has(k)) rows.add({'user_id': user!.id, 'key': k, 'value': store.get(k), 'ts': t});
    }
    if (rows.isEmpty) return;
    await client!.from('werd_sync').upsert(rows, onConflict: 'user_id,key');
    final pl = store.readIntMap('__pulled');
    for (final r in rows) {
      pushed[r['key'] as String] = r['ts'] as int;
      pl[r['key'] as String] = r['ts'] as int;
    }
    store.writeIntMap('__pushed', pushed);
    store.writeIntMap('__pulled', pl);
  }
}

final SyncService sync = SyncService();
