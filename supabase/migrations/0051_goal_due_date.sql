-- ============================================================================
-- 1% Better — Optional due date (deadline) on goals.
-- ============================================================================

alter table public.goals add column due_date date;

-- ----------------------------------------------------------------------------
-- create_goal: create a top-level (lifetime) goal with an optional deadline.
-- ----------------------------------------------------------------------------
create or replace function public.create_goal(
  p_title text,
  p_description text default '',
  p_due_date date default null
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

  insert into public.goals (user_id, level, title, description, due_date)
  values (auth.uid(), 'lifetime', p_title, coalesce(p_description, ''), p_due_date)
  returning id into v_id;
  return v_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- create_goal_child: create a sub-goal at the next level down, with an
-- optional deadline.
-- ----------------------------------------------------------------------------
create or replace function public.create_goal_child(
  p_parent_goal_id uuid,
  p_title text,
  p_description text default '',
  p_due_date date default null
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
    when 'monthly'  then 'weekly'
    when 'weekly'   then 'daily'
    else null
  end;
  if v_child_level is null then
    raise exception 'Daily tasks cannot be broken down further';
  end if;

  insert into public.goals (user_id, parent_goal_id, level, title, description, due_date)
  values (auth.uid(), p_parent_goal_id, v_child_level, p_title, coalesce(p_description, ''), p_due_date)
  returning id into v_id;
  return v_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- update_goal: edit title/description/due date. The client always sends the
-- full due date value (null clears it).
-- ----------------------------------------------------------------------------
create or replace function public.update_goal(
  p_goal_id uuid,
  p_title text default null,
  p_description text default null,
  p_due_date date default null
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
         description = coalesce(p_description, description),
         due_date    = p_due_date
   where id = p_goal_id and user_id = auth.uid();
end;
$$;

-- ----------------------------------------------------------------------------
-- Access control: revoke the old signatures (still granted by default) and
-- grant the new ones with the due date parameter.
-- ----------------------------------------------------------------------------
revoke all on function public.create_goal(text, text) from public, anon;
revoke all on function public.create_goal_child(uuid, text, text) from public, anon;
revoke all on function public.update_goal(uuid, text, text) from public, anon;

revoke all on function public.create_goal(text, text, date) from public, anon;
revoke all on function public.create_goal_child(uuid, text, text, date) from public, anon;
revoke all on function public.update_goal(uuid, text, text, date) from public, anon;

grant execute on function public.create_goal(text, text, date) to authenticated;
grant execute on function public.create_goal_child(uuid, text, text, date) to authenticated;
grant execute on function public.update_goal(uuid, text, text, date) to authenticated;