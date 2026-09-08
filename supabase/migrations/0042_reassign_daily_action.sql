-- Reassign today's 1% after a fresh mood check-in.
-- Keeps the completed-day guard: an already-completed task is never changed.
-- Mirrors assign_daily_action (00010) but UPDATEs today's uncompleted row so
-- the recommendation reflects the mood the user just saved.

create or replace function public.reassign_daily_action(p_action_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row    public.action_history%rowtype;
  v_action public.actions%rowtype;
  v_mood   text;
  v_situ   text[];
  v_new_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_action_id is null then
    raise exception 'An action is required';
  end if;

  select * into v_action from public.actions where id = p_action_id and active = true;
  if not found then
    raise exception 'Action not found';
  end if;

  select mood, situation into v_mood, v_situ
  from public.mood_checkins
  where user_id = auth.uid()
  order by created_at desc
  limit 1;

  select * into v_row
  from public.action_history
  where user_id = auth.uid() and assigned_date = current_date
  for update;

  if found then
    if v_row.completed then
      return jsonb_build_object(
        'history_id', v_row.id,
        'action_id', v_row.action_id,
        'source', v_row.source,
        'status', 'completed'
      );
    end if;

    update public.action_history
       set action_id = p_action_id,
           mood_at_assignment = v_mood,
           situation_at_assignment = coalesce(v_situ, '{}'),
           source = 'algorithm'
     where id = v_row.id;

    update public.daily_progress
       set action_id = p_action_id
     where user_id = auth.uid() and date = current_date;

    return jsonb_build_object(
      'history_id', v_row.id,
      'action_id', p_action_id,
      'source', 'algorithm',
      'status', 'reassigned'
    );
  end if;

  insert into public.action_history
    (user_id, action_id, mood_at_assignment, situation_at_assignment, source)
  values (auth.uid(), p_action_id, v_mood, coalesce(v_situ, '{}'), 'algorithm')
  returning id into v_new_id;

  insert into public.daily_progress (user_id, date, action_id)
  values (auth.uid(), current_date, p_action_id)
  on conflict (user_id, date) do update
    set action_id = excluded.action_id;

  return jsonb_build_object(
    'history_id', v_new_id,
    'action_id', p_action_id,
    'source', 'algorithm',
    'status', 'assigned'
  );
end;
$$;

revoke all on function public.reassign_daily_action(uuid) from public, anon;
grant execute on function public.reassign_daily_action(uuid) to authenticated;