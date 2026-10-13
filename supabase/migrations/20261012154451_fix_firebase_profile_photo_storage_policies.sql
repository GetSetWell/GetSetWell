-- Firebase Auth compatibility for profile-photos.
-- Keep customer UUIDs as Storage folder names.

drop policy if exists "Users can upload own profile photo"
on storage.objects;

create policy "Users can upload own profile photo"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] =
      (select public.current_customer_id())::text
);

drop policy if exists "Users can view own profile photo"
on storage.objects;

create policy "Users can view own profile photo"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] =
      (select public.current_customer_id())::text
);

drop policy if exists "Users can update own profile photo"
on storage.objects;

create policy "Users can update own profile photo"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] =
      (select public.current_customer_id())::text
)
with check (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] =
      (select public.current_customer_id())::text
);

drop policy if exists "Users can delete own profile photo"
on storage.objects;

create policy "Users can delete own profile photo"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] =
      (select public.current_customer_id())::text
);