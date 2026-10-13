drop trigger if exists booking_requests_match_ready_notification
on public.booking_requests;

drop function if exists public.create_match_ready_notification();