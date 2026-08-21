-- ============================================================
-- Trainer verification checks
-- ============================================================

create table public.trainer_verification_checks (
  id uuid primary key default gen_random_uuid(),

  trainer_id uuid not null
    references public.trainers(id)
    on delete cascade,

  title text not null,

  description text not null,

  check_type text not null
    check (
      check_type in (
        'identity',
        'primary_certification',
        'additional_certification',
        'first_aid_cpr',
        'experience',
        'reference',
        'in_person',
        'other'
      )
    ),

  display_order integer not null default 999,

  is_verified boolean not null default true,

  verified_at date,

  created_at timestamptz not null default now()
);


create index trainer_verification_checks_trainer_id_idx
on public.trainer_verification_checks(trainer_id);

create index trainer_verification_checks_order_idx
on public.trainer_verification_checks(
  trainer_id,
  display_order
);


-- ============================================================
-- RLS
-- ============================================================

alter table public.trainer_verification_checks
enable row level security;


create policy "Public can view verified trainer checks"
on public.trainer_verification_checks
for select
to anon, authenticated
using (
  is_verified = true
  and exists (
    select 1
    from public.trainers
    where trainers.id =
      trainer_verification_checks.trainer_id
      and trainers.is_active = true
      and trainers.is_verified = true
  )
);


grant select
on public.trainer_verification_checks
to anon, authenticated;