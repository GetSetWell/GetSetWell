alter table public.booking_requests
  add column if not exists rematch_reason text,
  add column if not exists rematch_note text,
  add column if not exists rematch_requested_at timestamptz,
  add column if not exists rejected_trainer_id uuid
    references public.trainers(id)
    on delete set null;

alter table public.booking_requests
  add constraint booking_requests_rematch_reason_check
  check (
    rematch_reason is null
    or rematch_reason in (
      'price',
      'days_times',
      'area',
      'trainer',
      'other'
    )
  );


create or replace function public.request_concierge_rematch(
  p_request_id uuid,
  p_reason text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
begin
  current_user_id := auth.uid();

  if current_user_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_reason not in (
    'price',
    'days_times',
    'area',
    'trainer',
    'other'
  ) then
    raise exception 'INVALID_REMATCH_REASON';
  end if;

  update public.booking_requests
  set
    rejected_trainer_id = trainer_id,
    trainer_id = null,
    status = 'matching',

    rematch_reason = p_reason,
    rematch_note = nullif(trim(p_note), ''),
    rematch_requested_at = now(),

    match_outcome = null,
    match_reason = null,
    matched_at = null

  where id = p_request_id
    and user_id = current_user_id
    and request_type = 'concierge_match'
    and status = 'matched';

  if not found then
    raise exception 'MATCH_REQUEST_NOT_FOUND';
  end if;
end;
$$;

grant execute
on function public.request_concierge_rematch(uuid, text, text)
to authenticated;