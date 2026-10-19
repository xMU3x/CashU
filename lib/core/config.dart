import 'dart:convert';

/// مشروع Supabase الجديد + جدول المزامنة cash_sync (user_id, key, value jsonb, ts bigint).
const String kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://suxjvfyraqpcxplpvqzz.supabase.co',
);

/// اسم جدول المزامنة (يجب أن يطابق supabase/schema.sql).
const String kSyncTable = 'cash_sync';

/// المفتاح العام (publishable / anon) الخاص بالمشروع الجديد — يُمرَّر وقت البناء:
/// `--dart-define=SUPABASE_ANON_KEY=...` (في GitHub: Secret باسم SUPABASE_ANON_KEY).
/// لا يوجد مفتاح افتراضي عمدًا: مفتاح المشروع القديم لا يعمل مع المشروع الجديد.
const String _kKeyDefine = String.fromEnvironment('SUPABASE_ANON_KEY');
String get kSupabaseKey => _kKeyDefine.trim();

/// فحص شكلي للمفتاح (لا يثبت صلاحيته للسيرفر): publishable أو anon JWT، ولا يقبل مفتاح service/secret أبدًا.
bool keyLooksValid(String k) {
  final t = k.trim();
  if (t.isEmpty || t.startsWith('sb_secret_')) return false;
  if (t.startsWith('sb_publishable_') && t.length > 25) return true;
  if (RegExp(r'^eyJ[\w-]+\.[\w-]+\.[\w-]+$').hasMatch(t)) {
    // JWT: نرفض role=service_role
    try {
      final js = utf8.decode(base64Url.decode(base64Url.normalize(t.split('.')[1])));
      return !js.contains('service_role');
    } catch (_) {
      return false;
    }
  }
  return false;
}

const String kNativeRedirect = 'com.werd.cashu://auth';
const String kStorePrefix = 'tyr:';

/// مفاتيح داخل جدول cash_sync (key text).
const List<String> kSyncKeys = [
  'tyr_acc', 'tyr_bud', 'tyr_tx', 'tyr_loan', 'tyr_goal', 'tyr_cat', 'tyr_ctg', 'tyr_set', 'tyr_sub', 'tyr_assoc', 'tyr_inst',
];
