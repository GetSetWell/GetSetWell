import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const allowedDays = new Set<string>([
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
  "sunday",
]);

const allowedTimes = new Set<string>([
  "morning",
  "afternoon",
  "evening",
]);

const allowedTrainerPreferences = new Set<string>([
  "male",
  "female",
]);

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const uaeMobilePattern =
  /^\+971(50|52|54|55|56|58)\d{7}$/;

const internationalPhonePattern =
  /^\+[1-9]\d{7,14}$/;

type JsonObject = Record<string, unknown>;

type RequestType =
  | "trainer_request"
  | "concierge_match";

type TrainerAvailabilityRow = {
  id: string;
  gender: string | null;
  languages: string[] | null;
  price_per_session: number | null;
};

type TrainerLocationRelationRow = {
  trainer_id: string;
};

type AuthenticatedCustomer = {
  userId: string;
  fullName: string;
  phone: string;
  city: string;
};

const supabaseUrl =
  Deno.env.get("SUPABASE_URL");

const serviceRoleKey =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error(
    "Missing Supabase environment variables",
  );
}
console.log(
  "Function SUPABASE_URL:",
  Deno.env.get("SUPABASE_URL"),
);
const supabaseAdmin = createClient(
  supabaseUrl,
  serviceRoleKey,
  {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  },
);

function jsonResponse(
  body: JsonObject,
  status = 200,
): Response {
  return new Response(
    JSON.stringify(body),
    {
      status,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    },
  );
}

function isNonEmptyString(
  value: unknown,
  maxLength: number,
): value is string {
  return (
    typeof value === "string" &&
    value.trim().length > 0 &&
    value.trim().length <= maxLength
  );
}

function isUuid(
  value: unknown,
): value is string {
  return (
    typeof value === "string" &&
    uuidPattern.test(value)
  );
}

function validateRequestFields(
  body: JsonObject,
): string[] {
  const errors: string[] = [];

  if (
    !isNonEmptyString(
      body.goal,
      100,
    )
  ) {
    errors.push(
      "goal is required",
    );
  }

  if (
    !Array.isArray(body.preferred_days) ||
    body.preferred_days.length === 0 ||
    !body.preferred_days.every(
      (day) =>
        typeof day === "string" &&
        allowedDays.has(day),
    )
  ) {
    errors.push(
      "preferred_days is invalid",
    );
  }

  if (
    typeof body.preferred_time !==
      "string" ||
    !allowedTimes.has(
      body.preferred_time,
    )
  ) {
    errors.push(
      "preferred_time is invalid",
    );
  }

  if (
    !isUuid(
      body.training_location_id,
    )
  ) {
    errors.push(
      "training_location_id is invalid",
    );
  }

  if (
    !isNonEmptyString(
      body.preferred_area,
      100,
    )
  ) {
    errors.push(
      "preferred_area is required",
    );
  }

  if (
    body.message !== undefined &&
    body.message !== null
  ) {
    if (
      typeof body.message !== "string" ||
      body.message.trim().length > 250
    ) {
      errors.push(
        "message must be 250 characters or fewer",
      );
    }
  }

  return errors;
}

function validateTrainerRequest(
  body: JsonObject,
): string[] {
  const errors =
    validateRequestFields(body);

  // Keep the existing V1 trainer-request contract intact.
  if (
    !isNonEmptyString(
      body.customer_name,
      100,
    )
  ) {
    errors.push(
      "customer_name is required",
    );
  }

  if (
    typeof body.phone !== "string" ||
    !uaeMobilePattern.test(body.phone)
  ) {
    errors.push(
      "phone must be a valid UAE mobile number",
    );
  }

  if (
    body.share_details_consent !== true
  ) {
    errors.push(
      "share_details_consent must be true",
    );
  }

  if (!isUuid(body.trainer_id)) {
    errors.push(
      "trainer_id is required",
    );
  }

  if (
    body.trainer_gender_preference !==
      undefined ||
    body.budget_min !== undefined ||
    body.budget_max !== undefined ||
    body.language_preference !== undefined
  ) {
    errors.push(
      "trainer request contains concierge-only fields",
    );
  }

  return errors;
}
const allowedTrainingPlaces = new Set<string>([
  "gym",
  "home",
  "outdoors",
]);

