import { createClient } from "npm:@supabase/supabase-js@2";
import { GoogleAuth } from "npm:google-auth-library@9";

type NotificationType =
  | "trainer_match"
  | "booking_confirmed"
  | "booking_cancelled"
  | "booking_rescheduled"
  | "session_reminder"
  | "session_feedback"
  | "new_trainer";

type NotificationBody = {
  user_id: string;
  type: NotificationType;
  title: string;
  body: string;
  booking_request_id?: string | null;
  event_key?: string | null;
  data?: Record<string, string>;
};

type FcmResponse = {
  ok: boolean;
  status: number;
  body: Record<string, unknown> | null;
};

type DeliveryState = {
  id: string;
  status: string;
  attempts: number;
  next_attempt_at: string;
  lease_expires_at: string | null;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-admin-secret",
};

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID");
const firebaseClientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL");
const firebasePrivateKey = Deno.env.get("FIREBASE_PRIVATE_KEY")
  ?.replace(/\\n/g, "\n");
const notificationAdminSecret = Deno.env.get("NOTIFICATION_ADMIN_SECRET");

if (
  !supabaseUrl || !serviceRoleKey || !firebaseProjectId ||
  !firebaseClientEmail || !firebasePrivateKey || !notificationAdminSecret
) {
  throw new Error("Missing required notification environment variables");
}

const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const googleAuth = new GoogleAuth({
  credentials: {
    client_email: firebaseClientEmail,
    private_key: firebasePrivateKey,
  },
  scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
});

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function preferenceForType(
  type: NotificationType,
):
  | "trainer_matches"
  | "booking_updates"
  | "session_reminders"
  | "new_trainers" {
  switch (type) {
    case "trainer_match":
      return "trainer_matches";
    case "booking_confirmed":
    case "booking_cancelled":
    case "booking_rescheduled":
      return "booking_updates";
    case "session_reminder":
    case "session_feedback":
      return "session_reminders";
    case "new_trainer":
      return "new_trainers";
  }
}

function defaultPreference(key: ReturnType<typeof preferenceForType>): boolean {
  return key !== "new_trainers";
}

async function getAccessToken(): Promise<string> {
  const client = await googleAuth.getClient();
  const response = await client.getAccessToken();
  const token = typeof response === "string" ? response : response?.token;
  if (!token) throw new Error("Could not obtain Firebase access token");
  return token;
}

async function sendFcm(args: {
  token: string;
  title: string;
  body: string;
  data: Record<string, string>;
}): Promise<FcmResponse> {
  const accessToken = await getAccessToken();
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: args.token,
          notification: { title: args.title, body: args.body },
          data: args.data,
          android: { priority: "high", notification: { sound: "default" } },
          apns: { payload: { aps: { sound: "default" } } },
        },
      }),
      signal: AbortSignal.timeout(20_000),
    },
  );
  let body: Record<string, unknown> | null = null;
  try {
    const parsed: unknown = await response.json();
    if (isRecord(parsed)) body = parsed;
  } catch { /* An HTTP response without JSON is still a response. */ }
  return { ok: response.ok, status: response.status, body };
}

function fcmErrorCode(result: FcmResponse): string | null {
  const error = result.body?.error;
  if (!isRecord(error)) return null;
  const details = error.details;
  if (Array.isArray(details)) {
    for (const detail of details) {
      if (isRecord(detail) && typeof detail.errorCode === "string") {
        return detail.errorCode;
      }
    }
  }
  return typeof error.status === "string" ? error.status : null;
}

