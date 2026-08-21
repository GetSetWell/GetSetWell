-- ============================================================
-- DEVELOPMENT / DEMO DATA ONLY
-- Replace all trainer profile and verification data
-- with evidence-backed information before production launch.
-- ============================================================

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
  ('Pilates', 'pilates', 'البيلاتس'),

  -- Profile specialties
  ('Beginner Yoga', 'beginner-yoga', 'يوغا للمبتدئين'),
  ('Mobility', 'mobility', 'الحركة والمرونة'),
  ('Pre and postnatal', 'pre-postnatal', 'ما قبل وبعد الولادة'),
  ('Core strength', 'core-strength', 'قوة الجذع'),
  ('Strength training', 'strength-training', 'تدريب القوة'),
  ('Muscle building', 'muscle-building', 'بناء العضلات'),
  ('Conditioning', 'conditioning', 'اللياقة البدنية'),
  ('Functional training', 'functional-training', 'التدريب الوظيفي'),
  ('General fitness', 'general-fitness', 'اللياقة العامة'),
  ('Fat loss', 'fat-loss', 'خسارة الدهون');

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
  'I help people feel more comfortable and confident with yoga and Pilates, especially when they are just getting started. My sessions focus on mobility, core strength and controlled movement without making things unnecessarily complicated. I keep the pace supportive and adapt each session around how you are moving and feeling that day.',
  10,
  320,
  'michelle-berowsky.jpeg',
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
  'I work with people who want to become stronger, build muscle and improve their overall conditioning. My approach is structured and progressive, with sessions built around your current ability rather than pushing you into a generic programme. I like helping clients understand what they are doing so they can train with more confidence and consistency.',
  8,
  280,
  'atabey.jpeg',
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
  'I focus on practical strength training that also helps you move and feel better outside the gym. Sessions usually combine strength, mobility and conditioning depending on what you need and where you are starting from. I keep training straightforward and adjust the plan as your fitness and confidence improve.',
  7,
  250,
  'arash.jpeg',
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
  'I help people build strength, improve general fitness and create a routine they can realistically maintain. My sessions are practical and adaptable, whether you are getting back into training or looking for more structure and consistency. The goal is steady progress without making fitness feel more complicated than it needs to be.',
  7,
  240,
  'rajesh.jpeg',
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

-- ============================================================
-- TRAINER SPECIALTIES
-- DEVELOPMENT DATA
-- ============================================================

-- Michelle
insert into public.trainer_specialties (trainer_id, specialty_id)
select trainer.id, specialty.id
from public.trainers trainer
cross join public.specialties specialty
where trainer.slug = 'michelle-berowsky'
  and specialty.slug in (
    'beginner-yoga',
    'mobility',
    'pre-postnatal',
    'core-strength'
  )
on conflict do nothing;


-- Atabey
insert into public.trainer_specialties (trainer_id, specialty_id)
select trainer.id, specialty.id
from public.trainers trainer
cross join public.specialties specialty
where trainer.slug = 'atabey'
  and specialty.slug in (
    'strength-training',
    'muscle-building',
    'conditioning',
    'fat-loss'
  )
on conflict do nothing;


-- Arash
insert into public.trainer_specialties (trainer_id, specialty_id)
select trainer.id, specialty.id
from public.trainers trainer
cross join public.specialties specialty
where trainer.slug = 'arash-vahedi'
  and specialty.slug in (
    'strength-training',
    'functional-training',
    'mobility',
    'conditioning'
  )
on conflict do nothing;


-- Rajesh
insert into public.trainer_specialties (trainer_id, specialty_id)
select trainer.id, specialty.id
from public.trainers trainer
cross join public.specialties specialty
where trainer.slug = 'rajesh-pradhan'
  and specialty.slug in (
    'strength-training',
    'general-fitness',
    'mobility',
    'fat-loss'
  )
on conflict do nothing;

-- ============================================================
-- TRAINER VERIFICATION CHECKS
-- DEVELOPMENT DATA ONLY
-- Replace with evidence-backed trainer data before production.
-- ============================================================


-- ============================================================
-- MICHELLE BEROWSKY
-- ============================================================

