import { createClient } from "npm:@supabase/supabase-js@2";
import { createRemoteJWKSet, jwtVerify } from "npm:jose@6";

/**
 * GetSetWell Firebase-authenticated account closure.
 *
 * Requires SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, FIREBASE_WEB_API_KEY.
 * Set [functions.delete-account] verify_jwt = false in supabase/config.toml.
 * This function verifies the Firebase ID token itself.
 *
 * Required local migrations (deploy before deploying this function):
 *  - customer_account_deletion_tracking
 *  - account_deletion_atomic_operations
 *  - account_deletion_recovery_operations
 *  - account_deletion_retry_safeguards
 *  - account_deletion_personal_data_cleanup
 *
 * Deletion is not a transaction across Firebase, Storage and Postgres.
 * The deletion tracker must be reconciled when a step is interrupted.
 * Historical booking/session/financial records and customer_identities are
 * deliberately preserved until the documented retention review is completed.
 * Never describe HTTP 202 as complete personal-data erasure.
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

const firebaseProjectId = "getsetwell-prod-510013";
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const firebaseApiKey = Deno.env.get("FIREBASE_WEB_API_KEY");
if (!supabaseUrl || !serviceRoleKey || !firebaseApiKey) {
  throw new Error("Missing account-deletion environment variables");
}

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const firebaseKeys = createRemoteJWKSet(
  new URL(
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
  ),
);
const photoBucket = "profile-photos";
const listPageSize = 100;
const removeBatchSize = 100;
const maxPhotoObjects = 1000;
const maxPhotoFolders = 500;
const maxFolderDepth = 10;

type FirebaseDeleteResult = { ok: true } | { ok: false; code: string };

// Only explicit, definitive Firebase rejections allow restoring the Firebase UID.
// USER_NOT_FOUND is excluded: the login might already have been deleted.
// Timeouts, 429/5xx and unexpected responses have an ambiguous outcome.
const definiteRejections = new Set([
  "CREDENTIAL_TOO_OLD_LOGIN_AGAIN",
  "TOKEN_EXPIRED",
  "INVALID_ID_TOKEN",
  "OPERATION_NOT_ALLOWED",
  "API_KEY_INVALID",
  "PROJECT_NOT_FOUND",
]);

async function verifyFirebaseUid(token: string): Promise<string> {
  const { payload } = await jwtVerify(token, firebaseKeys, {
    issuer: `https://securetoken.google.com/${firebaseProjectId}`,
    audience: firebaseProjectId,
    algorithms: ["RS256"],
    clockTolerance: 5,
  });

  const now = Math.floor(Date.now() / 1000);
  if (
    !payload.sub || payload.sub.length > 128 ||
    typeof payload.auth_time !== "number" || payload.auth_time > now + 5 ||
    typeof payload.iat !== "number" || payload.iat > now + 5 ||
    typeof payload.exp !== "number" || payload.exp <= now - 5
  ) {
    throw new Error("Invalid Firebase authentication claims");
  }
  return payload.sub;
}

async function deleteFirebaseAccount(
  token: string,
): Promise<FirebaseDeleteResult> {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${
      encodeURIComponent(firebaseApiKey!)
    }`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ idToken: token }),
      signal: AbortSignal.timeout(15000),
    },
  );
  if (response.ok) return { ok: true };

  const result: unknown = await response.json().catch(() => null);
  const errorObject = result && typeof result === "object" && "error" in result
    ? (result as { error?: unknown }).error
    : undefined;
  const code = errorObject && typeof errorObject === "object" &&
      "message" in errorObject &&
      typeof (errorObject as { message?: unknown }).message === "string"
    ? (errorObject as { message: string }).message
    : "UNKNOWN_FIREBASE_ERROR";

  console.error("Firebase account deletion rejected", {
    status: response.status,
    code,
  });
  if (
    response.status >= 500 || response.status === 429 ||
    !definiteRejections.has(code)
  ) {
    throw new Error(
      `Firebase deletion outcome unconfirmed (${response.status}; ${code})`,
    );
  }
  return { ok: false, code };
}

function dbErrorCode(message: string): string {
  if (message.includes("UPCOMING_SESSION")) return "upcoming_session";
  if (message.includes("DELETION_ALREADY_TRACKED")) {
    return "deletion_already_tracked";
  }
  if (message.includes("DELETION_REQUIRES_REVIEW")) {
    return "deletion_requires_review";
  }
  if (message.includes("CUSTOMER_NOT_FOUND")) return "customer_not_found";
  return "deletion_prepare_failed";
}

async function recordReview(
  customerId: string,
  firebaseUid: string,
  errorCode: string,
): Promise<boolean> {
  try {
    const { error } = await admin.rpc("flag_customer_deletion_for_review", {
      p_customer_id: customerId,
      p_firebase_uid: firebaseUid,
      p_error_code: errorCode,
    });
    if (error) throw error;
    return true;
  } catch (error) {
    console.error("CRITICAL: Could not record deletion review", {
      customerId,
      error: String(error),
    });
    return false;
  }
}

async function recordCleanupError(
  customerId: string,
  errorCode: string,
): Promise<void> {
  try {
    const { data, error } = await admin.from("customer_account_deletions")
      .update({
        last_error_code: errorCode,
        updated_at: new Date().toISOString(),
      })
      .eq("customer_id", customerId)
      .eq("status", "cleanup_pending")
      .select("id")
      .maybeSingle();
    if (error || !data?.id) throw error ?? new Error("Tracking row not found");
  } catch (error) {
    console.error("CRITICAL: Could not record cleanup failure", {
      customerId,
      errorCode,
      error: String(error),
    });
  }
}

/**
 * Enumerate every object inside profile-photos/<customer UUID>/, including
 * nested folders. Never infer success from the profile's saved photo path.
 */
