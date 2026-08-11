-- ============================================================================
-- 1% Better — Professions
-- 1. profiles.profession: mandatory (defaults to 'other'), chosen at signup.
-- 2. profession_rank(): similarity score between two professions.
-- 3. find_helper(): matches people to helpers with the same or a similar
--    profession first (falling back to any available helper).
--
-- Scoring:
--   4 = same profession
--   3 = same professional group (e.g. student <-> teacher)
--   2 = curated complementary pair (e.g. engineer <-> trades)
--   1 = unrelated profession
-- ============================================================================

alter table public.profiles add column if not exists profession text not null default 'other';
alter table public.profiles drop constraint if exists profiles_profession_check;
alter table public.profiles
  add constraint profiles_profession_check
  check (profession in (
    'student', 'teacher', 'software_engineer', 'engineer', 'designer',
    'artist', 'writer', 'doctor', 'nurse', 'therapist_counselor',
    'entrepreneur', 'sales_marketing', 'finance_accounting', 'lawyer',
    'trades', 'chef', 'hospitality_retail', 'caregiving',
    'parent_homemaker', 'unemployed_job_seeking', 'retired', 'other'
  ));

-- Capture the profession chosen at signup (from auth user metadata).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security invoker
as $$
begin
  insert into public.profiles (id, display_name, role, profession)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), 'Friend'),
    'user',
    coalesce(nullif(new.raw_user_meta_data ->> 'profession', ''), 'other')
  )
  on conflict (id) do nothing;
  return new;
end
$$;

-- ----------------------------------------------------------------------------
-- Similarity score between two professions. Higher = better match.
-- ----------------------------------------------------------------------------
create or replace function public.profession_rank(p_human text, p_helper text)
returns int
language plpgsql
stable
as $$
declare
  i int;
  v_group_a text;
  v_group_b text;
  v_groups text[][] := array[
    array['student','teacher'],
    array['software_engineer','engineer'],
    array['designer','artist','writer'],
    array['doctor','nurse','therapist_counselor'],
    array['entrepreneur','sales_marketing','finance_accounting'],
    array['lawyer'],
    array['trades'],
    array['chef'],
    array['hospitality_retail'],
    array['caregiving','parent_homemaker'],
    array['unemployed_job_seeking','retired','other']
  ];
  v_pairs text[][] := array[
    array['software_engineer','designer'],
    array['entrepreneur','finance_accounting'],
    array['entrepreneur','lawyer'],
    array['engineer','trades'],
    array['chef','hospitality_retail'],
    array['doctor','therapist_counselor'],
    array['nurse','caregiving'],
    array['parent_homemaker','caregiving'],
    array['student','engineer']
  ];
begin
  if p_human is null or p_helper is null then
    return 1;
  end if;

  if p_human = p_helper then
    return 4;
  end if;

  for i in 1..array_length(v_groups, 1) loop
    if array_position(v_groups[i], p_human) is not null then
      v_group_a := 'g' || i;
    end if;
    if array_position(v_groups[i], p_helper) is not null then
      v_group_b := 'g' || i;
    end if;
  end loop;

  if v_group_a is not null and v_group_a = v_group_b then
    return 3;
  end if;

  for i in 1..array_length(v_pairs, 1) loop
    if (v_pairs[i][1] = p_human and v_pairs[i][2] = p_helper)
       or (v_pairs[i][1] = p_helper and v_pairs[i][2] = p_human) then
      return 2;
    end if;
  end loop;

  return 1;
end;
$$;

-- ----------------------------------------------------------------------------
-- find_helper: prefer helpers whose profession is the same or similar to the
-- user's, then fall back to the least-recently-active available helper.
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
  v_helper_profession text;
  v_user_profession text;
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

  select profession into v_user_profession
  from public.profiles where id = v_user_id;

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
  order by public.profession_rank(v_user_profession, p.profession) desc,
           hs.last_active_at asc
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

  select display_name, profession into v_helper_name, v_helper_profession
  from public.profiles where id = v_helper_id;

  insert into public.messages (conversation_id, sender_id, message, message_type)
  values (v_conv_id, v_helper_id, 'You are now connected with ' || v_helper_name || '.', 'system');

  -- Helper earns acceptance XP.
  perform public.internal_add_xp(v_helper_id, 5, 'helper_accept', v_conv_id);

  return jsonb_build_object(
    'conversation_id', v_conv_id,
    'status', 'active',
    'helper_id', v_helper_id,
    'helper_name', v_helper_name,
    'helper_profession', v_helper_profession
  );
end;
$$;
