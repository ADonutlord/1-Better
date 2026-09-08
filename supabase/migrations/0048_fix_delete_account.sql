-- ============================================================================
-- 1% Better — Fix account deletion referencing a dropped table.
--
-- Migration 0016 dropped the helper_status table, but delete_my_account still
-- deleted from it, so deleting an account failed with:
--   relation "public.helper_status" does not exist (SQLSTATE 42P01)
-- ============================================================================

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