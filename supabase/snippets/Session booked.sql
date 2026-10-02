insert into public.sessions (
  user_id,
  trainer_id,
  scheduled_at,
  location_label,
  status
)
select
  cp.id,
  t.id,
  now() + interval '2 days',
  'Dubai Marina',
  'confirmed'
from public.customer_profiles cp
cross join lateral (
  select id
  from public.trainers
  limit 1
) t
where cp.phone = '971501234567'
returning *;