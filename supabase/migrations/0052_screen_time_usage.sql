-- ============================================================================
-- 1% Better — Automatic screen-time measurement (Android UsageStatsManager).
--
-- Replaces the manual "set_screen_time" workflow. The app now measures usage
-- on-device (per app, including the launcher -> "Home screen") and logs it
-- here:
--
--   * app_screen_time     — one row per user/day/app (package, label, minutes)
--   * daily_screen_time   — unchanged day totals (now written automatically by
--                           log_day_usage; total == sum of the per-app minutes)
--
-- log_day_usage REPLACES the day's breakdown (deletes apps that are no longer
-- reported) and upserts the daily total, so a fresh sync always reflects the
-- device.
-- ============================================================================

create table if not exists public.app_screen_time (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles (id) on delete cascade,
  day          date not null,
  package_name text not null,
  app_label    text not null default '',
  minutes      int not null check (minutes >= 0 and minutes <= 24 * 60),
  unique (user_id, day, package_name)
);

alter table public.app_screen_time enable row level security;

create policy "app_screen_time_select_own"
  on public.app_screen_time for select to authenticated
  using ( (select auth.uid()) = user_id );

create index if not exists app_screen_time_user_day_idx
  on public.app_screen_time (user_id, day desc);

-- ----------------------------------------------------------------------------
-- log_day_usage: store a measured day. p_apps is a jsonb array of
--   {package, label, minutes}. Replaces the whole day's breakdown and upserts
-- the daily total.
-- ----------------------------------------------------------------------------
create or replace function public.log_day_usage(
  p_day date,
  p_total_minutes int,
  p_apps jsonb
)
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

  insert into public.daily_screen_time (user_id, day, minutes)
  values (v_uid, p_day, greatest(coalesce(p_total_minutes, 0), 0))
  on conflict (user_id, day) do update
    set minutes = excluded.minutes;

  -- Remove apps no longer reported for that day.
  delete from public.app_screen_time
   where user_id = v_uid and day = p_day
     and package_name <> all (
       select (x->>'package')::text
       from jsonb_array_elements(coalesce(p_apps, '[]'::jsonb)) x
     );

  insert into public.app_screen_time (user_id, day, package_name, app_label, minutes)
  select v_uid, p_day,
         (x->>'package')::text,
         coalesce((x->>'label')::text, (x->>'package')::text),
         greatest(coalesce(((x->>'minutes')::text)::int, 0), 0)
  from jsonb_array_elements(coalesce(p_apps, '[]'::jsonb)) x
  on conflict (user_id, day, package_name) do update
    set app_label = excluded.app_label,
        minutes   = excluded.minutes;
end;
$$;

-- ----------------------------------------------------------------------------
-- Access control.
-- ----------------------------------------------------------------------------
revoke all on table public.app_screen_time from public, anon;
grant select on table public.app_screen_time to authenticated;

revoke all on function public.log_day_usage(date, int, jsonb) from public, anon;
grant execute on function public.log_day_usage(date, int, jsonb) to authenticated;

-- The manual screen-time writer is no longer used.
drop function if exists public.set_screen_time(date, integer);

-- ----------------------------------------------------------------------------
-- Account deletion also wipes screen-time data.
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

  delete from public.goals where user_id = v_uid;
  delete from public.study_sessions where user_id = v_uid;
  delete from public.daily_screen_time where user_id = v_uid;
  delete from public.app_screen_time where user_id = v_uid;
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