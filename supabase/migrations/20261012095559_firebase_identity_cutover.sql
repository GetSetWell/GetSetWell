-- GetSetWell Firebase third-party auth identity cutover (REVIEW BEFORE APPLYING)
-- Derived from remote public schema dump 2026-10-12.
-- Does not delete data or replace existing UUID identifiers.
-- Requires Firebase third-party auth and role=authenticated claim.
-- IMPORTANT: Storage RLS, Edge Functions, and Flutter must be migrated too.
BEGIN;

CREATE TABLE public.customer_identities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid text UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT customer_identities_firebase_uid_nonempty
    CHECK (firebase_uid IS NULL OR length(trim(firebase_uid)) > 0)
);

-- Preserve EVERY legacy auth.users ID, including users without a completed profile.
INSERT INTO public.customer_identities (id)
SELECT id FROM auth.users
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.customer_identities ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.customer_identities FROM PUBLIC, anon, authenticated;
-- No direct table RLS policies: mappings are only visible through secure RPCs.

-- The authenticated user's internal UUID. Supabase-native tokens remain supported
-- during the transition; Firebase tokens resolve by their verified subject.
CREATE FUNCTION public.current_customer_id()
RETURNS uuid
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_jwt jsonb := auth.jwt();
  v_issuer text := v_jwt->>'iss';
  v_sub text := v_jwt->>'sub';
  v_id uuid;
BEGIN
  IF auth.role() IS DISTINCT FROM 'authenticated' THEN RETURN NULL; END IF;
  IF v_issuer = 'https://securetoken.google.com/getsetwell-prod-510013'
     AND v_jwt->>'aud' = 'getsetwell-prod-510013'
     AND nullif(v_sub, '') IS NOT NULL THEN
    SELECT ci.id INTO v_id FROM public.customer_identities ci
    WHERE ci.firebase_uid = v_sub;
    RETURN v_id;
  END IF;
  IF v_issuer = 'https://tijezquislhgmfchbkyt.supabase.co/auth/v1' THEN
    RETURN auth.uid();
  END IF;
  RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION public.current_customer_id() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_customer_id() TO authenticated;

-- First-time provisioning uses ONLY the signed, verified Firebase JWT claims.
-- Does not accept an arbitrary Firebase UID, phone, or customer UUID from a client.
CREATE FUNCTION public.ensure_customer_identity()
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_jwt jsonb := auth.jwt();
  v_uid text := v_jwt->>'sub';
  v_phone text := v_jwt->>'phone_number';
  v_id uuid;
BEGIN
  IF auth.role() IS DISTINCT FROM 'authenticated'
    OR v_jwt->>'iss' IS DISTINCT FROM 'https://securetoken.google.com/getsetwell-prod-510013'
    OR v_jwt->>'aud' IS DISTINCT FROM 'getsetwell-prod-510013'
    OR nullif(trim(coalesce(v_uid,'')), '') IS NULL THEN
      RAISE EXCEPTION 'FIREBASE_AUTH_REQUIRED';
  END IF;
  IF v_phone IS NULL OR v_phone !~ '^\+[1-9][0-9]{6,14}$' THEN
    RAISE EXCEPTION 'VERIFIED_PHONE_REQUIRED';
  END IF;

  INSERT INTO public.customer_identities (firebase_uid)
  VALUES (v_uid)
  ON CONFLICT (firebase_uid) DO UPDATE
    SET firebase_uid = EXCLUDED.firebase_uid
  RETURNING id INTO v_id;

  INSERT INTO public.customer_profiles (id, phone)
  VALUES (v_id, v_phone)
  ON CONFLICT (id) DO UPDATE
    SET phone = EXCLUDED.phone,
        updated_at = now();
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.ensure_customer_identity() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ensure_customer_identity() TO authenticated;

-- Re-target existing FKs; preserve ON DELETE semantics and nullable columns.

ALTER TABLE public.booking_requests DROP CONSTRAINT booking_requests_user_id_fkey;
ALTER TABLE public.booking_requests ADD CONSTRAINT booking_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.customer_identities(id) ON DELETE SET NULL;

