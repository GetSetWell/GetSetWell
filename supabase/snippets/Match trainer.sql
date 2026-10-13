update public.booking_requests
set
  status = 'matched',
  trainer_id = 'c427df7b-fe61-48b4-adb0-f9e17dc7455b',
  match_outcome = 'within_request',
  match_reason = 'You want to lose weight and build a routine. This trainer fits your preferred schedule, area and budget.',
  matched_at = now()
where id = '4d237c91-a4a5-4ef9-aec6-40e44098d65e';