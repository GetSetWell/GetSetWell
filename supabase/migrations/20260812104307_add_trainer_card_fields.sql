-- ============================================================
-- Trainer card fields
-- ============================================================

-- Human-readable service area shown on trainer cards.
-- Examples:
-- "Dubai Marina & JLT"
-- "Business Bay & Downtown"
alter table public.trainers
add column service_area text;


-- Languages spoken by the trainer.
-- Examples:
-- {'English'}
-- {'English', 'Arabic', 'Turkish'}
alter table public.trainers
add column languages text[] not null default '{}';


-- One of a trainer's services can be marked as the
-- primary service displayed on the trainer card.
alter table public.trainer_services
add column is_primary boolean not null default false;


-- Helps when retrieving the primary service.
create index trainer_services_primary_idx
on public.trainer_services (trainer_id, is_primary);