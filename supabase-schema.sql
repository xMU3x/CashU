-- ============================================================
-- Surgery Department Cases Tracker - Supabase Schema
-- Run this file once, from Supabase Dashboard -> SQL Editor
-- (Includes real login / Supabase Auth + "who registered/edited" tracking)
-- ============================================================

-- Cases table: one row per patient case, full data stored as JSON payload
create table if not exists cases (
  id bigint primary key,
  pt_name text not null,
  consultant text,
  status text not null default 'active', -- active = still in dept, archived = discharged
  payload jsonb not null,
  created_by uuid references auth.users(id) on delete set null,
  created_by_name text,
  updated_by uuid references auth.users(id) on delete set null,
  updated_by_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- If you already have the table from an earlier version, this adds the
-- new "who did it" columns without touching your existing data.
alter table cases add column if not exists created_by uuid references auth.users(id) on delete set null;
alter table cases add column if not exists created_by_name text;
alter table cases add column if not exists updated_by uuid references auth.users(id) on delete set null;
alter table cases add column if not exists updated_by_name text;

create index if not exists cases_status_idx on cases (status);
create index if not exists cases_name_idx on cases (pt_name);

-- Config table: stores the customizable lists (consultants, departments) as JSON
create table if not exists app_config (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

-- Seed default seniors, consultants (up to 8) and departments — edit anytime from the app's Settings page
insert into app_config (key, value) values
  ('seniors', '["Dr. Ahmed Hassan","Dr. Mohamed Ali","Dr. Sara Youssef","Dr. Khaled Mostafa"]')
on conflict (key) do nothing;

insert into app_config (key, value) values
  ('consultants', '["Dr. Ahmed Hassan","Dr. Mohamed Ali","Dr. Sara Youssef","Dr. Khaled Mostafa","Dr. Omar Fathy","Dr. Nour ElDin","Dr. Amr Sami","Dr. Laila Adel"]')
on conflict (key) do nothing;

insert into app_config (key, value) values
  ('departments', '["Surgery A","Surgery B","ICU 6th Floor"]')
on conflict (key) do nothing;

-- Default password to access Settings and to delete cases (change it from the app's Settings screen)
insert into app_config (key, value) values
  ('password', '"1234"')
on conflict (key) do nothing;

-- ------------------------------------------------------------
-- Doctor accounts (real login via Supabase Auth)
-- ------------------------------------------------------------
-- One row per doctor, linked 1:1 to their Supabase Auth account (auth.users).
-- This is where "who is an admin" and "is this doctor still active" live.
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  display_name text not null,
  role text not null default 'doctor', -- 'doctor' or 'admin'
  is_active boolean not null default true,
  sort_order integer not null default 0, -- manual ordering set by the Admin in Doctors (Accounts)
  created_at timestamptz not null default now()
);

-- If you already have this table from an earlier version, this adds the
-- new "sort_order" column (used for manual drag/­sort ordering) without
-- touching your existing data.
alter table profiles add column if not exists sort_order integer not null default 0;

create index if not exists profiles_email_idx on profiles (email);
create index if not exists profiles_sort_idx on profiles (sort_order);

-- Security: RLS is on, no public policies.
-- The only access path is via the service_role key used server-side by the
-- Cloudflare Functions (which bypasses RLS). The browser never talks to
-- Supabase's data API directly — it only talks to Supabase Auth (sign in)
-- using the public anon key, which is safe to expose.
alter table cases enable row level security;
alter table app_config enable row level security;
alter table profiles enable row level security;

-- ------------------------------------------------------------
-- IMPORTANT — one-time manual step after you create your first doctor
-- account from the app's Settings screen:
--
--   update profiles set role = 'admin' where email = 'your-email@example.com';
--
-- Only an 'admin' can open the "Doctors" section in Settings to create
-- new accounts or disable/enable existing ones.
-- ------------------------------------------------------------
