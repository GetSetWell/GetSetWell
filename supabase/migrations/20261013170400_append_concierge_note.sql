-- Lets a customer add a note to their own OPEN Help me choose request.
-- Used by the app's "Welcome back, same goal" screen (Figma 3.6), where a
-- returning customer re-asks for the same goal and we keep their existing
-- request instead of creating a second one.
--
-- The note is appended to booking_requests.message on a new line with a
-- Dubai-time stamp, so the matcher sees what changed and when. The customer
-- cannot otherwise update their request (RLS only allows cancelling).

create or replace function public.append_concierge_note(
  p_request_id uuid,
  p_note text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_note text;
  v_stamp text;
begin
  v_user_id := public.current_customer_id();

  if v_user_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  v_note := nullif(trim(p_note), '');

  if v_note is null then
    raise exception 'NOTE_REQUIRED';
  end if;

  if char_length(v_note) > 1000 then
    raise exception 'NOTE_TOO_LONG';
  end if;

  v_stamp := to_char(now() at time zone 'Asia/Dubai', 'Dy DD Mon, HH12:MI AM');

  update public.booking_requests
  set message = case
    when nullif(trim(message), '') is null then v_note
    else message || E'\n\n' || 'Added ' || v_stamp || ': ' || v_note
  end
  where id = p_request_id
    and user_id = v_user_id
    and request_type = 'concierge_match'
    and lower(status) not in (
      'confirmed',
      'booked',
      'completed',
      'closed',
      'cancelled',
      'canceled',
      'lost'
    );

  if not found then
    raise exception 'OPEN_REQUEST_NOT_FOUND';
  end if;
end;
$$;

revoke all on function public.append_concierge_note(uuid, text) from public;
revoke all on function public.append_concierge_note(uuid, text) from anon;
grant execute on function public.append_concierge_note(uuid, text) to authenticated;

comment on function public.append_concierge_note(uuid, text) is
'Appends a customer note to their own open concierge request (Figma 3.6). Raises AUTH_REQUIRED, NOTE_REQUIRED, NOTE_TOO_LONG or OPEN_REQUEST_NOT_FOUND.';