const allowedVenueChoices = new Set<string>([
  "customer_choice",
  "trainer_private_gym",
]);
function validateTrainerSessionRequest(
  body: JsonObject,
): string[] {
  const errors: string[] = [];

  // Specific trainer is required.
  if (!isUuid(body.trainer_id)) {
    errors.push(
      "trainer_id is required",
    );
  }

  // Exact session date/time is required.
  if (
    typeof body.scheduled_at !== "string" ||
    Number.isNaN(
      Date.parse(body.scheduled_at),
    )
  ) {
    errors.push(
      "scheduled_at is invalid",
    );
  }

  // Customer's original location preference.
  if (
    typeof body.customer_training_place !==
      "string" ||
    !allowedTrainingPlaces.has(
      body.customer_training_place,
    )
  ) {
    errors.push(
      "customer_training_place is invalid",
    );
  }

  // Whether they use their chosen place
  // or the trainer's private gym.
  if (
    typeof body.venue_choice !==
      "string" ||
    !allowedVenueChoices.has(
      body.venue_choice,
    )
  ) {
    errors.push(
      "venue_choice is invalid",
    );
  }

  // Final human-readable session location.
  if (
    !isNonEmptyString(
      body.location_label,
      150,
    )
  ) {
    errors.push(
      "location_label is required",
    );
  }

  // Prices sent by Flutter for now.
  // We will verify these against trainer/backend
  // prices in the database-validation step.
  if (
    typeof body.session_rate !== "number" ||
    !Number.isFinite(
      body.session_rate,
    ) ||
    body.session_rate < 0
  ) {
    errors.push(
      "session_rate is invalid",
    );
  }

  if (
    typeof body.service_fee !== "number" ||
    !Number.isFinite(
      body.service_fee,
    ) ||
    body.service_fee < 0
  ) {
    errors.push(
      "service_fee is invalid",
    );
  }

  if (
    typeof body.total !== "number" ||
    !Number.isFinite(body.total) ||
    body.total < 0
  ) {
    errors.push(
      "total is invalid",
    );
  }

  // Goal is optional in direct booking.
  if (
    body.goal !== undefined &&
    body.goal !== null &&
    !isNonEmptyString(
      body.goal,
      100,
    )
  ) {
    errors.push(
      "goal is invalid",
    );
  }

  // Notes are optional.
  if (
    body.message !== undefined &&
    body.message !== null
  ) {
    if (
      typeof body.message !== "string" ||
      body.message.trim().length > 250
    ) {
      errors.push(
        "message must be 250 characters or fewer",
      );
    }
  }

  // Current dummy payment methods.
  if (
    body.payment_method !== "card" &&
    body.payment_method !== "apple_pay"
  ) {
    errors.push(
      "payment_method is invalid",
    );
  }

  return errors;
}
async function validateTrainerSessionDatabaseRules(
  body: JsonObject,
): Promise<string[]> {
  const errors: string[] = [];

  const trainerId =
    body.trainer_id as string;

  const {
    data: trainer,
    error: trainerError,
  } = await supabaseAdmin
    .from("trainers")
    .select(`
      id,
      is_active,
      is_verified,
      price_per_session,
      gym_price_per_session,
      gym_location_label
    `)
    .eq("id", trainerId)
    .maybeSingle();

  if (trainerError) {
    throw trainerError;
  }

  if (
    !trainer ||
    trainer.is_active !== true ||
    trainer.is_verified !== true
  ) {
    return [
      "trainer is no longer available",
    ];
  }

  const venueChoice =
    body.venue_choice as string;

  const customerTrainingPlace =
    body.customer_training_place as string;

  const locationLabel =
    body.location_label as string;

  const standardRate =
    Number(
      trainer.price_per_session,
    );

  if (
    !Number.isFinite(standardRate) ||
    standardRate <= 0
  ) {
    return [
      "trainer session price is unavailable",
    ];
  }

  let expectedSessionRate =
    standardRate;

  if (
    venueChoice ===
      "trainer_private_gym"
  ) {
    const gymRate =
      Number(
        trainer.gym_price_per_session,
      );

    const gymLocation =
      typeof trainer.gym_location_label ===
        "string"
        ? trainer.gym_location_label.trim()
        : "";

    if (
      !Number.isFinite(gymRate) ||
      gymRate <= 0 ||
      gymLocation.length === 0
    ) {
      errors.push(
        "trainer private gym is unavailable",
      );
    } else {
      expectedSessionRate =
        gymRate;

      if (
        locationLabel.trim() !==
        gymLocation
      ) {
        errors.push(
          "trainer gym location does not match",
        );
      }
    }
  }

  if (
    venueChoice ===
      "customer_choice" &&
    !allowedTrainingPlaces.has(
      customerTrainingPlace,
    )
  ) {
    errors.push(
      "customer training place is invalid",
    );
  }

  const expectedServiceFee =
    expectedSessionRate * 0.05;

  const expectedTotal =
    expectedSessionRate +
    expectedServiceFee;

  const submittedSessionRate =
    Number(body.session_rate);

  const submittedServiceFee =
    Number(body.service_fee);

  const submittedTotal =
    Number(body.total);

  const moneyMatches = (
    left: number,
    right: number,
  ) =>
    Math.abs(left - right) <
    0.01;

  if (
    !moneyMatches(
      submittedSessionRate,
      expectedSessionRate,
    )
  ) {
    errors.push(
      "session rate does not match backend price",
    );
  }

  if (
    !moneyMatches(
      submittedServiceFee,
      expectedServiceFee,
    )
  ) {
    errors.push(
      "service fee does not match backend price",
    );
  }

  if (
    !moneyMatches(
      submittedTotal,
      expectedTotal,
    )
  ) {
    errors.push(
      "total does not match backend price",
    );
  }

  return errors;
}
function validateConciergeMatch(
  body: JsonObject,
): string[] {
  const errors =
    validateRequestFields(body);

  // Identity for Help Me Choose now comes from the authenticated
  // Supabase user and customer_profiles, never from Flutter.
  if (
    body.customer_name !== undefined ||
    body.phone !== undefined ||
    body.user_id !== undefined
  ) {
    errors.push(
      "concierge_match must not contain customer identity fields",
    );
  }

  if (
    body.share_details_consent !== undefined
  ) {
    errors.push(
      "concierge_match must not contain share_details_consent",
    );
  }

  if (body.trainer_id !== undefined) {
    errors.push(
      "concierge_match must not contain trainer_id",
    );
  }

  if (
    body.trainer_gender_preference !==
      undefined &&
    body.trainer_gender_preference !==
      null
  ) {
    if (
      typeof body
          .trainer_gender_preference !==
        "string" ||
      !allowedTrainerPreferences.has(
        body.trainer_gender_preference,
      )
    ) {
      errors.push(
        "trainer_gender_preference is invalid",
      );
    }
  }

  const hasBudgetMin =
    body.budget_min !== undefined &&
    body.budget_min !== null;

  const hasBudgetMax =
    body.budget_max !== undefined &&
    body.budget_max !== null;

  if (hasBudgetMin !== hasBudgetMax) {
    errors.push(
      "budget_min and budget_max must be provided together",
    );
  }

  if (
    hasBudgetMin &&
    hasBudgetMax
  ) {
    const budgetMin =
      body.budget_min;

    const budgetMax =
      body.budget_max;

    if (
      typeof budgetMin !== "number" ||
      typeof budgetMax !== "number" ||
      !Number.isInteger(budgetMin) ||
      !Number.isInteger(budgetMax) ||
      budgetMin < 0 ||
      budgetMax < budgetMin
    ) {
      errors.push(
        "budget range is invalid",
      );
    }
  }

  if (
    body.language_preference !==
      undefined &&
    body.language_preference !== null &&
    !isNonEmptyString(
      body.language_preference,
      50,
    )
  ) {
    errors.push(
      "language_preference is invalid",
    );
  }

  return errors;
}
async function getAuthenticatedCustomer(
  req: Request,
): Promise<AuthenticatedCustomer> {
  const authorization =
    req.headers.get("authorization");

  if (
    !authorization ||
    !authorization.startsWith("Bearer ")
  ) {
    throw new Error("AUTH_REQUIRED");
  }

  const token =
    authorization.slice(7).trim();

  if (token.length === 0) {
    throw new Error("AUTH_REQUIRED");
  }

  const {
    data: userData,
    error: userError,
  } = await supabaseAdmin.auth.getUser(
    token,
  );

  if (
    userError ||
    !userData.user
  ) {
    console.error(
      "Auth user lookup failed:",
      userError,
    );

    throw new Error(
      "AUTH_REQUIRED",
    );
  }

  const user =
    userData.user;

  const {
    data: profile,
    error: profileError,
  } = await supabaseAdmin
    .from("customer_profiles")
    .select(
      "full_name, phone, city",
    )
    .eq(
      "id",
      user.id,
    )
    .maybeSingle();

  if (profileError) {
    console.error(
      "Customer profile query failed:",
      {
        message:
          profileError.message,
        code:
          profileError.code,
        details:
          profileError.details,
        hint:
          profileError.hint,
        userId:
          user.id,
      },
    );

    throw new Error(
      `PROFILE_QUERY_FAILED:${profileError.message}`,
    );
  }

  const fullName =
    typeof profile?.full_name === "string"
        ? profile.full_name.trim()
        : "";

  const city =
    typeof profile?.city === "string"
        ? profile.city.trim()
        : "";

  const authPhone =
    typeof user.phone === "string"
        ? user.phone.trim()
        : "";

  const profilePhone =
    typeof profile?.phone === "string"
        ? profile.phone.trim()
        : "";

  const phone =
    authPhone.length > 0
        ? authPhone
        : profilePhone;

  if (
    profile == null ||
    fullName.length === 0 ||
    city.length === 0 ||
    phone.length === 0
  ) {
    console.error(
      "Customer profile is incomplete:",
      {
        userId: user.id,
        profileFound: profile != null,
        hasName: fullName.length > 0,
        hasCity: city.length > 0,
        hasPhone: phone.length > 0,
      },
    );

    throw new Error(
      "PROFILE_INCOMPLETE",
    );
  }

  console.log(
    "Authenticated customer loaded:",
    {
      userId:
          user.id,
      profileFound:
          true,
      hasName:
          true,
      hasCity:
          true,
      hasPhone:
          true,
    },
  );

  return {
    userId:
        user.id,
    fullName,
    phone,
    city,
  };
}

