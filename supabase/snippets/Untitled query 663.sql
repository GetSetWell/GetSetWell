-- ============================================================
-- GETSETWELL HOME STATES BACKEND
-- Covers:
-- 1. Matching in progress
-- 2. Match ready
-- 3. Maximum 2 open concierge requests
-- 4. Replace oldest open concierge request
-- 5. Notifications storage
-- 6. Upcoming confirmed sessions
-- ============================================================

begin;

-- ============================================================
-- 1. BOOKING REQUEST STATUS SUPPORT
-- ============================================================

-- Make sure booking_requests has updated_at.
alter table public.booking_requests
add column if not exists updated_at timestamptz not null default now();

-- ============================================================
-- 2. NOTIFICATIONS
-- ============================================================

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references auth.users(id)
    on delete cascade,

  booking_request_id uuid
    references public.booking_requests(id)
    on delete cascade,

  type text not null,

  title text not null,

  body text,

  is_read boolean not null default false,

  created_at timestamptz not null default now()
);

create index if not exists notifications_user_id_created_at_idx
on public.notifications (
  user_id,
  created_at desc
);

alter table public.notifications
enable row level security;

grant select, update
on table public.notifications
to authenticated;

drop policy if exists
"Customers can read own notifications"
on public.notifications;

create policy
"Customers can read own notifications"
on public.notifications
for select
to authenticated
using (
  user_id = auth.uid()
);

drop policy if exists
"Customers can update own notifications"
on public.notifications;

create policy
"Customers can update own notifications"
on public.notifications
for update
to authenticated
using (
  user_id = auth.uid()
)
with check (
  user_id = auth.uid()
);


-- ============================================================
-- 3. DEVICE PUSH TOKENS
-- Used later for Firebase Cloud Messaging.
-- ============================================================

create table if not exists public.device_push_tokens (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references auth.users(id)
    on delete cascade,

  token text not null,

  platform text,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now(),

  unique (
    user_id,
    token
  )
);

create index if not exists device_push_tokens_user_id_idx
on public.device_push_tokens (
  user_id
);

alter table public.device_push_tokens
enable row level security;

grant select, insert, update, delete
on table public.device_push_tokens
to authenticated;

drop policy if exists
"Customers can manage own push tokens"
on public.device_push_tokens;

create policy
"Customers can manage own push tokens"
on public.device_push_tokens
for all
to authenticated
using (
  user_id = auth.uid()
)
with check (
  user_id = auth.uid()
);


-- ============================================================
-- 4. SESSIONS
-- Minimal confirmed-session model needed for Home.
-- ============================================================

create table if not exists public.sessions (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references auth.users(id)
    on delete cascade,

  trainer_id uuid not null
    references public.trainers(id)
    on delete restrict,

  booking_request_id uuid
    references public.booking_requests(id)
    on delete set null,

  scheduled_at timestamptz not null,

  location_label text,

  status text not null default 'confirmed',

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now(),

  constraint sessions_status_check
  check (
    status in (
      'confirmed',
      'completed',
      'cancelled',
      'no_show'
    )
  )
);

create index if not exists sessions_user_scheduled_idx
on public.sessions (
  user_id,
  scheduled_at
);

alter table public.sessions
enable row level security;

grant select
on table public.sessions
to authenticated;

drop policy if exists
"Customers can read own sessions"
on public.sessions;

create policy
"Customers can read own sessions"
on public.sessions
for select
to authenticated
using (
  user_id = auth.uid()
);


-- ============================================================
-- 5. BOOKING REQUEST READ ACCESS
-- ============================================================

alter table public.booking_requests
enable row level security;

grant select
on table public.booking_requests
to authenticated;

drop policy if exists
"Customers can read own booking requests"
on public.booking_requests;

create policy
"Customers can read own booking requests"
on public.booking_requests
for select
to authenticated
using (
  user_id = auth.uid()
);


-- ============================================================
-- 6. MAXIMUM TWO OPEN CONCIERGE REQUESTS
-- ============================================================

create or replace function public.enforce_open_concierge_request_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  open_request_count integer;
begin
  if new.request_type <> 'concierge_match' then
    return new;
  end if;

  if new.user_id is null then
    return new;
  end if;

  if new.status in (
    'closed',
    'cancelled',
    'canceled',
    'completed',
    'lost'
  ) then
    return new;
  end if;

  select count(*)
  into open_request_count
  from public.booking_requests
  where user_id = new.user_id
    and request_type = 'concierge_match'
    and status not in (
      'closed',
      'cancelled',
      'canceled',
      'completed',
      'lost'
    )
    and (
      tg_op = 'INSERT'
      or id <> new.id
    );

  if open_request_count >= 2 then
    raise exception 'ACTIVE_CONCIERGE_LIMIT'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists
