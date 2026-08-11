-- ============================================================================
-- 1% Better — Fix suspension expiry return value
--
-- to_char(infinity) yields NULL in Postgres, so permanent suspensions were
-- reported with a null suspended_until. Return the literal 'infinity' for
-- permanent suspensions instead.
-- ============================================================================

create or replace function public.admin_suspend_account(
  p_user_id uuid,
  p_suspend boolean,
  p_duration interval default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller_role  text;
  v_target_role  text;
  v_target_name  text;
  v_until        timestamptz;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select role into v_caller_role from public.profiles where id = auth.uid();
  if v_caller_role not in ('admin', 'owner') then
    raise exception 'Only admins or the owner can suspend accounts';
  end if;

  if p_user_id = auth.uid() then
    raise exception 'You cannot suspend your own account';
  end if;

  select role, display_name into v_target_role, v_target_name
  from public.profiles where id = p_user_id;
  if not found then
    raise exception 'No account found with that id';
  end if;

  if v_target_role = 'owner' then
    raise exception 'The owner account cannot be suspended';
  end if;

  if v_target_role = 'admin' and v_caller_role <> 'owner' then
    raise exception 'Only the owner can suspend admins';
  end if;

  v_until := case
    when p_suspend and p_duration is null then 'infinity'::timestamptz
    when p_suspend then now() + p_duration
    else null
  end;

  perform set_config('app.internal', 'on', true);
  update public.profiles
     set suspended_until = v_until
   where id = p_user_id;

  return jsonb_build_object(
    'user_id', p_user_id,
    'display_name', v_target_name,
    'suspended', p_suspend,
    'suspended_until', case
      when v_until = 'infinity'::timestamptz then 'infinity'
      else to_char(v_until, 'YYYY-MM-DD"T"HH24:MI:SSOF')
    end
  );
end;
$$;

revoke all on function public.admin_suspend_account(uuid, boolean, interval) from public, anon;
grant execute on function public.admin_suspend_account(uuid, boolean, interval) to authenticated;