function attachAuthenticatedCustomer(
  body: JsonObject,
  customer: AuthenticatedCustomer,
): JsonObject {
  return {
    ...body,

    user_id: customer.userId,
    customer_name: customer.fullName,
    phone: customer.phone,

    // Preserve the existing server-managed booking_requests field.
    share_details_consent: true,
  };
}

async function getActiveVerifiedTrainers():
  Promise<TrainerAvailabilityRow[]> {
  const { data, error } =
    await supabaseAdmin
      .from("trainers")
      .select(
        `
        id,
        gender,
        languages,
        price_per_session
        `,
      )
      .eq("is_active", true)
      .eq("is_verified", true);

  if (error) {
    throw error;
  }

  return (
    (data ?? []) as TrainerAvailabilityRow[]
  );
}

async function isActiveTrainingLocation(
  locationId: string,
): Promise<boolean> {
  const { data, error } =
    await supabaseAdmin
      .from("training_locations")
      .select("id")
      .eq("id", locationId)
      .eq("is_active", true)
      .maybeSingle();

  if (error) {
    throw error;
  }

  return data !== null;
}

async function trainerSupportsLocation(
  trainerId: string,
  locationId: string,
): Promise<boolean> {
  const { data, error } =
    await supabaseAdmin
      .from(
        "trainer_training_locations",
      )
      .select("trainer_id")
      .eq("trainer_id", trainerId)
      .eq(
        "training_location_id",
        locationId,
      )
      .maybeSingle();

  if (error) {
    throw error;
  }

  return data !== null;
}

