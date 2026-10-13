
-- GetSetWell automatic session reminders
-- Uses existing notification_outbox and dispatcher.
-- No changes to booking, payment or session RPCs.

-- 1. Allow reminders in the existing outbox.

alter table public.notification_outbox
drop constraint if exists notification_outbox_type_check;

alter table public.notification_outbox
add constraint notification_outbox_type_check
check (
  type in (
    'booking_confirmed',
    'booking_cancelled',
    'booking_rescheduled',
    'session_reminder'
  )
);

-- 2. Queue reminders for eligible sessions.

create or replace function public.enqueue_due_session_reminders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inserted integer := 0;
begin
  with eligible as (
    select
      s.id,
      s.user_id,
      s.booking_request_id,
      s.scheduled_at,
      case
        when s.scheduled_at > now() + interval '23 hours 45 minutes'
         and s.scheduled_at <= now() + interval '24 hours'
          then '24h'

        when s.scheduled_at > now() + interval '45 minutes'
         and s.scheduled_at <= now() + interval '1 hour'
          then '1h'
      end as reminder_kind
    from public.sessions s
    where s.user_id is not null
      and lower(s.status) in ('confirmed', 'booked')
      and (
        (
          s.scheduled_at > now() + interval '23 hours 45 minutes'
          and s.scheduled_at <= now() + interval '24 hours'
        )
        or
        (
          s.scheduled_at > now() + interval '45 minutes'
          and s.scheduled_at <= now() + interval '1 hour'
        )
      )
  ),
  inserted as (
    insert into public.notification_outbox (
      event_key,
      user_id,
      session_id,
      booking_request_id,
      type,
      title,
      body
    )
    select
      'session_reminder:' ||
      e.id::text || ':' ||
      e.reminder_kind || ':' ||
      to_char(
        e.scheduled_at at time zone 'UTC',
        'YYYYMMDDHH24MISSUS'
      ),
      e.user_id,
      e.id,
      e.booking_request_id,
      'session_reminder',
      case
        when e.reminder_kind = '24h'
          then 'Your session is tomorrow'
        else 'Your session starts soon'
      end,
      case
        when e.reminder_kind = '24h'
          then 'Your GetSetWell session is coming up tomorrow. Tap to view the details.'
        else 'Your GetSetWell session starts in about an hour. Tap to view the details.'
      end
    from eligible e
    where e.reminder_kind is not null
    on conflict (event_key) do nothing
    returning id
  )
  select count(*) into v_inserted
  from inserted;

  return v_inserted;
end;
$$;

revoke all
on function public.enqueue_due_session_reminders()
from public, anon, authenticated;

-- 3. Run the reminder queue every minute.
-- The existing dispatcher will send queued events.

select cron.schedule(
  'getsetwell-session-reminders',
  '* * * * *',
  $job$
    select public.enqueue_due_session_reminders();
  $job$
);
