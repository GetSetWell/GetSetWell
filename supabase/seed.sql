insert into public.cities (name, slug, name_ar, is_active)
values
  ('Dubai', 'dubai', 'دبي', true),
  ('Abu Dhabi', 'abu-dhabi', 'أبوظبي', false),
  ('Sharjah', 'sharjah', 'الشارقة', false);

insert into public.services (name, slug, name_ar)
values
  ('Personal Training', 'personal-training', 'تدريب شخصي'),
  ('Yoga and Pilates', 'yoga-and-pilates', 'اليوغا والبيلاتس'),
  ('Running Coaching', 'running-coaching', 'تدريب الجري');
insert into public.specialties (name, slug, name_ar)
values
  ('Strength', 'strength', 'القوة'),
  ('Weight Loss', 'weight-loss', 'خسارة الوزن'),
  ('Running', 'running', 'الجري'),
  ('Women''s Health', 'womens-health', 'صحة المرأة'),
  ('Post-natal', 'post-natal', 'ما بعد الولادة'),
  ('Rehab', 'rehab', 'إعادة التأهيل'),
  ('Yoga', 'yoga', 'اليوغا'),
  ('Pilates', 'pilates', 'البيلاتس');

-- ============================================================
-- TRAINERS
-- ============================================================

insert into public.trainers (
  full_name,
  slug,
  gender,
  city_id,
  credentials,
  bio,
  years_experience,
  price_per_session,
  profile_image_url,
  service_area,
  languages,
  availability_note,
  is_verified,
  is_active,
  display_order
)
values
(
  'Michelle Berowsky',
  'michelle-berowsky',
  'female',
  (select id from public.cities where slug = 'dubai'),
  'Certified Yoga and Pilates Trainer',
  'Yoga and Pilates trainer focused on movement quality, strength and sustainable wellbeing.',
  10,
  320,
  'michelle-berowsky.jpg',
  'Dubai Marina & JLT',
  array['English'],
  'Available this week',
  true,
  true, 
  1
),
(
  'Atabey',
  'atabey',
  'male',
  (select id from public.cities where slug = 'dubai'),
  'Certified Personal Trainer',
  'Personal trainer focused on strength, conditioning and sustainable fitness.',
  8,
  280,
  null,
  'Business Bay & Downtown',
  array['English', 'Arabic', 'Turkish'],
  'Available this week',
  true,
  true, 
  2
),
(
  'Arash Vahedi',
  'arash-vahedi',
  'male',
  (select id from public.cities where slug = 'dubai'),
  'Certified Personal Trainer',
  'Personal trainer helping clients improve strength, fitness and movement.',
  7,
  250,
  null,
  'Dubai',
  array['English', 'Persian'],
  'Available this week',
  true,
  true, 
  3
),
(
  'Rajesh Pradhan',
  'rajesh-pradhan',
  'male',
  (select id from public.cities where slug = 'dubai'),
  'Certified Personal Trainer',
  'Personal trainer focused on practical strength, conditioning and long-term consistency.',
  7,
  240,
  null,
  'Dubai',
  array['English', 'Hindi'],
  'Available this week',
  true,
  true, 
  4
);


-- ============================================================
-- TRAINER SERVICES
-- ============================================================

insert into public.trainer_services (
  trainer_id,
  service_id,
  is_primary
)
values
(
  (select id from public.trainers where slug = 'michelle-berowsky'),
  (select id from public.services where slug = 'yoga-and-pilates'),
  true
),
(
  (select id from public.trainers where slug = 'atabey'),
  (select id from public.services where slug = 'personal-training'),
  true
),
(
  (select id from public.trainers where slug = 'arash-vahedi'),
  (select id from public.services where slug = 'personal-training'),
  true
),
(
  (select id from public.trainers where slug = 'rajesh-pradhan'),
  (select id from public.services where slug = 'personal-training'),
  true
);