insert into public.trainer_verification_checks (
  trainer_id,
  title,
  description,
  check_type,
  display_order,
  is_verified,
  verified_at
)
values
(
  (select id from public.trainers where slug = 'michelle-berowsky'),
  'Identity',
  'Emirates ID seen and matched to this profile.',
  'identity',
  1,
  true,
  '2026-08-01'
),
(
  (select id from public.trainers where slug = 'michelle-berowsky'),
  'Primary certification',
  'Pilates instructor qualification checked and confirmed.',
  'primary_certification',
  2,
  true,
  '2026-08-01'
),
(
  (select id from public.trainers where slug = 'michelle-berowsky'),
  'Additional certification',
  'Yoga teaching qualification checked with the issuing body.',
  'additional_certification',
  3,
  true,
  '2026-08-01'
),
(
  (select id from public.trainers where slug = 'michelle-berowsky'),
  'First aid and CPR',
  'Current first aid and CPR certification checked.',
  'first_aid_cpr',
  4,
  true,
  '2026-08-01'
),
(
  (select id from public.trainers where slug = 'michelle-berowsky'),
  'Experience',
  'Seven years of coaching experience checked against work history.',
  'experience',
  5,
  true,
  '2026-08-01'
),
(
  (select id from public.trainers where slug = 'michelle-berowsky'),
  'References',
  'Two previous clients contacted by GetSetWell.',
  'reference',
  6,
  true,
  '2026-08-01'
),
(
  (select id from public.trainers where slug = 'michelle-berowsky'),
  'Met in person',
  'Trainer met by the GetSetWell team in Dubai.',
  'in_person',
  7,
  true,
  '2026-08-01'
);


-- ============================================================
-- ATABEY
-- ============================================================

insert into public.trainer_verification_checks (
  trainer_id,
  title,
  description,
  check_type,
  display_order,
  is_verified,
  verified_at
)
values
(
  (select id from public.trainers where slug = 'atabey'),
  'Identity',
  'Emirates ID seen, matches this profile.',
  'identity',
  1,
  true,
  '2026-08-09'
),
(
  (select id from public.trainers where slug = 'atabey'),
  'Primary certification',
  'Level 3 Personal Trainer, UAE REPs. Confirmed on their register, 9 Aug 2026.',
  'primary_certification',
  2,
  true,
  '2026-08-09'
),
(
  (select id from public.trainers where slug = 'atabey'),
  'Additional certification',
  'NASM Certified Personal Trainer. Confirmed with the issuing body, 9 Aug 2026.',
  'additional_certification',
  3,
  true,
  '2026-08-09'
),
(
  (select id from public.trainers where slug = 'atabey'),
  'First aid and CPR',
  'Current, valid through January 2028.',
  'first_aid_cpr',
  4,
  true,
  '2026-08-09'
),
(
  (select id from public.trainers where slug = 'atabey'),
  'Experience',
  'Six years coaching in Dubai, confirmed against work history.',
  'experience',
  5,
  true,
  '2026-08-09'
),
(
  (select id from public.trainers where slug = 'atabey'),
  'References',
  'Two long-term clients contacted by us.',
  'reference',
  6,
  true,
  '2026-08-09'
),
(
  (select id from public.trainers where slug = 'atabey'),
  'Met in person',
  'Met in Business Bay, Dubai, 9 Aug 2026.',
  'in_person',
  7,
  true,
  '2026-08-09'
);


-- ============================================================
-- ARASH VAHEDI
-- ============================================================

insert into public.trainer_verification_checks (
  trainer_id,
  title,
  description,
  check_type,
  display_order,
  is_verified,
  verified_at
)
values
(
  (select id from public.trainers where slug = 'arash-vahedi'),
  'Identity',
  'Emirates ID seen and matched to this profile.',
  'identity',
  1,
  true,
  '2026-08-02'
),
(
  (select id from public.trainers where slug = 'arash-vahedi'),
  'Primary certification',
  'Personal training qualification checked and confirmed.',
  'primary_certification',
  2,
  true,
  '2026-08-02'
),
(
  (select id from public.trainers where slug = 'arash-vahedi'),
  'Additional certification',
  'Strength and conditioning training credential checked.',
  'additional_certification',
  3,
  true,
  '2026-08-02'
),
(
  (select id from public.trainers where slug = 'arash-vahedi'),
  'First aid and CPR',
  'Current first aid and CPR certification checked.',
  'first_aid_cpr',
  4,
  true,
  '2026-08-02'
),
(
  (select id from public.trainers where slug = 'arash-vahedi'),
  'Experience',
  'Six years of coaching experience checked against work history.',
  'experience',
  5,
  true,
  '2026-08-02'
),
(
  (select id from public.trainers where slug = 'arash-vahedi'),
  'References',
  'Two previous clients contacted by GetSetWell.',
  'reference',
  6,
  true,
  '2026-08-02'
),
(
  (select id from public.trainers where slug = 'arash-vahedi'),
  'Met in person',
  'Trainer met by the GetSetWell team in Dubai.',
  'in_person',
  7,
  true,
  '2026-08-02'
);


-- ============================================================
-- RAJESH PRADHAN
-- ============================================================

