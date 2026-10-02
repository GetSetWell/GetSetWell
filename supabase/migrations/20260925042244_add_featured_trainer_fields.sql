-- GetSetWell
-- Backend-controlled featured trainers for Home.

alter table public.trainers
add column if not exists is_featured boolean not null default false;

alter table public.trainers
add column if not exists featured_order smallint;

alter table public.trainers
add constraint trainers_featured_order_check
check (
  (
    is_featured = false
    and featured_order is null
  )
  or
  (
    is_featured = true
    and featured_order between 1 and 2
  )
);

create unique index if not exists trainers_featured_order_unique
on public.trainers(featured_order)
where is_featured = true;