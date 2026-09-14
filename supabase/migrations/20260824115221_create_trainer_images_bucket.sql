insert into storage.buckets (
  id,
  name,
  public
)
values (
  'trainer-images',
  'trainer-images',
  true
)
on conflict (id) do update
set public = true;