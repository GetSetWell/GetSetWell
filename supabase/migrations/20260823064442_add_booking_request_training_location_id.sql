-- ============================================================
-- Structured training location for concierge matching
-- ============================================================

alter table public.booking_requests
add column training_location_id uuid
references public.training_locations(id)
on delete set null;


create index booking_requests_training_location_id_idx
on public.booking_requests(training_location_id);