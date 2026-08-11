-- ============================================================================
-- 1% Better — Admin panel: set role by email
--
-- The client cannot read auth.users directly, and admin_set_role expects a
-- uuid. This RPC resolves an email to a user id server-side and then delegates
-- to admin_set_role so all existing guards still apply (owner-only for the
-- testing/owner roles, protection of the owner account, single-owner check).
-- ============================================================================

create or replace function public.admin_set_role_by_email(p_email text, p_role text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller_role text;
  v_user_id     uuid;
  v_display_name text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select role into v_caller_role from public.profiles where id = auth.uid();
  if v_caller_role not in ('admin', 'owner') then
    raise exception 'Only admins or the owner can change roles';
  end if;

  select u.id into v_user_id
  from auth.users u
  where lower(u.email) = lower(trim(p_email))
  limit 1;

  if v_user_id is null then
    raise exception 'No account found with that email';
  end if;

  perform public.admin_set_role(v_user_id, p_role);

  select display_name into v_display_name
  from public.profiles where id = v_user_id;

  return jsonb_build_object(
    'user_id', v_user_id,
    'display_name', v_display_name,
    'email', p_email,
    'role', p_role
  );
end;
$$;

revoke all on function public.admin_set_role_by_email(text, text) from public, anon;
grant execute on function public.admin_set_role_by_email(text, text) to authenticated;
