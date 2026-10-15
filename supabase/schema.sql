-- شغّل هذا الملف مرة واحدة في Supabase → SQL Editor
create table if not exists public.budget_sync (
  user_id uuid not null references auth.users(id) on delete cascade,
  key text not null,
  value jsonb,
  ts bigint not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, key)
);
alter table public.budget_sync enable row level security;
drop policy if exists "own rows select" on public.budget_sync;
drop policy if exists "own rows insert" on public.budget_sync;
drop policy if exists "own rows update" on public.budget_sync;
drop policy if exists "own rows delete" on public.budget_sync;
create policy "own rows select" on public.budget_sync for select using (auth.uid() = user_id);
create policy "own rows insert" on public.budget_sync for insert with check (auth.uid() = user_id);
create policy "own rows update" on public.budget_sync for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows delete" on public.budget_sync for delete using (auth.uid() = user_id);

-- حذف بيانات الميزانية السحابية من داخل التطبيق (لا يمس حساب الدخول نفسه،
-- عشان لو المشروع مشترك مع تطبيق تاني ما يتأثرش)
create or replace function public.delete_my_budget_data() returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  delete from public.budget_sync where user_id = auth.uid();
end $$;
revoke all on function public.delete_my_budget_data() from public, anon;
grant execute on function public.delete_my_budget_data() to authenticated;

-- عدّاد استخدام الذكاء الاصطناعي (حد يومي لكل مستخدم). مفيش policies: الدالة بس (service role) بتكتب فيه.
create table if not exists public.ai_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  n int not null default 0,
  primary key (user_id, day)
);
alter table public.ai_usage enable row level security;
