grant update on table public.booking_requests to authenticated;

create policy "Users can cancel their own concierge requests"
on public.booking_requests
for update
to authenticated
using (
  auth.uid() = user_id
  and request_type = 'concierge_match'
)
with check (
  auth.uid() = user_id
  and request_type = 'concierge_match'
  and status = 'cancelled'
);