ALTER TABLE public.customer_profiles DROP CONSTRAINT customer_profiles_id_fkey;
ALTER TABLE public.customer_profiles ADD CONSTRAINT customer_profiles_id_fkey FOREIGN KEY (id) REFERENCES public.customer_identities(id) ON DELETE CASCADE;

ALTER TABLE public.device_push_tokens DROP CONSTRAINT device_push_tokens_user_id_fkey;
ALTER TABLE public.device_push_tokens ADD CONSTRAINT device_push_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.customer_identities(id) ON DELETE CASCADE;

ALTER TABLE public.notification_outbox DROP CONSTRAINT notification_outbox_user_id_fkey;
ALTER TABLE public.notification_outbox ADD CONSTRAINT notification_outbox_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.customer_identities(id) ON DELETE CASCADE;

ALTER TABLE public.notification_preferences DROP CONSTRAINT notification_preferences_user_id_fkey;
ALTER TABLE public.notification_preferences ADD CONSTRAINT notification_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.customer_identities(id) ON DELETE CASCADE;

ALTER TABLE public.notifications DROP CONSTRAINT notifications_user_id_fkey;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.customer_identities(id) ON DELETE CASCADE;

ALTER TABLE public.sessions DROP CONSTRAINT sessions_user_id_fkey;
ALTER TABLE public.sessions ADD CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.customer_identities(id) ON DELETE CASCADE;


-- Replace the 13 original ownership policies without broadening privileges.
-- Existing predicate conditions (consent, status, etc.) are retained.

DROP POLICY IF EXISTS "Customers can create own booking requests" ON public.booking_requests;
CREATE POLICY "Customers can create own booking requests" ON "public"."booking_requests" FOR INSERT TO "authenticated" WITH CHECK ((("user_id" = (SELECT public.current_customer_id())) AND ("status" = 'new'::"text") AND ("share_details_consent" = true) AND ("consented_at" IS NOT NULL)));

DROP POLICY IF EXISTS "Customers can create own profile" ON public.customer_profiles;
CREATE POLICY "Customers can create own profile" ON "public"."customer_profiles" FOR INSERT TO "authenticated" WITH CHECK (((SELECT public.current_customer_id()) = "id"));

DROP POLICY IF EXISTS "Customers can manage own push tokens" ON public.device_push_tokens;
CREATE POLICY "Customers can manage own push tokens" ON "public"."device_push_tokens" TO "authenticated" USING ((( SELECT (SELECT public.current_customer_id()) AS "uid") = "user_id")) WITH CHECK ((( SELECT (SELECT public.current_customer_id()) AS "uid") = "user_id"));

DROP POLICY IF EXISTS "Customers can read own booking requests" ON public.booking_requests;
CREATE POLICY "Customers can read own booking requests" ON "public"."booking_requests" FOR SELECT TO "authenticated" USING (("user_id" = (SELECT public.current_customer_id())));

DROP POLICY IF EXISTS "Customers can read own notifications" ON public.notifications;
CREATE POLICY "Customers can read own notifications" ON "public"."notifications" FOR SELECT TO "authenticated" USING (("user_id" = (SELECT public.current_customer_id())));

DROP POLICY IF EXISTS "Customers can read own sessions" ON public.sessions;
CREATE POLICY "Customers can read own sessions" ON "public"."sessions" FOR SELECT TO "authenticated" USING (("user_id" = (SELECT public.current_customer_id())));

DROP POLICY IF EXISTS "Customers can update own notifications" ON public.notifications;
CREATE POLICY "Customers can update own notifications" ON "public"."notifications" FOR UPDATE TO "authenticated" USING (("user_id" = (SELECT public.current_customer_id()))) WITH CHECK (("user_id" = (SELECT public.current_customer_id())));

