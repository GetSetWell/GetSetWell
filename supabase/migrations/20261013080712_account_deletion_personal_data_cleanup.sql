-- GetSetWell: Account deletion personal-data cleanup
-- Local migration only.
-- Requires the existing customer_account_deletions table.
--
-- IMPORTANT:
-- Profile photos must be removed through the Supabase
-- Storage API before the customer profile is deleted.
--
-- Historical booking and session records are deliberately
-- excluded pending the approved retention policy.

alter table public.customer_account_deletions
  add column if not exists photo_cleanup_completed_at timestamptz;

alter table public.customer_account_deletions
  add column if not exists profile_cleanup_completed_at timestamptz;


-- Called by the trusted backend only AFTER confirming
-- that the customer's profile-photo Storage objects
-- have been removed or that no objects exist.

create or replace function public.confirm_customer_photo_cleanup(
  p_customer_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
begin
  select d.status
  into v_status
  from public.customer_account_deletions d
  where d.customer_id = p_customer_id
  for update;

  if v_status is distinct from 'cleanup_pending' then
    raise exception 'INVALID_DELETION_STATE';
  end if;

  if not exists (
    select 1
    from public.customer_identities ci
    where ci.id = p_customer_id
      and ci.firebase_uid is null
  ) then
    raise exception 'IDENTITY_NOT_DETACHED';
  end if;

  update public.customer_account_deletions
  set
    photo_cleanup_completed_at =
      coalesce(photo_cleanup_completed_at, now()),
    updated_at = now()
  where customer_id = p_customer_id;
end;
$$;


-- Remove account-specific profile and notification data.
-- Does not delete booking requests, sessions or identities.
-- Does not mark the overall deletion as completed.

create or replace function public.cleanup_customer_profile_data(
  p_customer_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_deletion public.customer_account_deletions%rowtype;
begin
  select *
  into v_deletion
  from public.customer_account_deletions d
  where d.customer_id = p_customer_id
  for update;

  if not found
     or v_deletion.status <> 'cleanup_pending' then
    raise exception 'INVALID_DELETION_STATE';
  end if;

  if v_deletion.photo_cleanup_completed_at is null then
    raise exception 'PHOTO_CLEANUP_REQUIRED';
  end if;

  if not exists (
    select 1
    from public.customer_identities ci
    where ci.id = p_customer_id
      and ci.firebase_uid is null
  ) then
    raise exception 'IDENTITY_NOT_DETACHED';
  end if;

  -- Remove profile information only after Storage cleanup.
  delete from public.customer_profiles
  where id = p_customer_id;

  -- Remove account-specific notifications and preferences.
  delete from public.notification_outbox
  where user_id = p_customer_id;

  delete from public.notifications
  where user_id = p_customer_id;

  delete from public.notification_preferences
  where user_id = p_customer_id;

  delete from public.device_push_tokens
  where user_id = p_customer_id;

  -- Record this stage, not overall account deletion.
  update public.customer_account_deletions
  set
    profile_cleanup_completed_at =
      coalesce(profile_cleanup_completed_at, now()),
    updated_at = now()
  where customer_id = p_customer_id;
end;
$$;


-- Restrict both operations to the trusted backend.

revoke all on function
  public.confirm_customer_photo_cleanup(uuid)
from public, anon, authenticated;

revoke all on function
  public.cleanup_customer_profile_data(uuid)
from public, anon, authenticated;

grant execute on function
  public.confirm_customer_photo_cleanup(uuid)
to service_role;

grant execute on function
  public.cleanup_customer_profile_data(uuid)
to service_role;