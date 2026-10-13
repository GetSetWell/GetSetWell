create or replace function public.get_reschedule_availability(
  p_session_id uuid
)
returns table (
  starts_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_user_id uuid;
  v_session public.sessions%rowtype;
  v_start_date date;
  v_end_date date;
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

  -- Rolling 7-day window from today in Dubai time.
  v_start_date :=
    (now() at time zone 'Asia/Dubai')::date;

  v_end_date :=
    v_start_date + 6;

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
      and (
        w.week_start_date
        + (w.day_of_week - 1)
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
$function$;

revoke all
on function public.get_reschedule_availability(uuid)
from public;

grant execute
on function public.get_reschedule_availability(uuid)
to authenticated;