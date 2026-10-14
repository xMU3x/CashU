/// إعدادات Supabase تُمرَّر وقت البناء عبر --dart-define (لا مفاتيح داخل الكود).
/// المفتاح المستخدم هو المفتاح العام (publishable/anon)، والحماية الفعلية عبر RLS.
const String kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String kSupabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const String kNativeRedirect = 'com.flousy.budget://auth';
const String kStorePrefix = 'flousy1:';
const String kTable = 'budget_sync';

/// المفاتيح اللي بتتزامن مع السيرفر.
const List<String> kSyncKeys = ['accounts', 'transactions', 'settings'];

/// مفاتيح بتخزّن سجلات (id → سجل فيه u=وقت التعديل و d=محذوف).
const Set<String> kRecordKeys = {'accounts', 'transactions'};
