-- ============================================================
-- Trainer supported training locations
-- Used for filtering and concierge matching.
-- ============================================================

alter table public.trainers
add column training_locations text[]
not null
default '{}';

alter table public.trainers
add constraint trainers_training_locations_check
check (
  training_locations <@ array[
    'home_gym',
    'gym_visit',
    'outdoor',
    'online'
  ]::text[]
);