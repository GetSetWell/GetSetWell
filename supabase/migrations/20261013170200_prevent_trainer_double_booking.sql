-- GetSetWell: no double-booking of a trainer (13 Oct 2026)
--
-- 1. btree_gist so a GiST exclusion constraint can mix uuid "=" with range "&&".
-- 2. public.session_time_range(timestamptz): IMMUTABLE 60-minute range helper.
--    (timestamptz + interval is only STABLE in Postgres, so it cannot be used
--    directly in an index/constraint expression. Adding a fixed 1 hour does not
--    depend on the time zone, so the wrapper is safely immutable.)
-- 3. Guard: lists overlapping active sessions with RAISE NOTICE and aborts the
--    migration with a clear exception if any exist, so the data can be fixed
--    first. Nothing is created in that case (the migration is transactional).
-- 4. Exclusion constraint sessions_no_trainer_overlap on active sessions
--    (status confirmed or booked, the only active statuses in
--    sessions_status_check).
-- 5. public.check_trainer_slot(trainer, starts_at, exclude_session) for the
--    create-booking-request edge function (service_role only). Same rules as
--    get_trainer_booking_availability.
--
-- Idempotent: safe to run more than once.

create extension if not exists btree_gist with schema extensions;

create or replace function public.session_time_range(
  p_starts_at timestamptz
)
returns tstzrange
language sql
immutable
parallel safe
set search_path = ''
as $$
  select tstzrange(p_starts_at, p_starts_at + interval '1 hour', '[)');
$$;

comment on function public.session_time_range(timestamptz) is
'Fixed 60-minute session window [start, start + 1h). Immutable so it can back the sessions_no_trainer_overlap exclusion constraint.';

-- ------------------------------------------------------------
-- Guard: report and stop on existing conflicts.
-- ------------------------------------------------------------
do $$
declare
  v_conflict record;
  v_count integer := 0;
begin
  if exists (
    select 1
    from pg_constraint
    where conname = 'sessions_no_trainer_overlap'
      and conrelid = 'public.sessions'::regclass
  ) then
    raise notice 'sessions_no_trainer_overlap already exists, skipping conflict check.';
    return;
  end if;

  for v_conflict in
    select
      a.trainer_id,
      a.id as session_a,
      a.scheduled_at as starts_a,
      a.status as status_a,
      b.id as session_b,
      b.scheduled_at as starts_b,
      b.status as status_b
    from public.sessions a
    join public.sessions b
      on b.trainer_id = a.trainer_id
     and b.id > a.id
     and public.session_time_range(b.scheduled_at)
         && public.session_time_range(a.scheduled_at)
    where a.status in ('confirmed', 'booked')
      and b.status in ('confirmed', 'booked')
    order by a.trainer_id, a.scheduled_at
  loop
    v_count := v_count + 1;
    raise notice
      'Overlapping active sessions for trainer %: % (% at %) and % (% at %)',
      v_conflict.trainer_id,
      v_conflict.session_a, v_conflict.status_a, v_conflict.starts_a,
      v_conflict.session_b, v_conflict.status_b, v_conflict.starts_b;
  end loop;

  if v_count > 0 then
    raise exception
      'Cannot add sessions_no_trainer_overlap: % overlapping active session pair(s) found (see NOTICE lines). Cancel or move one session in each pair, then run supabase db push again.',
      v_count;
  end if;
end;
$$;

-- ------------------------------------------------------------
-- Exclusion constraint.
-- ------------------------------------------------------------
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'sessions_no_trainer_overlap'
      and conrelid = 'public.sessions'::regclass
  ) then
    alter table public.sessions
      add constraint sessions_no_trainer_overlap
      exclude using gist (
        trainer_id with =,
        public.session_time_range(scheduled_at) with &&
      )
      where (status in ('confirmed', 'booked'));
  end if;
end;
$$;

-- ------------------------------------------------------------
-- Slot check for the booking edge function.
-- Mirrors get_trainer_booking_availability: Dubai rolling 7-day window,
-- declared weekly start time, in the future, no overlapping active session.
-- Returns one of: 'ok', 'past', 'not_offered', 'taken'.
-- ------------------------------------------------------------
create or replace function public.check_trainer_slot(
  p_trainer_id uuid,
  p_starts_at timestamptz,
  p_exclude_session_id uuid default null
)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_local timestamp without time zone;
  v_date date;
  v_dow integer;
  v_week_start date;
  v_start_date date;
  v_end_date date;
begin
  if p_trainer_id is null or p_starts_at is null then
    return 'not_offered';
  end if;

  if p_starts_at <= now() then
    return 'past';
  end if;

  v_local := p_starts_at at time zone 'Asia/Dubai';
  v_date := v_local::date;
  v_dow := extract(isodow from v_local)::integer;
  v_week_start := v_date - (v_dow - 1);

  v_start_date := (now() at time zone 'Asia/Dubai')::date;
  v_end_date := v_start_date + 6;

  if v_date < v_start_date or v_date > v_end_date then
    return 'not_offered';
  end if;

  if not exists (
    select 1
    from public.trainer_weekly_availability w
    where w.trainer_id = p_trainer_id
      and w.week_start_date = v_week_start
      and w.day_of_week = v_dow
      and v_local::time = any(w.start_times)
  ) then
    return 'not_offered';
  end if;

  if exists (
    select 1
    from public.sessions s
    where s.trainer_id = p_trainer_id
      and (p_exclude_session_id is null or s.id <> p_exclude_session_id)
      and lower(coalesce(s.status, '')) in ('confirmed', 'booked')
      and public.session_time_range(s.scheduled_at)
          && public.session_time_range(p_starts_at)
  ) then
    return 'taken';
  end if;

  return 'ok';
end;
$$;

revoke all
on function public.check_trainer_slot(uuid, timestamptz, uuid)
from public, anon, authenticated;

grant execute
on function public.check_trainer_slot(uuid, timestamptz, uuid)
to service_role;
