/// نفس مشروع Supabase وجدول werd_sync (user_id, key, value jsonb, ts bigint) — بلا أي تغيير في السيرفر.
const String kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://mckhvbkzcanjtjqiqqyd.supabase.co',
);
const String _kKeyDefine = String.fromEnvironment('SUPABASE_ANON_KEY');
/// المفتاح العام (publishable) المخصّص للعميل — موجود أصلًا في js/config.js بتطبيق دُرَر؛ الحماية عبر RLS.
const String kDefaultKey = 'sb_publishable_B_BtTMvtrlvXqiE01qdUQQ_wBtn_SEh';
String get kSupabaseKey => _kKeyDefine.isEmpty ? kDefaultKey : _kKeyDefine;
const String kNativeRedirect = 'com.werd.tayyar://auth';
const String kStorePrefix = 'tyr:';

/// مفاتيح جديدة داخل نفس الجدول (key text) — لا تتعارض مع مفاتيح دُرَر.
const List<String> kSyncKeys = [
  'tyr_acc', 'tyr_bud', 'tyr_tx', 'tyr_loan', 'tyr_goal', 'tyr_cat', 'tyr_set',
];
