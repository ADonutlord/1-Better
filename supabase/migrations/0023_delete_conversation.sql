-- ============================================================================
-- 1% Better — Delete my conversation (all roles)
--
-- Any participant may remove a conversation from their own list, regardless of
-- role. Deletion is per-user: it only hides the conversation for the caller and
-- never touches the other participant's copy.
--
-- If the conversation is still active, it is ended first (via end_conversation)
-- so the other peer is never stranded and the "talk to someone" task / XP are
-- handled the same way as a normal end.
-- ============================================================================

alter table public.conversation_participants
  add column if not exists deleted_at timestamptz;

create or replace function public.delete_my_conversation(p_conversation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me      uuid;
  v_status  text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select user_id into v_me
  from public.conversation_participants
  where conversation_id = p_conversation_id
    and user_id = auth.uid()
    and deleted_at is null;

  if v_me is null then
    raise exception 'You are not a participant of this conversation';
  end if;

  select status into v_status
  from public.conversations
  where id = p_conversation_id;

  -- Never strand the other peer: end active conversations normally first.
  if v_status = 'active' then
    perform public.end_conversation(p_conversation_id);
  end if;

  update public.conversation_participants
     set deleted_at = now()
   where conversation_id = p_conversation_id
     and user_id = auth.uid();

  return jsonb_build_object('conversation_id', p_conversation_id, 'deleted', true);
end;
$$;

revoke all on function public.delete_my_conversation(uuid) from public, anon;
grant execute on function public.delete_my_conversation(uuid) to authenticated;
