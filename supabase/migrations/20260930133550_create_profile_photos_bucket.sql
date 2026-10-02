insert into storage.buckets (
  id,
  name,
  public
)
values (
  'profile-photos',
  'profile-photos',
  false
)
on conflict (id) do nothing;