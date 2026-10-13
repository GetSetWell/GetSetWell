create table if not exists public.trainer_weekly_availability (
  id uuid primary key default gen_random_uuid(),

  trainer_id uuid not null
    references public.trainers(id)
    on delete cascade,

  week_start_date date not null,

  day_of_week smallint not null
    check (day_of_week between 1 and 7),

  start_times time[] not null default '{}',

  updated_at timestamptz not null default now(),

  constraint trainer_weekly_availability_unique_day
    unique (
      trainer_id,
      week_start_date,
      day_of_week
    )
);

create index if not exists
  trainer_weekly_availability_lookup_idx
on public.trainer_weekly_availability (
  trainer_id,
  week_start_date,
  day_of_week
);

alter table public.trainer_weekly_availability
  enable row level security;

grant select
on table public.trainer_weekly_availability
to authenticated;

create policy
  "Authenticated users can view trainer availability"
on public.trainer_weekly_availability
for select
to authenticated
using (true);