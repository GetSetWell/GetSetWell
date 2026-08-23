-- ============================================================
-- Edge Function database permissions
--
-- service_role is used only server-side by Supabase Edge
-- Functions. It bypasses RLS but still requires PostgreSQL
-- table privileges.
-- ============================================================

grant select
on public.training_locations
to service_role;

grant select
on public.trainer_training_locations
to service_role;

grant select
on public.trainers
to service_role;