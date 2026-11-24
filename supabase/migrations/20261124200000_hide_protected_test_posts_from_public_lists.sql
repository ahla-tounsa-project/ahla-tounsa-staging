create or replace function public.public_service_requests()
returns table(id bigint, title text, description text, city text, created_at timestamptz, phone text, image_urls text[])
language sql
stable
security definer
set search_path = ''
as $function$
  select s.id, s.title, s.description, s.city, s.created_at,
         case when s.contact_public then s.phone else null end,
         s.image_urls
  from public.service_requests as s
  where s.status = 'approved'
    and s.id <> 9876543210123
    and s.id <> 13
    and coalesce(s.title, '') || ' ' || coalesce(s.description, '') !~* '(تجريب|تجريبي|اختبار|test|demo|مثال)'
  order by s.created_at desc;
$function$;

create or replace function public.public_job_posts()
returns table(id bigint, title text, description text, city text, created_at timestamptz, job_type text, work_nature text, phone text, image_urls text[])
language sql
stable
security definer
set search_path = ''
as $function$
  select j.id, j.title, j.description, j.city, j.created_at, j.job_type, j.work_nature,
         case when j.contact_public then j.phone else null end,
         j.image_urls
  from public.job_posts as j
  where j.status = 'approved'
    and j.id <> 7
    and coalesce(j.title, '') || ' ' || coalesce(j.description, '') !~* '(تجريب|تجريبي|اختبار|test|demo|مثال)'
  order by j.created_at desc;
$function$;

create or replace function public.public_real_estate_posts()
returns table(id bigint, title text, property_type text, listing_type text, description text, city text, created_at timestamptz, price numeric, size numeric, rooms integer, phone text, image_urls text[])
language sql
stable
security definer
set search_path = ''
as $function$
  select r.id, r.title, r.property_type, r.listing_type, r.description, r.city, r.created_at,
         r.price, r.size, r.rooms,
         case when r.contact_public then r.phone else null end,
         r.image_urls
  from public.real_estate_posts as r
  where r.status = 'approved'
    and r.id not in (1, 2, 6)
    and coalesce(r.title, '') || ' ' || coalesce(r.description, '') !~* '(تجريب|تجريبي|اختبار|test|demo|مثال)'
  order by r.created_at desc;
$function$;

create or replace function public.public_market_posts()
returns table(id bigint, created_at timestamptz, title text, description text, category text, price numeric, city text, listing_type text, phone text, image_urls text[])
language sql
stable
security definer
set search_path = ''
as $function$
  select m.id, m.created_at, m.title, m.description, m.category, m.price, m.city, m.listing_type,
         case when m.contact_public then m.phone else null end,
         m.image_urls
  from public.market_posts as m
  where m.status = 'approved'
    and m.id not in (2, 3, 7, 8, 9)
    and coalesce(m.title, '') || ' ' || coalesce(m.description, '') !~* '(تجريب|تجريبي|اختبار|test|demo|مثال)'
  order by m.created_at desc;
$function$;

revoke all on function public.public_service_requests() from public;
grant execute on function public.public_service_requests() to anon, authenticated;
revoke all on function public.public_job_posts() from public;
grant execute on function public.public_job_posts() to anon, authenticated;
revoke all on function public.public_real_estate_posts() from public;
grant execute on function public.public_real_estate_posts() to anon, authenticated;
revoke all on function public.public_market_posts() from public;
grant execute on function public.public_market_posts() to anon, authenticated;