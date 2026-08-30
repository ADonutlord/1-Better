-- ============================================================================
-- 1% Better — Fix: admin_set_streak_by_email
--
-- The original 0033 function was missing the `set_config('app.internal','on')`
-- call, so protect_profile_fields() rejected the update with
-- "Protected profile fields cannot be changed by the client". Re-create with
-- the required internal marker (mirrors admin_set_level_by_email).
-- ============================================================================

create or replace function public.admin_set_streak_by_email(p_email text, p_streak int)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller_role  text;
  v_user_id      uuid;
  v_display_name text;
  v_longest      int;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select role into v_caller_role from public.profiles where id = auth.uid();
  if v_caller_role <> 'owner' then
    raise exception 'Only the owner can set daily streaks';
  end if;

  if p_streak < 0 or p_streak > 100000 then
    raise exception 'Streak must be between 0 and 100000';
  end if;

  select u.id into v_user_id
  from auth.users u
  where lower(u.email) = lower(trim(p_email))
  limit 1;

  if v_user_id is null then
    raise exception 'No account found with that email';
  end if;

  perform set_config('app.internal', 'on', true);

  update public.profiles
     set current_streak  = p_streak,
         longest_streak  = greatest(longest_streak, p_streak),
         last_action_date = current_date
   where id = v_user_id
   returning longest_streak into v_longest;

  select display_name into v_display_name
  from public.profiles where id = v_user_id;

  return jsonb_build_object(
    'user_id', v_user_id,
    'display_name', v_display_name,
    'email', p_email,
    'current_streak', p_streak,
    'longest_streak', v_longest
  );
end;
$$;

revoke all on function public.admin_set_streak_by_email(text, int) from public, anon;
grant execute on function public.admin_set_streak_by_email(text, int) to authenticated;
