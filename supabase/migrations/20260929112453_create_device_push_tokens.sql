-- Harden the existing device_push_tokens table.
-- The table itself was created in:
-- 20260923053412_home_states_backend.sql


-- ------------------------------------------------------------
-- PLATFORM
-- Every registered push token must identify its platform.
-- ------------------------------------------------------------

alter table public.device_push_tokens
alter column platform set not null;

alter table public.device_push_tokens
drop constraint if exists device_push_tokens_platform_check;

alter table public.device_push_tokens
add constraint device_push_tokens_platform_check
check (
  platform in ('android', 'ios')
);


-- ------------------------------------------------------------
-- TOKEN UNIQUENESS
-- One FCM token represents one app installation.
-- Do not allow the same installation token to belong to
-- multiple user rows.
-- ------------------------------------------------------------

alter table public.device_push_tokens
drop constraint if exists device_push_tokens_user_id_token_key;

alter table public.device_push_tokens
add constraint device_push_tokens_token_key
unique (token);


-- ------------------------------------------------------------
-- API PERMISSIONS
-- Signed-out users should have no access.
-- ------------------------------------------------------------

revoke all
on table public.device_push_tokens
from anon, authenticated;

grant select, insert, update, delete
on table public.device_push_tokens
to authenticated;


-- ------------------------------------------------------------
-- ROW LEVEL SECURITY
-- Authenticated users can manage only their own device tokens.
-- ------------------------------------------------------------

alter table public.device_push_tokens
enable row level security;

drop policy if exists
"Customers can manage own push tokens"
on public.device_push_tokens;

create policy
"Customers can manage own push tokens"
on public.device_push_tokens
for all
to authenticated
using (
  (select auth.uid()) = user_id
)
with check (
  (select auth.uid()) = user_id
);