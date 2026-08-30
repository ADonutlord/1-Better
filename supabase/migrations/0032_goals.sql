-- ============================================================================
-- 1% Better — Goals task breakdown
--
-- Lets a user split a big lifetime goal into yearly, monthly and daily
-- actionable tasks. All levels live in one self-referencing `goals` table:
--
--   lifetime  (root, no parent)
--     └─ yearly
--          └─ monthly
--               └─ daily   (leaf - no children)
--
-- Reads go through direct selects (RLS restricts to the caller's own goals);
-- every write goes through the SECURITY DEFINER RPCs below, which always
-- validate that the goal (and its parent chain) belongs to auth.uid().
-- ============================================================================

create table if not exists public.goals (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles (id) on delete cascade,
  parent_goal_id  uuid references public.goals (id) on delete cascade,
  level           text not null check (level in ('lifetime','yearly','monthly','daily')),
  title           text not null,
  description     text not null default '',
  completed       boolean not null default false,
  created_at      timestamptz not null default now()
);

alter table public.goals enable row level security;

create policy "goals_select_own"
  on public.goals for select to authenticated
  using ( (select auth.uid()) = user_id );

-- Index the hierarchy lookups used by the UI and RPCs.
create index if not exists goals_user_parent_idx
  on public.goals (user_id, parent_goal_id);
create index if not exists goals_parent_idx
  on public.goals (parent_goal_id);

-- ----------------------------------------------------------------------------
-- create_goal: create a top-level (lifetime) goal.
-- ----------------------------------------------------------------------------
create or replace function public.create_goal(
  p_title text,
  p_description text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if coalesce(p_title, '') = '' then
    raise exception 'A goal needs a title';
  end if;

  insert into public.goals (user_id, level, title, description)
  values (auth.uid(), 'lifetime', p_title, coalesce(p_description, ''))
  returning id into v_id;
  return v_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- create_goal_child: create a yearly/monthly/daily sub-goal under a parent.
-- The parent must belong to the caller; the child's level is the next one down
-- (lifetime -> yearly -> monthly -> daily). Daily goals have no children.
-- ----------------------------------------------------------------------------
create or replace function public.create_goal_child(
  p_parent_goal_id uuid,
  p_title text,
  p_description text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_parent_level text;
  v_child_level  text;
  v_id           uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if coalesce(p_title, '') = '' then
    raise exception 'A task needs a title';
  end if;

  select g.level into v_parent_level
  from public.goals g
  where g.id = p_parent_goal_id and g.user_id = auth.uid();
  if v_parent_level is null then
    raise exception 'Goal not found';
  end if;

  v_child_level := case v_parent_level
    when 'lifetime' then 'yearly'
    when 'yearly'   then 'monthly'
    when 'monthly'  then 'daily'
    else null
  end;
  if v_child_level is null then
    raise exception 'Daily tasks cannot be broken down further';
  end if;

  insert into public.goals (user_id, parent_goal_id, level, title, description)
  values (auth.uid(), p_parent_goal_id, v_child_level, p_title, coalesce(p_description, ''))
  returning id into v_id;
  return v_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- update_goal: edit the title/description of one of the caller's goals.
-- ----------------------------------------------------------------------------
create or replace function public.update_goal(
  p_goal_id uuid,
  p_title text,
  p_description text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if p_title is not null and p_title = '' then
    raise exception 'A goal needs a title';
  end if;

  update public.goals
     set title       = coalesce(p_title, title),
         description = coalesce(p_description, description)
   where id = p_goal_id and user_id = auth.uid();
end;
$$;

-- ----------------------------------------------------------------------------
-- set_goal_completed: mark a goal (any level) done or reopen it.
-- ----------------------------------------------------------------------------
create or replace function public.set_goal_completed(
  p_goal_id uuid,
  p_completed boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  update public.goals
     set completed = p_completed
   where id = p_goal_id and user_id = auth.uid();
end;
$$;

-- ----------------------------------------------------------------------------
-- delete_goal: remove a goal and, via cascade, everything nested under it.
-- ----------------------------------------------------------------------------
create or replace function public.delete_goal(
  p_goal_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.goals
   where id = p_goal_id and user_id = auth.uid();
end;
$$;

-- ----------------------------------------------------------------------------
-- Access control: the goals table is exposed to the Data API for reads (RLS
-- confines it to the caller's own rows); the RPCs are authenticated-only.
-- ----------------------------------------------------------------------------
revoke all on table public.goals from public, anon;
grant select on table public.goals to authenticated;

revoke all on function public.create_goal(text, text) from public, anon;
revoke all on function public.create_goal_child(uuid, text, text) from public, anon;
revoke all on function public.update_goal(uuid, text, text) from public, anon;
revoke all on function public.set_goal_completed(uuid, boolean) from public, anon;
revoke all on function public.delete_goal(uuid) from public, anon;

grant execute on function public.create_goal(text, text) to authenticated;
grant execute on function public.create_goal_child(uuid, text, text) to authenticated;
grant execute on function public.update_goal(uuid, text, text) to authenticated;
grant execute on function public.set_goal_completed(uuid, boolean) to authenticated;
grant execute on function public.delete_goal(uuid) to authenticated;

-- ----------------------------------------------------------------------------
-- Account deletion also wipes the user's goals.
-- ----------------------------------------------------------------------------
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.helper_status where user_id = v_uid;
  delete from public.goals where user_id = v_uid;
  delete from public.action_history where user_id = v_uid;
  delete from public.mood_checkins where user_id = v_uid;
  delete from public.xp_events where user_id = v_uid;
  delete from public.daily_progress where user_id = v_uid;
  delete from public.blocks where blocker_id = v_uid or blocked_user_id = v_uid;
  delete from public.reports where reporter_id = v_uid or reported_user_id = v_uid;
  delete from public.conversation_participants where user_id = v_uid;
  delete from public.profiles where id = v_uid;
  delete from auth.users where id = v_uid;
end;
$$;
