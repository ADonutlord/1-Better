-- Rename the action_history.source 'helper' value to 'peer' now that the
-- helper system is gone (a "peer" is the person you chatted with).

alter table public.action_history
  drop constraint action_history_source_check;

update public.action_history
   set source = 'peer'
 where source = 'helper';

alter table public.action_history
  add constraint action_history_source_check
  check (source in ('algorithm', 'peer'));

-- recommend_action (from 0016) still inserted 'helper'; recreate with 'peer'.
create or replace function public.recommend_action(
  p_conversation_id uuid,
  p_action_id       uuid,
  p_user_id         uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_action  public.actions%rowtype;
  v_row     public.action_history%rowtype;
  v_valid   boolean;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_action from public.actions where id = p_action_id and active = true;
  if not found then
    raise exception 'Action not found';
  end if;

  -- Caller must be in an active conversation with the target user.
  select exists (
    select 1
    from public.conversations c
    join public.conversation_participants me
      on me.conversation_id = c.id and me.user_id = auth.uid()
    join public.conversation_participants them
      on them.conversation_id = c.id and them.user_id = p_user_id
    where c.id = p_conversation_id
      and c.status = 'active'
      and me.user_id <> them.user_id
  ) into v_valid;

  if not v_valid then
    raise exception 'No active conversation with that user';
  end if;

  select * into v_row
  from public.action_history
  where user_id = p_user_id and assigned_date = current_date
  for update;

  if found and v_row.completed then
    raise exception 'This user already completed today''s 1%%';
  end if;

  if found then
    update public.action_history
       set action_id = p_action_id, source = 'peer',
           completed = false, completed_at = null, xp_earned = 0
     where id = v_row.id;
  else
    insert into public.action_history (user_id, action_id, source)
    values (p_user_id, p_action_id, 'peer');
  end if;

  insert into public.messages (conversation_id, sender_id, message, message_type)
  values (p_conversation_id, auth.uid(),
          'Recommended 1% action: ' || v_action.title, 'action_recommendation');

  update public.conversations
     set assigned_action_id = p_action_id
   where id = p_conversation_id;

  return jsonb_build_object('ok', true, 'action_id', p_action_id);
end;
$$;
