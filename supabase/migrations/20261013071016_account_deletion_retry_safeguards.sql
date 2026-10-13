-- GetSetWell: Safe account-deletion retries
-- Replaces the preparation function from the earlier migration.
-- Apply through Supabase CLI migrations only.

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
  v_status text;
begin
  if nullif(trim(coalesce(p_firebase_uid, '')), '') is null then
    raise exception 'INVALID_FIREBASE_UID';
  end if;

  -- Serialise deletion attempts for this Firebase identity.
  select ci.id
  into v_customer_id
  from public.customer_identities ci
  where ci.firebase_uid = p_firebase_uid
  for update;

  if v_customer_id is null then
    raise exception 'CUSTOMER_NOT_FOUND';
  end if;

  -- Lock the existing deletion record, if present.
  select d.status
  into v_status
  from public.customer_account_deletions d
  where d.customer_id = v_customer_id
  for update;

  -- Only a previously restored identity may retry.
  -- Unknown outcomes remain detached and cannot reach
  -- this stage using their original Firebase UID.
  if v_status is not null and v_status <> 'needs_review' then
    raise exception 'DELETION_ALREADY_TRACKED';
  end if;

  -- Preserve the upcoming-session restriction.
  if exists (
    select 1
    from public.sessions s
    where s.user_id = v_customer_id
      and lower(s.status) in ('confirmed', 'booked')
      and s.scheduled_at >= now()
  ) then
    raise exception 'UPCOMING_SESSION';
  end if;

  if v_status is null then
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
  else
    -- Retry only after a confirmed rejection and restoration.
    -- The original UID must still be linked to the customer.
    update public.customer_account_deletions
    set
      status = 'pending',
      attempt_count = attempt_count + 1,
      last_error_code = null,
      completed_at = null,
      updated_at = now()
    where customer_id = v_customer_id
      and firebase_uid = p_firebase_uid
      and status = 'needs_review'
      and last_error_code like 'REJECTED:%';

    if not found then
      raise exception 'DELETION_REQUIRES_REVIEW';
    end if;
  end if;

  -- Detach authentication before contacting Firebase.
  update public.customer_identities
  set firebase_uid = null
  where id = v_customer_id
    and firebase_uid = p_firebase_uid;

  if not found then
    raise exception 'IDENTITY_DETACH_FAILED';
  end if;

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

revoke all on function
  public.begin_customer_account_deletion(text)
from public, anon, authenticated;

grant execute on function
  public.begin_customer_account_deletion(text)
to service_role;