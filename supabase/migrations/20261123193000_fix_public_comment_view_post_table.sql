-- Keep the public comments view aligned with comments.js filters.
-- The client filters by post_table and post_id; omitting post_table makes every
-- comment query fail with a missing-column error.
create or replace view public.post_comments_public
with (security_barrier = true, security_invoker = true)
as
select
  c.id,
  c.post_table,
  c.post_id,
  c.parent_id,
  c.body,
  c.created_at,
  ahla_internal.is_own_post_comment(c.id) as is_mine
from public.post_comments c
where c.status = 'published'
  and ahla_internal.comment_target_is_public(c.post_table, c.post_id)
  and (
    c.parent_id is null
    or ahla_internal.comment_parent_is_public(c.parent_id, c.post_table, c.post_id)
  );

grant select on public.post_comments_public to anon, authenticated;
