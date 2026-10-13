create or replace function public.claim_device_push_token(
  p_token text,
  p_platform text
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_token is null or trim(p_token) = '' then
    raise exception 'TOKEN_REQUIRED';
  end if;

  if p_platform not in ('android', 'ios') then
    raise exception 'INVALID_PLATFORM';
  end if;

  insert into public.device_push_tokens (
    user_id,
    token,
    platform,
    updated_at
  )
  values (
    v_user_id,
    p_token,
    p_platform,
    now()
  )
  on conflict (token)
  do update
  set
    user_id = excluded.user_id,
    platform = excluded.platform,
    updated_at = now();
end;
$$;

revoke all
on function public.claim_device_push_token(text, text)
from public;

grant execute
on function public.claim_device_push_token(text, text)
to authenticated;