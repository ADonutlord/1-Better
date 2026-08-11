-- ============================================================================
-- 1% Better — chat schema
-- conversations, conversation_participants, messages, blocks, reports
-- ============================================================================
create table if not exists public.conversations (
  id                 uuid primary key default gen_random_uuid(),
  status             text not null default 'waiting'
                       check (status in ('waiting', 'active', 'ended', 'cancelled')),
  created_at         timestamptz not null default now(),
  started_at         timestamptz,
  ended_at           timestamptz,
  assigned_action_id uuid references public.actions (id)
);

create index if not exists conversations_status_created_idx
  on public.conversations (status, created_at);

create table if not exists public.conversation_participants (
  id               uuid primary key default gen_random_uuid(),
  conversation_id  uuid not null references public.conversations (id) on delete cascade,
  user_id          uuid not null references public.profiles (id) on delete cascade,
  participant_role text not null check (participant_role in ('user', 'helper', 'admin')),
  joined_at        timestamptz not null default now(),
  left_at          timestamptz,
  unique (conversation_id, user_id)
);

create index if not exists conversation_participants_user_idx
  on public.conversation_participants (user_id);
create index if not exists conversation_participants_conversation_idx
  on public.conversation_participants (conversation_id);

create table if not exists public.messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id       uuid not null references public.profiles (id) on delete cascade,
  message         text not null check (char_length(message) <= 4000),
  message_type    text not null default 'text'
                    check (message_type in ('text', 'system', 'action_recommendation')),
  created_at      timestamptz not null default now()
);

create index if not exists messages_conversation_created_idx
  on public.messages (conversation_id, created_at);

create table if not exists public.blocks (
  id              uuid primary key default gen_random_uuid(),
  blocker_id      uuid not null references public.profiles (id) on delete cascade,
  blocked_user_id uuid not null references public.profiles (id) on delete cascade,
  created_at      timestamptz not null default now(),
  unique (blocker_id, blocked_user_id),
  check (blocker_id <> blocked_user_id)
);

create index if not exists blocks_blocker_idx on public.blocks (blocker_id);

create table if not exists public.reports (
  id               uuid primary key default gen_random_uuid(),
  reporter_id      uuid not null references public.profiles (id) on delete cascade,
  reported_user_id uuid not null references public.profiles (id) on delete cascade,
  conversation_id  uuid references public.conversations (id) on delete set null,
  reason           text not null,
  created_at       timestamptz not null default now()
);

create index if not exists reports_reporter_idx on public.reports (reporter_id);
create index if not exists reports_reported_idx on public.reports (reported_user_id);

-- ----------------------------------------------------------------------------
-- RLS
-- ----------------------------------------------------------------------------
alter table public.conversations enable row level security;
alter table public.conversation_participants enable row level security;
alter table public.messages enable row level security;
alter table public.blocks enable row level security;
alter table public.reports enable row level security;

-- A participant may read a conversation they belong to.
create policy "conversations_select_participant"
  on public.conversations for select
  to authenticated
  using (
    exists (
      select 1 from public.conversation_participants cp
      where cp.conversation_id = conversations.id
        and cp.user_id = (select auth.uid())
    )
  );

-- Available helpers may see waiting conversations in order to accept them.
create policy "conversations_select_waiting_available_helper"
  on public.conversations for select
  to authenticated
  using (
    status = 'waiting'
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.role = 'helper'
    )
    and exists (
      select 1 from public.helper_status hs
      where hs.user_id = (select auth.uid())
        and hs.status = 'available'
    )
  );

-- Participants may read each other (names for chat UI).
create policy "participants_select_member"
  on public.conversation_participants for select
  to authenticated
  using (
    exists (
      select 1 from public.conversation_participants mine
      where mine.conversation_id = conversation_participants.conversation_id
        and mine.user_id = (select auth.uid())
    )
  );

-- Messages: only participants of the conversation.
create policy "messages_select_participant"
  on public.messages for select
  to authenticated
  using (
    exists (
      select 1 from public.conversation_participants cp
      where cp.conversation_id = messages.conversation_id
        and cp.user_id = (select auth.uid())
    )
  );

-- Send a text message into an active conversation you are part of.
create policy "messages_insert_participant_active"
  on public.messages for insert
  to authenticated
  with check (
    (select auth.uid()) = sender_id
    and exists (
      select 1 from public.conversations c
      where c.id = conversation_id
        and c.status = 'active'
    )
    and exists (
      select 1 from public.conversation_participants cp
      where cp.conversation_id = messages.conversation_id
        and cp.user_id = (select auth.uid())
    )
  );

-- Blocks: owner manages their own block list.
create policy "blocks_select_own"
  on public.blocks for select
  to authenticated
  using ((select auth.uid()) = blocker_id);

create policy "blocks_insert_own"
  on public.blocks for insert
  to authenticated
  with check ((select auth.uid()) = blocker_id);

create policy "blocks_delete_own"
  on public.blocks for delete
  to authenticated
  using ((select auth.uid()) = blocker_id);

-- Reports: reporter manages their own reports.
create policy "reports_select_own"
  on public.reports for select
  to authenticated
  using ((select auth.uid()) = reporter_id);

create policy "reports_insert_own"
  on public.reports for insert
  to authenticated
  with check ((select auth.uid()) = reporter_id);
