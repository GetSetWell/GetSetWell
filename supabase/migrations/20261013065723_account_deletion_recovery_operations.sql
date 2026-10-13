-- GetSetWell: Account deletion recovery operations
-- Trusted backend only.
-- All changes are transactional.

-- 1. Firebase confirmed successful account deletion.
create or replace function public.confirm_customer_firebase_deletion(
  p_customer_id uuid,
  p_firebase_uid text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.customer_account_deletions
  set
    status = 'firebase_deleted',
    updated_at = now(),
    last_error_code = null
  where customer_id = p_customer_id
    and firebase_uid = p_firebase_uid
    and status = 'identity_detached'
    and exists (
      select 1
      from public.customer_identities ci
      where ci.id = p_customer_id
        and ci.firebase_uid is null
    );

  if not found then
    raise exception 'INVALID_DELETION_STATE';
  end if;
end;
$$;


-- 2. Firebase explicitly rejected deletion.
-- Restore the original identity mapping atomically.
create or replace function public.restore_customer_after_failed_deletion(
  p_customer_id uuid,
  p_firebase_uid text,
  p_error_code text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Lock the deletion record to serialise recovery attempts.
  perform 1
  from public.customer_account_deletions
  where customer_id = p_customer_id
    and firebase_uid = p_firebase_uid
    and status = 'identity_detached'
  for update;

  if not found then
    raise exception 'INVALID_DELETION_STATE';
  end if;

  update public.customer_identities
  set firebase_uid = p_firebase_uid
  where id = p_customer_id
    and firebase_uid is null;

  if not found then
    raise exception 'IDENTITY_RESTORE_FAILED';
  end if;

  update public.customer_account_deletions
  set
    status = 'needs_review',
    last_error_code = left(
      coalesce(nullif(p_error_code, ''), 'FIREBASE_DELETE_REJECTED'),
      200
    ),
    updated_at = now()
  where customer_id = p_customer_id
    and firebase_uid = p_firebase_uid
    and status = 'identity_detached';

  if not found then
    raise exception 'RECOVERY_TRACKING_FAILED';
  end if;
end;
$$;


-- 3. Firebase deletion outcome is unknown.
-- Never restore authentication automatically.
create or replace function public.flag_customer_deletion_for_review(
  p_customer_id uuid,
  p_firebase_uid text,
  p_error_code text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.customer_account_deletions
  set
    status = 'needs_review',
    last_error_code = left(
      coalesce(
        nullif(p_error_code, ''),
        'FIREBASE_OUTCOME_UNKNOWN'
      ),
      200
    ),
    updated_at = now()
  where customer_id = p_customer_id
    and firebase_uid = p_firebase_uid
    and status = 'identity_detached'
    and exists (
      select 1
      from public.customer_identities ci
      where ci.id = p_customer_id
        and ci.firebase_uid is null
    );

  if not found then
    raise exception 'INVALID_DELETION_STATE';
  end if;
end;
$$;

-- Restrict recovery operations to trusted backend code.
revoke all on function
  public.confirm_customer_firebase_deletion(uuid, text)
from public, anon, authenticated;

revoke all on function
  public.restore_customer_after_failed_deletion(uuid, text, text)
from public, anon, authenticated;

revoke all on function
  public.flag_customer_deletion_for_review(uuid, text, text)
from public, anon, authenticated;

grant execute on function
  public.confirm_customer_firebase_deletion(uuid, text)
to service_role;

grant execute on function
  public.restore_customer_after_failed_deletion(uuid, text, text)
to service_role;

grant execute on function
  public.flag_customer_deletion_for_review(uuid, text, text)
to service_role;