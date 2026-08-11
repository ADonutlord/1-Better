-- ============================================================================
-- 1% Better — actions library
-- ============================================================================
create table if not exists public.actions (
  id               uuid primary key default gen_random_uuid(),
  title            text not null unique,
  description      text not null,
  category         text not null check (category in ('wellbeing', 'productivity', 'study', 'social', 'physical', 'reflection')),
  sub_category     text not null default '',
  estimated_minutes int not null default 5 check (estimated_minutes >= 1),
  difficulty       int not null default 1 check (difficulty between 1 and 5),
  required_energy  text not null default 'low' check (required_energy in ('low', 'medium', 'high')),
  mood_tags        text[] not null default '{}',
  situation_tags   text[] not null default '{}',
  base_xp          int not null default 10 check (base_xp > 0),
  active           boolean not null default true,
  created_at       timestamptz not null default now()
);

create index if not exists actions_category_idx on public.actions (category);
create index if not exists actions_mood_tags_idx on public.actions using gin (mood_tags);
create index if not exists actions_situation_tags_idx on public.actions using gin (situation_tags);
create index if not exists actions_active_idx on public.actions (active);

alter table public.actions enable row level security;

-- Any signed-in user may read the action library.
create policy "actions_select_authenticated"
  on public.actions for select
  to authenticated
  using (true);
