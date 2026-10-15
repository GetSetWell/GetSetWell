-- GetSetWell: price snapshot on sessions (13 Oct 2026)
--
-- Every booked session stores what the customer was charged at booking time:
--   session_rate  = trainer rate for the chosen venue (standard or private gym)
--   service_fee   = round(session_rate * 0.05, 2), non-refundable
--   total_amount  = session_rate + service_fee
-- Refunds, receipts and "paid" amounts must read these columns, never the
-- trainer's current price (which can change after booking).
--
-- Idempotent: safe to run more than once.

alter table public.sessions
  add column if not exists session_rate numeric(10,2),
  add column if not exists service_fee numeric(10,2),
  add column if not exists total_amount numeric(10,2);

comment on column public.sessions.session_rate is
'Snapshot of the session rate charged at booking (AED). Fee excluded.';

comment on column public.sessions.service_fee is
'Snapshot of the 5% GetSetWell service fee charged at booking (AED). Non-refundable.';

comment on column public.sessions.total_amount is
'Snapshot of session_rate + service_fee charged at booking (AED).';

-- Backfill legacy rows.
-- booking_requests has no amount columns, so the snapshot is rebuilt from the
-- trainer's price. A session booked at the trainer private gym uses the gym
-- price when the trainer has one, matching the edge function's pricing rule.
update public.sessions s
set
  session_rate = p.rate,
  service_fee = round(p.rate * 0.05, 2),
  total_amount = p.rate + round(p.rate * 0.05, 2)
from (
  select
    s2.id,
    case
      when s2.venue_choice = 'trainer_private_gym'
           and t.gym_price_per_session is not null
        then t.gym_price_per_session
      else t.price_per_session
    end::numeric(10,2) as rate
  from public.sessions s2
  join public.trainers t
    on t.id = s2.trainer_id
  where s2.session_rate is null
) p
where s.id = p.id
  and p.rate is not null;

-- Amount sanity checks (re-created so the migration is re-runnable).
alter table public.sessions
  drop constraint if exists sessions_price_snapshot_nonnegative_check;

alter table public.sessions
  add constraint sessions_price_snapshot_nonnegative_check
  check (
    (session_rate is null or session_rate >= 0)
    and (service_fee is null or service_fee >= 0)
    and (total_amount is null or total_amount >= 0)
  );
