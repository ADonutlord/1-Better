-- ============================================================================
-- 1% Better — Study sessions & statistics
--
-- Records completed study-session bursts so the client can render a weekly
-- "hours studied" graph and per-day statistics.
--
-- A "study session" is one uninterrupted focus block (started -> ended). A
-- whole day's study time is the sum of that day's sessions.
--
-- Reads go through direct selects (RLS confines them to the caller's own
-- rows); every insert goes through the SECURITY DEFINER RPC below so the
-- server owns duration/date bookkeeping and can reject negative or zero
-- durations. A study session is deleted (cascade) with its owner's account.
-- ============================================================================

create table if not exists public.study_sessions (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.profiles (id) on delete cascade,
  started_at       timestamptz not null default now(),
  ended_at         timestamptz not null default now(),
  duration_seconds int not null check (duration_seconds > 0 and duration_seconds <= 24 * 60 * 60)
);

alter table public.study_sessions enable row level security;

create policy "study_sessions_select_own"
  on public.study_sessions for select to authenticated
  using ( (select auth.uid()) = user_id );

create index if not exists study_sessions_user_started_idx
  on public.study_sessions (user_id, started_at desc);

-- ----------------------------------------------------------------------------
-- record_study_session: store a finished study block for the caller.
--   p_started_at    when the timer started (UTC)
--   p_ended_at      when the timer ended (UTC)
-- Server-side the date used for daily/weekly stats is derived from ended_at
-- in UTC, matching how the rest of the app stores dates.
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

  return jsonb_build_object(
    'id', v_id,
    'duration_seconds', v_seconds
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- Access control: the table is exposed to the Data API for reads (RLS
-- confines it to the caller's own rows); the RPC is authenticated-only.
-- ----------------------------------------------------------------------------
revoke all on table public.study_sessions from public, anon;
grant select on table public.study_sessions to authenticated;

revoke all on function public.record_study_session(timestamptz, timestamptz) from public, anon;
grant execute on function public.record_study_session(timestamptz, timestamptz) to authenticated;

-- ----------------------------------------------------------------------------
-- Account deletion also wipes the user's study history.
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
