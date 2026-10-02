import { createClient } from 'npm:@supabase/supabase-js@2';

Deno.serve(async (req) => {
  try {
    const authHeader = req.headers.get('Authorization');

    if (!authHeader) {
      return new Response(
        JSON.stringify({
          message: 'Missing authorization header',
        }),
        {
          status: 401,
          headers: {
            'Content-Type': 'application/json',
          },
        },
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;

    const supabase = createClient(
      supabaseUrl,
      supabaseAnonKey,
      {
        global: {
          headers: {
            Authorization: authHeader,
          },
        },
      },
    );

    const {
      data: { user },
      error,
    } = await supabase.auth.getUser();

    if (error || !user) {
      return new Response(
        JSON.stringify({
          message: 'Unauthorized',
        }),
        {
          status: 401,
          headers: {
            'Content-Type': 'application/json',
          },
        },
      );
    }

    const serviceRoleKey =
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const adminSupabase = createClient(
  supabaseUrl,
  serviceRoleKey,
  {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  },
);
const { error: pushTokenError } = await adminSupabase
  .from('device_push_tokens')
  .delete()
  .eq('user_id', user.id);

if (pushTokenError) {
  throw pushTokenError;
}

const { error: notificationPreferencesError } = await adminSupabase
  .from('notification_preferences')
  .delete()
  .eq('user_id', user.id);

if (notificationPreferencesError) {
  throw notificationPreferencesError;
}
const { error: notificationsError } = await adminSupabase
  .from('notifications')
  .delete()
  .eq('user_id', user.id);

if (notificationsError) {
  throw notificationsError;
}
const { error: sessionsError } = await adminSupabase
  .from('sessions')
  .update({ user_id: null })
  .eq('user_id', user.id);

if (sessionsError) {
  throw sessionsError;
}

const { error: bookingRequestsError } = await adminSupabase
  .from('booking_requests')
  .delete()
  .eq('user_id', user.id);

if (bookingRequestsError) {
  throw bookingRequestsError;
}
const { error: customerProfileError } = await adminSupabase
  .from('customer_profiles')
  .delete()
  .eq('id', user.id);

if (customerProfileError) {
  throw customerProfileError;
}

const { error: deleteUserError } =
  await adminSupabase.auth.admin.deleteUser(user.id);

if (deleteUserError) {
  throw deleteUserError;
}

const { data: upcomingSessions, error: sessionError } =
  await supabase
    .from('sessions')
    .select('id, scheduled_at, status')
    .eq('user_id', user.id)
    .gt('scheduled_at', new Date().toISOString())
    .neq('status', 'cancelled')
    .limit(1);

if (sessionError) {
  throw sessionError;
}


if (upcomingSessions.length > 0) {
  return new Response(
    JSON.stringify({
      success: false,
      code: 'upcoming_session',
      message: 'You have an upcoming session.',
    }),
    {
      status: 409,
      headers: {
        'Content-Type': 'application/json',
      },
    },
  );
}
    return new Response(
      JSON.stringify({
        success: true,
        userId: user.id,
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
        },
      },
    );
  } catch (error) {
    console.error(error);

    return new Response(
      JSON.stringify({
        message: 'Internal server error',
      }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
        },
      },
    );
  }
});