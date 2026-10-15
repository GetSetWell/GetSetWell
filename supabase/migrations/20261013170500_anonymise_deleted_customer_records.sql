-- Completes account deletion within 30 days (Figma 12.6a/12.6b promise).
--
-- The delete-account flow already removes the sign-in account, profile
-- (name, email, photo), notifications and push tokens. Booking and session
-- rows are kept, because payment and refund records must be retained, but
-- they still carry copies of the customer's name, mobile number, free-text
-- notes and, for home or outdoor sessions, an address.
--
-- This migration strips those personal details from the retained rows once
-- profile cleanup has finished, and runs daily, so every deletion is complete
-- well inside 30 days. Amounts, dates, statuses and trainer links are kept.

alter table public.customer_account_deletions
  add column if not exists records_anonymised_at timestamptz;

comment on column public.customer_account_deletions.records_anonymised_at is
'When names, numbers, notes and addresses were removed from retained booking and session rows.';

create or replace function public.anonymise_deleted_customer_records()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_deletion record;
  v_count integer := 0;
begin
  for v_deletion in
    select d.customer_id
    from public.customer_account_deletions d
    where d.profile_cleanup_completed_at is not null
      and d.records_anonymised_at is null
    for update skip locked
  loop
    update public.booking_requests
    set
      customer_name = 'Deleted customer',
      phone = 'deleted',
      email = null,
      message = null,
      rematch_note = null
    where user_id = v_deletion.customer_id;

    update public.sessions
    set
      notes = null,
      customer_feedback_note = null,
      location_label = case
        when customer_training_place in ('home', 'outdoors') then null
        else location_label
      end
    where user_id = v_deletion.customer_id;

    update public.customer_account_deletions
    set
      records_anonymised_at = now(),
      updated_at = now()
    where customer_id = v_deletion.customer_id;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.anonymise_deleted_customer_records()
from public, anon, authenticated;

comment on function public.anonymise_deleted_customer_records() is
'Daily job. Removes names, numbers, notes and home/outdoor addresses from retained booking and session rows of customers whose account deletion has completed profile cleanup. Returns how many customers were processed.';

-- Daily at 02:15 Dubai time (22:15 UTC). Re-running the migration replaces
-- the job instead of duplicating it.
select cron.unschedule(jobid)
from cron.job
where jobname = 'getsetwell-anonymise-deleted-customers';

select cron.schedule(
  'getsetwell-anonymise-deleted-customers',
  '15 22 * * *',
  $job$
    select public.anonymise_deleted_customer_records();
  $job$
);
