-- ============================================================================
-- 1% Better — Testing role
--
-- Adds a 'testing' role for the owner's test accounts so they never interfere
-- with real member accounts:
--   * 'testing' is added to the profiles role check.
--   * Only the owner may assign or revoke the testing role (admins cannot).
--   * Testers only match with other testers in find_match — they can never be
--     matched with real members, and real members never match with testers.
-- ============================================================================

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check
  check (role in ('user', 'helper', 'admin', 'owner', 'testing'));

-- ----------------------------------------------------------------------------
-- admin_set_role: only the owner may manage the testing role.
-- ----------------------------------------------------------------------------
create or replace function public.admin_set_role(p_user_id uuid, p_role text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller_role text;
  v_target_role text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select role into v_caller_role from public.profiles where id = auth.uid();
  if v_caller_role not in ('admin', 'owner') then
    raise exception 'Only admins or the owner can change roles';
  end if;

  if p_role not in ('user', 'helper', 'admin', 'owner', 'testing') then
    raise exception 'Invalid role';
  end if;

  select role into v_target_role from public.profiles where id = p_user_id;
  if v_target_role = 'owner' then
    raise exception 'The owner account cannot be changed';
  end if;

  -- The testing role is owner-only: neither assigning it to someone nor
  -- changing a tester's role is allowed for admins.
  if p_role = 'testing' or v_target_role = 'testing' then
    if v_caller_role <> 'owner' then
      raise exception 'Only the owner can manage the testing role';
    end if;
  end if;

  if p_role = 'owner' then
    if v_caller_role <> 'owner' then
      raise exception 'Only the owner can assign the owner role';
    end if;
    if exists (
      select 1 from public.profiles
      where role = 'owner' and id <> p_user_id
    ) then
      raise exception 'An owner account already exists';
    end if;
  end if;

  perform set_config('app.internal', 'on', true);
  update public.profiles set role = p_role where id = p_user_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- find_match: keep testers and real members in separate pools.
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
  v_user_role         text;
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

  select profession, role into v_user_profession, v_user_role
  from public.profiles where id = v_user_id;

  select c2.id, cp2.user_id into v_partner_conv, v_partner_id
  from public.conversations c2
  join public.conversation_participants cp2 on cp2.conversation_id = c2.id
  join public.profiles p2 on p2.id = cp2.user_id
  where c2.status = 'waiting'
    and cp2.participant_role = 'user'
    and cp2.user_id <> v_user_id
    and c2.id <> v_conv_id
    and (v_user_role = 'testing') = (p2.role = 'testing')
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
