alter table public.booking_requests
  add column source_concierge_request_id uuid
  references public.booking_requests(id)
  on delete set null;

create index booking_requests_source_concierge_request_idx
  on public.booking_requests(source_concierge_request_id);