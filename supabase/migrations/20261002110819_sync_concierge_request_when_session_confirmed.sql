create or replace function public.sync_request_when_session_confirmed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  source_request_id uuid;
begin
  if new.status = 'confirmed'
     and new.booking_request_id is not null then

    -- Confirm the trainer_request linked directly to this session.
    update public.booking_requests
    set status = 'confirmed'
    where id = new.booking_request_id;

    -- Check whether that trainer_request came from a concierge match.
    select source_concierge_request_id
    into source_request_id
    from public.booking_requests
    where id = new.booking_request_id;

    -- If yes, mark the original concierge request as booked too.
    if source_request_id is not null then
      update public.booking_requests
      set status = 'confirmed'
      where id = source_request_id
        and request_type = 'concierge_match';
    end if;
  end if;

  return new;
end;
$$;