DROP POLICY IF EXISTS "Customers can update own profile" ON public.customer_profiles;
CREATE POLICY "Customers can update own profile" ON "public"."customer_profiles" FOR UPDATE TO "authenticated" USING (((SELECT public.current_customer_id()) = "id")) WITH CHECK (((SELECT public.current_customer_id()) = "id"));

DROP POLICY IF EXISTS "Customers can view own profile" ON public.customer_profiles;
CREATE POLICY "Customers can view own profile" ON "public"."customer_profiles" FOR SELECT TO "authenticated" USING (((SELECT public.current_customer_id()) = "id"));

DROP POLICY IF EXISTS "Users can cancel their own concierge requests" ON public.booking_requests;
CREATE POLICY "Users can cancel their own concierge requests" ON "public"."booking_requests" FOR UPDATE TO "authenticated" USING ((((SELECT public.current_customer_id()) = "user_id") AND ("request_type" = 'concierge_match'::"text"))) WITH CHECK ((((SELECT public.current_customer_id()) = "user_id") AND ("request_type" = 'concierge_match'::"text") AND ("status" = 'cancelled'::"text")));

DROP POLICY IF EXISTS "Users can create own notification preferences" ON public.notification_preferences;
CREATE POLICY "Users can create own notification preferences" ON "public"."notification_preferences" FOR INSERT TO "authenticated" WITH CHECK (((SELECT public.current_customer_id()) = "user_id"));

DROP POLICY IF EXISTS "Users can read own notification preferences" ON public.notification_preferences;
CREATE POLICY "Users can read own notification preferences" ON "public"."notification_preferences" FOR SELECT TO "authenticated" USING (((SELECT public.current_customer_id()) = "user_id"));

DROP POLICY IF EXISTS "Users can update own notification preferences" ON public.notification_preferences;
CREATE POLICY "Users can update own notification preferences" ON "public"."notification_preferences" FOR UPDATE TO "authenticated" USING (((SELECT public.current_customer_id()) = "user_id")) WITH CHECK (((SELECT public.current_customer_id()) = "user_id"));


-- Replace all database RPCs that currently call auth.uid().
-- Business rules and input parameters are otherwise preserved verbatim.

