create or replace function public.admin_list_posts(
  p_table text,
  p_limit integer default 100,
  p_offset integer default 0
)
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 100), 100));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
begin
  if (select auth.uid()) is null or not coalesce(public.is_admin(), false) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  if p_table not in ('service_requests', 'job_posts', 'real_estate_posts', 'market_posts') then
    raise exception 'invalid post table' using errcode = '22023';
  end if;

  return query execute format(
    'select to_jsonb(t) from public.%I as t order by t.created_at desc, t.id asc limit $1 offset $2',
    p_table
  ) using v_limit, v_offset;
end;
$function$;

revoke all on function public.admin_list_posts(text, integer, integer) from public, anon;
grant execute on function public.admin_list_posts(text, integer, integer) to authenticated;