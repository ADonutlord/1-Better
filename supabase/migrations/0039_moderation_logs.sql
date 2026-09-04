-- ============================================================================
-- 1% Better — Community moderation log
-- Records a required moderation reason whenever staff (admin/owner) permanently
-- remove a community post or answer. The reason persists even after the post or
-- answer is deleted, providing an audit trail.
-- ============================================================================

create table if not exists public.moderation_logs (
  id           uuid primary key default gen_random_uuid(),
  moderated_by uuid not null references public.profiles (id) on delete set null,
  target_type  text not null check (target_type in ('post', 'answer')),
  target_id    uuid not null,
  target_owner uuid not null references public.profiles (id) on delete cascade,
  reason       text not null check (char_length(reason) between 1 and 1000),
  created_at   timestamptz not null default now()
);

create index if not exists moderation_logs_created_idx
  on public.moderation_logs (created_at desc);

-- ----------------------------------------------------------------------------
-- RLS: only staff may insert a log; only staff may read/modify logs. Logs are
-- not exposed to the public feed.
-- ----------------------------------------------------------------------------
alter table public.moderation_logs enable row level security;

create policy "moderation_logs_insert_staff"
  on public.moderation_logs for insert
  to authenticated
  with check (
    moderated_by = (select auth.uid())
    and coalesce((
      select role from public.profiles where id = (select auth.uid())
    ), 'user') in ('admin', 'owner')
  );

create policy "moderation_logs_select_staff"
  on public.moderation_logs for select
  to authenticated
  using (
    coalesce((
      select role from public.profiles where id = (select auth.uid())
    ), 'user') in ('admin', 'owner')
  );

grant select, insert on public.moderation_logs to authenticated;