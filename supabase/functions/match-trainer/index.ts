import { createClient } from "npm:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const adminSecret = Deno.env.get("NOTIFICATION_ADMIN_SECRET");

if (!supabaseUrl || !serviceRoleKey || !adminSecret) {
  throw new Error("Missing required environment variables");
}

const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const eligibleStatuses = ["new", "pending", "contacted", "matching"];
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type Booking = {
  id: string;
  user_id: string | null;
  request_type: string;
  status: string;
  trainer_id: string | null;
  matched_at: string | null;
};

function respond(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

async function activeCustomer(customerId: string): Promise<boolean> {
  const { data, error } = await supabaseAdmin
    .from("customer_identities")
    .select("firebase_uid")
    .eq("id", customerId)
    .maybeSingle();
  if (error) throw error;
  return typeof data?.firebase_uid === "string" && data.firebase_uid.length > 0;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return respond({ error: "METHOD_NOT_ALLOWED" }, 405);
  }
  const suppliedSecret = req.headers.get("x-admin-secret");
  if (!suppliedSecret || suppliedSecret !== adminSecret) {
    return respond({ error: "UNAUTHORIZED" }, 401);
  }

  let payload: unknown;
  try {
    payload = await req.json();
  } catch {
    return respond({ error: "INVALID_JSON" }, 400);
  }
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return respond({ error: "INVALID_PAYLOAD" }, 400);
  }
  const input = payload as Record<string, unknown>;
  const bookingRequestId = input.booking_request_id;
  const trainerId = input.trainer_id;
  if (
    typeof bookingRequestId !== "string" || typeof trainerId !== "string" ||
    !uuidPattern.test(bookingRequestId) || !uuidPattern.test(trainerId)
  ) {
    return respond({ error: "INVALID_REQUEST_IDS" }, 400);
  }

  try {
    const { data: booking, error: bookingError } = await supabaseAdmin
      .from("booking_requests")
      .select("id, user_id, request_type, status, trainer_id, matched_at")
      .eq("id", bookingRequestId)
      .maybeSingle();
    if (bookingError) throw bookingError;
    if (!booking) return respond({ error: "BOOKING_NOT_FOUND" }, 404);
    if (booking.request_type !== "concierge_match") {
      return respond({ error: "NOT_CONCIERGE_REQUEST" }, 400);
    }
    if (!booking.user_id) return respond({ error: "BOOKING_HAS_NO_USER" }, 400);
    if (!(await activeCustomer(booking.user_id))) {
      return respond({ error: "CUSTOMER_ACCOUNT_INACTIVE" }, 409);
    }

    const { data: trainer, error: trainerError } = await supabaseAdmin
      .from("trainers")
      .select("id, full_name, is_active, is_verified")
      .eq("id", trainerId)
      .maybeSingle();
    if (trainerError) throw trainerError;
    if (!trainer) return respond({ error: "TRAINER_NOT_FOUND" }, 404);

    const sameExistingMatch = booking.status === "matched" &&
      booking.trainer_id === trainerId && booking.matched_at != null;
    // Allow an idempotent retry for a pre-existing match, even if the trainer
    // has since been deactivated. Do not create new matches to inactive trainers.
    if (
      !sameExistingMatch &&
      (trainer.is_active !== true || trainer.is_verified !== true)
    ) {
      return respond({ error: "TRAINER_NOT_ACTIVE" }, 409);
    }

    let matchedBooking: Booking = booking as Booking;
    let newlyMatched = false;
    if (!sameExistingMatch) {
      if (!eligibleStatuses.includes(booking.status)) {
        return respond({
          error: "BOOKING_NOT_ELIGIBLE",
          current_status: booking.status,
        }, 409);
      }
      if (booking.trainer_id !== null) {
        return respond({ error: "TRAINER_ALREADY_ASSIGNED" }, 409);
      }

      const { data: updatedBooking, error: updateError } = await supabaseAdmin
        .from("booking_requests")
        .update({
          trainer_id: trainerId,
          status: "matched",
          matched_at: new Date().toISOString(),
        })
        .eq("id", bookingRequestId)
        .eq("user_id", booking.user_id)
        .eq("request_type", "concierge_match")
        .in("status", eligibleStatuses)
        .is("trainer_id", null)
        .select("id, user_id, request_type, status, trainer_id, matched_at")
        .maybeSingle();
      if (updateError) throw updateError;
      if (updatedBooking) {
        matchedBooking = updatedBooking as Booking;
        newlyMatched = true;
      } else {
        const { data: latest, error: latestError } = await supabaseAdmin
          .from("booking_requests")
          .select("id, user_id, request_type, status, trainer_id, matched_at")
          .eq("id", bookingRequestId)
          .maybeSingle();
        if (latestError) throw latestError;
        if (
          !latest || latest.request_type !== "concierge_match" ||
          latest.status !== "matched" || latest.trainer_id !== trainerId ||
          !latest.matched_at || latest.user_id !== booking.user_id
        ) {
          return respond({ error: "BOOKING_ALREADY_CHANGED" }, 409);
        }
        matchedBooking = latest as Booking;
      }
    }

    if (!matchedBooking.matched_at || !matchedBooking.user_id) {
      return respond({ error: "MATCH_TIMESTAMP_MISSING" }, 409);
    }
    // Recheck before notifying: account deletion may have started during matching.
    // A fully atomic deletion/matching guarantee would require a database RPC.
    if (!(await activeCustomer(matchedBooking.user_id))) {
      return respond({
        error: "CUSTOMER_ACCOUNT_INACTIVE",
        booking_matched: true,
      }, 409);
    }

    const eventKey =
      `trainer_match:${matchedBooking.id}:${matchedBooking.matched_at}`;
    const notificationPayload = {
      user_id: matchedBooking.user_id,
      booking_request_id: matchedBooking.id,
      type: "trainer_match",
      title: "We picked your trainer",
      body: `${trainer.full_name} looks like the right fit. Tap to see why.`,
      event_key: eventKey,
      data: { booking_request_id: matchedBooking.id, trainer_id: trainerId },
    };

    let notificationResponse: Response;
    try {
      notificationResponse = await fetch(
        `${supabaseUrl}/functions/v1/send-notification`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-admin-secret": adminSecret,
          },
          body: JSON.stringify(notificationPayload),
          signal: AbortSignal.timeout(30000),
        },
      );
    } catch (error) {
      console.error("Notification request failed:", error);
      return respond({
        success: false,
        error: "NOTIFICATION_DELIVERY_FAILED",
        booking_matched: true,
        retry_safe: true,
        booking_request_id: matchedBooking.id,
        event_key: eventKey,
      }, 502);
    }

    let notificationResult: Record<string, unknown>;
    try {
      const parsed: unknown = await notificationResponse.json();
      if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
        throw new Error("Invalid response");
      }
      notificationResult = parsed as Record<string, unknown>;
    } catch {
      return respond({
        success: false,
        error: "INVALID_NOTIFICATION_RESPONSE",
        booking_matched: true,
        retry_safe: true,
        booking_request_id: matchedBooking.id,
        event_key: eventKey,
      }, 502);
    }
    if (!notificationResponse.ok || notificationResult.success !== true) {
      console.error(
        "Notification service failed:",
        notificationResponse.status,
      );
      return respond({
        success: false,
        error: "NOTIFICATION_SERVICE_FAILED",
        booking_matched: true,
        retry_safe: true,
        booking_request_id: matchedBooking.id,
        event_key: eventKey,
      }, 502);
    }

    return respond({
      success: true,
      booking_request_id: matchedBooking.id,
      trainer_id: trainerId,
      trainer_name: trainer.full_name,
      status: matchedBooking.status,
      matched_at: matchedBooking.matched_at,
      newly_matched: newlyMatched,
      notification_id: notificationResult.notification_id ?? null,
      notification_skipped: notificationResult.skipped === true,
      notification_reason: notificationResult.reason ?? null,
      push_sent: notificationResult.push_sent ?? 0,
      push_failed: notificationResult.push_failed ?? 0,
      event_key: eventKey,
    });
  } catch (error) {
    console.error("match-trainer failed:", error);
    return respond({ success: false, error: "INTERNAL_SERVER_ERROR" }, 500);
  }
});