async function listAllCustomerPhotos(customerId: string): Promise<string[]> {
  const storage = admin.storage.from(photoBucket);
  const paths: string[] = [];
  const foldersSeen = new Set<string>();

  async function visit(folder: string, depth: number): Promise<void> {
    if (depth > maxFolderDepth || foldersSeen.size >= maxPhotoFolders) {
      throw new Error("PHOTO_FOLDER_LIMIT_REACHED");
    }
    if (foldersSeen.has(folder)) return;
    foldersSeen.add(folder);

    let offset = 0;
    while (true) {
      const { data, error } = await storage.list(folder, {
        limit: listPageSize,
        offset,
        sortBy: { column: "name", order: "asc" },
      });
      if (error || !data) {
        throw new Error(`PHOTO_LIST_FAILED:${error?.message ?? "No data"}`);
      }
      for (const item of data) {
        if (
          !item.name || item.name === "." || item.name === ".." ||
          item.name.includes("/")
        ) {
          throw new Error("UNEXPECTED_STORAGE_OBJECT_NAME");
        }
        const path = `${folder}/${item.name}`;
        if (item.id == null) {
          await visit(path, depth + 1);
        } else {
          paths.push(path);
          if (paths.length > maxPhotoObjects) {
            throw new Error("PHOTO_OBJECT_LIMIT_REACHED");
          }
        }
      }
      if (data.length < listPageSize) break;
      offset += data.length;
    }
  }

  await visit(customerId, 0);
  return paths;
}

async function cleanupCustomerPhotos(customerId: string): Promise<void> {
  const storage = admin.storage.from(photoBucket);
  const photoPaths = await listAllCustomerPhotos(customerId);
  for (let i = 0; i < photoPaths.length; i += removeBatchSize) {
    const batch = photoPaths.slice(i, i + removeBatchSize);
    const { error } = await storage.remove(batch);
    if (error) throw new Error(`PHOTO_REMOVE_FAILED:${error.message}`);
  }

  // An API success on remove is not, by itself, proof that the directory is empty.
  const remaining = await listAllCustomerPhotos(customerId);
  if (remaining.length > 0) {
    throw new Error(`PHOTO_OBJECTS_REMAIN:${remaining.length}`);
  }

  const { error } = await admin.rpc("confirm_customer_photo_cleanup", {
    p_customer_id: customerId,
  });
  if (error) throw new Error(`PHOTO_CLEANUP_CONFIRM_FAILED:${error.message}`);
}

async function cleanupCustomerProfile(customerId: string): Promise<void> {
  const { error } = await admin.rpc("cleanup_customer_profile_data", {
    p_customer_id: customerId,
  });
  if (error) throw new Error(`PROFILE_CLEANUP_FAILED:${error.message}`);
}

