-- GetSetWell: Atomic account deletion preparation
-- Run through local migrations only.
-- Never expose this function to normal authenticated clients.

create or replace function public.begin_customer_account_deletion(
  p_firebase_uid text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer_id uuid;
begin
  if nullif(trim(coalesce(p_firebase_uid, '')), '') is null then
    raise exception 'INVALID_FIREBASE_UID';
  end if;

  -- Lock the customer identity row for the duration of this transaction.
  -- Concurrent deletion attempts for the same UID are serialised.
  select ci.id
    into v_customer_id
  from public.customer_identities ci
  where ci.firebase_uid = p_firebase_uid
  for update;

  if v_customer_id is null then
    raise exception 'CUSTOMER_NOT_FOUND';
  end if;

  -- Do not begin a second deletion while an existing operation
  -- remains recorded. Recovery must be handled explicitly.
  if exists (
    select 1
    from public.customer_account_deletions d
    where d.customer_id = v_customer_id
  ) then
    raise exception 'DELETION_ALREADY_TRACKED';
  end if;

  -- Preserve the existing upcoming-session restriction.
  if exists (
    select 1
    from public.sessions s
    where s.user_id = v_customer_id
      and lower(s.status) in ('confirmed', 'booked')
      and s.scheduled_at >= now()
  ) then
    raise exception 'UPCOMING_SESSION';
  end if;

  -- Record the operation before detaching the identity.
  insert into public.customer_account_deletions (
    customer_id,
    firebase_uid,
    status,
    attempt_count
  )
  values (
    v_customer_id,
    p_firebase_uid,
    'pending',
    1
  );

  -- Detach the Firebase UID.
  update public.customer_identities
  set firebase_uid = null
  where id = v_customer_id
    and firebase_uid = p_firebase_uid;

  if not found then
    raise exception 'IDENTITY_DETACH_FAILED';
  end if;

  -- Record the successful database-side detachment.
  update public.customer_account_deletions
  set
    status = 'identity_detached',
    updated_at = now()
  where customer_id = v_customer_id
    and status = 'pending';

  if not found then
    raise exception 'DELETION_TRACKING_FAILED';
  end if;

  return v_customer_id;
end;
$$;

-- This operation is exclusively for trusted backend code.
revoke all on function
  public.begin_customer_account_deletion(text)
from public, anon, authenticated;

grant execute on function
  public.begin_customer_account_deletion(text)
to service_role;