async function locationHasActiveTrainer(
  locationId: string,
): Promise<boolean> {
  const {
    data: relationData,
    error: relationError,
  } = await supabaseAdmin
    .from("trainer_training_locations")
    .select("trainer_id")
    .eq(
      "training_location_id",
      locationId,
    );

  if (relationError) {
    throw relationError;
  }

  const relationships =
    (relationData ?? []) as
      TrainerLocationRelationRow[];

  if (relationships.length === 0) {
    return false;
  }

  const trainerIds =
    relationships.map(
      (relationship) =>
        relationship.trainer_id,
    );

  const {
    data: trainerData,
    error: trainerError,
  } = await supabaseAdmin
    .from("trainers")
    .select("id")
    .in("id", trainerIds)
    .eq("is_active", true)
    .eq("is_verified", true);

  if (trainerError) {
    throw trainerError;
  }

  return (
    trainerData !== null &&
    trainerData.length > 0
  );
}

async function validateDatabaseRules(
  body: JsonObject,
  requestType: RequestType,
): Promise<string[]> {
  const errors: string[] = [];

  const locationId =
    body.training_location_id;

  if (!isUuid(locationId)) {
    return [
      "training_location_id is invalid",
    ];
  }

  const locationIsActive =
    await isActiveTrainingLocation(
      locationId,
    );

  if (!locationIsActive) {
    return [
      "training location is no longer available",
    ];
  }

  // ----------------------------------------------------------
  // Specific trainer request
  // ----------------------------------------------------------

  if (
    requestType === "trainer_request"
  ) {
    const trainerId =
      body.trainer_id;

    if (!isUuid(trainerId)) {
      return [
        "trainer_id is invalid",
      ];
    }

    const {
      data: trainer,
      error,
    } = await supabaseAdmin
      .from("trainers")
      .select("id")
      .eq("id", trainerId)
      .eq("is_active", true)
      .eq("is_verified", true)
      .maybeSingle();

    if (error) {
      throw error;
    }

    if (!trainer) {
      return [
        "trainer is no longer available",
      ];
    }

    const supportsLocation =
      await trainerSupportsLocation(
        trainerId,
        locationId,
      );

    if (!supportsLocation) {
      errors.push(
        "selected training location is not available for this trainer",
      );
    }

    return errors;
  }

  // ----------------------------------------------------------
  // Help me choose
  // ----------------------------------------------------------

  const locationAvailable =
    await locationHasActiveTrainer(
      locationId,
    );

  if (!locationAvailable) {
    errors.push(
      "selected training location is no longer available",
    );
  }

  const trainers =
    await getActiveVerifiedTrainers();

  if (
    typeof body
        .trainer_gender_preference ===
      "string"
  ) {
    const requestedGender =
      body.trainer_gender_preference
        .trim()
        .toLowerCase();

    const genderAvailable =
      trainers.some((trainer) => {
        return (
          typeof trainer.gender ===
            "string" &&
          trainer.gender
              .trim()
              .toLowerCase() ===
            requestedGender
        );
      });

    if (!genderAvailable) {
      errors.push(
        "trainer preference is currently unavailable",
      );
    }
  }

  if (
    typeof body.language_preference ===
      "string"
  ) {
    const requestedLanguage =
      body.language_preference
        .trim()
        .toLowerCase();

    const languageAvailable =
      trainers.some((trainer) => {
        const languages =
          trainer.languages;

        if (!Array.isArray(languages)) {
          return false;
        }

        return languages.some(
          (language) =>
            typeof language === "string" &&
            language
                .trim()
                .toLowerCase() ===
              requestedLanguage,
        );
      });

    if (!languageAvailable) {
      errors.push(
        "language preference is currently unavailable",
      );
    }
  }

  if (
    typeof body.budget_min ===
      "number" &&
    typeof body.budget_max ===
      "number"
  ) {
    const budgetMin =
      body.budget_min;

    const budgetMax =
      body.budget_max;

    const trainerInBudget =
      trainers.some((trainer) => {
        const price =
          Number(
            trainer.price_per_session,
          );

        return (
          Number.isFinite(price) &&
          price >= budgetMin &&
          price <= budgetMax
        );
      });

    if (!trainerInBudget) {
      errors.push(
        "budget preference is currently unavailable",
      );
    }
  }

  return errors;
}
function buildBookingRequestInsert(
  body: JsonObject,
  requestType: RequestType,
): JsonObject {
    const isTrainerSessionRequest =
    requestType === "trainer_request" &&
    body.scheduled_at !== undefined;

  if (isTrainerSessionRequest) {
    const insertData: JsonObject = {
      request_type:
        "trainer_request",

      user_id:
        body.user_id,

      trainer_id:
        body.trainer_id,

      customer_name:
        body.customer_name,

      phone:
        body.phone,

      share_details_consent:
        true,

      consented_at:
        new Date().toISOString(),

      status:
        "new",

      source:
        "app",
    };

    if (
      typeof body.goal === "string" &&
      body.goal.trim().length > 0
    ) {
      insertData.goal =
        body.goal.trim();
    }

    if (
      typeof body.message === "string" &&
      body.message.trim().length > 0
    ) {
      insertData.message =
        body.message.trim();
    }

    return insertData;
  }
  const common: JsonObject = {
    request_type: requestType,

    customer_name: body.customer_name,
    phone: body.phone,
    goal: body.goal,

    preferred_days: body.preferred_days,
    preferred_time: body.preferred_time,

    training_location_id:
      body.training_location_id,

    preferred_area: body.preferred_area,

    share_details_consent: true,

    // These values come from our server, never Flutter.
    consented_at: new Date().toISOString(),
    status: "new",
    source: "app",
  };

  if (
    typeof body.message === "string" &&
    body.message.trim().length > 0
  ) {
    common.message = body.message.trim();
  }

if (requestType === "trainer_request") {
  return {
    ...common,
    trainer_id: body.trainer_id,

    ...(isUuid(body.source_concierge_request_id)
      ? {
          source_concierge_request_id:
            body.source_concierge_request_id,
        }
      : {}),
  };
}

  if (isUuid(body.user_id)) {
    common.user_id = body.user_id;
  }

  // Help me choose fields
  if (
    typeof body.trainer_gender_preference ===
    "string"
  ) {
    common.trainer_gender_preference =
      body.trainer_gender_preference;
  }

  if (
    typeof body.budget_min === "number" &&
    typeof body.budget_max === "number"
  ) {
    common.budget_min = body.budget_min;
    common.budget_max = body.budget_max;
  }

  if (
    typeof body.language_preference ===
      "string" &&
    body.language_preference.trim().length > 0
  ) {
    common.language_preference =
      body.language_preference.trim();
  }

  return common;
}

