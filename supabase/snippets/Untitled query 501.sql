select
  id,
  profile_photo_path
from public.customer_profiles
where profile_photo_path is not null;