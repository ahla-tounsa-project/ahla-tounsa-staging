create table if not exists public.admin_role_events (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  target_user_id uuid references auth.users(id) on delete set null,
  action text not null check (action in ('granted','revoked')),
  created_at timestamptz not null default now()
);
alter table public.admin_role_events enable row level security;
revoke all on table public.admin_role_events from public, anon, authenticated;

create table if not exists public.admin_status_audit (
  id bigint generated always as identity primary key,
  table_name text not null,
  record_id text not null,
  old_status text,
  new_status text,
  actor_id uuid references auth.users(id) on delete set null,
  changed_at timestamptz not null default now()
);
alter table public.admin_status_audit enable row level security;
revoke all on table public.admin_status_audit from public, anon, authenticated;

create or replace function public.admin_list_users()
returns table(user_id uuid,email text,created_at timestamptz,last_sign_in_at timestamptz,is_moderator boolean)
language plpgsql stable security definer set search_path to ''
as $function$
begin
  if not public.is_owner() then raise exception 'owner_only'; end if;
  return query
    select u.id,u.email::text,u.created_at,u.last_sign_in_at,
           (r.user_id is not null) as is_moderator
    from auth.users u
    left join public.staff_roles r on r.user_id=u.id and r.role='moderator'
    order by u.created_at desc;
end;
$function$;
revoke all on function public.admin_list_users() from public, anon;
grant execute on function public.admin_list_users() to authenticated;

create or replace function public.admin_list_status_audit()
returns table(table_name text,record_id text,old_status text,new_status text,actor_email text,changed_at timestamptz)
language plpgsql stable security definer set search_path to ''
as $function$
begin
  if not public.is_owner() then raise exception 'owner_only'; end if;
  return query
    select a.table_name,a.record_id,a.old_status,a.new_status,
           coalesce(u.email::text,'غير متاح'),a.changed_at
    from public.admin_status_audit a
    left join auth.users u on u.id=a.actor_id
    order by a.changed_at desc
    limit 100;
end;
$function$;
revoke all on function public.admin_list_status_audit() from public, anon;
grant execute on function public.admin_list_status_audit() to authenticated;

create or replace function public.admin_set_moderator(p_user_id uuid,p_make_moderator boolean)
returns boolean
language plpgsql security definer set search_path to ''
as $function$
begin
  if not public.is_owner() then raise exception 'owner_only'; end if;
  if p_user_id is null or p_user_id=(select auth.uid()) then raise exception 'invalid_target'; end if;
  if not exists (select 1 from auth.users u where u.id=p_user_id) then raise exception 'user_not_found'; end if;
  if exists (select 1 from public.admins a where a.user_id=p_user_id) then raise exception 'owner_role_protected'; end if;
  if p_make_moderator then
    insert into public.staff_roles(user_id,role,granted_by)
    values(p_user_id,'moderator',(select auth.uid()))
    on conflict(user_id) do update set role='moderator',granted_by=(select auth.uid()),granted_at=now();
    insert into public.admin_role_events(actor_id,target_user_id,action)
    values((select auth.uid()),p_user_id,'granted');
  else
    delete from public.staff_roles where user_id=p_user_id;
    if found then
      insert into public.admin_role_events(actor_id,target_user_id,action)
      values((select auth.uid()),p_user_id,'revoked');
    end if;
  end if;
  return true;
end;
$function$;
revoke all on function public.admin_set_moderator(uuid,boolean) from public, anon;
grant execute on function public.admin_set_moderator(uuid,boolean) to authenticated;