async function insertBookingRequest(
  body: JsonObject,
  requestType: RequestType,
) {
  const insertData =
    buildBookingRequestInsert(
      body,
      requestType,
    );

  const { data, error } =
    await supabaseAdmin
      .from("booking_requests")
      .insert(insertData)
      .select(
        `
        id,
        reference_code
        `,
      )
      .single();

  if (error) {
    throw error;
  }

  return data;
}

async function useExistingConciergeRequest(
  body: JsonObject,
) {
  const requestId =
    body.source_concierge_request_id;

  const userId =
    body.user_id;

  if (!isUuid(requestId) || !isUuid(userId)) {
    throw new Error(
      "INVALID_SOURCE_CONCIERGE_REQUEST",
    );
  }

  const {
    data: existingRequest,
    error: lookupError,
  } = await supabaseAdmin
    .from("booking_requests")
    .select(`
      id,
      reference_code,
      request_type,
      status,
      user_id,
      trainer_id
    `)
    .eq("id", requestId)
    .eq("user_id", userId)
    .eq("request_type", "concierge_match")
    .maybeSingle();

  if (lookupError) {
    throw lookupError;
  }

  if (!existingRequest) {
    throw new Error(
      "SOURCE_CONCIERGE_REQUEST_NOT_FOUND",
    );
  }

  if (
    existingRequest.status !== "matched"
  ) {
    throw new Error(
      "SOURCE_CONCIERGE_REQUEST_NOT_MATCHED",
    );
  }

  const trainerId =
    body.trainer_id;

  if (!isUuid(trainerId)) {
    throw new Error(
      "INVALID_TRAINER",
    );
  }

  const {
    data: updatedRequest,
    error: updateError,
  } = await supabaseAdmin
    .from("booking_requests")
    .update({
      trainer_id: trainerId,
      status: "confirmed",
    })
    .eq("id", requestId)
    .eq("user_id", userId)
    .select(`
      id,
      reference_code
    `)
    .single();

  if (updateError) {
    throw updateError;
  }

  return updatedRequest;
}

