select cron.schedule(
  'getsetwell-session-feedback',
  '* * * * *',
  $job$
    select public.enqueue_due_session_feedback();
  $job$
);