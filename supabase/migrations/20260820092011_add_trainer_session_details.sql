alter table public.trainers
add column session_duration_minutes integer,
add column session_format text,
add column session_locations text,
add column session_schedule_note text,
add column payment_note text;