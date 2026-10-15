-- شغّل هذا الملف مرة واحدة في Supabase → SQL Editor
create table if not exists public.werd_sync (
  user_id uuid not null references auth.users(id) on delete cascade,
  key text not null,
  value jsonb,
  ts bigint not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, key)
);
alter table public.werd_sync enable row level security;
drop policy if exists "own rows select" on public.werd_sync;
drop policy if exists "own rows insert" on public.werd_sync;
drop policy if exists "own rows update" on public.werd_sync;
drop policy if exists "own rows delete" on public.werd_sync;
create policy "own rows select" on public.werd_sync for select using (auth.uid() = user_id);
create policy "own rows insert" on public.werd_sync for insert with check (auth.uid() = user_id);
create policy "own rows update" on public.werd_sync for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows delete" on public.werd_sync for delete using (auth.uid() = user_id);

-- حذف الحساب من داخل التطبيق
create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  delete from public.werd_sync where user_id = auth.uid();
  delete from auth.users where id = auth.uid();
end $$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
