-- GetSetWell
-- Only one active Help Me Choose request is allowed per customer.

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

  -- Prevent simultaneous submissions from both passing the count check.
  perform pg_advisory_xact_lock(
    hashtextextended(new.user_id::text, 0)
  );

  select count(*)
  into open_count
  from public.booking_requests br
  where br.user_id = new.user_id
    and br.request_type = 'concierge_match'
    and lower(br.status) not in (
      'closed',
      'cancelled',
      'canceled',
      'completed',
      'confirmed',
      'lost'
    );

  if open_count >= 1 then
    raise exception 'ACTIVE_CONCIERGE_EXISTS'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

-- The old "replace oldest" behavior is no longer part of the product rule.
drop function if exists public.replace_oldest_open_concierge_request();