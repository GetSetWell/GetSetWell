-- ============================================================
-- TRAINING LOCATIONS
--
-- Structured source of truth for where trainers can train.
--
-- trainers.session_locations remains human-readable profile copy.
-- These tables power matching/filtering.
-- ============================================================


-- ------------------------------------------------------------
-- Available training locations
-- ------------------------------------------------------------

create table public.training_locations (
  id uuid primary key default gen_random_uuid(),

  -- Human-readable name shown in the app.
  -- Examples:
  -- Home
  -- Outdoors
  -- Fitness First Dubai Marina
  -- Warehouse Gym Al Quoz
  name text not null,

  -- Stable identifier used by the app/database.
  slug text not null unique,

  -- Broad category of location.
  location_type text not null check (
    location_type in (
      'home',
      'gym',
      'outdoor',
      'online'
    )
  ),

  -- Optional area for a physical venue.
  -- Examples: Dubai Marina, Al Quoz, Business Bay
  area text,

  -- Lets us identify GetSetWell partner venues later.
  is_partner boolean not null default false,

  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


-- Prevent duplicate location names regardless of letter casing.
create unique index training_locations_name_unique_idx
on public.training_locations (lower(name));


-- ------------------------------------------------------------
-- Trainer ↔ Training Location relationship
-- ------------------------------------------------------------

create table public.trainer_training_locations (
  trainer_id uuid not null
    references public.trainers(id)
    on delete cascade,

  training_location_id uuid not null
    references public.training_locations(id)
    on delete cascade,

  display_order integer not null default 999,

  created_at timestamptz not null default now(),

  primary key (
    trainer_id,
    training_location_id
  )
);


create index trainer_training_locations_trainer_idx
on public.trainer_training_locations(trainer_id);


create index trainer_training_locations_location_idx
on public.trainer_training_locations(training_location_id);


-- ============================================================
-- RLS
-- ============================================================

alter table public.training_locations
enable row level security;

alter table public.trainer_training_locations
enable row level security;


-- A location is publicly visible only when:
-- 1. the location itself is active
-- 2. at least one active + verified trainer offers it
create policy "Public can view available training locations"
on public.training_locations
for select
to anon, authenticated
using (
  is_active = true
  and exists (
    select 1
    from public.trainer_training_locations ttl
    join public.trainers t
      on t.id = ttl.trainer_id
    where ttl.training_location_id = training_locations.id
      and t.is_active = true
      and t.is_verified = true
  )
);


-- Relationships are public only for active + verified trainers
-- and active locations.
create policy "Public can view trainer training locations"
on public.trainer_training_locations
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.trainers t
    join public.training_locations tl
      on tl.id = trainer_training_locations.training_location_id
    where t.id = trainer_training_locations.trainer_id
      and t.is_active = true
      and t.is_verified = true
      and tl.is_active = true
  )
);


grant select on public.training_locations
to anon, authenticated;

grant select on public.trainer_training_locations
to anon, authenticated;