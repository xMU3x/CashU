-- تقييمات ردود المساعد حسّاب (👍/👎). كل مستخدم يكتب ويقرأ تقييماته بس.
-- شغّله مرة واحدة في Supabase SQL Editor (آمن لو اتشغّل أكتر من مرة).
create table if not exists public.ai_feedback (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  rating smallint not null check (rating in (-1, 1)),                  -- 1 = 👍 · -1 = 👎
  reply_excerpt text not null default '' check (char_length(reply_excerpt) <= 200),  -- مقتطف الرد (٢٠٠ حرف كحد أقصى)
  created_at timestamptz not null default now()
);

create index if not exists ai_feedback_user_time on public.ai_feedback (user_id, created_at desc);

alter table public.ai_feedback enable row level security;

-- قراءة تقييماتي أنا بس
drop policy if exists ai_feedback_select_own on public.ai_feedback;
create policy ai_feedback_select_own on public.ai_feedback
  for select to authenticated
  using (user_id = (select auth.uid()));

-- كتابة تقييم باسمي أنا بس
drop policy if exists ai_feedback_insert_own on public.ai_feedback;
create policy ai_feedback_insert_own on public.ai_feedback
  for insert to authenticated
  with check (user_id = (select auth.uid()));

-- مفيش policies للتعديل/الحذف = ممنوعين من التطبيق (التقييم سجل ثابت).
revoke all on public.ai_feedback from anon;
revoke all on public.ai_feedback from authenticated;
grant select, insert on public.ai_feedback to authenticated;
