-- ============================================================================
-- 1% Better — server-side logic (RPCs)
--
-- The client is never trusted for XP, level, streak, role, helper status or
-- daily completion. Every sensitive write goes through these functions.
--
-- SECURITY DEFINER functions run as the table owner (bypasses RLS) so every
-- one of them MUST begin by authenticating auth.uid() and authorising the
-- caller. Reads use security invoker so RLS applies.
-- ============================================================================

set search_path = public;

-- ----------------------------------------------------------------------------
-- Level from cumulative XP.
-- Threshold(level n) = 25 * (n - 1) * (n + 2)
--      L1: 0, L2: 100, L3: 250, L4: 450, L5: 700 ...
-- ----------------------------------------------------------------------------
create or replace function public.compute_level(p_total_xp int)
returns int
language sql
immutable
as $$
  select coalesce(max(lv), 1) from (
    select lv from generate_series(1, 200) lv
    where 25 * (lv - 1) * (lv + 2) <= p_total_xp
  ) t;
$$;

-- ----------------------------------------------------------------------------
-- Award XP exactly once (unique user_id+event_type+reference_id).
-- Updates total_xp and level. Never touches role or streak.
-- ----------------------------------------------------------------------------
create or replace function public.internal_add_xp(
  p_user_id      uuid,
  p_amount       int,
  p_event_type   text,
  p_reference_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted uuid;
begin
  if p_user_id is null then
    raise exception 'Not authenticated';
  end if;

  insert into public.xp_events (user_id, amount, event_type, reference_id)
  values (p_user_id, p_amount, p_event_type, p_reference_id)
  on conflict (user_id, event_type, reference_id) do nothing
  returning id into v_inserted;

  if v_inserted is null then
    raise exception 'XP already awarded for this event';
  end if;

  perform set_config('app.internal', 'on', true);
  update public.profiles
     set total_xp = public.profiles.total_xp + p_amount,
         level    = public.compute_level(public.profiles.total_xp + p_amount)
   where id = p_user_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- Daily loop payload for the home screen (read-only, RLS applies).
-- ----------------------------------------------------------------------------
create or replace function public.get_daily_loop()
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'profile', (
      select to_jsonb(p)
      from public.profiles p
      where p.id = (select auth.uid())
    ),
    'daily_progress', (
      select to_jsonb(d)
      from public.daily_progress d
      where d.user_id = (select auth.uid())
        and d.date = current_date
    ),
    'today_action', (
      select to_jsonb(ah) || jsonb_build_object('action', to_jsonb(a))
      from public.action_history ah
      join public.actions a on a.id = ah.action_id
      where ah.user_id = (select auth.uid())
        and ah.assigned_date = current_date
      limit 1
    ),
    'latest_mood', (
      select to_jsonb(m)
      from public.mood_checkins m
      where m.user_id = (select auth.uid())
      order by m.created_at desc
      limit 1
    )
  );
$$;

-- ----------------------------------------------------------------------------
-- A user starts a (waiting) conversation. One active conversation at a time.
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

  return jsonb_build_object('conversation_id', v_conv_id, 'status', 'waiting');
end;
$$;

