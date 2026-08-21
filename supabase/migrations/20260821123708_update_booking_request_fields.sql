-- ============================================================
-- BOOKING REQUEST FLOW FIELDS
-- ============================================================

alter table public.booking_requests
add column preferred_days text[] not null default '{}',
add column preferred_area text,
add column share_details_consent boolean not null default false,
add column consented_at timestamptz;


-- ============================================================
-- VALIDATE PREFERRED DAYS
-- ============================================================

alter table public.booking_requests
add constraint booking_requests_preferred_days_check
check (
  preferred_days <@ array[
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday'
  ]::text[]
);


-- ============================================================
-- UPDATE PUBLIC INSERT POLICY
-- A booking request can only be submitted when consent is given.
-- ============================================================

drop policy if exists "Public can create booking requests"
on public.booking_requests;

create policy "Public can create booking requests"
on public.booking_requests
for insert
to anon, authenticated
with check (
  status = 'new'
  and share_details_consent = true
  and consented_at is not null
);