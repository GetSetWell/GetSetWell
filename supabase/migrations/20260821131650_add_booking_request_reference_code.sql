create sequence if not exists public.booking_request_reference_seq
start with 1000;

alter table public.booking_requests
add column reference_code text
not null
default (
  'GSW-' ||
  lpad(
    nextval('public.booking_request_reference_seq')::text,
    4,
    '0'
  )
);

create unique index booking_requests_reference_code_idx
on public.booking_requests(reference_code);