import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";

const hookSecret = Deno.env.get("SEND_SMS_HOOK_SECRET");

if (!hookSecret) {
  throw new Error("Missing SEND_SMS_HOOK_SECRET");
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", {
      status: 405,
    });
  }

  const payload = await req.text();

  const headers = Object.fromEntries(req.headers);

  const webhook = new Webhook(hookSecret);

  try {
    webhook.verify(payload, headers);
  } catch (error) {
    console.error("Invalid Send SMS hook signature:", error);

    return new Response(
      JSON.stringify({
        error: "Invalid webhook signature",
      }),
      {
        status: 401,
        headers: {
          "Content-Type": "application/json",
        },
      },
    );
  }

  const body = JSON.parse(payload);

  const phone =
    body?.user?.phone ??
    body?.phone ??
    null;

  const otp =
    body?.sms?.otp ??
    body?.otp ??
    body?.code ??
    null;

  console.log("Send SMS hook received", {
    phone,
    hasOtp: Boolean(otp),
  });

  if (!phone || !otp) {
    return new Response(
      JSON.stringify({
        error: "Missing phone or OTP",
      }),
      {
        status: 400,
        headers: {
          "Content-Type": "application/json",
        },
      },
    );
  }

  /*
   * IMPORTANT:
   *
   * This is where we will send the OTP using the final delivery provider.
   *
   * For now, we intentionally do not send anything externally.
   * Once we choose the provider, replace this block with its API call.
   */

console.log("Send SMS hook processed (delivery not configured)");

  return new Response(
    JSON.stringify({
      success: true,
    }),
    {
      status: 200,
      headers: {
        "Content-Type": "application/json",
      },
    },
  );
});