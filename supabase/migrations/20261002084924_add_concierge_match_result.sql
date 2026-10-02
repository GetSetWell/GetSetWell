alter table public.booking_requests
  add column match_outcome text,
  add column match_reason text,
  add column matched_at timestamptz;

alter table public.booking_requests
  add constraint booking_requests_match_outcome_check
  check (
    match_outcome is null
    or match_outcome in (
      'within_request',
      'outside_budget',
      'no_fit'
    )
  );