-- ============================================================
-- Concierge matching fields
-- ============================================================

alter table public.booking_requests
add column request_type text not null default 'trainer_request',
add column budget_min integer,
add column budget_max integer,
add column language_preference text;


-- Selected trainer request vs Help me choose
alter table public.booking_requests
add constraint booking_requests_request_type_check
check (
  request_type in (
    'trainer_request',
    'concierge_match'
  )
);


-- Budget must either be completely absent,
-- or contain a valid numeric range.
alter table public.booking_requests
add constraint booking_requests_budget_range_check
check (
  (
    budget_min is null
    and budget_max is null
  )
  or
  (
    budget_min is not null
    and budget_max is not null
    and budget_min >= 0
    and budget_max >= budget_min
  )
);


-- Language remains dynamic because it comes from trainers.languages
alter table public.booking_requests
add constraint booking_requests_language_preference_length_check
check (
  language_preference is null
  or char_length(trim(language_preference)) between 1 and 50
);