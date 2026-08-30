-- ============================================================================
-- 1% Better — Study XP + daily screen time
--
-- 1) Studying now earns XP: every minute studied = +5 XP on the level system.
--    XP is granted server-side inside record_study_session so the client never
--    picks its own reward. The reward is deduplicated via internal_add_xp using
--    the session's own id as the reference (unique per session).
--
-- 2) daily_screen_time lets a student log how many minutes they spent on their
--    phone each day. Apps cannot read a device's usage automatically (that data
--    lives only in Android Digital Wellbeing / iOS Screen Time and is private),
--    so the student enters it manually and we show it beside study time.
--
-- A local daily screen-time value (a whole number of minutes for a calendar
-- day) is stored in a `daily_screen_time` table owned by the caller.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Study XP: award 5 XP per full minute studied, once per session.
-- ----------------------------------------------------------------------------
create or replace function public.record_study_session(
  p_started_at timestamptz,
  p_ended_at   timestamptz default now()
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seconds int;
  v_id      uuid;
  v_minutes int;
  v_xp      int;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_started_at is null then
    raise exception 'A session start time is required';
  end if;

  if p_ended_at is null then
    p_ended_at := now();
  end if;

  v_seconds := extract(epoch from (p_ended_at - p_started_at))::int;

  if v_seconds <= 0 then
    raise exception 'Session duration must be positive';
  end if;
  if v_seconds > 24 * 60 * 60 then
    raise exception 'Session duration cannot exceed 24 hours';
  end if;

  insert into public.study_sessions (user_id, started_at, ended_at, duration_seconds)
  values (auth.uid(), p_started_at, p_ended_at, v_seconds)
  returning id into v_id;

  -- 5 XP per minute studied (rounded up to the nearest whole minute; a real
  -- study block is always at least 15 minutes so this is meaningful).
  v_minutes := ceil(v_seconds / 60.0)::int;
  v_xp      := v_minutes * 5;

  if v_xp > 0 then
    perform public.internal_add_xp(auth.uid(), v_xp, 'study', v_id);
  end if;

  return jsonb_build_object(
    'id', v_id,
    'duration_seconds', v_seconds,
    'minutes', v_minutes,
    'xp_awarded', v_xp
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- daily_screen_time: one local "minutes on phone" value per calendar day.
-- ----------------------------------------------------------------------------
create table if not exists public.daily_screen_time (
  id       uuid primary key default gen_random_uuid(),
  user_id  uuid not null references public.profiles (id) on delete cascade,
  day      date not null,
  minutes  int not null check (minutes >= 0 and minutes <= 24 * 60),
  unique (user_id, day)
);

alter table public.daily_screen_time enable row level security;

create policy "daily_screen_time_select_own"
  on public.daily_screen_time for select to authenticated
  using ( (select auth.uid()) = user_id );

create index if not exists daily_screen_time_user_day_idx
  on public.daily_screen_time (user_id, day desc);

-- ----------------------------------------------------------------------------
-- set_screen_time: upsert the caller's screen-time minutes for a date.
-- ----------------------------------------------------------------------------
create or replace function public.set_screen_time(
  p_day      date,
  p_minutes  int
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_day is null then
    raise exception 'A date is required';
  end if;

  if p_minutes < 0 or p_minutes > 24 * 60 then
    raise exception 'Screen time must be between 0 and 1440 minutes';
  end if;

  insert into public.daily_screen_time (user_id, day, minutes)
  values (auth.uid(), p_day, p_minutes)
  on conflict (user_id, day) do update
    set minutes = excluded.minutes;

  return jsonb_build_object('day', p_day, 'minutes', p_minutes, 'status', 'ok');
end;
$$;

-- ----------------------------------------------------------------------------
-- Access control.
-- ----------------------------------------------------------------------------
revoke all on table public.daily_screen_time from public, anon;
grant select on table public.daily_screen_time to authenticated;

revoke all on function public.set_screen_time(date, int) from public, anon;
grant execute on function public.set_screen_time(date, int) to authenticated;

-- ----------------------------------------------------------------------------
-- Account deletion also wipes the user's screen-time history.
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
  delete from public.goals where user_id = v_uid;
  delete from public.study_sessions where user_id = v_uid;
  delete from public.daily_screen_time where user_id = v_uid;
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
