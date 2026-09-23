-- ============================================================
-- CUSTOMER PROFILES
--
-- One profile per authenticated customer.
-- Authentication itself remains managed by Supabase auth.users.
-- ============================================================

create table public.customer_profiles (
  id uuid primary key
    references auth.users(id)
    on delete cascade,

  phone text not null,

  full_name text,

  city text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


-- ------------------------------------------------------------
-- RLS
-- ------------------------------------------------------------

alter table public.customer_profiles
enable row level security;


-- Customers can read only their own profile.
create policy "Customers can view own profile"
on public.customer_profiles
for select
to authenticated
using (
  auth.uid() = id
);


-- Customers can create only their own profile.
create policy "Customers can create own profile"
on public.customer_profiles
for insert
to authenticated
with check (
  auth.uid() = id
);


-- Customers can update only their own profile.
create policy "Customers can update own profile"
on public.customer_profiles
for update
to authenticated
using (
  auth.uid() = id
)
with check (
  auth.uid() = id
);


grant select, insert, update
on public.customer_profiles
to authenticated;