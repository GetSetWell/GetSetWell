alter table public.trainers
add column display_order integer not null default 999;

create index trainers_display_order_idx
on public.trainers(display_order);