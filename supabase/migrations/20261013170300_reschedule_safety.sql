-- GetSetWell: reschedule safety (13 Oct 2026)
--
-- Replaces get_reschedule_availability(uuid) and
-- reschedule_session_weekly(uuid, timestamptz). Base definitions copied from
-- 20261012095559_firebase_identity_cutover.sql (latest versions).
-- Signatures and return types are unchanged so the app keeps working.
--
-- Rules (v1.2 policy):
--   * Only active sessions (confirmed / booked) that have NOT started can move.
--     Started sessions raise SESSION_NOT_MOVABLE (both RPCs).
--   * One move per booking (reschedule_count), unchanged: SESSION_ALREADY_MOVED.
--   * 24h or more before start: free move via reschedule_session_weekly.
--   * Under 24h: a move follows the late-cancellation rule and needs payment
--     ("Pay to move"). reschedule_session_weekly refuses with
--     LATE_MOVE_PAYMENT_REQUIRED. get_reschedule_availability still returns
--     slots inside 24h so the app can show the Pay to move flow.
--     TODO(Tap): once Tap confirms the late-move payment server-side, a
--     service_role-only RPC (or the payment webhook) performs the move with the
--     same checks. Until then no client path can move a session inside 24h.
--   * Target slot must be offered and free (unchanged), now also checked via
--     the shared session_time_range helper. The sessions_no_trainer_overlap
--     constraint is the final guard; a race surfaces as SLOT_UNAVAILABLE.

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
  v_start_date date;
  v_end_date date;
begin
  v_user_id := public.current_customer_id();

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

  if lower(coalesce(v_session.status, '')) not in ('confirmed', 'booked')
     or v_session.scheduled_at <= now() then
    raise exception 'SESSION_NOT_MOVABLE';
  end if;

  -- reschedule_count is not checked here on purpose: the app reads it from
  -- the session row to show the "already moved" state, and
  -- reschedule_session_weekly enforces the one-move rule.

  -- Rolling 7-day window from today in Dubai time.
  v_start_date := (now() at time zone 'Asia/Dubai')::date;
  v_end_date := v_start_date + 6;

  return query
  with declared_slots as (
    select
      (
        (
          w.week_start_date + (w.day_of_week - 1)
        )::date + t
      ) at time zone 'Asia/Dubai' as slot_start
    from public.trainer_weekly_availability w
    cross join lateral unnest(w.start_times) as t
    where w.trainer_id = v_session.trainer_id
      and (
        w.week_start_date + (w.day_of_week - 1)
      )::date between v_start_date and v_end_date
  )
  select d.slot_start
  from declared_slots d
  where d.slot_start > now()
    -- Do not offer the currently booked time.
    and d.slot_start <> v_session.scheduled_at
    -- Remove already occupied trainer times.
    and not exists (
      select 1
      from public.sessions s
      where s.trainer_id = v_session.trainer_id
        and s.id <> v_session.id
        and lower(coalesce(s.status, '')) in ('confirmed', 'booked')
        and public.session_time_range(s.scheduled_at)
            && public.session_time_range(d.slot_start)
    )
  order by d.slot_start;
end;
$$;

revoke all
on function public.get_reschedule_availability(uuid)
from public, anon;

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
  v_user_id := public.current_customer_id();

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

  if lower(coalesce(v_session.status, '')) not in ('confirmed', 'booked') then
    raise exception 'SESSION_NOT_MOVABLE';
  end if;

  -- A session that has already started can never be moved.
  if v_session.scheduled_at <= now() then
    raise exception 'SESSION_NOT_MOVABLE';
  end if;

  if coalesce(v_session.reschedule_count, 0) >= 1 then
    raise exception 'SESSION_ALREADY_MOVED';
  end if;

  -- Inside 24 hours a move must go through Pay to move.
  -- TODO(Tap): the paid late move is performed server-side after Tap confirms
  -- payment; this customer RPC only handles the free move.
  if v_session.scheduled_at - now() < interval '24 hours' then
    raise exception 'LATE_MOVE_PAYMENT_REQUIRED';
  end if;

  if p_new_scheduled_at is null or p_new_scheduled_at <= now() then
    raise exception 'SLOT_UNAVAILABLE';
  end if;

  v_local_target := p_new_scheduled_at at time zone 'Asia/Dubai';
  v_target_date := v_local_target::date;
  v_day_of_week := extract(isodow from v_local_target)::integer;
  v_week_start := v_target_date - (v_day_of_week - 1);
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
      and lower(coalesce(s.status, '')) in ('confirmed', 'booked')
      and public.session_time_range(s.scheduled_at)
          && public.session_time_range(p_new_scheduled_at)
  ) then
    raise exception 'SLOT_UNAVAILABLE';
  end if;

  begin
    update public.sessions
    set
      scheduled_at = p_new_scheduled_at,
      reschedule_count = coalesce(reschedule_count, 0) + 1,
      rescheduled_at = now()
    where id = v_session.id;
  exception
    when exclusion_violation then
      -- Another booking took the slot between the check and the update.
      raise exception 'SLOT_UNAVAILABLE';
  end;
end;
$$;

revoke all
on function public.reschedule_session_weekly(uuid, timestamptz)
from public, anon;

grant execute
on function public.reschedule_session_weekly(uuid, timestamptz)
to authenticated;
