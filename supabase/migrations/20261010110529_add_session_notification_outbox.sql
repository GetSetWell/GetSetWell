
-- GetSetWell session notification outbox
-- Does not modify existing booking or payment functions.

create table if not exists public.notification_outbox (
  id uuid primary key default gen_random_uuid(),
  event_key text not null unique,
  user_id uuid not null references auth.users(id)
    on delete cascade,
  session_id uuid not null references public.sessions(id)
    on delete cascade,
  booking_request_id uuid references public.booking_requests(id)
    on delete set null,
  type text not null check (
    type in (
      'booking_confirmed',
      'booking_cancelled',
      'booking_rescheduled'
    )
  ),
  title text not null,
  body text not null,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'skipped', 'failed')),
  attempts integer not null default 0,
  next_attempt_at timestamptz not null default now(),
  processed_at timestamptz,
  last_error text,
  created_at timestamptz not null default now()
);

create index if not exists notification_outbox_pending_idx
on public.notification_outbox (next_attempt_at, created_at)
where status in ('pending', 'failed');

alter table public.notification_outbox
  enable row level security;

revoke all on public.notification_outbox from anon, authenticated;

create or replace function public.queue_session_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_type text;
  v_title text;
  v_body text;
  v_event_key text;
begin
  if new.user_id is null then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.status = 'confirmed' then
      v_type := 'booking_confirmed';
      v_title := 'Your session is confirmed';
      v_body := 'Your GetSetWell session is confirmed. Tap to view the details.';
      v_event_key := 'booking_confirmed:' || new.id::text;
    end if;
  else
    if new.status = 'cancelled'
       and old.status is distinct from new.status then
      v_type := 'booking_cancelled';
      v_title := 'Your session has been cancelled';
      v_body := 'Your GetSetWell session has been cancelled. Tap to view the details.';
      v_event_key := 'booking_cancelled:' || new.id::text;

    elsif new.status = 'confirmed'
       and old.status is distinct from new.status then
      v_type := 'booking_confirmed';
      v_title := 'Your session is confirmed';
      v_body := 'Your GetSetWell session is confirmed. Tap to view the details.';
      v_event_key := 'booking_confirmed:' || new.id::text;

    elsif new.scheduled_at is distinct from old.scheduled_at
       and new.status in ('confirmed', 'booked')
       and old.status in ('confirmed', 'booked') then
      v_type := 'booking_rescheduled';
      v_title := 'Your session has been rescheduled';
      v_body := 'Your GetSetWell session time has changed. Tap to view the details.';
      v_event_key :=
        'booking_rescheduled:' ||
        new.id::text || ':' ||
        coalesce(new.reschedule_count, 0)::text;
    end if;
  end if;

  if v_type is null then
    return new;
  end if;

  insert into public.notification_outbox (
    event_key,
    user_id,
    session_id,
    booking_request_id,
    type,
    title,
    body
  )
  values (
    v_event_key,
    new.user_id,
    new.id,
    new.booking_request_id,
    v_type,
    v_title,
    v_body
  )
  on conflict (event_key) do nothing;

  return new;
end;
$$;

revoke all on function public.queue_session_notification()
from public, anon, authenticated;

drop trigger if exists session_notification_outbox_trigger
on public.sessions;

create trigger session_notification_outbox_trigger
after insert or update on public.sessions
for each row
execute function public.queue_session_notification();
