alter table public.sessions
  add column if not exists customer_training_place text,
  add column if not exists venue_choice text,
  add column if not exists goal text,
  add column if not exists notes text;

alter table public.sessions
  add constraint sessions_customer_training_place_check
  check (
    customer_training_place is null
    or customer_training_place in (
      'gym',
      'home',
      'outdoors'
    )
  );

alter table public.sessions
  add constraint sessions_venue_choice_check
  check (
    venue_choice is null
    or venue_choice in (
      'customer_choice',
      'trainer_private_gym'
    )
  );

comment on column public.sessions.customer_training_place is
'Snapshot of where the customer chose to train when this session was booked.';

comment on column public.sessions.venue_choice is
'Snapshot of whether the customer chose their own location or the trainer private gym.';

comment on column public.sessions.goal is
'Snapshot of the customer goal at the time this session was booked.';

comment on column public.sessions.notes is
'Snapshot of optional customer notes at the time this session was booked.';