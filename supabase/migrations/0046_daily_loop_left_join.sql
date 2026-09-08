-- ============================================================================
-- 1% Better — Keep today's completed action visible when its action was deleted.
--
-- Migration 0044 wiped the action library and (for rows that referenced a
-- deleted action) set action_history.action_id = NULL. get_daily_loop joined
-- action_history to actions with an INNER JOIN, so a completed row whose action
-- was removed no longer surfaced as today_action. The client then saw "no task
-- today", called assign_daily_action, and hit the completed-day guard
-- ("Today's 1% is already completed", P000).
--
-- Switches to a LEFT JOIN so today's completed row still appears (with a null
-- nested action); the client sees completed=true and stops trying to assign.
-- ============================================================================

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
      left join public.actions a on a.id = ah.action_id
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

revoke all on function public.get_daily_loop() from public, anon;
grant execute on function public.get_daily_loop() to authenticated;
