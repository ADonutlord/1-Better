-- ============================================================================
-- 1% Better — Admin/owner moderation of community posts
-- Backs up the per-author delete policies in 0037 with an admin/owner override
-- so staff can remove any community post or answer from people.
-- ============================================================================

-- Staff may delete any post (authors delete their own via 0037's policy).
create policy "posts_delete_staff"
  on public.posts for delete
  to authenticated
  using (
    coalesce((
      select role from public.profiles where id = (select auth.uid())
    ), 'user') in ('admin', 'owner')
  );

-- Staff may delete any answer.
create policy "post_answers_delete_staff"
  on public.post_answers for delete
  to authenticated
  using (
    coalesce((
      select role from public.profiles where id = (select auth.uid())
    ), 'user') in ('admin', 'owner')
  );
