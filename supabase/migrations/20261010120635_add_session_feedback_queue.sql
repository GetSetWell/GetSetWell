
-- Allow feedback events in the notification outbox.
alter table public.notification_outbox
  drop constraint if exists notification_outbox_type_check;

alter table public.notification_outbox
  add constraint notification_outbox_type_check
  check (type in (
    'booking_confirmed',
    'booking_cancelled',
    'booking_rescheduled',
    'session_reminder',
    'session_feedback'
  ));

-- Queue feedback notifications only for recently ended sessions.
-- This function will be scheduled after dispatcher safeguards are added.
create or replace function public.enqueue_due_session_feedback()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.notification_outbox (
    event_key,
    user_id,
    session_id,
    booking_request_id,
    type,
    title,
    body,
    status
  )
  select
    'session_feedback:' || s.id::text,
    s.user_id,
    s.id,
    s.booking_request_id,
    'session_feedback',
    'How did your session go?',
    'Tell us how your training session went.',
    'pending'
  from public.sessions s
  join public.trainers t on t.id = s.trainer_id
  where lower(s.status) in ('confirmed', 'booked')
    and s.user_id is not null
    and s.customer_outcome is null
    and t.session_duration_minutes > 0
    and s.scheduled_at
      + (t.session_duration_minutes * interval '1 minute')
      <= now()
    and s.scheduled_at
      + (t.session_duration_minutes * interval '1 minute')
      > now() - interval '15 minutes'
  on conflict (event_key) do nothing;
end;
$$;

-- Not scheduled yet.
