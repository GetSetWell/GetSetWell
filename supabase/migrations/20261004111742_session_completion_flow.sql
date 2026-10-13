-- GetSetWell session completion / post-session feedback
-- Apply as a new local migration, then run: supabase db push

alter table public.sessions
  add column if not exists completion_prompt_shown_at timestamptz,
  add column if not exists customer_outcome text,
  add column if not exists customer_feedback_category text,
  add column if not exists customer_feedback_note text,
  add column if not exists customer_confirmed_at timestamptz;

create or replace function public.mark_session_completion_prompt_shown(
  p_session_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  update public.sessions
  set completion_prompt_shown_at = coalesce(completion_prompt_shown_at, now())
  where id = p_session_id
    and user_id = v_user_id
    and customer_outcome is null
    and lower(coalesce(status, '')) in ('confirmed', 'booked')
    and scheduled_at + interval '1 hour' <= now();

  if not found then
    raise exception 'SESSION_NOT_AVAILABLE_FOR_CONFIRMATION';
  end if;
end;
$$;

revoke all
on function public.mark_session_completion_prompt_shown(uuid)
from public;

grant execute
on function public.mark_session_completion_prompt_shown(uuid)
to authenticated;

create or replace function public.submit_session_outcome(
  p_session_id uuid,
  p_outcome text,
  p_feedback_category text default null,
  p_feedback_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_session public.sessions%rowtype;
  v_new_status text;
  v_normalized_outcome text;
  v_note text;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  v_normalized_outcome := lower(trim(coalesce(p_outcome, '')));

  if v_normalized_outcome not in (
    'took_place_well',
    'took_place_fine',
    'took_place_not_hoped',
    'did_not_take_place',
    'cut_short'
  ) then
    raise exception 'INVALID_SESSION_OUTCOME';
  end if;

  select *
  into v_session
  from public.sessions
  where id = p_session_id
    and user_id = v_user_id
  for update;

  if not found then
    raise exception 'SESSION_NOT_FOUND';
  end if;

  if lower(coalesce(v_session.status, '')) in ('cancelled', 'canceled') then
    raise exception 'SESSION_CANCELLED';
  end if;

  if v_session.scheduled_at + interval '1 hour' > now() then
    raise exception 'SESSION_NOT_ENDED';
  end if;

  if v_session.customer_outcome is not null then
    raise exception 'SESSION_OUTCOME_ALREADY_SUBMITTED';
  end if;

  v_note := nullif(trim(coalesce(p_feedback_note, '')), '');

  if v_note is not null and char_length(v_note) > 250 then
    raise exception 'FEEDBACK_NOTE_TOO_LONG';
  end if;

  if v_normalized_outcome in (
    'did_not_take_place',
    'cut_short'
  ) then
    v_new_status := 'reported';
  else
    v_new_status := 'completed';
  end if;

  update public.sessions
  set
    status = v_new_status,
    customer_outcome = v_normalized_outcome,
    customer_feedback_category = nullif(trim(coalesce(p_feedback_category, '')), ''),
    customer_feedback_note = v_note,
    customer_confirmed_at = now(),
    completion_prompt_shown_at = coalesce(completion_prompt_shown_at, now())
  where id = p_session_id;

  -- The request itself is finished once the booked session has concluded.
  if v_session.booking_request_id is not null then
    update public.booking_requests
    set status = 'completed'
    where id = v_session.booking_request_id
      and user_id = v_user_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'session_id', p_session_id,
    'status', v_new_status,
    'outcome', v_normalized_outcome,
    'submitted_at', now()
  );
end;
$$;

revoke all
on function public.submit_session_outcome(uuid, text, text, text)
from public;

grant execute
on function public.submit_session_outcome(uuid, text, text, text)
to authenticated;
