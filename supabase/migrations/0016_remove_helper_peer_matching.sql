-- ============================================================================
-- 1% Better — Remove helper system, peer-to-peer matching
--
-- The helper role, helper_status table and helper-only RPCs are removed.
-- Anyone can ask to talk; the matching algorithm pairs two waiting people
-- whose professions are the same or similar (see profession_rank in 0015).
-- Both peers get chat_complete XP and conversation credit.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Drop the RLS policy that let available helpers browse waiting chats
--    (depends on helper_status, so drop it before the table).
-- ----------------------------------------------------------------------------
drop policy if exists "conversations_select_waiting_available_helper" on public.conversations;

-- ----------------------------------------------------------------------------
-- 2. Drop helper_status (table, trigger, function, policies, index)
-- ----------------------------------------------------------------------------
drop policy if exists "helper_status_select_all_authenticated" on public.helper_status;
drop policy if exists "helper_status_insert_own" on public.helper_status;
drop policy if exists "helper_status_update_own" on public.helper_status;
drop policy if exists "helper_status_delete_own" on public.helper_status;
drop trigger if exists protect_helper_status_trg on public.helper_status;
drop function if exists public.protect_helper_status();
drop table if exists public.helper_status;

-- ----------------------------------------------------------------------------
-- 3. Drop helper-only RPCs
-- ----------------------------------------------------------------------------
drop function if exists public.find_helper();
drop function if exists public.accept_conversation(uuid);
drop function if exists public.set_helper_status(text);

-- ----------------------------------------------------------------------------
-- 4. start_conversation: keep as-is, but return a shape the app can parse
--    (the app builds a Conversation from the RPC result).
-- ----------------------------------------------------------------------------
create or replace function public.start_conversation()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conv_id uuid;
  v_exists  boolean;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select exists (
    select 1
    from public.conversations c
    join public.conversation_participants cp on cp.conversation_id = c.id
    where cp.user_id = auth.uid()
      and c.status in ('waiting', 'active')
  ) into v_exists;

  if v_exists then
    raise exception 'You already have an active conversation';
  end if;

  insert into public.conversations (status)
  values ('waiting')
  returning id into v_conv_id;

  insert into public.conversation_participants (conversation_id, user_id, participant_role)
  values (v_conv_id, auth.uid(), 'user');

  return jsonb_build_object(
    'id', v_conv_id,
    'conversation_id', v_conv_id,
    'status', 'waiting',
    'created_at', now()
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- 5. find_match: pair the caller's waiting conversation with the best waiting
--    partner (same / similar profession first, oldest request first), then
--    fall back to any other waiting person. Concurrency-safe via an advisory
--    lock plus FOR UPDATE SKIP LOCKED.
--
--    The partner's conversation becomes the active one (they are already
--    watching it); the caller joins it and their own waiting conversation is
--    withdrawn. Returns null when no one else is waiting.
-- ----------------------------------------------------------------------------
create or replace function public.find_match()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conv_id           uuid;
  v_user_id           uuid;
  v_user_profession   text;
  v_partner_conv      uuid;
  v_partner_id        uuid;
  v_partner_name      text;
  v_partner_profession text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  -- Serialise matching so two users never race for the same pair.
  perform pg_advisory_xact_lock(727001);

  select c.id, cp.user_id into v_conv_id, v_user_id
  from public.conversations c
  join public.conversation_participants cp on cp.conversation_id = c.id
  where c.status = 'waiting'
    and cp.user_id = auth.uid()
    and cp.participant_role = 'user'
  order by c.created_at asc
  limit 1
  for update of c skip locked;

  if v_conv_id is null then
    return null;
  end if;

  select profession into v_user_profession
  from public.profiles where id = v_user_id;

  select c2.id, cp2.user_id into v_partner_conv, v_partner_id
  from public.conversations c2
  join public.conversation_participants cp2 on cp2.conversation_id = c2.id
  join public.profiles p2 on p2.id = cp2.user_id
  where c2.status = 'waiting'
    and cp2.participant_role = 'user'
    and cp2.user_id <> v_user_id
    and c2.id <> v_conv_id
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = cp2.user_id and b.blocked_user_id = v_user_id)
         or (b.blocker_id = v_user_id and b.blocked_user_id = cp2.user_id)
    )
  order by public.profession_rank(v_user_profession, p2.profession) desc,
           c2.created_at asc
  limit 1
  for update of c2 skip locked;

  if v_partner_conv is null then
    -- No one else is waiting right now; conversation stays waiting.
    return null;
  end if;

  -- Activate the partner's conversation and join the caller to it.
  update public.conversations
     set status = 'active', started_at = now()
   where id = v_partner_conv;

  insert into public.conversation_participants (conversation_id, user_id, participant_role)
  values (v_partner_conv, v_user_id, 'user');

  -- Withdraw the caller's own waiting conversation.
  update public.conversations
     set status = 'cancelled', ended_at = now()
   where id = v_conv_id;

  update public.conversation_participants
     set left_at = now()
   where conversation_id = v_conv_id;

  select display_name, profession into v_partner_name, v_partner_profession
  from public.profiles where id = v_partner_id;

  insert into public.messages (conversation_id, sender_id, message, message_type)
  values (v_partner_conv, v_partner_id,
          'You and ' || v_partner_name || ' are now connected. 🌱', 'system');

  return jsonb_build_object(
    'id', v_partner_conv,
    'conversation_id', v_partner_conv,
    'status', 'active',
    'created_at', now(),
    'matched_user_id', v_partner_id,
    'matched_user_name', v_partner_name,
    'matched_user_profession', v_partner_profession
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- 6. end_conversation: both peers complete the conversation together.
-- ----------------------------------------------------------------------------
create or replace function public.end_conversation(p_conversation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conv  public.conversations%rowtype;
  v_me    uuid;
  r       record;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_conv
  from public.conversations
  where id = p_conversation_id
  for update;

  if not found then
    raise exception 'Conversation not found';
  end if;

  if v_conv.status <> 'active' then
    raise exception 'Conversation is not active';
  end if;

  select user_id into v_me
  from public.conversation_participants
  where conversation_id = p_conversation_id and user_id = auth.uid();

  if v_me is null then
    raise exception 'You are not a participant of this conversation';
  end if;

  update public.conversations
     set status = 'ended', ended_at = now()
   where id = p_conversation_id;

  -- Both peers earn the chat completion reward.
  for r in
    select user_id from public.conversation_participants
    where conversation_id = p_conversation_id and left_at is null
  loop
    perform public.internal_add_xp(r.user_id, 15, 'chat_complete', p_conversation_id);
    insert into public.daily_progress (user_id, date, conversation_completed)
    values (r.user_id, current_date, true)
    on conflict (user_id, date) do update
      set conversation_completed = true;
  end loop;

  update public.conversation_participants
     set left_at = now()
   where conversation_id = p_conversation_id and left_at is null;

  insert into public.messages (conversation_id, sender_id, message, message_type)
  values (p_conversation_id, auth.uid(), 'Conversation ended. Take care. 🌱', 'system');

  return jsonb_build_object('conversation_id', p_conversation_id, 'status', 'ended');
end;
$$;

-- ----------------------------------------------------------------------------
-- 7. recommend_action: any participant may recommend an action (was helper-only).
-- ----------------------------------------------------------------------------
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

-- ----------------------------------------------------------------------------
-- 8. Grants: find_match is the new public matching RPC.
-- ----------------------------------------------------------------------------
grant execute on function public.find_match() to authenticated;
