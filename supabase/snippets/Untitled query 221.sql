select
  p.proname,
  p.prosecdef as security_definer,
  r.rolname as function_owner,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as force_rls,
  pg_get_functiondef(p.oid) as function_definition
from pg_proc p
join pg_namespace n
  on n.oid = p.pronamespace
join pg_roles r
  on r.oid = p.proowner
cross join pg_class c
join pg_namespace cn
  on cn.oid = c.relnamespace
where n.nspname = 'public'
  and p.proname = 'claim_device_push_token'
  and cn.nspname = 'public'
  and c.relname = 'device_push_tokens';