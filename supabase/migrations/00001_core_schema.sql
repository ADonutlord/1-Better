-- ============================================================================
-- 1% Better — Core schema
-- profiles, mood_checkins, helper_status
-- ============================================================================

create extension if not exists pgcrypto;

-- ----------------------------------------------------------------------------
-- profiles
-- ----------------------------------------------------------------------------
create table if not exists public.profiles (
  id               uuid primary key references auth.users (id) on delete cascade,
  display_name     text not null default '',
  role             text not null default 'user' check (role in ('user', 'helper', 'admin')),
  level            int  not null default 1 check (level >= 1),
  total_xp         int  not null default 0 check (total_xp >= 0),
  current_streak   int  not null default 0 check (current_streak >= 0),
  longest_streak   int  not null default 0 check (longest_streak >= 0),
  last_action_date date,
  created_at       timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- Progression / role fields are protected server-side.
-- Clients may update display_name only; anything else is refused unless an
-- internal SECURITY DEFINER function set app.internal = 'on' for the txn.
-- ----------------------------------------------------------------------------
create or replace function public.protect_profile_fields()
returns trigger
language plpgsql
security invoker
as $$
begin
  if new.role            is distinct from old.role
     or new.level        is distinct from old.level
     or new.total_xp     is distinct from old.total_xp
     or new.current_streak is distinct from old.current_streak
     or new.longest_streak is distinct from old.longest_streak
     or new.last_action_date is distinct from old.last_action_date then
    if current_setting('app.internal', true) = 'on' then
      return new;
    end if;
    raise exception 'Protected profile fields cannot be changed by the client';
  end if;
  return new;
end
$$;

drop trigger if exists protect_profile_fields_trg on public.profiles;
create trigger protect_profile_fields_trg
  before update on public.profiles
  for each row execute function public.protect_profile_fields();

-- Create a profile whenever a new auth user is created.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security invoker
as $$
begin
  insert into public.profiles (id, display_name, role)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), 'Friend'),
    'user'
  )
  on conflict (id) do nothing;
  return new;
end
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ----------------------------------------------------------------------------
-- mood_checkins
-- ----------------------------------------------------------------------------
create table if not exists public.mood_checkins (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  mood       text not null check (mood in ('great', 'good', 'okay', 'low', 'stressed')),
  situation  text[] not null default '{}',
  created_at timestamptz not null default now()
);

create index if not exists mood_checkins_user_created_idx
  on public.mood_checkins (user_id, created_at desc);

-- ----------------------------------------------------------------------------
-- helper_status
-- ----------------------------------------------------------------------------
create table if not exists public.helper_status (
  user_id        uuid primary key references public.profiles (id) on delete cascade,
  status         text not null default 'offline' check (status in ('available', 'busy', 'offline')),
  last_active_at timestamptz not null default now()
);

-- Only people whose profile role is 'helper' may go available / busy.
create or replace function public.protect_helper_status()
returns trigger
language plpgsql
security invoker
as $$
declare
  role_text text;
begin
  select role into role_text from public.profiles where id = new.user_id;
  if new.status in ('available', 'busy') then
    if role_text <> 'helper' then
      raise exception 'Only helpers can be available';
    end if;
  end if;
  return new;
end
$$;

drop trigger if exists protect_helper_status_trg on public.helper_status;
create trigger protect_helper_status_trg
  before insert or update on public.helper_status
  for each row execute function public.protect_helper_status();

create index if not exists helper_status_available_idx
  on public.helper_status (status, last_active_at desc)
  where status = 'available';

-- ----------------------------------------------------------------------------
-- Row Level Security
-- ----------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.mood_checkins enable row level security;
alter table public.helper_status enable row level security;

-- Profiles: everyone signed-in can read names/roles (needed for chat).
-- Only the owner may update, and only display_name (see trigger above).
create policy "profiles_select_all_authenticated"
  on public.profiles for select
  to authenticated
  using (true);

create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- Mood check-ins are private.
create policy "mood_insert_own"
  on public.mood_checkins for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "mood_select_own"
  on public.mood_checkins for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "mood_update_own"
  on public.mood_checkins for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "mood_delete_own"
  on public.mood_checkins for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- helper_status is public availability info.
create policy "helper_status_select_all_authenticated"
  on public.helper_status for select
  to authenticated
  using (true);

create policy "helper_status_insert_own"
  on public.helper_status for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "helper_status_update_own"
  on public.helper_status for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
