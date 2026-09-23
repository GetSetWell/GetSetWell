
-- ============================================================
-- RECONCILE BOOKING REQUEST USER OWNERSHIP
--
-- booking_requests.user_id was previously added directly to
-- the database and was therefore missing from migration history.
-- ============================================================

alter table public.booking_requests
add column if not exists user_id uuid;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'booking_requests_user_id_fkey'
      and conrelid = 'public.booking_requests'::regclass
  ) then
    alter table public.booking_requests
    add constraint booking_requests_user_id_fkey
    foreign key (user_id)
    references auth.users(id)
    on delete set null;
  end if;
end
$$;

create index if not exists booking_requests_user_id_idx
on public.booking_requests(user_id);