function partialDeletionResponse(code: string): Response {
  return jsonResponse({
    error:
      "Your login was removed, but account cleanup needs support. Please contact info@getsetwell.com.",
    code,
    firebaseAccountDeleted: true,
    accountDeletionComplete: false,
  }, 500);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({
      error: "Method not allowed",
      code: "method_not_allowed",
    }, 405);
  }

  const authorization = req.headers.get("Authorization");
  const token = authorization?.startsWith("Bearer ")
    ? authorization.slice("Bearer ".length).trim()
    : "";
  if (!token) {
    return jsonResponse({
      error: "Authentication required",
      code: "auth_required",
    }, 401);
  }

  let firebaseUid: string;
  try {
    firebaseUid = await verifyFirebaseUid(token);
  } catch (error) {
    console.error("Account deletion: Firebase token rejected", String(error));
    return jsonResponse({
      error: "Authentication required",
      code: "auth_required",
    }, 401);
  }

  // Atomic: check blocked sessions, claim deletion and detach Firebase mapping.
  let customerId: string;
  try {
    const { data, error } = await admin.rpc("begin_customer_account_deletion", {
      p_firebase_uid: firebaseUid,
    });
    if (error || typeof data !== "string") {
      const code = dbErrorCode(error?.message ?? "UNKNOWN");
      console.error("Account deletion preparation rejected", { code, error });
      const status =
        [
            "upcoming_session",
            "deletion_already_tracked",
            "deletion_requires_review",
          ]
            .includes(code)
          ? 409
          : code === "customer_not_found"
          ? 404
          : 500;
      const message = code === "upcoming_session"
        ? "You cannot delete your account while you have an upcoming session."
        : code === "deletion_already_tracked" ||
            code === "deletion_requires_review"
        ? "Account deletion requires support before another attempt."
        : code === "customer_not_found"
        ? "Customer identity not found."
        : "Unable to prepare account deletion.";
      return jsonResponse({ error: message, code }, status);
    }
    customerId = data;
  } catch (error) {
    console.error("Account deletion preparation unavailable", String(error));
    return jsonResponse({
      error: "Unable to prepare account deletion",
      code: "deletion_prepare_failed",
    }, 503);
  }

  let firebaseResult: FirebaseDeleteResult;
  try {
    firebaseResult = await deleteFirebaseAccount(token);
  } catch (error) {
    // Firebase may already have processed this deletion. Do not restore UID.
    console.error("CRITICAL: Firebase deletion outcome unknown", {
      customerId,
      error: String(error),
    });
    const reviewRecorded = await recordReview(
      customerId,
      firebaseUid,
      "FIREBASE_OUTCOME_UNKNOWN",
    );
    return jsonResponse({
      error:
        "Account deletion could not be confirmed. Contact support before trying again.",
      code: "deletion_status_unknown",
      reviewRecorded,
    }, 503);
  }

  if (!firebaseResult.ok) {
    let restoreError: unknown = null;
    try {
      const result = await admin.rpc("restore_customer_after_failed_deletion", {
        p_customer_id: customerId,
        p_firebase_uid: firebaseUid,
        p_error_code: `REJECTED:${firebaseResult.code}`,
      });
      restoreError = result.error;
    } catch (error) {
      restoreError = error;
    }
    if (restoreError) {
      console.error(
        "CRITICAL: Firebase rejected deletion; identity restore failed",
        {
          customerId,
          error: String(restoreError),
        },
      );
      await recordReview(customerId, firebaseUid, "RESTORE_FAILED");
      return jsonResponse({
        error: "Account deletion requires support before another attempt.",
        code: "restore_failed",
      }, 500);
    }
    if (
      ["CREDENTIAL_TOO_OLD_LOGIN_AGAIN", "TOKEN_EXPIRED"].includes(
        firebaseResult.code,
      )
    ) {
      return jsonResponse({
        error: "Please sign in again before deleting your account.",
        code: "recent_login_required",
      }, 401);
    }
    return jsonResponse({
      error: "Firebase could not delete this login. Please contact support.",
      code: "firebase_delete_failed",
    }, 502);
  }

  // The Firebase login is now deleted. Never reattach its Firebase UID.
  try {
    const { error } = await admin.rpc("confirm_customer_firebase_deletion", {
      p_customer_id: customerId,
      p_firebase_uid: firebaseUid,
    });
    if (error) throw error;
  } catch (error) {
    console.error("CRITICAL: Firebase login deleted but confirmation failed", {
      customerId,
      error: String(error),
    });
    await recordReview(customerId, firebaseUid, "CONFIRM_WRITE_FAILED");
    return partialDeletionResponse("partial_deletion");
  }

  // Transition to cleanup_pending BEFORE touching photos or profile data.
  // This makes interrupted/failed cleanup visible in the tracking table.
  try {
    const { data, error } = await admin.from("customer_account_deletions")
      .update({
        status: "cleanup_pending",
        last_error_code: null,
        updated_at: new Date().toISOString(),
      })
      .eq("customer_id", customerId)
      .eq("firebase_uid", firebaseUid)
      .eq("status", "firebase_deleted")
      .select("id")
      .maybeSingle();
    if (error || !data?.id) {
      throw error ?? new Error("Tracking transition matched no rows");
    }
  } catch (error) {
    console.error(
      "CRITICAL: Login deleted but cleanup tracking transition failed",
      {
        customerId,
        error: String(error),
      },
    );
    return partialDeletionResponse("partial_deletion");
  }

  try {
    await cleanupCustomerPhotos(customerId);
  } catch (error) {
    console.error("Account deletion: Storage photo cleanup failed", {
      customerId,
      error: String(error),
    });
    await recordCleanupError(customerId, "PHOTO_CLEANUP_FAILED");
    return partialDeletionResponse("partial_deletion");
  }

  try {
    await cleanupCustomerProfile(customerId);
  } catch (error) {
    console.error("Account deletion: profile data cleanup failed", {
      customerId,
      error: String(error),
    });
    await recordCleanupError(customerId, "PROFILE_CLEANUP_FAILED");
    return partialDeletionResponse("partial_deletion");
  }

  // A completed cleanup stage is not completion of the overall erasure request.
  // Historic booking/session/financial data is retained for policy-based review.
  return jsonResponse({
    success: true,
    firebaseAccountDeleted: true,
    photoCleanupCompleted: true,
    profileCleanupCompleted: true,
    accountDeletionComplete: false,
    customerDataStatus: "historical_records_pending_retention_review",
  }, 202);
});
