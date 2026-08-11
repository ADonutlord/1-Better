-- ============================================================================
-- 1% Better — Realtime + API grants
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Realtime: WALRUS postgres_changes on the tables the app streams.
-- ----------------------------------------------------------------------------
alter table public.messages replica identity full;
alter table public.conversations replica identity full;
alter table public.conversation_participants replica identity full;
alter table public.helper_status replica identity full;

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end $$;

do $$
declare
  tbl text;
begin
  foreach tbl in array array[
    'public.messages',
    'public.conversations',
    'public.conversation_participants',
    'public.helper_status'
  ] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname || '.' || tablename = tbl
    ) then
      execute format('alter publication supabase_realtime add table %s', tbl);
    end if;
  end loop;
end $$;

-- ----------------------------------------------------------------------------
-- Data API grants (in case the project has restrictive Data API settings).
-- anon gets nothing: every endpoint requires a signed-in user.
-- ----------------------------------------------------------------------------
grant usage on schema public to anon, authenticated;

grant select on public.profiles, public.actions, public.helper_status to authenticated;
grant update on public.profiles to authenticated;

grant select, insert, update, delete on public.mood_checkins to authenticated;

grant select on public.action_history, public.xp_events, public.daily_progress to authenticated;

grant select on public.conversations, public.conversation_participants, public.messages to authenticated;
grant insert on public.messages to authenticated;

grant select, insert, delete on public.blocks to authenticated;
grant select, insert on public.reports to authenticated;

-- RPCs: revoke PUBLIC execute, allow authenticated only.
revoke all on function public.compute_level(int) from public, anon;
revoke all on function public.internal_add_xp(uuid, int, text, uuid) from public, anon;
revoke all on function public.get_daily_loop() from public, anon;
revoke all on function public.start_conversation() from public, anon;
revoke all on function public.find_helper() from public, anon;
revoke all on function public.accept_conversation(uuid) from public, anon;
revoke all on function public.end_conversation(uuid) from public, anon;
revoke all on function public.check_in_mood(text, text[]) from public, anon;
revoke all on function public.assign_daily_action(uuid) from public, anon;
revoke all on function public.recommend_action(uuid, uuid, uuid) from public, anon;
revoke all on function public.complete_daily_action() from public, anon;
revoke all on function public.add_focus_xp() from public, anon;
revoke all on function public.set_helper_status(text) from public, anon;
revoke all on function public.report_user(uuid, text, uuid) from public, anon;
revoke all on function public.block_user(uuid) from public, anon;
revoke all on function public.unblock_user(uuid) from public, anon;
revoke all on function public.cancel_waiting_conversation() from public, anon;
revoke all on function public.admin_set_role(uuid, text) from public, anon;
revoke all on function public.delete_my_account() from public, anon;

grant execute on function public.compute_level(int) to authenticated;
grant execute on function public.get_daily_loop() to authenticated;
grant execute on function public.start_conversation() to authenticated;
grant execute on function public.find_helper() to authenticated;
grant execute on function public.accept_conversation(uuid) to authenticated;
grant execute on function public.end_conversation(uuid) to authenticated;
grant execute on function public.check_in_mood(text, text[]) to authenticated;
grant execute on function public.assign_daily_action(uuid) to authenticated;
grant execute on function public.recommend_action(uuid, uuid, uuid) to authenticated;
grant execute on function public.complete_daily_action() to authenticated;
grant execute on function public.add_focus_xp() to authenticated;
grant execute on function public.set_helper_status(text) to authenticated;
grant execute on function public.report_user(uuid, text, uuid) to authenticated;
grant execute on function public.block_user(uuid) to authenticated;
grant execute on function public.unblock_user(uuid) to authenticated;
grant execute on function public.cancel_waiting_conversation() to authenticated;
grant execute on function public.admin_set_role(uuid, text) to authenticated;
grant execute on function public.delete_my_account() to authenticated;
-- internal_add_xp is only called from other functions; keep it out of the API.
