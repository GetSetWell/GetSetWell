create table public.notification_preferences (
  user_id uuid primary key
    references auth.users(id)
    on delete cascade,

  trainer_matches boolean not null default true,
  booking_updates boolean not null default true,
  session_reminders boolean not null default true,
  new_trainers boolean not null default false,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.notification_preferences
enable row level security;

create policy "Users can read own notification preferences"
on public.notification_preferences
for select
to authenticated
using (auth.uid() = user_id);

create policy "Users can create own notification preferences"
on public.notification_preferences
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users can update own notification preferences"
on public.notification_preferences
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

grant select, insert, update
on public.notification_preferences
to authenticated;