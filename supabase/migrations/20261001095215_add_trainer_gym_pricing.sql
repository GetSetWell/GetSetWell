alter table public.trainers
  add column gym_price_per_session numeric(10,2),
  add column gym_location_label text;

alter table public.trainers
  add constraint trainers_gym_price_positive
  check (
    gym_price_per_session is null
    or gym_price_per_session > 0
  );

alter table public.trainers
  add constraint trainers_gym_price_not_above_standard
  check (
    gym_price_per_session is null
    or price_per_session is null
    or gym_price_per_session <= price_per_session
  );

alter table public.trainers
  add constraint trainers_gym_offer_complete
  check (
    (
      gym_price_per_session is null
      and gym_location_label is null
    )
    or
    (
      gym_price_per_session is not null
      and nullif(trim(gym_location_label), '') is not null
    )
  );

comment on column public.trainers.gym_price_per_session is
  'Optional per-session price when the customer trains at the trainer gym.';

comment on column public.trainers.gym_location_label is
  'Customer-facing location label for the trainer gym.';