-- ----------------------------------------------------------------------------
-- Try to auto-match the caller's waiting conversation to a free helper.
-- Concurrency-safe: available helpers are claimed with FOR UPDATE SKIP LOCKED.
-- Returns the active conversation jsonb, or null if no helper is free.
-- ----------------------------------------------------------------------------
create or replace function public.find_helper()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conv_id   uuid;
  v_user_id   uuid;
  v_helper_id uuid;
  v_helper_name text;
  v_role      text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

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

  select hs.user_id into v_helper_id
  from public.helper_status hs
  join public.profiles p on p.id = hs.user_id
  where hs.status = 'available'
    and p.role = 'helper'
    and hs.user_id <> v_user_id
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = hs.user_id and b.blocked_user_id = v_user_id)
         or (b.blocker_id = v_user_id and b.blocked_user_id = hs.user_id)
    )
  order by hs.last_active_at asc
  limit 1
  for update of hs skip locked;

  if v_helper_id is null then
    -- Conversation stays waiting; a helper may accept it later.
    return null;
  end if;

  update public.conversations
     set status = 'active', started_at = now()
   where id = v_conv_id;

  insert into public.conversation_participants (conversation_id, user_id, participant_role)
  values (v_conv_id, v_helper_id, 'helper');

  update public.helper_status
     set status = 'busy', last_active_at = now()
   where user_id = v_helper_id;

  select display_name into v_helper_name from public.profiles where id = v_helper_id;

  insert into public.messages (conversation_id, sender_id, message, message_type)
  values (v_conv_id, v_helper_id, 'You are now connected with ' || v_helper_name || '.', 'system');

  -- Helper earns acceptance XP.
  perform public.internal_add_xp(v_helper_id, 5, 'helper_accept', v_conv_id);

  return jsonb_build_object(
    'conversation_id', v_conv_id,
    'status', 'active',
    'helper_id', v_helper_id,
    'helper_name', v_helper_name
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- A helper accepts a waiting conversation (used when no auto-match happened).
-- Concurrency-safe claim. Requires helper to be available.
-- ----------------------------------------------------------------------------
create or replace function public.accept_conversation(p_conversation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role    text;
  v_conv    public.conversations%rowtype;
  v_user_id uuid;
  v_blocked boolean;
  v_active  boolean;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select role into v_role from public.profiles where id = auth.uid();
  if v_role <> 'helper' then
    raise exception 'Only helpers can accept conversations';
  end if;

  select * into v_conv
  from public.conversations
  where id = p_conversation_id
  for update;

  if not found then
    raise exception 'Conversation not found';
  end if;

  if v_conv.status <> 'waiting' then
    raise exception 'This conversation is no longer waiting for a helper';
  end if;

  select user_id into v_user_id
  from public.conversation_participants
  where conversation_id = p_conversation_id and participant_role = 'user'
  limit 1;

  if v_user_id is null then
    raise exception 'Conversation has no user participant';
  end if;

  -- Helper must be available right now.
  if not exists (
    select 1 from public.helper_status
    where user_id = auth.uid() and status = 'available'
    for update
  ) then
    raise exception 'You are not available to accept conversations';
  end if;

  -- Helper must not already be in an active conversation.
  select exists (
    select 1
    from public.conversations c
    join public.conversation_participants cp on cp.conversation_id = c.id
    where cp.user_id = auth.uid() and c.status = 'active'
  ) into v_active;

  if v_active then
    raise exception 'You already have an active conversation';
  end if;

  -- Blocked (either direction) users are never matched.
  select exists (
    select 1 from public.blocks b
    where (b.blocker_id = auth.uid() and b.blocked_user_id = v_user_id)
       or (b.blocker_id = v_user_id and b.blocked_user_id = auth.uid())
  ) into v_blocked;

  if v_blocked then
    raise exception 'You cannot accept this conversation';
  end if;

  update public.conversations
     set status = 'active', started_at = now()
   where id = p_conversation_id;

  insert into public.conversation_participants (conversation_id, user_id, participant_role)
  values (p_conversation_id, auth.uid(), 'helper');

  update public.helper_status
     set status = 'busy', last_active_at = now()
   where user_id = auth.uid();

  insert into public.messages (conversation_id, sender_id, message, message_type)
  values (p_conversation_id, auth.uid(),
          'You are now connected with a helper. Take your time. 🌱', 'system');

  perform public.internal_add_xp(auth.uid(), 5, 'helper_accept', p_conversation_id);

  return jsonb_build_object(
    'conversation_id', p_conversation_id,
    'status', 'active',
    'helper_id', auth.uid()
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- End an active conversation. Awards XP, releases the helper, records daily
-- progress. Any participant may end it.
-- ----------------------------------------------------------------------------
create or replace function public.end_conversation(p_conversation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conv       public.conversations%rowtype;
  v_caller_role text;
  v_user_id    uuid;
  v_helper_id  uuid;
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

  select participant_role into v_caller_role
  from public.conversation_participants
  where conversation_id = p_conversation_id and user_id = auth.uid();

  if v_caller_role is null then
    raise exception 'You are not a participant of this conversation';
  end if;

  select user_id into v_user_id
  from public.conversation_participants
  where conversation_id = p_conversation_id and participant_role = 'user';

  select user_id into v_helper_id
  from public.conversation_participants
  where conversation_id = p_conversation_id and participant_role = 'helper';

  update public.conversations
     set status = 'ended', ended_at = now()
   where id = p_conversation_id;

  -- The supported user completes a conversation.
  if v_user_id is not null then
    perform public.internal_add_xp(v_user_id, 15, 'chat_complete', p_conversation_id);
    insert into public.daily_progress (user_id, date, conversation_completed)
    values (v_user_id, current_date, true)
    on conflict (user_id, date) do update
      set conversation_completed = true;
  end if;

  -- The helper completes a conversation when they end it.
  if v_helper_id is not null and auth.uid() = v_helper_id then
    perform public.internal_add_xp(v_helper_id, 15, 'helper_complete', p_conversation_id);
  end if;

  -- Release the helper back to available.
  if v_helper_id is not null then
    insert into public.helper_status (user_id, status, last_active_at)
    values (v_helper_id, 'available', now())
    on conflict (user_id) do update
      set status = 'available', last_active_at = now();
  end if;

  update public.conversation_participants
     set left_at = now()
   where conversation_id = p_conversation_id and left_at is null;

  insert into public.messages (conversation_id, sender_id, message, message_type)
  values (p_conversation_id, auth.uid(), 'Conversation ended. Take care. 🌱', 'system');

  return jsonb_build_object('conversation_id', p_conversation_id, 'status', 'ended');
end;
$$;

-- ----------------------------------------------------------------------------
-- Mood check-in. Stores the mood privately and marks today's progress.
-- ----------------------------------------------------------------------------
create or replace function public.check_in_mood(
  p_mood       text,
  p_situations text[] default '{}'
)
returns jsonb
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

  if p_mood not in ('great', 'good', 'okay', 'low', 'stressed') then
    raise exception 'Invalid mood';
  end if;

  insert into public.mood_checkins (user_id, mood, situation)
  values (auth.uid(), p_mood,
          coalesce(p_situations, '{}')::text[])
  returning id into v_id;

  insert into public.daily_progress (user_id, date, mood_completed)
  values (auth.uid(), current_date, true)
  on conflict (user_id, date) do update
    set mood_completed = true;

  return jsonb_build_object('id', v_id, 'mood', p_mood, 'status', 'ok');
end;
$$;

-- ----------------------------------------------------------------------------
-- Assign today's 1% action (algorithm source). Idempotent per day.
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
  values (auth.uid(), p_action_id, v_mood, v_situ, 'algorithm')
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

-- ----------------------------------------------------------------------------
-- A helper recommends an action for the user in their active conversation.
-- Replaces today's not-yet-completed assignment (helper source wins).
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
  v_role    text;
  v_action  public.actions%rowtype;
  v_row     public.action_history%rowtype;
  v_valid   boolean;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select role into v_role from public.profiles where id = auth.uid();
  if v_role <> 'helper' then
    raise exception 'Only helpers can recommend actions';
  end if;

  select * into v_action from public.actions where id = p_action_id and active = true;
  if not found then
    raise exception 'Action not found';
  end if;

  -- Must be an active conversation with this helper and this user.
  select exists (
    select 1
    from public.conversations c
    join public.conversation_participants hp
      on hp.conversation_id = c.id and hp.user_id = auth.uid() and hp.participant_role = 'helper'
    join public.conversation_participants up
      on up.conversation_id = c.id and up.user_id = p_user_id and up.participant_role = 'user'
    where c.id = p_conversation_id and c.status = 'active'
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
       set action_id = p_action_id, source = 'helper',
           completed = false, completed_at = null, xp_earned = 0
     where id = v_row.id;
  else
    insert into public.action_history (user_id, action_id, source)
    values (p_user_id, p_action_id, 'helper');
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
-- Complete today's 1% action. Validates it, awards XP, advances the streak,
-- recomputes level, records daily progress. All server-side, race-safe.
-- ----------------------------------------------------------------------------
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
    'total_xp', v_prof.total_xp + v_earned,
    'level', public.compute_level(v_prof.total_xp + v_earned),
    'current_streak', v_prof.current_streak,
    'longest_streak', v_prof.longest_streak,
    'action_id', v_history.action_id
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- Focus timer completion: +15 XP, once per day.
-- ----------------------------------------------------------------------------
create or replace function public.add_focus_xp()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ref uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  v_ref := md5(auth.uid()::text || current_date::text || 'focus')::uuid;
  perform public.internal_add_xp(auth.uid(), 15, 'focus', v_ref);

  return jsonb_build_object('xp', 15, 'status', 'ok');
end;
$$;

-- ----------------------------------------------------------------------------
-- Helper availability.
-- ----------------------------------------------------------------------------
create or replace function public.set_helper_status(p_status text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_status not in ('available', 'offline') then
    raise exception 'Invalid status';
  end if;

  insert into public.helper_status (user_id, status, last_active_at)
  values (auth.uid(), p_status, now())
  on conflict (user_id) do update
    set status = excluded.status, last_active_at = now();
end;
$$;

-- ----------------------------------------------------------------------------
-- Safety: report and block.
-- ----------------------------------------------------------------------------
create or replace function public.report_user(
  p_reported_user_id uuid,
  p_reason           text,
  p_conversation_id  uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_valid bool;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_reported_user_id = auth.uid() then
    raise exception 'You cannot report yourself';
  end if;

  if length(trim(p_reason)) = 0 then
    raise exception 'A reason is required';
  end if;

  -- Must share a conversation with the reported user.
  if p_conversation_id is not null then
    select exists (
      select 1 from public.conversation_participants a
      join public.conversation_participants b on b.conversation_id = a.conversation_id
      where a.user_id = auth.uid()
        and b.user_id = p_reported_user_id
        and a.conversation_id = p_conversation_id
    ) into v_valid;
    if not v_valid then
      raise exception 'You can only report someone you talked to';
    end if;
  end if;

  insert into public.reports (reporter_id, reported_user_id, conversation_id, reason)
  values (auth.uid(), p_reported_user_id, p_conversation_id, trim(p_reason));
end;
$$;

create or replace function public.block_user(p_blocked_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_blocked_user_id = auth.uid() then
    raise exception 'You cannot block yourself';
  end if;

  insert into public.blocks (blocker_id, blocked_user_id)
  values (auth.uid(), p_blocked_user_id)
  on conflict (blocker_id, blocked_user_id) do nothing;
end;
$$;

create or replace function public.unblock_user(p_blocked_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.blocks
  where blocker_id = auth.uid() and blocked_user_id = p_blocked_user_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- Cancel the caller's own waiting conversation (no helper was found yet).
-- ----------------------------------------------------------------------------
create or replace function public.cancel_waiting_conversation()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conv_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select c.id into v_conv_id
  from public.conversations c
  join public.conversation_participants cp on cp.conversation_id = c.id
  where c.status = 'waiting'
    and cp.user_id = auth.uid()
    and cp.participant_role = 'user'
  order by c.created_at desc
  limit 1
  for update;

  if v_conv_id is null then
    return;
  end if;

  update public.conversations
     set status = 'cancelled', ended_at = now()
   where id = v_conv_id;

  update public.conversation_participants
     set left_at = now()
   where conversation_id = v_conv_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- Admin: change a user's role. Only an existing admin may call this.
-- ----------------------------------------------------------------------------
create or replace function public.admin_set_role(p_user_id uuid, p_role text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller_role text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select role into v_caller_role from public.profiles where id = auth.uid();
  if v_caller_role <> 'admin' then
    raise exception 'Only admins can change roles';
  end if;

  if p_role not in ('user', 'helper', 'admin') then
    raise exception 'Invalid role';
  end if;

  perform set_config('app.internal', 'on', true);
  update public.profiles set role = p_role where id = p_user_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- Self-service account deletion. Wipes the user's data, profile and the auth
-- account itself. Runs as the function owner (postgres) so it may delete from
-- auth.users.
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
