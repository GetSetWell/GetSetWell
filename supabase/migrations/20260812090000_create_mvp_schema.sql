-- ============================================================
-- GetSetWell MVP Core Schema
-- ============================================================


-- CITIES

create table public.cities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  name_ar text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);


-- SERVICES

create table public.services (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  name_ar text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);


-- SPECIALTIES

create table public.specialties (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  name_ar text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);


-- TRAINERS

create table public.trainers (
  id uuid primary key default gen_random_uuid(),

  full_name text not null,
  slug text not null unique,

  gender text
    check (gender in ('male', 'female')),

  city_id uuid
    references public.cities(id)
    on delete set null,

  credentials text,
  bio text,

  years_experience integer
    check (years_experience >= 0),

  price_per_session numeric(10, 2)
    check (price_per_session >= 0),

  profile_image_url text,

  availability_note text,

  is_verified boolean not null default false,
  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


-- TRAINER SERVICES

create table public.trainer_services (
  trainer_id uuid not null
    references public.trainers(id)
    on delete cascade,

  service_id uuid not null
    references public.services(id)
    on delete cascade,

  primary key (trainer_id, service_id)
);


-- TRAINER SPECIALTIES

create table public.trainer_specialties (
  trainer_id uuid not null
    references public.trainers(id)
    on delete cascade,

  specialty_id uuid not null
    references public.specialties(id)
    on delete cascade,

  primary key (trainer_id, specialty_id)
);


-- BOOKING REQUESTS

create table public.booking_requests (
  id uuid primary key default gen_random_uuid(),

  trainer_id uuid
    references public.trainers(id)
    on delete set null,

  service_id uuid
    references public.services(id)
    on delete set null,

  city_id uuid
    references public.cities(id)
    on delete set null,

  customer_name text not null,
  phone text not null,
  email text,

  goal text,

  training_location text
    check (
      training_location in (
        'home_gym',
        'outdoor',
        'gym_visit',
        'online',
        'not_sure'
      )
    ),

  preferred_date date,
  preferred_time text,

  trainer_gender_preference text
    check (
      trainer_gender_preference in (
        'male',
        'female',
        'no_preference'
      )
    ),

  message text,

  status text not null default 'new'
    check (
      status in (
        'new',
        'contacted',
        'matched',
        'booked',
        'closed',
        'cancelled'
      )
    ),

  source text not null default 'app',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


-- INDEXES

create index trainers_city_id_idx
on public.trainers(city_id);

create index trainers_active_verified_idx
on public.trainers(is_active, is_verified);

create index booking_requests_trainer_id_idx
on public.booking_requests(trainer_id);

create index booking_requests_status_idx
on public.booking_requests(status);

create index booking_requests_created_at_idx
on public.booking_requests(created_at desc);


-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table public.cities enable row level security;
alter table public.services enable row level security;
alter table public.specialties enable row level security;
alter table public.trainers enable row level security;
alter table public.trainer_services enable row level security;
alter table public.trainer_specialties enable row level security;
alter table public.booking_requests enable row level security;


-- PUBLIC READ POLICIES

create policy "Public can view active cities"
on public.cities
for select
to anon, authenticated
using (is_active = true);


create policy "Public can view active services"
on public.services
for select
to anon, authenticated
using (is_active = true);


create policy "Public can view active specialties"
on public.specialties
for select
to anon, authenticated
using (is_active = true);


create policy "Public can view verified active trainers"
on public.trainers
for select
to anon, authenticated
using (
  is_active = true
  and is_verified = true
);


create policy "Public can view trainer services"
on public.trainer_services
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.trainers
    where trainers.id = trainer_services.trainer_id
      and trainers.is_active = true
      and trainers.is_verified = true
  )
);


create policy "Public can view trainer specialties"
on public.trainer_specialties
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.trainers
    where trainers.id = trainer_specialties.trainer_id
      and trainers.is_active = true
      and trainers.is_verified = true
  )
);


-- BOOKING REQUEST INSERT

create policy "Public can create booking requests"
on public.booking_requests
for insert
to anon, authenticated
with check (
  status = 'new'
);


-- API PERMISSIONS

revoke all on public.booking_requests
from anon, authenticated;

grant insert
on public.booking_requests
to anon, authenticated;

grant select
on public.cities,
   public.services,
   public.specialties,
   public.trainers,
   public.trainer_services,
   public.trainer_specialties
to anon, authenticated;