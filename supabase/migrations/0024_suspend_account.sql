-- ============================================================================
-- 1% Better — Suspend accounts
--
-- Adds a per-profile suspension flag so admins and the owner can block a
-- specific account by its user id:
--   * profiles.suspended_at timestamptz — null means the account is fine;
--     a value means it is suspended.
--   * admin_suspend_account(p_user_id, p_suspend) — sets/clears suspended_at.
--     Usable by admins and the owner. The owner account can never be
--     suspended, and admins cannot suspend other admins (owner-only).
--   * The suspended flag rides along in get_daily_loop (profile row is
--     serialised as-is), so the app can gate the UI on it.
-- ============================================================================

alter table public.profiles
  add column if not exists suspended_at timestamptz;

create or replace function public.admin_suspend_account(p_user_id uuid, p_suspend boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller_role text;
  v_target_role text;
  v_target_name text;
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

  perform set_config('app.internal', 'on', true);
  update public.profiles
     set suspended_at = case when p_suspend then now() else null end
   where id = p_user_id;

  return jsonb_build_object(
    'user_id', p_user_id,
    'display_name', v_target_name,
    'suspended', p_suspend
  );
end;
$$;

revoke all on function public.admin_suspend_account(uuid, boolean) from public, anon;
grant execute on function public.admin_suspend_account(uuid, boolean) to authenticated;
