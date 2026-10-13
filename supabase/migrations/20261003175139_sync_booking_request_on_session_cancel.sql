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
    cancellation_reason = nullif(trim(p_reason), ''),
    cancellation_refund_amount = v_refund_amount
  where id = p_session_id;

  /*
   * Keep the linked request in sync with the actual session.
   * This is what the Requests tab reads.
   */
  if v_session.booking_request_id is not null then
    update public.booking_requests
    set
      status = 'cancelled'
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
$function$;

revoke all
on function public.cancel_session(uuid, text)
from public;

grant execute
on function public.cancel_session(uuid, text)
to authenticated;