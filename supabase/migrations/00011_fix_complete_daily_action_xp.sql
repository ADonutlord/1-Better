-- ============================================================================
-- Fix: complete_daily_action double-counted XP in its response.
-- v_prof is reloaded (FOR UPDATE) AFTER internal_add_xp awards XP, so
-- v_prof.total_xp already includes v_earned. The previous return added
-- v_earned again, reporting e.g. 20 total XP when only 10 was awarded.
-- ============================================================================

create or replace function public.complete_daily_action()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_history public.action_history%rowtype;
  v_action  public.actions%rowtype;
  v_prof    public.profiles%rowtype;
  v_earned  int;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_history
  from public.action_history
  where user_id = auth.uid() and assigned_date = current_date
  for update;

  if not found then
    raise exception 'No 1%% action assigned today';
  end if;

  if v_history.completed then
    raise exception 'Today''s 1%% is already completed';
  end if;

  select * into v_action from public.actions where id = v_history.action_id;
  if not found then
    raise exception 'The assigned action is no longer available';
  end if;

  v_earned := v_action.base_xp;

  update public.action_history
     set completed = true, completed_at = now(), xp_earned = v_earned
   where id = v_history.id;

  -- XP (deduplicated) and level.
  perform public.internal_add_xp(auth.uid(), v_earned, 'action', v_history.id);

  -- Streak + last action date. Profile row is locked to prevent double credit.
  -- Reloaded after internal_add_xp, so total_xp/level already include v_earned.
  select * into v_prof from public.profiles where id = auth.uid() for update;

  if v_prof.last_action_date is null or v_prof.last_action_date < current_date - 1 then
    v_prof.current_streak := 1;
  elsif v_prof.last_action_date = current_date - 1 then
    v_prof.current_streak := v_prof.current_streak + 1;
  else
    raise exception 'Today''s 1%% is already completed';
  end if;

  v_prof.longest_streak := greatest(v_prof.longest_streak, v_prof.current_streak);
  v_prof.last_action_date := current_date;

  perform set_config('app.internal', 'on', true);
  update public.profiles
     set current_streak = v_prof.current_streak,
         longest_streak = v_prof.longest_streak,
         last_action_date = v_prof.last_action_date
   where id = auth.uid();

  insert into public.daily_progress (user_id, date, action_id, action_completed, xp_awarded)
  values (auth.uid(), current_date, v_history.action_id, true, v_earned)
  on conflict (user_id, date) do update
    set action_id = excluded.action_id,
        action_completed = true,
        xp_awarded = daily_progress.xp_awarded + excluded.xp_awarded;

  return jsonb_build_object(
    'xp_earned', v_earned,
    'total_xp', v_prof.total_xp,
    'level', public.compute_level(v_prof.total_xp),
    'current_streak', v_prof.current_streak,
    'longest_streak', v_prof.longest_streak,
    'action_id', v_history.action_id
  );
end;
$$;