function permanentFcmFailure(result: FcmResponse): boolean {
  const code = fcmErrorCode(result);
  // INVALID_ARGUMENT may also indicate an invalid *payload*. Do not delete
  // the token on that error without differentiating the underlying reason.
  return code === "UNREGISTERED" || code === "SENDER_ID_MISMATCH";
}

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const notificationTypes = new Set<NotificationType>([
  "trainer_match",
  "booking_confirmed",
  "booking_cancelled",
  "booking_rescheduled",
  "session_reminder",
  "session_feedback",
  "new_trainer",
]);
function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
function validatePayload(value: unknown): NotificationBody | null {
  if (!isRecord(value)) return null;
  if (typeof value.user_id !== "string" || !uuidPattern.test(value.user_id)) {
    return null;
  }
  if (
    typeof value.type !== "string" ||
    !notificationTypes.has(value.type as NotificationType)
  ) return null;
  if (
    typeof value.title !== "string" || !value.title.trim() ||
    value.title.length > 120
  ) return null;
  if (
    typeof value.body !== "string" || !value.body.trim() ||
    value.body.length > 1000
  ) return null;
  if (
    value.booking_request_id != null &&
    (typeof value.booking_request_id !== "string" ||
      !uuidPattern.test(value.booking_request_id))
  ) return null;
  if (
    value.event_key != null &&
    (typeof value.event_key !== "string" || !value.event_key ||
      value.event_key.length > 250)
  ) return null;
  if (value.data != null) {
    if (!isRecord(value.data) || Object.keys(value.data).length > 20) {
      return null;
    }
    for (const [key, item] of Object.entries(value.data)) {
      if (
        !/^[A-Za-z0-9_]{1,64}$/.test(key) || typeof item !== "string" ||
        item.length > 1024
      ) return null;
    }
  }
  return value as NotificationBody;
}

const DELIVERY_LEASE_MS = 90_000;
const MAX_DELIVERY_ATTEMPTS = 6;

// Claim one device atomically. The unique constraint protects creation, while
// conditional updates prevent two overlapping dispatchers sending simultaneously.
async function claimDelivery(outboxId: string, token: string): Promise<{
  claimed: DeliveryState | null;
  alreadyAccepted: boolean;
  permanentlyFailed: boolean;
  deferred: boolean;
}> {
  const { error: insertError } = await supabaseAdmin
    .from("notification_push_deliveries")
    .upsert({ outbox_id: outboxId, device_token: token }, {
      onConflict: "outbox_id,device_token",
      ignoreDuplicates: true,
    });
  if (insertError) throw insertError;

  const { data: state, error: loadError } = await supabaseAdmin
    .from("notification_push_deliveries")
    .select("id,status,attempts,next_attempt_at,lease_expires_at")
    .eq("outbox_id", outboxId)
    .eq("device_token", token)
    .single();
  if (loadError) throw loadError;
  const delivery = state as DeliveryState;
  if (delivery.status === "accepted") {
    return {
      claimed: null,
      alreadyAccepted: true,
      permanentlyFailed: false,
      deferred: false,
    };
  }
  if (delivery.status === "permanent_failed") {
    return {
      claimed: null,
      alreadyAccepted: false,
      permanentlyFailed: true,
      deferred: false,
    };
  }

  const now = Date.now();
  const readyAt = delivery.status === "processing"
    ? delivery.lease_expires_at
    : delivery.next_attempt_at;
  if (readyAt && new Date(readyAt).getTime() > now) {
    return {
      claimed: null,
      alreadyAccepted: false,
      permanentlyFailed: false,
      deferred: true,
    };
  }
  if (delivery.attempts >= MAX_DELIVERY_ATTEMPTS) {
    const { error } = await supabaseAdmin.from("notification_push_deliveries")
      .update({
        status: "permanent_failed",
        last_error: "MAX_DELIVERY_ATTEMPTS",
        updated_at: new Date().toISOString(),
      })
      .eq("id", delivery.id).eq("status", delivery.status).eq(
        "attempts",
        delivery.attempts,
      );
    if (error) throw error;
    return {
      claimed: null,
      alreadyAccepted: false,
      permanentlyFailed: true,
      deferred: false,
    };
  }

  const leaseExpiry = new Date(now + DELIVERY_LEASE_MS).toISOString();
  const { data: claimed, error: claimError } = await supabaseAdmin
    .from("notification_push_deliveries")
    .update({
      status: "processing",
      attempts: delivery.attempts + 1,
      lease_expires_at: leaseExpiry,
      updated_at: new Date().toISOString(),
    })
    .eq("id", delivery.id)
    .eq("status", delivery.status)
    .eq("attempts", delivery.attempts)
    .select("id,status,attempts,next_attempt_at,lease_expires_at")
    .maybeSingle();
  if (claimError) throw claimError;
  return {
    claimed: claimed as DeliveryState | null,
    alreadyAccepted: false,
    permanentlyFailed: false,
    deferred: claimed == null,
  };
}

