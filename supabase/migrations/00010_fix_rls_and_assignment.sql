-- ============================================================================
-- Fix 1: RLS infinite recursion on conversation_participants.
-- The old participants_select_member policy filtered the table by querying
-- itself, which Postgres detects as infinite recursion. A SECURITY DEFINER
-- helper (runs as owner, bypasses RLS) breaks the cycle and is reused by the
-- conversations / messages policies.
--
-- Fix 2: assign_daily_action inserted NULL situation_at_assignment when the
-- user had no mood check-in yet (NOT NULL violation). Now coalesced.
-- ============================================================================

create or replace function public.is_conversation_participant(
  p_conversation_id uuid,
  p_user_id         uuid
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.conversation_participants cp
    where cp.conversation_id = p_conversation_id
      and cp.user_id = p_user_id
  );
$$;

grant execute on function public.is_conversation_participant(uuid, uuid) to authenticated;

drop policy if exists "participants_select_member" on public.conversation_participants;
create policy "participants_select_member"
  on public.conversation_participants for select
  to authenticated
  using (public.is_conversation_participant(conversation_id, auth.uid()));

drop policy if exists "conversations_select_participant" on public.conversations;
create policy "conversations_select_participant"
  on public.conversations for select
  to authenticated
  using (public.is_conversation_participant(id, auth.uid()));

drop policy if exists "messages_select_participant" on public.messages;
create policy "messages_select_participant"
  on public.messages for select
  to authenticated
  using (public.is_conversation_participant(conversation_id, auth.uid()));

drop policy if exists "messages_insert_participant_active" on public.messages;
create policy "messages_insert_participant_active"
  on public.messages for insert
  to authenticated
  with check (
    (select auth.uid()) = sender_id
    and exists (
      select 1 from public.conversations c
      where c.id = conversation_id and c.status = 'active'
    )
    and public.is_conversation_participant(conversation_id, auth.uid())
  );

-- ----------------------------------------------------------------------------
-- assign_daily_action: tolerate a missing mood check-in.
-- ----------------------------------------------------------------------------
create or replace function public.assign_daily_action(p_action_id uuid)
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

  select * into v_row
  from public.action_history
  where user_id = auth.uid() and assigned_date = current_date
  for update;

  if found then
    if v_row.completed then
      raise exception 'Today''s 1%% is already completed';
    end if;
    return jsonb_build_object(
      'history_id', v_row.id,
      'action_id', v_row.action_id,
      'source', v_row.source,
      'status', 'existing'
    );
  end if;

  select mood, situation into v_mood, v_situ
  from public.mood_checkins
  where user_id = auth.uid()
  order by created_at desc
  limit 1;

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