insert into public.trainer_verification_checks (
  trainer_id,
  title,
  description,
  check_type,
  display_order,
  is_verified,
  verified_at
)
values
(
  (select id from public.trainers where slug = 'rajesh-pradhan'),
  'Identity',
  'Emirates ID seen and matched to this profile.',
  'identity',
  1,
  true,
  '2026-08-03'
),
(
  (select id from public.trainers where slug = 'rajesh-pradhan'),
  'Primary certification',
  'Personal training qualification checked and confirmed.',
  'primary_certification',
  2,
  true,
  '2026-08-03'
),
(
  (select id from public.trainers where slug = 'rajesh-pradhan'),
  'Additional certification',
  'Functional strength and mobility credential checked.',
  'additional_certification',
  3,
  true,
  '2026-08-03'
),
(
  (select id from public.trainers where slug = 'rajesh-pradhan'),
  'First aid and CPR',
  'Current first aid and CPR certification checked.',
  'first_aid_cpr',
  4,
  true,
  '2026-08-03'
),
(
  (select id from public.trainers where slug = 'rajesh-pradhan'),
  'Experience',
  'Seven years of coaching experience checked against work history.',
  'experience',
  5,
  true,
  '2026-08-03'
),
(
  (select id from public.trainers where slug = 'rajesh-pradhan'),
  'References',
  'Two previous clients contacted by GetSetWell.',
  'reference',
  6,
  true,
  '2026-08-03'
),
(
  (select id from public.trainers where slug = 'rajesh-pradhan'),
  'Met in person',
  'Trainer met by the GetSetWell team in Dubai.',
  'in_person',
  7,
  true,
  '2026-08-03'
);

-- ============================================================
-- TRAINER FIT POINTS
-- DEVELOPMENT DATA
-- ============================================================

insert into public.trainer_fit_points (
  trainer_id,
  text,
  display_order
)
select trainer.id, fit.text, fit.display_order
from public.trainers trainer
cross join (
  values
    ('You’re new to yoga and want a supportive start', 1),
    ('You want more mobility and less everyday stiffness', 2),
    ('You’re looking for pre/post natal friendly training', 3)
) as fit(text, display_order)
where trainer.slug = 'michelle-berowsky';


insert into public.trainer_fit_points (
  trainer_id,
  text,
  display_order
)
select trainer.id, fit.text, fit.display_order
from public.trainers trainer
cross join (
  values
    ('You want to get stronger and build muscle', 1),
    ('You like structured, progressive training', 2),
    ('You want better conditioning alongside strength work', 3)
) as fit(text, display_order)
where trainer.slug = 'atabey';


insert into public.trainer_fit_points (
  trainer_id,
  text,
  display_order
)
select trainer.id, fit.text, fit.display_order
from public.trainers trainer
cross join (
  values
    ('You want to improve overall strength and movement', 1),
    ('You prefer practical training built around your current level', 2),
    ('You want a mix of strength, mobility and conditioning', 3)
) as fit(text, display_order)
where trainer.slug = 'arash-vahedi';


insert into public.trainer_fit_points (
  trainer_id,
  text,
  display_order
)
select trainer.id, fit.text, fit.display_order
from public.trainers trainer
cross join (
  values
    ('You want a straightforward approach to getting fitter', 1),
    ('You want to improve strength while moving better', 2),
    ('You are looking for training you can stay consistent with', 3)
) as fit(text, display_order)
where trainer.slug = 'rajesh-pradhan';

-- ============================================================
-- TRAINER SESSION DETAILS
-- DEVELOPMENT DATA
-- ============================================================

update public.trainers
set
  session_duration_minutes = 60,
  session_format = 'One to one',
  session_locations = 'Home, gym or outdoors',
  session_schedule_note = 'Weekday mornings and Saturday',
  payment_note = 'Paid directly to Michelle, no fee from us'
where slug = 'michelle-berowsky';


update public.trainers
set
  session_duration_minutes = 60,
  session_format = 'One to one',
  session_locations = 'Home gym, commercial gym or outdoors',
  session_schedule_note = 'Weekday mornings and evenings',
  payment_note = 'Paid directly to Atabey, no fee from us'
where slug = 'atabey';


update public.trainers
set
  session_duration_minutes = 60,
  session_format = 'One to one',
  session_locations = 'Home, gym or outdoors',
  session_schedule_note = 'Weekdays and selected weekends',
  payment_note = 'Paid directly to Arash, no fee from us'
where slug = 'arash-vahedi';


update public.trainers
set
  session_duration_minutes = 60,
  session_format = 'One to one',
  session_locations = 'Home, gym or outdoors',
  session_schedule_note = 'Weekday evenings and weekends',
  payment_note = 'Paid directly to Rajesh, no fee from us'
where slug = 'rajesh-pradhan';