async function finishDelivery(
  claimed: DeliveryState,
  status: "accepted" | "retryable_failed" | "permanent_failed",
  error: string | null,
  fcmMessageId: string | null = null,
): Promise<void> {
  const timestamp = new Date().toISOString();
  const delayMinutes = Math.min(60, 2 ** Math.min(claimed.attempts, 6));
  const { data, error: dbError } = await supabaseAdmin
    .from("notification_push_deliveries")
    .update({
      status,
      next_attempt_at: status === "retryable_failed"
        ? new Date(Date.now() + delayMinutes * 60_000).toISOString()
        : timestamp,
      lease_expires_at: null,
      accepted_at: status === "accepted" ? timestamp : null,
      fcm_message_id: status === "accepted" ? fcmMessageId : null,
      last_error: error,
      updated_at: timestamp,
    })
    .eq("id", claimed.id)
    .eq("status", "processing")
    .eq("attempts", claimed.attempts)
    .select("id")
    .maybeSingle();
  if (dbError || !data) throw new Error("DELIVERY_STATE_UPDATE_FAILED");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "METHOD_NOT_ALLOWED" }, 405);
  }
  if (req.headers.get("x-admin-secret") !== notificationAdminSecret) {
    return jsonResponse({ error: "UNAUTHORIZED" }, 401);
  }

  let payload: NotificationBody | null;
  try {
    payload = validatePayload(await req.json());
  } catch {
    return jsonResponse({ error: "INVALID_JSON" }, 400);
  }
  if (!payload) {
    return jsonResponse({ error: "INVALID_NOTIFICATION_PAYLOAD" }, 400);
  }

  const {
    user_id,
    type,
    title,
    body,
    booking_request_id = null,
    event_key = null,
    data = {},
  } = payload;
  try {
    const { data: identity, error: identityError } = await supabaseAdmin
      .from("customer_identities").select("firebase_uid").eq("id", user_id)
      .maybeSingle();
    if (identityError) throw identityError;
    if (!identity?.firebase_uid) {
      return jsonResponse({
        success: true,
        skipped: true,
        reason: "ACCOUNT_UNAVAILABLE",
      });
    }

    const preferenceKey = preferenceForType(type);
    const { data: preferences, error: preferenceError } = await supabaseAdmin
      .from("notification_preferences")
      .select("trainer_matches,booking_updates,session_reminders,new_trainers")
      .eq("user_id", user_id).maybeSingle();
    if (preferenceError) throw preferenceError;
    const enabled = preferences == null
      ? defaultPreference(preferenceKey)
      : preferences[preferenceKey] === true;
    if (!enabled) {
      return jsonResponse({
        success: true,
        skipped: true,
        reason: "NOTIFICATION_DISABLED",
        type,
      });
    }

    // Insert only once. A duplicate event reuses its notification instead of
    // abandoning delivery on a retry.
    const { data: inserted, error: insertError } = await supabaseAdmin
      .from("notifications")
      .insert({
        user_id,
        booking_request_id,
        type,
        title,
        body,
        is_read: false,
        event_key,
      })
      .select("id")
      .single();
    let notificationId: string;
    if (!insertError && inserted) {
      notificationId = inserted.id;
    } else if (event_key && insertError?.code === "23505") {
      const { data: existing, error: existingError } = await supabaseAdmin
        .from("notifications").select("id,user_id").eq("event_key", event_key)
        .single();
      if (existingError || !existing || existing.user_id !== user_id) {
        throw new Error("EVENT_KEY_CONFLICT");
      }
      notificationId = existing.id;
    } else {
      throw insertError ?? new Error("NOTIFICATION_INSERT_FAILED");
    }

    const { data: tokenRows, error: tokenError } = await supabaseAdmin
      .from("device_push_tokens").select("token").eq("user_id", user_id);
    if (tokenError) throw tokenError;
    if (!tokenRows?.length) {
      return jsonResponse({
        success: true,
        notification_id: notificationId,
        push_sent: 0,
        push_failed: 0,
        reason: "NO_REGISTERED_DEVICES",
      });
    }

    const pushData: Record<string, string> = {
      ...data,
      notification_id: notificationId,
      type,
    };
    if (booking_request_id) pushData.booking_request_id = booking_request_id;

    // Only outbox-managed events use persistent per-device delivery tracking.
    // Direct internal notification calls retain the existing best-effort path.
    let outboxId: string | null = null;
    if (event_key) {
      const { data: outbox, error: outboxError } = await supabaseAdmin
        .from("notification_outbox").select("id,user_id")
        .eq("event_key", event_key).maybeSingle();
      if (outboxError) throw outboxError;
      if (outbox) {
        if (outbox.user_id !== user_id) {
          throw new Error("OUTBOX_CUSTOMER_MISMATCH");
        }
        outboxId = outbox.id;
      }
    }

    let sent = 0;
    let failed = 0;
    let deferred = 0;
    const invalidTokens: string[] = [];

    for (const row of tokenRows) {
      const token = row.token?.toString();
      if (!token) continue;
      let claim: DeliveryState | null = null;
      if (outboxId) {
        const result = await claimDelivery(outboxId, token);
        if (result.alreadyAccepted || result.permanentlyFailed) continue;
        if (result.deferred || !result.claimed) {
          deferred++;
          continue;
        }
        claim = result.claimed;
      }
      try {
        const result = await sendFcm({ token, title, body, data: pushData });
        if (result.ok) {
          sent++;
          if (claim) {
            const messageId = typeof result.body?.name === "string"
              ? result.body.name
              : null;
            await finishDelivery(claim, "accepted", null, messageId);
          }
        } else {
          failed++;
          const permanent = permanentFcmFailure(result);
          console.error("FCM send failed", {
            status: result.status,
            code: fcmErrorCode(result),
          });
          if (claim) {
            await finishDelivery(
              claim,
              permanent ? "permanent_failed" : "retryable_failed",
              `FCM_HTTP_${result.status}`,
            );
          }
          if (permanent) invalidTokens.push(token);
        }
      } catch (error) {
        // An exception can be an uncertain delivery: Firebase might have
        // accepted the request. A retry can therefore produce a duplicate.
        console.error(
          "FCM delivery exception",
          error instanceof Error ? error.message : "UNKNOWN",
        );
        failed++;
        if (claim) {
          await finishDelivery(
            claim,
            "retryable_failed",
            "FCM_REQUEST_UNCERTAIN",
          );
        }
      }
    }

    if (invalidTokens.length) {
      const { error: deletionError } = await supabaseAdmin.from(
        "device_push_tokens",
      )
        .delete().eq("user_id", user_id).in("token", invalidTokens);
      if (deletionError) {
        console.error(
          "Failed to remove invalid FCM tokens",
          deletionError.message,
        );
      }
    }

    if (outboxId && (failed > 0 || deferred > 0)) {
      // Existing dispatcher retries on non-2xx and preserves the outbox event.
      // Accepted device rows will not be resent.
      return jsonResponse({
        success: false,
        error: "PUSH_DELIVERY_PENDING",
        notification_id: notificationId,
        push_sent: sent,
        push_failed: failed,
        push_deferred: deferred,
      }, 503);
    }
    return jsonResponse({
      success: true,
      notification_id: notificationId,
      push_sent: sent,
      push_failed: failed,
      invalid_tokens_removed: invalidTokens.length,
    });
  } catch (error) {
    console.error(
      "send-notification failed",
      error instanceof Error ? error.message : "UNKNOWN",
    );
    return jsonResponse(
      { success: false, error: "NOTIFICATION_SEND_FAILED" },
      500,
    );
  }
});
