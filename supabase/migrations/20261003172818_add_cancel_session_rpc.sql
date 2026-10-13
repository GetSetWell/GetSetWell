alter table public.sessions
  add column if not exists cancelled_at timestamptz,
  add column if not exists cancellation_reason text,
  add column if not exists cancellation_refund_amount numeric(10,2);

create or replace function public.cancel_session(
  p_session_id uuid,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_user_id uuid;
  v_session public.sessions%rowtype;
  v_session_rate numeric(10,2);
  v_cancelled_at timestamptz;
  v_minutes_before integer;
  v_refund_amount numeric(10,2);
begin
  v_user_id := auth.uid();

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

  /*
   * Current MVP pricing source.
   * Uses the trainer's current per-session rate.
   *
   * Later, when payments are persisted, this should use
   * the amount actually charged for this booking instead.
   */
  select t.price_per_session
  into v_session_rate
  from public.trainers t
  where t.id = v_session.trainer_id;

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

  /*
   * Cancellation policy:
   *
   * 24 hours or more:
   *   refund 100% of session fee
   *
   * Less than 24 hours:
   *   refund 50% of session fee
   *
   * Service fee is retained separately and therefore
   * is not part of cancellation_refund_amount.
   */
  if v_minutes_before >= 1440 then
    v_refund_amount := v_session_rate;
  else
    v_refund_amount :=
      round(v_session_rate * 0.50, 2);
  end if;

  update public.sessions
  set
    status = 'cancelled',
    cancelled_at = v_cancelled_at,
    cancellation_reason =
      nullif(trim(p_reason), ''),
    cancellation_refund_amount =
      v_refund_amount
  where id = p_session_id;

  return jsonb_build_object(
    'success', true,
    'session_id', p_session_id,
    'cancelled_at', v_cancelled_at,
    'refund_amount', v_refund_amount,
    'minutes_before_session', v_minutes_before,
    'late_cancellation', v_minutes_before < 1440
  );
end;
$function$;

revoke all
on function public.cancel_session(uuid, text)
from public;

grant execute
on function public.cancel_session(uuid, text)
to authenticated;