alter table public.booking_requests
  drop constraint if exists booking_requests_status_check;

alter table public.booking_requests
  add constraint booking_requests_status_check
  check (
    status in (
      'new',
      'pending',
      'contacted',
      'matching',
      'in_progress',
      'matched',
      'confirmed',
      'booked',
      'cancelled',
      'canceled',
      'completed',
      'closed',
      'lost'
    )
  );