-- ============================================================================
-- 1% Better — Add weekly level to the goal breakdown.
--
-- The goal tree was lifetime -> yearly -> monthly -> daily. Inserting a
-- weekly step gives:
--
--   lifetime  (root, no parent)
--     └─ yearly
--          └─ monthly
--               └─ weekly
--                    └─ daily   (leaf - no children)
-- ============================================================================

-- Drop the existing level check constraint (whatever its auto-generated name)
-- and re-create it allowing 'weekly'.
do $$
declare r record;
begin
  for r in
    select conname
    from pg_constraint
    where conrelid = 'public.goals'::regclass
      and contype = 'c'
    order by conname
  loop
    execute format('alter table public.goals drop constraint %I', r.conname);
  end loop;
end $$;

alter table public.goals
  add constraint goals_level_check
  check (level in ('lifetime','yearly','monthly','weekly','daily'));

-- ----------------------------------------------------------------------------
-- create_goal_child: yearly/monthly/weekly/daily sub-goal under a parent.
-- The child's level is the next one down (lifetime -> yearly -> monthly ->
-- weekly -> daily). Daily goals have no children.
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
    when 'monthly'  then 'weekly'
    when 'weekly'   then 'daily'
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

revoke all on function public.create_goal_child(uuid, text, text) from public, anon;
grant execute on function public.create_goal_child(uuid, text, text) to authenticated;