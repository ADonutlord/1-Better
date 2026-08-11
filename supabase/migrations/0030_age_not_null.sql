-- ============================================================================
-- 1% Better — Age is mandatory
--
-- birth_year becomes NOT NULL. Existing accounts (no age) are backfilled with
-- a neutral default (2000), handle_new_user falls back to the same default
-- when signup metadata lacks a birth year, and find_match no longer needs to
-- tolerate missing ages.
-- ============================================================================

alter table public.profiles
  alter column birth_year set default 2000;

update public.profiles
   set birth_year = 2000
 where birth_year is null;

alter table public.profiles
  alter column birth_year set not null;

-- Capture birth year from signup metadata, defaulting when absent.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, role, profession, birth_year)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), 'Friend'),
    'user',
    coalesce(nullif(new.raw_user_meta_data ->> 'profession', ''), 'other'),
    coalesce(nullif((new.raw_user_meta_data ->> 'birth_year')::int, 0), 2000)
  )
  on conflict (id) do nothing;
  return new;
end
$$;

-- find_match: every profile has a birth_year now, so the ordering is direct.
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
  v_user_birth_year   int;
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

  select profession, role, birth_year into v_user_profession, v_user_role, v_user_birth_year
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
  order by
    (p2.birth_year = v_user_birth_year) desc,
    abs(p2.birth_year - v_user_birth_year) asc,
    public.profession_rank(v_user_profession, p2.profession) desc,
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
