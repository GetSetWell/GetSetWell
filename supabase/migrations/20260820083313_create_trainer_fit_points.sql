create table public.trainer_fit_points (
  id uuid primary key default gen_random_uuid(),

  trainer_id uuid not null
    references public.trainers(id)
    on delete cascade,

  text text not null,

  display_order integer not null default 999,

  created_at timestamptz not null default now()
);

create index trainer_fit_points_trainer_id_idx
on public.trainer_fit_points(trainer_id);

create index trainer_fit_points_order_idx
on public.trainer_fit_points(trainer_id, display_order);


-- Public trainer profiles can read fit points
alter table public.trainer_fit_points enable row level security;

create policy "Public can view trainer fit points"
on public.trainer_fit_points
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.trainers
    where trainers.id = trainer_fit_points.trainer_id
      and trainers.is_active = true
      and trainers.is_verified = true
  )
);

grant select on public.trainer_fit_points
to anon, authenticated;