CREATE OR REPLACE FUNCTION "public"."cancel_session"("p_session_id" "uuid", "p_reason" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;

CREATE OR REPLACE FUNCTION "public"."claim_device_push_token"("p_token" "text", "p_platform" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    SET "row_security" TO 'off'
    AS $$
declare
  v_user_id uuid;
begin
  v_user_id := public.current_customer_id();

  if v_user_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_token is null or trim(p_token) = '' then
    raise exception 'TOKEN_REQUIRED';
  end if;

  if p_platform not in ('android', 'ios') then
    raise exception 'INVALID_PLATFORM';
  end if;

  insert into public.device_push_tokens (
    user_id,
    token,
    platform,
    updated_at
  )
  values (
    v_user_id,
    p_token,
    p_platform,
    now()
  )
  on conflict (token)
  do update
  set
    user_id = excluded.user_id,
    platform = excluded.platform,
    updated_at = now();
end;
$$;

CREATE OR REPLACE FUNCTION "public"."get_reschedule_availability"("p_session_id" "uuid") RETURNS TABLE("starts_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_session public.sessions%rowtype;
  v_start_date date;
  v_end_date date;
begin
  v_user_id := public.current_customer_id();

  if v_user_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select *
  into v_session
  from public.sessions
  where id = p_session_id
    and user_id = v_user_id;

  if not found then
    raise exception 'SESSION_NOT_FOUND';
  end if;

  -- Rolling 7-day window from today in Dubai time.
  v_start_date :=
    (now() at time zone 'Asia/Dubai')::date;

  v_end_date :=
    v_start_date + 6;

  return query
  with declared_slots as (
    select
      (
        (
          w.week_start_date
          + (w.day_of_week - 1)
        )::date
        + t
      ) at time zone 'Asia/Dubai' as slot_start
    from public.trainer_weekly_availability w
    cross join lateral unnest(w.start_times) as t
    where w.trainer_id = v_session.trainer_id
      and (
        w.week_start_date
        + (w.day_of_week - 1)
      )::date between v_start_date and v_end_date
  )
  select d.slot_start
  from declared_slots d
  where d.slot_start > now()

    -- Do not offer the currently booked time.
    and d.slot_start <> v_session.scheduled_at

    -- Remove already occupied trainer times.
    and not exists (
      select 1
      from public.sessions s
      where s.trainer_id = v_session.trainer_id
        and s.id <> v_session.id
        and lower(coalesce(s.status, '')) in (
          'confirmed',
          'booked'
        )
        and s.scheduled_at <
          d.slot_start + interval '1 hour'
        and s.scheduled_at + interval '1 hour' >
          d.slot_start
    )

  order by d.slot_start;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."get_trainer_booking_availability"("p_trainer_id" "uuid") RETURNS TABLE("starts_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_start_date date;
  v_end_date date;
begin
  v_user_id := public.current_customer_id();

  if v_user_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  v_start_date := (now() at time zone 'Asia/Dubai')::date;
  v_end_date := v_start_date + 6;

  return query
  with declared_slots as (
    select
      (
        (
          w.week_start_date + (w.day_of_week - 1)
        )::date + t
      ) at time zone 'Asia/Dubai' as slot_start
    from public.trainer_weekly_availability w
    cross join lateral unnest(w.start_times) as t
    where w.trainer_id = p_trainer_id
      and (
        w.week_start_date + (w.day_of_week - 1)
      )::date between v_start_date and v_end_date
  )
  select d.slot_start
  from declared_slots d
  where d.slot_start > now()
    and not exists (
      select 1
      from public.sessions s
      where s.trainer_id = p_trainer_id
        and lower(coalesce(s.status, '')) in (
          'confirmed',
          'booked'
        )
        and s.scheduled_at < d.slot_start + interval '1 hour'
        and s.scheduled_at + interval '1 hour' > d.slot_start
    )
  order by d.slot_start;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."mark_session_completion_prompt_shown"("p_session_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_user_id uuid;
begin
  v_user_id := public.current_customer_id();

  if v_user_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  update public.sessions
  set completion_prompt_shown_at = coalesce(completion_prompt_shown_at, now())
  where id = p_session_id
    and user_id = v_user_id
    and customer_outcome is null
    and lower(coalesce(status, '')) in ('confirmed', 'booked')
    and scheduled_at + interval '1 hour' <= now();

  if not found then
    raise exception 'SESSION_NOT_AVAILABLE_FOR_CONFIRMATION';
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."request_concierge_rematch"("p_request_id" "uuid", "p_reason" "text", "p_note" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  current_user_id uuid;
begin
  current_user_id := public.current_customer_id();

  if current_user_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_reason not in (
    'price',
    'days_times',
    'area',
    'trainer',
    'other'
  ) then
    raise exception 'INVALID_REMATCH_REASON';
  end if;

  update public.booking_requests
  set
    rejected_trainer_id = trainer_id,
    trainer_id = null,
    status = 'matching',

    rematch_reason = p_reason,
    rematch_note = nullif(trim(p_note), ''),
    rematch_requested_at = now(),

    match_outcome = null,
    match_reason = null,
    matched_at = null

  where id = p_request_id
    and user_id = current_user_id
    and request_type = 'concierge_match'
    and status = 'matched';

  if not found then
    raise exception 'MATCH_REQUEST_NOT_FOUND';
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."reschedule_session_weekly"("p_session_id" "uuid", "p_new_scheduled_at" timestamp with time zone) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_session public.sessions%rowtype;
  v_local_target timestamp without time zone;
  v_target_date date;
  v_week_start date;
  v_day_of_week integer;
  v_start_time time;
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
    raise exception 'SESSION_NOT_MOVABLE';
  end if;

  if coalesce(v_session.reschedule_count, 0) >= 1 then
    raise exception 'SESSION_ALREADY_MOVED';
  end if;

  if p_new_scheduled_at <= now() then
    raise exception 'SLOT_UNAVAILABLE';
  end if;

  v_local_target :=
    p_new_scheduled_at at time zone 'Asia/Dubai';

  v_target_date := v_local_target::date;
  v_day_of_week :=
    extract(isodow from v_local_target)::integer;
  v_week_start :=
    v_target_date - (v_day_of_week - 1);
  v_start_time := v_local_target::time;

  if not exists (
    select 1
    from public.trainer_weekly_availability w
    where w.trainer_id = v_session.trainer_id
      and w.week_start_date = v_week_start
      and w.day_of_week = v_day_of_week
      and v_start_time = any(w.start_times)
  ) then
    raise exception 'AVAILABILITY_NOT_FOUND';
  end if;

  if exists (
    select 1
    from public.sessions s
    where s.trainer_id = v_session.trainer_id
      and s.id <> v_session.id
      and lower(coalesce(s.status, '')) in (
        'confirmed',
        'booked'
      )
      and s.scheduled_at <
        p_new_scheduled_at + interval '1 hour'
      and s.scheduled_at + interval '1 hour' >
        p_new_scheduled_at
  ) then
    raise exception 'SLOT_UNAVAILABLE';
  end if;

  update public.sessions
  set
    scheduled_at = p_new_scheduled_at,
    reschedule_count =
      coalesce(reschedule_count, 0) + 1,
    rescheduled_at = now()
  where id = v_session.id;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."submit_session_outcome"("p_session_id" "uuid", "p_outcome" "text", "p_feedback_category" "text" DEFAULT NULL::"text", "p_feedback_note" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_session public.sessions%rowtype;
  v_new_status text;
  v_normalized_outcome text;
  v_note text;
begin
  v_user_id := public.current_customer_id();

  if v_user_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  v_normalized_outcome := lower(trim(coalesce(p_outcome, '')));

  if v_normalized_outcome not in (
    'took_place_well',
    'took_place_fine',
    'took_place_not_hoped',
    'did_not_take_place',
    'cut_short'
  ) then
    raise exception 'INVALID_SESSION_OUTCOME';
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

  if lower(coalesce(v_session.status, '')) in ('cancelled', 'canceled') then
    raise exception 'SESSION_CANCELLED';
  end if;

  if v_session.scheduled_at + interval '1 hour' > now() then
    raise exception 'SESSION_NOT_ENDED';
  end if;

  if v_session.customer_outcome is not null then
    raise exception 'SESSION_OUTCOME_ALREADY_SUBMITTED';
  end if;

  v_note := nullif(trim(coalesce(p_feedback_note, '')), '');

  if v_note is not null and char_length(v_note) > 250 then
    raise exception 'FEEDBACK_NOTE_TOO_LONG';
  end if;

  if v_normalized_outcome in (
    'did_not_take_place',
    'cut_short'
  ) then
    v_new_status := 'reported';
  else
    v_new_status := 'completed';
  end if;

  update public.sessions
  set
    status = v_new_status,
    customer_outcome = v_normalized_outcome,
    customer_feedback_category = nullif(trim(coalesce(p_feedback_category, '')), ''),
    customer_feedback_note = v_note,
    customer_confirmed_at = now(),
    completion_prompt_shown_at = coalesce(completion_prompt_shown_at, now())
  where id = p_session_id;

  -- The request itself is finished once the booked session has concluded.
  if v_session.booking_request_id is not null then
    update public.booking_requests
    set status = 'completed'
    where id = v_session.booking_request_id
      and user_id = v_user_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'session_id', p_session_id,
    'status', v_new_status,
    'outcome', v_normalized_outcome,
    'submitted_at', now()
  );
end;
$$;


COMMIT;
-- After provisioning Firebase user with RPC ensure_customer_identity,
-- verify current_customer_id(), RLS isolation and all RPCs in a staging environment.
-- DO NOT push until storage policies, Edge Functions, client, and preflight testing
-- have been updated for the Firebase identity source as a single cutover.
