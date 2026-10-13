alter table public.sessions
  drop constraint if exists sessions_status_check;

alter table public.sessions
  add constraint sessions_status_check
  check (
    status in (
      'confirmed',
      'booked',
      'completed',
      'cancelled',
      'canceled',
      'reported'
    )
  );