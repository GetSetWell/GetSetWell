-- GetSetWell: customer cancellation refunds from what was actually paid (13 Oct 2026)
--
-- Replaces public.cancel_session(uuid, text). Base definition copied from the
-- latest version in 20261012095559_firebase_identity_cutover.sql
-- (current_customer_id() identity, booking request sync).
--
-- Changes:
--   * Refund is computed from the sessions.session_rate snapshot. Falls back
--     to trainers.price_per_session only for legacy rows with no snapshot.
--   * v1.2 policy, customer cancels:
--       24h or more before start -> refund session_rate (5% fee kept)
--       under 24h               -> refund half of session_rate (fee kept)
--   * Trainer cancel / no-show has no path in this function (customer only),
--     so nothing changes there.
--
-- Signature, security and the returned JSON keys are unchanged:
--   success, session_id, cancelled_at, refund_amount,
--   minutes_before_session, late_cancellation

create or replace function public.cancel_session(
  p_session_id uuid,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_session public.sessions%rowtype;
  v_session_rate numeric(10,2);
  v_cancelled_at timestamptz;
  v_minutes_before integer;
  v_refund_amount numeric(10,2);
begin
  v_user_id := public.current_customer_id();

  if v_user_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select *
  into v_session
  from public.sessions
  where id = p_session_id
    and user_id = v_user_id
  for update;

  if not found then
    raise exception 'SESSION_NOT_FOUND';
  end if;

  if lower(coalesce(v_session.status, '')) not in (
    'confirmed',
    'booked'
  ) then
    raise exception 'SESSION_NOT_CANCELLABLE';
  end if;

  v_cancelled_at := now();

  if v_session.scheduled_at <= v_cancelled_at then
    raise exception 'SESSION_NOT_CANCELLABLE';
  end if;

  -- What the customer paid for the session itself (fee excluded).
  v_session_rate := v_session.session_rate;

  if v_session_rate is null then
    -- Legacy row without a price snapshot.
    select t.price_per_session
    into v_session_rate
    from public.trainers t
    where t.id = v_session.trainer_id;
  end if;

  if v_session_rate is null then
    raise exception 'SESSION_PRICE_NOT_FOUND';
  end if;

  v_minutes_before :=
    floor(
      extract(
        epoch from (
          v_session.scheduled_at - v_cancelled_at
        )
      ) / 60
    );

  -- The service fee is never refunded on a customer cancellation.
  if v_minutes_before >= 1440 then
    v_refund_amount := v_session_rate;
  else
    v_refund_amount := round(v_session_rate * 0.50, 2);
  end if;

  update public.sessions
  set
    status = 'cancelled',
    cancelled_at = v_cancelled_at,
    cancellation_reason = nullif(trim(p_reason), ''),
    cancellation_refund_amount = v_refund_amount
  where id = p_session_id;

  -- Keep the linked request in sync (Requests tab reads it).
  if v_session.booking_request_id is not null then
    update public.booking_requests
    set status = 'cancelled'
    where id = v_session.booking_request_id
      and user_id = v_user_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'session_id', p_session_id,
    'cancelled_at', v_cancelled_at,
    'refund_amount', v_refund_amount,
    'minutes_before_session', v_minutes_before,
    'late_cancellation', v_minutes_before < 1440
  );
end;
$$;

revoke all
on function public.cancel_session(uuid, text)
from public, anon;

grant execute
on function public.cancel_session(uuid, text)
to authenticated;
