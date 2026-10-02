-- A confirmed session means the originating request has been booked.
-- "confirmed" belongs to sessions; "booked" belongs to booking_requests.

create or replace function public.sync_request_when_session_confirmed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.booking_request_id is null then
    return new;
  end if;

  if lower(new.status) <> 'confirmed' then
    return new;
  end if;

  update public.booking_requests
  set
    status = 'booked',
    updated_at = now()
  where id = new.booking_request_id
    and status <> 'booked';

  return new;
end;
$$;

create or replace function public.enforce_open_concierge_request_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  open_count integer;
begin
  if new.request_type <> 'concierge_match' then
    return new;
  end if;

  if new.user_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(new.user_id::text, 0)
  );

  select count(*)
  into open_count
  from public.booking_requests br
  where br.user_id = new.user_id
    and br.request_type = 'concierge_match'
    and br.id <> new.id
    and lower(br.status) not in (
      'booked',
      'closed',
      'cancelled'
    );

  if open_count >= 1 then
    raise exception 'ACTIVE_CONCIERGE_EXISTS'
      using errcode = '23514';
  end if;

  return new;
end;
$$;