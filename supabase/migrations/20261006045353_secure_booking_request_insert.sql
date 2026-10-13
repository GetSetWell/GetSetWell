drop policy if exists "Public can create booking requests"
on public.booking_requests;

create policy "Customers can create own booking requests"
on public.booking_requests
for insert
to authenticated
with check (
  user_id = auth.uid()
  and status = 'new'
  and share_details_consent = true
  and consented_at is not null
);