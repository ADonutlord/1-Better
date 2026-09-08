-- ============================================================================
-- 1% Better — Bring existing accounts onto the new mood-gated task system.
--
-- Migration 0044 emptied the action library and nulled every
-- action_history.action_id. New accounts (no history rows) work, but existing
-- accounts are stuck: get_daily_loop returns today's stale row (action = null),
-- so the app believes a task already exists and never assigns a fresh one.
--
-- This resets each account's *today* so the new flow (check in a mood -> get a
-- 1% from that mood's 100-task pool -> complete) starts cleanly:
--   * today's stale assignments are removed,
--   * today's daily_progress is cleared (mood + action toggles, today's XP
--     tally only - total XP, levels and longest streak are untouched),
--   * users who already "completed today" under the old system regain a clean
--     slate today (streak restarts at their next completion; the bonus simply
--     accumulates from there).
-- ============================================================================

-- 1) Remove today's stale assignments (actions were deleted in 0044). Historical
-- rows are left in place: they don't affect the daily loop and XP is already
-- banked in xp_events/profile totals.
delete from public.action_history
 where action_id is null and assigned_date = current_date;

-- 2) Clear today's progress so the mood-gated flow starts fresh for everyone.
-- Only today's tally is affected; total XP, level and longest streak persist.
update public.daily_progress
   set action_id = null,
       action_completed = false,
       xp_awarded = 0,
       mood_completed = false,
       conversation_completed = false
 where date = current_date;

-- 3) Users who completed today under the old system can complete a fresh task
-- today instead of being blocked by the "already completed today" guard.
begin;
select set_config('app.internal', 'on', true);
update public.profiles
   set last_action_date = null,
       current_streak = 0
 where last_action_date = current_date;
commit;