-- جدول الحدّ من طلبات تحليل الرسائل (تكتب فيه الدالة بـ service role فقط)
create table if not exists public.ai_rate_limit (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create index if not exists ai_rate_limit_user_time on public.ai_rate_limit (user_id, created_at desc);
alter table public.ai_rate_limit enable row level security;  -- بدون policies = لا وصول من التطبيق
