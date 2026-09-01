-- ============================================================================
-- 1% Better — Community posts
-- An Instagram-style feed where users post questions/thoughts and other real
-- people (helpers and peers) answer them (community answers, not AI).
-- ============================================================================

create table if not exists public.posts (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  question   text not null check (char_length(question) between 1 and 2000),
  body       text not null default '' check (char_length(body) <= 4000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists posts_created_idx
  on public.posts (created_at desc);

-- Count answers per post efficiently (scan by newest).
create table if not exists public.post_answers (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.posts (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  answer     text not null check (char_length(answer) between 1 and 4000),
  created_at timestamptz not null default now()
);

create index if not exists post_answers_post_created_idx
  on public.post_answers (post_id, created_at);

-- ----------------------------------------------------------------------------
-- RLS: any signed-in user may read all posts/answers and post their own.
-- Anyone who did not author the post may answer it.
-- ----------------------------------------------------------------------------
alter table public.posts enable row level security;
alter table public.post_answers enable row level security;

create policy "posts_select_all_authenticated"
  on public.posts for select
  to authenticated
  using (true);

create policy "posts_insert_own"
  on public.posts for insert
  to authenticated
  with check (user_id = (select auth.uid()));

create policy "posts_update_own"
  on public.posts for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "posts_delete_own"
  on public.posts for delete
  to authenticated
  using (user_id = (select auth.uid()));

create policy "post_answers_select_all_authenticated"
  on public.post_answers for select
  to authenticated
  using (true);

create policy "post_answers_insert_nonauthor"
  on public.post_answers for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.posts p
      where p.id = post_answers.post_id
        and p.user_id <> (select auth.uid())
    )
  );

create policy "post_answers_update_own"
  on public.post_answers for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "post_answers_delete_own"
  on public.post_answers for delete
  to authenticated
  using (user_id = (select auth.uid()));

-- ----------------------------------------------------------------------------
-- Realtime: stream new posts and answers so the feed updates live.
-- ----------------------------------------------------------------------------
alter table public.posts replica identity full;
alter table public.post_answers replica identity full;

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end $$;

do $$
declare
  tbl text;
begin
  foreach tbl in array array['public.posts', 'public.post_answers'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname || '.' || tablename = tbl
    ) then
      execute format('alter publication supabase_realtime add table %s', tbl);
    end if;
  end loop;
end $$;

-- ----------------------------------------------------------------------------
-- Data API grants
-- ----------------------------------------------------------------------------
grant select, insert, update, delete on public.posts, public.post_answers to authenticated;
