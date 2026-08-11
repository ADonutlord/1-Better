-- ============================================================================
-- 1% Better — Age + profession editing
--
-- 1. profiles.birth_year: captured at signup (stored as birth year rather
--    than age so it never goes stale). Optional; used for same-age matching.
-- 2. handle_new_user reads birth_year from the signup metadata.
-- 3. update_my_profile lets a user change their own profession and/or birth
--    year (age >= 13 enforced server-side).
-- 4. find_match prefers the same age first, then the closest age, then the
--    profession ranking.
-- ============================================================================

alter table public.profiles
  add column if not exists birth_year int;
alter table public.profiles
  drop constraint if exists profiles_birth_year_check;
alter table public.profiles
  add constraint profiles_birth_year_check
  check (birth_year is null or (birth_year between 1900 and 2100));

-- Capture profession + birth year chosen at signup (from auth metadata).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_birth_year int;
begin
  v_birth_year := nullif((new.raw_user_meta_data ->> 'birth_year')::int, 0);

  insert into public.profiles (id, display_name, role, profession, birth_year)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), 'Friend'),
    'user',
    coalesce(nullif(new.raw_user_meta_data ->> 'profession', ''), 'other'),
    v_birth_year
  )
  on conflict (id) do nothing;
  return new;
end
$$;

-- ----------------------------------------------------------------------------
-- A user updates their own profession and/or birth year.
-- Passing NULL for an argument leaves that field unchanged.
-- ----------------------------------------------------------------------------
create or replace function public.update_my_profile(
  p_profession text default null,
  p_birth_year int default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_age int;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_profession is not null and p_profession not in (
    'student', 'teacher', 'software_engineer', 'engineer', 'designer',
    'artist', 'writer', 'doctor', 'nurse', 'therapist_counselor',
    'entrepreneur', 'sales_marketing', 'finance_accounting', 'lawyer',
    'trades', 'chef', 'hospitality_retail', 'caregiving',
    'parent_homemaker', 'unemployed_job_seeking', 'retired', 'other'
  ) then
    raise exception 'Invalid profession';
  end if;

  if p_birth_year is not null then
    v_age := date_part('year', now())::int - p_birth_year;
    if v_age < 13 or v_age > 120 then
      raise exception 'You must be at least 13 years old';
    end if;
  end if;

  perform set_config('app.internal', 'on', true);
  update public.profiles
     set profession = coalesce(p_profession, profession),
         birth_year = coalesce(p_birth_year, birth_year)
   where id = auth.uid();
end;
$$;

revoke all on function public.update_my_profile(text, int) from public, anon;
grant execute on function public.update_my_profile(text, int) to authenticated;

-- ----------------------------------------------------------------------------
-- find_match: same-age first, then closest age, then profession ranking.
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
    (p2.birth_year is not null and v_user_birth_year is not null
     and p2.birth_year = v_user_birth_year) desc,
    case
      when p2.birth_year is null or v_user_birth_year is null then 999999
      else abs(p2.birth_year - v_user_birth_year)
    end asc,
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
