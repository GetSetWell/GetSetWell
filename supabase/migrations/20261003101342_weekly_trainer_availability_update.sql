-- Final weekly trainer availability model for GetSetWell.
-- Add through a LOCAL Supabase migration, then run: supabase db push.

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

drop policy if exists
  "Authenticated users can view trainer weekly availability"
on public.trainer_weekly_availability;

create policy
  "Authenticated users can view trainer weekly availability"
on public.trainer_weekly_availability
for select
to authenticated
using (true);

alter table public.sessions
  add column if not exists reschedule_count integer
    not null default 0,
  add column if not exists rescheduled_at timestamptz;

create or replace function public.get_reschedule_availability(
  p_session_id uuid
)
returns table (
  starts_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_session public.sessions%rowtype;
  v_local_session timestamp without time zone;
  v_week_start date;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select *
  into v_session
  from public.sessions
  where id = p_session_id
    and user_id = v_user_id;

  if not found then
    raise exception 'SESSION_NOT_FOUND';
  end if;

  v_local_session :=
    v_session.scheduled_at at time zone 'Asia/Dubai';

  v_week_start :=
    v_local_session::date
    - (extract(isodow from v_local_session)::integer - 1);

  return query
  with declared_slots as (
    select
      (
        (
          w.week_start_date
          + (w.day_of_week - 1)
        )::date
        + t
      ) at time zone 'Asia/Dubai' as slot_start
    from public.trainer_weekly_availability w
    cross join lateral unnest(w.start_times) as t
    where w.trainer_id = v_session.trainer_id
      and w.week_start_date = v_week_start
  )
  select d.slot_start
  from declared_slots d
  where d.slot_start > now()
    and d.slot_start <> v_session.scheduled_at
    and not exists (
      select 1
      from public.sessions s
      where s.trainer_id = v_session.trainer_id
        and s.id <> v_session.id
        and lower(coalesce(s.status, '')) in (
          'confirmed',
          'booked'
        )
        and s.scheduled_at <
          d.slot_start + interval '1 hour'
        and s.scheduled_at + interval '1 hour' >
          d.slot_start
    )
  order by d.slot_start;
end;
$$;

revoke all
on function public.get_reschedule_availability(uuid)
from public;

grant execute
on function public.get_reschedule_availability(uuid)
to authenticated;

create or replace function public.reschedule_session_weekly(
  p_session_id uuid,
  p_new_scheduled_at timestamptz
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_session public.sessions%rowtype;
  v_local_target timestamp without time zone;
  v_target_date date;
  v_week_start date;
  v_day_of_week integer;
  v_start_time time;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select *
  into v_session
  from public.sessions
  where id = p_session_id
    and user_id = v_user_id
  for update;

  if not found then
    raise exception 'SESSION_NOT_FOUND';
  end if;

  if lower(coalesce(v_session.status, '')) not in (
    'confirmed',
    'booked'
  ) then
    raise exception 'SESSION_NOT_MOVABLE';
  end if;

  if coalesce(v_session.reschedule_count, 0) >= 1 then
    raise exception 'SESSION_ALREADY_MOVED';
  end if;

  if p_new_scheduled_at <= now() then
    raise exception 'SLOT_UNAVAILABLE';
  end if;

  v_local_target :=
    p_new_scheduled_at at time zone 'Asia/Dubai';

  v_target_date := v_local_target::date;
  v_day_of_week :=
    extract(isodow from v_local_target)::integer;
  v_week_start :=
    v_target_date - (v_day_of_week - 1);
  v_start_time := v_local_target::time;

  if not exists (
    select 1
    from public.trainer_weekly_availability w
    where w.trainer_id = v_session.trainer_id
      and w.week_start_date = v_week_start
      and w.day_of_week = v_day_of_week
      and v_start_time = any(w.start_times)
  ) then
    raise exception 'AVAILABILITY_NOT_FOUND';
  end if;

  if exists (
    select 1
    from public.sessions s
    where s.trainer_id = v_session.trainer_id
      and s.id <> v_session.id
      and lower(coalesce(s.status, '')) in (
        'confirmed',
        'booked'
      )
      and s.scheduled_at <
        p_new_scheduled_at + interval '1 hour'
      and s.scheduled_at + interval '1 hour' >
        p_new_scheduled_at
  ) then
    raise exception 'SLOT_UNAVAILABLE';
  end if;

  update public.sessions
  set
    scheduled_at = p_new_scheduled_at,
    reschedule_count =
      coalesce(reschedule_count, 0) + 1,
    rescheduled_at = now()
  where id = v_session.id;
end;
$$;

revoke all
on function public.reschedule_session_weekly(
  uuid,
  timestamptz
)
from public;

grant execute
on function public.reschedule_session_weekly(
  uuid,
  timestamptz
)
to authenticated;
