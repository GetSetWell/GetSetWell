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

const supabaseUrl =
  Deno.env.get("SUPABASE_URL");

const serviceRoleKey =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error(
    "Missing Supabase environment variables",
  );
}

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

function validateCommonFields(
  body: JsonObject,
): string[] {
  const errors: string[] = [];

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
    body.share_details_consent !== true
  ) {
    errors.push(
      "share_details_consent must be true",
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
    validateCommonFields(body);

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

function validateConciergeMatch(
  body: JsonObject,
): string[] {
  const errors =
    validateCommonFields(body);

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
    const availableBudgetBands =
      new Set<string>();

    for (const trainer of trainers) {
      const price =
        Number(
          trainer.price_per_session,
        );

      if (
        !Number.isFinite(price) ||
        price < 0
      ) {
        continue;
      }

      const lower =
        Math.floor(price / 100) * 100;

      const upper =
        lower + 99;

      availableBudgetBands.add(
        `${lower}-${upper}`,
      );
    }

    const requestedBand =
      `${body.budget_min}-${body.budget_max}`;

    if (
      !availableBudgetBands.has(
        requestedBand,
      )
    ) {
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
    };
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
    requestType ===
        "trainer_request"
      ? validateTrainerRequest(body)
      : validateConciergeMatch(body);

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

  try {
    const databaseErrors =
      await validateDatabaseRules(
        body,
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

  // Temporary response.
  // No insert and no Telegram notification yet.
try {
  const bookingRequest =
    await insertBookingRequest(
      body,
      requestType,
    );
try {
  await sendTelegramNotification(
    body,
    requestType,
    bookingRequest.reference_code,
  );
} catch (error) {
  console.error(
    "Telegram notification failed:",
    error,
  );
}
  return jsonResponse(
    {
      success: true,
      request_type: requestType,
      request_id: bookingRequest.id,
      reference_code:
        bookingRequest.reference_code,
    },
    201,
  );
} catch (error) {
  console.error(
    "Booking request insert failed:",
    error,
  );

  return jsonResponse(
    {
      error:
        "Unable to create request",
    },
    500,
  );
}
});