update public.trainers
set
  is_featured = false,
  featured_order = null
where is_featured = true;

update public.trainers
set
  is_featured = true,
  featured_order = 1
where slug = 'arash-vahedi';

update public.trainers
set
  is_featured = true,
  featured_order = 2
where slug = 'michelle-berowsky';
