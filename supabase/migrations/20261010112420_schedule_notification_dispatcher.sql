
-- GetSetWell automatic notification dispatcher
-- Runs once per minute.
-- Reads the admin secret securely from Supabase Vault.

do $$
begin
  if not exists (
    select 1
    from vault.secrets
    where name = 'notification_dispatch_admin_secret'
  ) then
    raise exception
      'Missing notification_dispatch_admin_secret in Supabase Vault';
  end if;
end;
$$;

select cron.schedule(
  'getsetwell-notification-dispatcher',
  '* * * * *',
  $job$
    select net.http_post(
      url :=
        'https://tijezquislhgmfchbkyt.supabase.co/functions/v1/dispatch-notifications',

      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-admin-secret',
        (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'notification_dispatch_admin_secret'
        )
      ),

      body := '{}'::jsonb,

      timeout_milliseconds := 60000
    ) as request_id;
  $job$
);
