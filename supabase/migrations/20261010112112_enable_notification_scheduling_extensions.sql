-- Enable scheduled database jobs.
create extension if not exists pg_cron
with schema pg_catalog;

-- Enable HTTP requests from PostgreSQL.
create extension if not exists pg_net
with schema extensions;