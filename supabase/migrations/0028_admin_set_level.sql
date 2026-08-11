-- ============================================================================
-- 1% Better — Owner-only: set any account's level
--
-- Levels are derived from total_xp (compute_level), so to set an exact level
-- we also set total_xp to that level's lower threshold:
--   25 * (level - 1) * (level + 2)
-- This keeps level and total_xp consistent (level 1 = 0 xp .. level 200).
--
-- Only the owner may call this; admins are rejected.
-- ============================================================================

create or replace function public.admin_set_level_by_email(p_email text, p_level int)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller_role  text;
  v_user_id      uuid;
  v_display_name text;
  v_total_xp     int;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select role into v_caller_role from public.profiles where id = auth.uid();
  if v_caller_role <> 'owner' then
    raise exception 'Only the owner can set account levels';
  end if;

  if p_level < 1 or p_level > 200 then
    raise exception 'Level must be between 1 and 200';
  end if;

  select u.id into v_user_id
  from auth.users u
  where lower(u.email) = lower(trim(p_email))
  limit 1;

  if v_user_id is null then
    raise exception 'No account found with that email';
  end if;

  v_total_xp := 25 * (p_level - 1) * (p_level + 2);

  perform set_config('app.internal', 'on', true);
  update public.profiles
     set level = p_level,
         total_xp = v_total_xp
   where id = v_user_id;

  select display_name into v_display_name
  from public.profiles where id = v_user_id;

  return jsonb_build_object(
    'user_id', v_user_id,
    'display_name', v_display_name,
    'email', p_email,
    'level', p_level,
    'total_xp', v_total_xp
  );
end;
$$;

revoke all on function public.admin_set_level_by_email(text, int) from public, anon;
grant execute on function public.admin_set_level_by_email(text, int) to authenticated;
