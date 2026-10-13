import { createClient } from "npm:@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL");

const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const adminSecret = Deno.env.get("NOTIFICATION_ADMIN_SECRET");

if (!url || !serviceKey || !adminSecret) {
  throw new Error("Missing notification configuration");
}

const db = createClient(url, serviceKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const BATCH_SIZE = 25;

const LEASE_MS = 5 * 60 * 1000;

type OutboxEvent = {
  id: string;

  event_key: string;

  user_id: string;

  session_id: string | null;

  booking_request_id: string | null;

  type: string;

  title: string;

  body: string;

  status: string;

  attempts: number;
};

type SenderResult = {
  success?: boolean;

  skipped?: boolean;

  reason?: string;

  push_failed?: number;
  push_deferred?: number;
  error?: string;
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

async function finishEvent(
  event: OutboxEvent,
  status: "sent" | "skipped",
  reason: string | null,
): Promise<void> {
  const { data, error } = await db.from("notification_outbox")
    .update({
      status,

      processed_at: new Date().toISOString(),

      last_error: reason,
    })
    .eq("id", event.id)
    .eq("status", "processing")
    .eq("attempts", event.attempts + 1)
    .select("id")
    .maybeSingle();

  if (error || !data) {
    throw new Error("OUTBOX_FINISH_FAILED");
  }
}

async function canDeliverToCustomer(userId: string): Promise<boolean> {
  // An account being deleted must not receive new push notifications.

  const { data, error } = await db.from("customer_identities")
    .select("firebase_uid")
    .eq("id", userId)
    .maybeSingle();

  if (error) throw error;

  return typeof data?.firebase_uid === "string" &&
    data.firebase_uid.length > 0;
}

async function invalidEventReason(event: OutboxEvent): Promise<string | null> {
  if (!(await canDeliverToCustomer(event.user_id))) {
    return "Customer identity is unavailable or detached";
  }

  if (event.type === "session_reminder") {
    if (!event.session_id) return "Reminder has no session";

    const { data: session, error } = await db.from("sessions")
      .select("id, user_id, status, scheduled_at")
      .eq("id", event.session_id)
      .maybeSingle();

    if (error) throw error;

    // The event key contains the UTC timestamp in YYYYMMDDHHmmssSSS000 format.

    const timestampMatch = event.event_key.match(
      /^session_reminder:[0-9a-f-]+:(24h|1h):(\d{20})$/i,
    );

    const scheduledTime = session?.scheduled_at
      ? new Date(session.scheduled_at)
      : null;

    const scheduledKey = scheduledTime &&
        !Number.isNaN(scheduledTime.getTime())
      ? scheduledTime.toISOString().replace(/[-:.TZ]/g, "").padEnd(20, "0")
      : null;

    const stillValid = session != null &&
      session.user_id === event.user_id &&
      ["confirmed", "booked"].includes(session.status?.toLowerCase() ?? "") &&
      scheduledTime != null &&
      scheduledTime.getTime() > Date.now() &&
      timestampMatch?.[2] === scheduledKey;

    if (!stillValid) {
      return "Reminder skipped: session cancelled, moved, expired or invalid";
    }
  }

  if (event.type === "session_feedback") {
    if (!event.session_id) return "Feedback has no session";

    const { data: session, error } = await db.from("sessions")
      .select("id, user_id, status, customer_outcome")
      .eq("id", event.session_id)
      .maybeSingle();

    if (error) throw error;

    const stillValid = session != null &&
      session.user_id === event.user_id &&
      ["confirmed", "booked"].includes(session.status?.toLowerCase() ?? "") &&
      session.customer_outcome === null;

    if (!stillValid) {
      return "Feedback skipped: session cancelled, missing or already reviewed";
    }
  }

  return null;
}

async function dispatch(event: OutboxEvent): Promise<SenderResult> {
  const response = await fetch(`${url}/functions/v1/send-notification`, {
    method: "POST",

    headers: {
      "Content-Type": "application/json",

      "x-admin-secret": adminSecret!,
    },

    body: JSON.stringify({
      user_id: event.user_id,

      type: event.type,

      title: event.title,

      body: event.body,

      booking_request_id: event.booking_request_id,

      event_key: event.event_key,

      data: event.session_id ? { session_id: event.session_id } : {},
    }),

    signal: AbortSignal.timeout(30_000),
  });

  let result: SenderResult;

  try {
    result = await response.json() as SenderResult;
  } catch {
    throw new Error(`NOTIFICATION_RESPONSE_INVALID:${response.status}`);
  }

  if (!response.ok || result?.success !== true) {
    // The sender returns 503 while at least one tracked device delivery
    // remains retryable or leased. Preserve the outbox entry for retry.
    const reason = result?.error === "PUSH_DELIVERY_PENDING"
      ? "PUSH_DELIVERY_PENDING"
      : `NOTIFICATION_SERVICE_FAILED:${response.status}`;
    throw new Error(reason);
  }

  // A successful HTTP response must not hide partial FCM failures.
  // Older sender versions could return success:true with push_failed > 0.
  const failures = Number(result.push_failed ?? 0);
  const deferred = Number(result.push_deferred ?? 0);
  if (
    !Number.isFinite(failures) || !Number.isFinite(deferred) ||
    failures > 0 || deferred > 0
  ) {
    throw new Error("PUSH_DELIVERY_INCOMPLETE");
  }

  return result;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return respond({ error: "METHOD_NOT_ALLOWED" }, 405);
  }

  if (
    !req.headers.get("x-admin-secret") ||
    req.headers.get("x-admin-secret") !== adminSecret
  ) {
    return respond({ error: "UNAUTHORIZED" }, 401);
  }

  const now = new Date().toISOString();

  try {
    const { data: ready, error: readyError } = await db
      .from("notification_outbox")
      .select("*")
      .in("status", ["pending", "failed"])
      .lte("next_attempt_at", now)
      .order("created_at", { ascending: true })
      .limit(BATCH_SIZE);

    if (readyError) throw readyError;

    const { data: expired, error: expiredError } = await db
      .from("notification_outbox")
      .select("*")
      .eq("status", "processing")
      .lte("next_attempt_at", now)
      .order("created_at", { ascending: true })
      .limit(BATCH_SIZE);

    if (expiredError) throw expiredError;

    const events = [...(ready ?? []), ...(expired ?? [])] as OutboxEvent[];

    let processed = 0;

    let sent = 0;

    let skipped = 0;

    let failed = 0;

    for (const event of events) {
      const leaseUntil = new Date(Date.now() + LEASE_MS).toISOString();

      const { data: claim, error: claimError } = await db
        .from("notification_outbox")
        .update({
          status: "processing",

          attempts: event.attempts + 1,

          next_attempt_at: leaseUntil,
        })
        .eq("id", event.id)
        .eq("status", event.status)
        .eq("attempts", event.attempts)
        .lte("next_attempt_at", now)
        .select("id")
        .maybeSingle();

      if (claimError) {
        console.error("Notification claim failed", {
          eventId: event.id,

          error: claimError,
        });

        failed++;

        continue;
      }

      if (!claim) continue;

      processed++;

      // Everything after the claim must be handled per-event, including

      // database lookups and validation, so one bad record cannot stop the batch.

      try {
        const invalidReason = await invalidEventReason(event);

        if (invalidReason) {
          await finishEvent(event, "skipped", invalidReason);

          skipped++;

          continue;
        }

        const result = await dispatch(event);

        const senderSkipped = result.skipped === true;

        const reason = senderSkipped ? result.reason ?? "SENDER_SKIPPED" : null;

        // dispatch() has already rejected incomplete FCM delivery. A terminal
        // outcome can now safely close the outbox event.
        await finishEvent(event, senderSkipped ? "skipped" : "sent", reason);

        if (senderSkipped) skipped++;
        else sent++;
      } catch (error) {
        console.error("Notification dispatch failed", {
          eventId: event.id,

          error: error instanceof Error ? error.message : "UNKNOWN_ERROR",
        });

        // The sender reuses in-app notifications and persists device acceptance.
        // Retries avoid resending to devices already accepted by FCM.
        const delayMinutes = Math.min(60, 2 ** Math.min(event.attempts, 6));

        const { error: retryError } = await db.from("notification_outbox")
          .update({
            status: "failed",

            next_attempt_at: new Date(Date.now() + delayMinutes * 60_000)
              .toISOString(),

            last_error: error instanceof Error
              ? error.message
              : "UNKNOWN_ERROR",
          })
          .eq("id", event.id)
          .eq("status", "processing")
          .eq("attempts", event.attempts + 1);

        if (retryError) {
          console.error("Notification retry update failed", {
            eventId: event.id,

            error: retryError,
          });
        }

        failed++;
      }
    }

    return respond({ success: true, processed, sent, skipped, failed });
  } catch (error) {
    console.error("Dispatcher failed", error);

    return respond({ success: false, error: "DISPATCHER_FAILED" }, 500);
  }
});
