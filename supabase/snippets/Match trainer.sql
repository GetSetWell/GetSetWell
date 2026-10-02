update public.booking_requests
set
  status = 'matched',
  trainer_id = 'c427df7b-fe61-48b4-adb0-f9e17dc7455b',
  match_outcome = 'within_request',
  match_reason = 'You want to lose weight and build a routine. This trainer fits your preferred schedule, area and budget.',
  matched_at = now()
where id = 'd11043fa-01bb-423b-ab14-5c0be1d8823c';