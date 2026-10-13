
-- GetSetWell: Immediate notification dispatch and push delivery tracking.
-- Keep the existing one-minute cron job as a fallback.
-- Edge Functions will be updated separately to use delivery tracking.

-- 1. Track FCM delivery independently for each device.

create table public.notification_push_deliveries (
  id uuid primary key default gen_random_uuid(),

  outbox_id uuid not null
    references public.notification_outbox(id)
    on delete cascade,

  device_token text not null,

  status text not null default 'pending'
    check (
      status in (
        'pending',
        'processing',
        'accepted',
        'retryable_failed',
        'permanent_failed'
      )
    ),

  attempts integer not null default 0
    check (attempts >= 0),

  next_attempt_at timestamptz not null default now(),
  lease_expires_at timestamptz,

  accepted_at timestamptz,
  fcm_message_id text,
  last_error text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (outbox_id, device_token)
);

create index notification_push_deliveries_ready_idx
on public.notification_push_deliveries (
  next_attempt_at,
  outbox_id
)
where status in ('pending', 'retryable_failed');

create index notification_push_deliveries_processing_idx
on public.notification_push_deliveries (
  lease_expires_at
)
where status = 'processing';

alter table public.notification_push_deliveries
  enable row level security;

revoke all on public.notification_push_deliveries
from public, anon, authenticated;

grant select, insert, update, delete
on public.notification_push_deliveries
to service_role;

comment on table public.notification_push_deliveries is
  'FCM request tracking per outbox event and device. Accepted means Firebase accepted the request, not that the device displayed it.';


-- 2. Dispatch immediately when a notification event is queued.
-- pg_net sends the request asynchronously after transaction commit.
-- If immediate dispatch fails, the existing cron job remains
-- responsible for processing the durable outbox entry.

create or replace function public.dispatch_notification_outbox_on_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin_secret text;
  v_request_id bigint;
begin
  select ds.decrypted_secret
  into v_admin_secret
  from vault.decrypted_secrets ds
  where ds.name = 'notification_dispatch_admin_secret'
  limit 1;

  if v_admin_secret is null or length(v_admin_secret) = 0 then
    raise warning
      'GetSetWell immediate dispatch: Vault secret unavailable';
    return new;
  end if;

  select net.http_post(
    url :=
      'https://tijezquislhgmfchbkyt.supabase.co/functions/v1/dispatch-notifications',

    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-admin-secret', v_admin_secret
    ),

    body := '{}'::jsonb,

    timeout_milliseconds := 30000
  )
  into v_request_id;

  return new;

exception when others then
  -- Do not block session creation or booking updates.
  -- The existing one-minute scheduler provides recovery.
  raise warning
    'GetSetWell immediate notification dispatch failed: SQLSTATE %',
    sqlstate;

  return new;
end;
$$;

revoke all
on function public.dispatch_notification_outbox_on_insert()
from public, anon, authenticated;

create trigger notification_outbox_immediate_dispatch_trigger
after insert on public.notification_outbox
for each row
execute function public.dispatch_notification_outbox_on_insert();
