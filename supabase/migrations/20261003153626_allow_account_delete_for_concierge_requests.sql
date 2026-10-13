create or replace function public.enforce_open_concierge_request_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
declare
  open_count integer;
begin
  if new.request_type <> 'concierge_match' then
    return new;
  end if;

  /*
   * Account deletion sets booking_requests.user_id to NULL through
   * the FK ON DELETE SET NULL rule.
   *
   * Allow that system-generated UPDATE to pass without treating it
   * as a new unauthenticated concierge request.
   */
  if (
    tg_op = 'UPDATE'
    and old.user_id is not null
    and new.user_id is null
  ) then
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
      'confirmed',
      'booked',
      'completed',
      'closed',
      'cancelled',
      'canceled',
      'lost'
    );

  if open_count >= 1 then
    raise exception 'ACTIVE_CONCIERGE_EXISTS'
      using errcode = '23514';
  end if;

  return new;
end;
$function$;