create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists private.active_site_presence (
  session_id uuid primary key,
  last_seen timestamptz not null default now()
);
create index if not exists active_site_presence_last_seen_idx on private.active_site_presence (last_seen);
alter table private.active_site_presence enable row level security;
revoke all on table private.active_site_presence from public, anon, authenticated;

create table if not exists private.site_page_daily_counts (
  visit_day date not null,
  page_key text not null,
  view_count bigint not null default 0 check (view_count >= 0),
  primary key (visit_day, page_key),
  constraint site_page_daily_counts_page_key_check
    check (page_key in ('__all__','home','services','jobs','realty','market','good','guide','cv','ask','saved','account'))
);
alter table private.site_page_daily_counts enable row level security;
revoke all on table private.site_page_daily_counts from public, anon, authenticated;

create or replace function public.is_owner()
returns boolean language sql stable security definer set search_path to ''
as $function$
  select exists (select 1 from public.admins a where a.user_id = (select auth.uid()));
$function$;
revoke all on function public.is_owner() from public, anon;
grant execute on function public.is_owner() to authenticated;

create or replace function public.heartbeat_site_presence(p_session_id uuid)
returns void language plpgsql security definer set search_path to ''
as $function$
begin
  if p_session_id is null then raise exception 'session token required' using errcode = '22023'; end if;
  if auth.uid() is not null and (public.is_admin() or public.is_owner()) then return; end if;
  delete from private.active_site_presence where last_seen < now() - interval '2 minutes';
  insert into private.active_site_presence (session_id, last_seen) values (p_session_id, now())
  on conflict (session_id) do update set last_seen = excluded.last_seen;
end;
$function$;
revoke all on function public.heartbeat_site_presence(uuid) from public;
grant execute on function public.heartbeat_site_presence(uuid) to anon, authenticated;

create or replace function public.record_site_page_view(p_page_key text)
returns void language plpgsql security definer set search_path to ''
as $function$
declare v_day date := (now() at time zone 'Africa/Tunis')::date;
begin
  if p_page_key is null or p_page_key not in ('home','services','jobs','realty','market','good','guide','cv','ask','saved','account') then
    raise exception 'invalid page key' using errcode = '22023';
  end if;
  if auth.uid() is not null and (public.is_admin() or public.is_owner()) then return; end if;
  insert into private.site_page_daily_counts (visit_day, page_key, view_count)
  values (v_day, p_page_key, 1), (v_day, '__all__', 1)
  on conflict (visit_day, page_key) do update set view_count = private.site_page_daily_counts.view_count + 1;
end;
$function$;
revoke all on function public.record_site_page_view(text) from public;
grant execute on function public.record_site_page_view(text) to anon, authenticated;

create or replace function public.get_active_site_presence_count()
returns bigint language plpgsql security definer set search_path to ''
as $function$
declare v_count bigint;
begin
  if auth.uid() is null or not public.is_owner() then raise exception 'not authorized' using errcode = '42501'; end if;
  delete from private.active_site_presence where last_seen < now() - interval '2 minutes';
  select count(*) into v_count from private.active_site_presence where last_seen >= now() - interval '2 minutes';
  return coalesce(v_count, 0);
end;
$function$;
revoke all on function public.get_active_site_presence_count() from public, anon;
grant execute on function public.get_active_site_presence_count() to authenticated;

create or replace function public.get_aggregate_site_analytics()
returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare v_today date := (now() at time zone 'Africa/Tunis')::date; v_result jsonb;
begin
  if auth.uid() is null or not public.is_owner() then raise exception 'not authorized' using errcode = '42501'; end if;
  select jsonb_build_object(
    'total_views', coalesce((select sum(view_count) from private.site_page_daily_counts where page_key = '__all__'), 0),
    'today_views', coalesce((select sum(view_count) from private.site_page_daily_counts where page_key = '__all__' and visit_day = v_today), 0),
    'month_views', coalesce((select sum(view_count) from private.site_page_daily_counts where page_key = '__all__' and visit_day >= date_trunc('month', v_today)::date), 0),
    'top_pages', coalesce((
      select jsonb_agg(jsonb_build_object('page_key', page_key, 'views', views) order by views desc, page_key)
      from (select page_key, sum(view_count)::bigint as views from private.site_page_daily_counts where page_key <> '__all__'
        group by page_key order by views desc, page_key limit 8) p
    ), '[]'::jsonb)
  ) into v_result;
  return v_result;
end;
$function$;
revoke all on function public.get_aggregate_site_analytics() from public, anon;
grant execute on function public.get_aggregate_site_analytics() to authenticated;
