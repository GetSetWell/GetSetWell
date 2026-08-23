-- ============================================================
-- Edge Function permissions for booking requests
--
-- create-booking-request uses service_role server-side.
-- The mobile app never receives this role/key.
-- ============================================================

grant insert
on public.booking_requests
to service_role;

-- Required because the Edge Function will return the generated
-- request ID and reference code after inserting.
grant select
on public.booking_requests
to service_role;

-- reference_code uses this sequence for values such as GSW-1000.
grant usage, select
on sequence public.booking_request_reference_seq
to service_role;