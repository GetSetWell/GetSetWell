import { Webhook } from 'https://esm.sh/standardwebhooks@1.0.0'

type SendSmsHookPayload = {
  user?: {
    phone?: string | null
  }
  sms?: {
    otp?: string | null
  }
}

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
) {
  return new Response(
    JSON.stringify(body),
    {
      status,
      headers: {
        'Content-Type': 'application/json',
      },
    },
  )
}

Deno.serve(async (req) => {
  // ---------------------------------------------------------------------------
  // METHOD
  // ---------------------------------------------------------------------------

  if (req.method !== 'POST') {
    return jsonResponse(
      {
        error: {
          http_code: 405,
          message: 'Method not allowed.',
        },
      },
      405,
    )
  }

  // ---------------------------------------------------------------------------
  // WEBHOOK SECRET
  // ---------------------------------------------------------------------------

  const configuredSecret = Deno.env.get('SEND_SMS_HOOK_SECRET')

  if (!configuredSecret) {
    console.error('SEND_SMS_HOOK_SECRET is not configured.')

    return jsonResponse(
      {
        error: {
          http_code: 500,
          message: 'OTP delivery is not configured.',
        },
      },
      500,
    )
  }

  // Supabase hook secrets use:
  // v1,whsec_<secret>
  //
  // standardwebhooks expects the secret value without that prefix.
  const hookSecret = configuredSecret.replace('v1,whsec_', '')

  // IMPORTANT:
  // Signature verification must use the original raw body.
  const rawBody = await req.text()

  let payload: SendSmsHookPayload

  try {
    const webhook = new Webhook(hookSecret)

    payload = webhook.verify(
      rawBody,
      Object.fromEntries(req.headers),
    ) as SendSmsHookPayload
  } catch {
    console.error('Invalid Send SMS hook signature.')

    return jsonResponse(
      {
        error: {
          http_code: 401,
          message: 'Invalid webhook signature.',
        },
      },
      401,
    )
  }

  // ---------------------------------------------------------------------------
  // PAYLOAD
  // ---------------------------------------------------------------------------

  const phone = payload.user?.phone?.trim()
  const otp = payload.sms?.otp?.trim()

  if (!phone || !otp) {
    console.error('Send SMS hook payload is missing required fields.')

    return jsonResponse(
      {
        error: {
          http_code: 400,
          message: 'Invalid OTP delivery request.',
        },
      },
      400,
    )
  }

  // ---------------------------------------------------------------------------
  // META WHATSAPP DELIVERY
  // ---------------------------------------------------------------------------
  //
  // We intentionally do NOT return success yet.
  //
  // The next step will send:
  //
  //   phone
  //   otp
  //
  // through the Meta WhatsApp Cloud API.
  //
  // Until that provider is configured, fail closed so Supabase never believes
  // that an OTP was delivered when nothing was actually sent.
  //
  // SECURITY:
  // Never log `phone`, `otp`, or the raw payload.

  console.error('Meta WhatsApp OTP provider is not configured yet.')

  return jsonResponse(
    {
      error: {
        http_code: 503,
        message: 'OTP delivery provider is not configured.',
      },
    },
    503,
  )
})