-- Remove the policy that references training_locations again.
drop policy if exists
  "Public can view trainer training locations"
on public.trainer_training_locations;


-- A relationship is visible when its trainer is active + verified.
-- Do NOT query training_locations here because the
-- training_locations policy already queries this table.
create policy "Public can view trainer training locations"
on public.trainer_training_locations
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.trainers t
    where t.id = trainer_training_locations.trainer_id
      and t.is_active = true
      and t.is_verified = true
  )
);