async function insertConfirmedSession(
  body: JsonObject,
  bookingRequestId: string,
) {
  const {
    data,
    error,
  } = await supabaseAdmin
    .from("sessions")
    .insert({
      booking_request_id:
        bookingRequestId,

      user_id:
        body.user_id,

      trainer_id:
        body.trainer_id,

      scheduled_at:
        body.scheduled_at,

      location_label:
        body.location_label,

      status:
        "confirmed",
    })
    .select(`
      id,
      booking_request_id,
      user_id,
      trainer_id,
      scheduled_at,
      location_label,
      status
    `)
    .single();

  if (error) {
    throw error;
  }

  return data;
}

async function getTrainingLocationName(
  locationId: string,
): Promise<string> {
  const { data, error } = await supabaseAdmin
    .from("training_locations")
    .select("name")
    .eq("id", locationId)
    .single();

  if (error) {
    throw error;
  }

  return data.name;
}

async function getTrainerName(
  trainerId: string,
): Promise<string> {
  const { data, error } = await supabaseAdmin
    .from("trainers")
    .select("full_name")
    .eq("id", trainerId)
    .single();

  if (error) {
    throw error;
  }

  return data.full_name;
}

async function sendTelegramNotification(
  body: JsonObject,
  requestType: RequestType,
  referenceCode: string,
): Promise<void> {
  const botToken =
    Deno.env.get("TELEGRAM_BOT_TOKEN");

  const chatId =
    Deno.env.get("TELEGRAM_CHAT_ID");

  if (!botToken || !chatId) {
    console.error(
      "Telegram secrets are missing",
    );
    return;
  }

  const locationId =
    body.training_location_id as string;

  const locationName =
    await getTrainingLocationName(
      locationId,
    );

  const days = Array.isArray(
    body.preferred_days,
  )
    ? body.preferred_days.join(", ")
    : "";

  let message = "";

  if (requestType === "trainer_request") {
    const trainerId =
      body.trainer_id as string;

    const trainerName =
      await getTrainerName(
        trainerId,
      );

    message = [
      "🟢 New GetSetWell Trainer Request",
      "",
      referenceCode,
      "",
      `Trainer: ${trainerName}`,
      `Goal: ${body.goal}`,
      `Days: ${days}`,
      `Time: ${body.preferred_time}`,
      `Where: ${locationName}`,
      `Area: ${body.preferred_area}`,
      "",
      `Customer: ${body.customer_name}`,
      `WhatsApp: ${body.phone}`,
    ].join("\n");
  } else {
    const preferenceLines: string[] = [];

    if (
      typeof body.trainer_gender_preference ===
      "string"
    ) {
      preferenceLines.push(
        `Trainer preference: ${body.trainer_gender_preference}`,
      );
    }

    if (
      typeof body.budget_min === "number" &&
      typeof body.budget_max === "number"
    ) {
      preferenceLines.push(
        `Budget: AED ${body.budget_min}-${body.budget_max}`,
      );
    }

    if (
      typeof body.language_preference ===
      "string"
    ) {
      preferenceLines.push(
        `Language: ${body.language_preference}`,
      );
    }

    message = [
      "🟢 New GetSetWell Match Request",
      "",
      referenceCode,
      "",
      `Goal: ${body.goal}`,
      `Days: ${days}`,
      `Time: ${body.preferred_time}`,
      `Where: ${locationName}`,
      `Area: ${body.preferred_area}`,
      ...preferenceLines,
      "",
      `Customer: ${body.customer_name}`,
      `WhatsApp: ${body.phone}`,
    ].join("\n");
  }

  const response = await fetch(
    `https://api.telegram.org/bot${botToken}/sendMessage`,
    {
      method: "POST",
      headers: {
        "Content-Type":
          "application/json",
      },
      body: JSON.stringify({
        chat_id: chatId,
        text: message,
      }),
    },
  );

  if (!response.ok) {
    const telegramError =
      await response.text();

    throw new Error(
      `Telegram notification failed: ${telegramError}`,
    );
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(
      "ok",
      {
        headers: corsHeaders,
      },
    );
  }

  if (req.method !== "POST") {
    return jsonResponse(
      {
        error: "Method not allowed",
      },
      405,
    );
  }

  let body: JsonObject;

  try {
    const parsedBody =
      await req.json();

    if (
      typeof parsedBody !== "object" ||
      parsedBody === null ||
      Array.isArray(parsedBody)
    ) {
      return jsonResponse(
        {
          error:
            "JSON body must be an object",
        },
        400,
      );
    }

    body =
      parsedBody as JsonObject;
  } catch {
    return jsonResponse(
      {
        error: "Invalid JSON body",
      },
      400,
    );
  }

  const requestType =
    body.request_type;

const isTrainerSessionRequest =
  requestType === "trainer_request" &&
  body.scheduled_at !== undefined;

  if (
    requestType !==
      "trainer_request" &&
    requestType !==
      "concierge_match"
  ) {
    return jsonResponse(
      {
        error: "Invalid request_type",
      },
      400,
    );
  }

const validationErrors =
  requestType === "trainer_request"
    ? isTrainerSessionRequest
      ? validateTrainerSessionRequest(
          body,
        )
      : validateTrainerRequest(
          body,
        )
    : validateConciergeMatch(
        body,
      );

  if (
    validationErrors.length > 0
  ) {
    return jsonResponse(
      {
        error:
          "Validation failed",
        details:
          validationErrors,
      },
      400,
    );
  }

  let effectiveBody = body;

  // Help Me Choose is now an authenticated flow.
  // Customer identity comes from Supabase Auth + customer_profiles.
  if (
    requestType === "concierge_match" ||
  isTrainerSessionRequest

  ) {
    try {
      const customer =
        await getAuthenticatedCustomer(
          req,
        );

      effectiveBody =
        attachAuthenticatedCustomer(
          body,
          customer,
        );
    } catch (error) {
      if (
        error instanceof Error &&
        error.message === "AUTH_REQUIRED"
      ) {
        return jsonResponse(
          {
            error:
              "Authentication required",
          },
          401,
        );
      }

      if (
        error instanceof Error &&
        error.message === "PROFILE_INCOMPLETE"
      ) {
        return jsonResponse(
          {
            error:
              "Profile incomplete",
            details: [
              "Complete your name and city before sending the request",
            ],
          },
          409,
        );
      }

      if (
        error instanceof Error &&
        error.message.startsWith(
          "PROFILE_QUERY_FAILED:",
        )
      ) {
        const profileMessage =
          error.message.replace(
            "PROFILE_QUERY_FAILED:",
            "",
          );

        console.error(
          "Customer profile query failed:",
          profileMessage,
        );

        return jsonResponse(
          {
            error:
              "Unable to load customer profile",
            details:
              profileMessage,
          },
          500,
        );
      }

      console.error(
        "Customer profile lookup failed:",
        error,
      );

      return jsonResponse(
        {
          error:
            "Unable to load customer profile",
        },
        500,
      );
    }
  }

  try {
const databaseErrors =
  isTrainerSessionRequest
    ? await validateTrainerSessionDatabaseRules(
        effectiveBody,
      )
    : await validateDatabaseRules(
        effectiveBody,
        requestType,
      );

    if (
      databaseErrors.length > 0
    ) {
      return jsonResponse(
        {
          error:
            "Validation failed",
          details:
            databaseErrors,
        },
        400,
      );
    }
  } catch (error) {
    console.error(
      "Database validation failed:",
      error,
    );

    return jsonResponse(
      {
        error:
          "Unable to validate request",
      },
      500,
    );
  }

  try {
let bookingRequest;

const sourceConciergeRequestId =
  effectiveBody.source_concierge_request_id;

const isConciergeBooking =
  isTrainerSessionRequest &&
  isUuid(sourceConciergeRequestId);

if (isConciergeBooking) {
  bookingRequest =
    await useExistingConciergeRequest(
      effectiveBody,
    );
} else {
  bookingRequest =
    await insertBookingRequest(
      effectiveBody,
      requestType,
    );
}

let session = null;

if (isTrainerSessionRequest) {
  try {
    session =
      await insertConfirmedSession(
        effectiveBody,
        bookingRequest.id,
      );
  } catch (error) {
    if (isConciergeBooking) {
      // Restore the original concierge request if
      // creating the session fails.
      const {
        error: rollbackError,
      } = await supabaseAdmin
        .from("booking_requests")
        .update({
          status: "matched",
        })
        .eq(
          "id",
          bookingRequest.id,
        );

      if (rollbackError) {
        console.error(
          "Concierge request rollback failed:",
          rollbackError,
        );
      }
    } else {
      // Only delete rows that were created as part
      // of a normal direct booking.
      const {
        error: cleanupError,
      } = await supabaseAdmin
        .from("booking_requests")
        .delete()
        .eq(
          "id",
          bookingRequest.id,
        );

      if (cleanupError) {
        console.error(
          "Booking request cleanup failed:",
          cleanupError,
        );
      }
    }

    throw error;
  }
}
if (!isTrainerSessionRequest) {
  try {
    await sendTelegramNotification(
      effectiveBody,
      requestType,
      bookingRequest.reference_code,
    );
  } catch (error) {
    console.error(
      "Telegram notification failed:",
      error,
    );
  }
}

return jsonResponse(
  {
    success: true,
    request_type: requestType,
    request_id: bookingRequest.id,
    reference_code:
      bookingRequest.reference_code,

    session_id:
      session?.id ?? null,

    scheduled_at:
      session?.scheduled_at ?? null,

    location_label:
      session?.location_label ?? null,

    status:
      session?.status ?? null,
  },
  201,
);
  } catch (error) {
    console.error(
      "Booking request insert failed:",
      error,
    );

    const databaseError =
      error !== null &&
      typeof error === "object"
        ? error as Record<string, unknown>
        : {};

    return jsonResponse(
      {
        error:
          "Unable to create request",
        details: {
          message:
            typeof databaseError.message === "string"
              ? databaseError.message
              : String(error),
          code:
            typeof databaseError.code === "string"
              ? databaseError.code
              : null,
          details:
            typeof databaseError.details === "string"
              ? databaseError.details
              : null,
          hint:
            typeof databaseError.hint === "string"
              ? databaseError.hint
              : null,
        },
      },
      500,
    );
  }
});
