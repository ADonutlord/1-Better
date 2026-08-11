-- ============================================================================
-- 1% Better — progression schema
-- action_history, xp_events, daily_progress
-- ============================================================================
create table if not exists public.action_history (
  id                       uuid primary key default gen_random_uuid(),
  user_id                  uuid not null references public.profiles (id) on delete cascade,
  action_id                uuid not null references public.actions (id),
  assigned_at              timestamptz not null default now(),
  assigned_date            date not null default (now() at time zone 'UTC')::date,
  completed_at             timestamptz,
  completed                boolean not null default false,
  mood_at_assignment       text,
  situation_at_assignment  text[] not null default '{}',
  xp_earned                int not null default 0 check (xp_earned >= 0),
  source                   text not null default 'algorithm' check (source in ('algorithm', 'helper'))
);

-- one assignment per user per day (a cast on timestamptz is STABLE, so the
-- unique enforcement lives on a real date column instead of an expression)
create unique index if not exists action_history_user_day_uq
  on public.action_history (user_id, assigned_date);

create index if not exists action_history_user_assigned_idx
  on public.action_history (user_id, assigned_at desc);
create index if not exists action_history_user_action_idx
  on public.action_history (user_id, action_id);
create index if not exists action_history_today_idx
  on public.action_history (user_id, assigned_at)
  where not completed;

create table if not exists public.xp_events (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles (id) on delete cascade,
  amount       int not null check (amount > 0),
  event_type   text not null,
  reference_id uuid,
  created_at   timestamptz not null default now(),
  unique (user_id, event_type, reference_id)
);

create index if not exists xp_events_user_created_idx
  on public.xp_events (user_id, created_at desc);

create table if not exists public.daily_progress (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null references public.profiles (id) on delete cascade,
  date                  date not null default current_date,
  mood_completed        boolean not null default false,
  conversation_completed boolean not null default false,
  action_id             uuid references public.actions (id),
  action_completed      boolean not null default false,
  xp_awarded            int not null default 0,
  unique (user_id, date)
);

create index if not exists daily_progress_user_date_idx
  on public.daily_progress (user_id, date desc);

-- ----------------------------------------------------------------------------
-- RLS
-- ----------------------------------------------------------------------------
alter table public.action_history enable row level security;
alter table public.xp_events enable row level security;
alter table public.daily_progress enable row level security;

-- Own history may be read; writes happen through SECURITY DEFINER functions
-- only, so no insert/update policies are granted to the client.
create policy "action_history_select_own"
  on public.action_history for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "xp_events_select_own"
  on public.xp_events for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "daily_progress_select_own"
  on public.daily_progress for select
  to authenticated
  using ((select auth.uid()) = user_id);