booking_requests_open_concierge_limit
on public.booking_requests;

create trigger
booking_requests_open_concierge_limit
before insert or update
on public.booking_requests
for each row
execute function public.enforce_open_concierge_request_limit();


-- ============================================================
-- 7. REPLACE OLDEST OPEN CONCIERGE REQUEST
-- Customer can only replace THEIR OWN request.
-- ============================================================

create or replace function public.replace_oldest_open_concierge_request()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
  oldest_request_id uuid;
begin
  current_user_id := auth.uid();

  if current_user_id is null then
    raise exception 'AUTH_REQUIRED'
      using errcode = 'P0001';
  end if;

  select id
  into oldest_request_id
  from public.booking_requests
  where user_id = current_user_id
    and request_type = 'concierge_match'
    and status not in (
      'closed',
      'cancelled',
      'canceled',
      'completed',
      'lost'
    )
  order by created_at asc
  limit 1;

  if oldest_request_id is null then
    raise exception 'NO_OPEN_CONCIERGE_REQUEST'
      using errcode = 'P0001';
  end if;

  delete from public.booking_requests
  where id = oldest_request_id
    and user_id = current_user_id;

  return oldest_request_id;
end;
$$;

grant execute
on function public.replace_oldest_open_concierge_request()
to authenticated;


-- ============================================================
-- 8. MATCH READY NOTIFICATION
-- Automatically creates notification when request becomes matched.
-- ============================================================

create or replace function public.create_match_ready_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  trainer_name text;
begin
  if new.request_type <> 'concierge_match' then
    return new;
  end if;

  if new.user_id is null then
    return new;
  end if;

  if new.trainer_id is null then
    return new;
  end if;

  if new.status <> 'matched' then
    return new;
  end if;

  -- Only trigger when match becomes newly available.
  if tg_op = 'UPDATE' then
    if old.status = 'matched'
       and old.trainer_id is not distinct from new.trainer_id then
      return new;
    end if;
  end if;

  select full_name
  into trainer_name
  from public.trainers
  where id = new.trainer_id;

  insert into public.notifications (
    user_id,
    booking_request_id,
    type,
    title,
    body
  )
  values (
    new.user_id,
    new.id,
    'match_ready',
    'We picked your trainer',
    case
      when trainer_name is not null then
        trainer_name ||
        ' looks like the right fit. Tap to see why.'
      else
        'Your trainer match is ready. Tap to see why.'
    end
  );

  return new;
end;
$$;

drop trigger if exists
booking_requests_match_ready_notification
on public.booking_requests;

create trigger
booking_requests_match_ready_notification
after insert or update
on public.booking_requests
for each row
execute function public.create_match_ready_notification();


-- ============================================================
-- 9. CONFIRMED SESSION CLOSES MATCHING REQUEST
-- ============================================================

create or replace function public.sync_request_when_session_confirmed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status <> 'confirmed' then
    return new;
  end if;

  if new.booking_request_id is null then
    return new;
  end if;

  update public.booking_requests
  set
    status = 'confirmed',
    updated_at = now()
  where id = new.booking_request_id;

  return new;
end;
$$;

drop trigger if exists
sessions_sync_booking_request
on public.sessions;

create trigger
sessions_sync_booking_request
after insert or update
on public.sessions
for each row
execute function public.sync_request_when_session_confirmed();


-- ============================================================
-- 10. UPDATED_AT HELPERS
-- ============================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists
booking_requests_set_updated_at
on public.booking_requests;

create trigger
booking_requests_set_updated_at
before update
on public.booking_requests
for each row
execute function public.set_updated_at();


drop trigger if exists
sessions_set_updated_at
on public.sessions;

create trigger
sessions_set_updated_at
before update
on public.sessions
for each row
execute function public.set_updated_at();


drop trigger if exists
device_push_tokens_set_updated_at
on public.device_push_tokens;

create trigger
device_push_tokens_set_updated_at
before update
on public.device_push_tokens
for each row
execute function public.set_updated_at();


-- ============================================================
-- 11. RELOAD POSTGREST
-- ============================================================

notify pgrst, 'reload schema';

commit;