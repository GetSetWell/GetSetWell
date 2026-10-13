insert into public.trainer_weekly_availability (
  trainer_id,
  week_start_date,
  day_of_week,
  start_times,
  updated_at
)
values
  (
    'f7f8587b-8499-4624-9f07-12241031b878',
    '2026-10-12',
    1,
    array['07:00', '18:30', '9:30', '12:30', '20:30']::time[],
    now()
  ),
  (
    'f7f8587b-8499-4624-9f07-12241031b878',
    '2026-10-12',
    2,
    array[]::time[],
    now()
  ),
  (
    'f7f8587b-8499-4624-9f07-12241031b878',
    '2026-10-12',
    3,
    array['06:00', '19:00']::time[],
    now()
  ),
  (
    'f7f8587b-8499-4624-9f07-12241031b878',
    '2026-10-12',
    4,
    array['07:00', '18:30']::time[],
    now()
  ),
  (
    'f7f8587b-8499-4624-9f07-12241031b878',
    '2026-10-12',
    5,
    array[]::time[],
    now()
  ),
  (
    'f7f8587b-8499-4624-9f07-12241031b878',
    '2026-10-12',
    6,
    array['08:00', '10:00']::time[],
    now()
  ),
  (
    'f7f8587b-8499-4624-9f07-12241031b878',
    '2026-10-12',
    7,
    array['07:00', '18:30']::time[],
    now()
  )
on conflict (
  trainer_id,
  week_start_date,
  day_of_week
)
do update
set
  start_times = excluded.start_times,
  updated_at = now();