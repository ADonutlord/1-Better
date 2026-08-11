-- ============================================================================
-- 1% Better — Owner role
-- Adds a top-level 'owner' role. There is exactly one owner account; it may
-- manage admins (who may manage user/helper/admin roles). The owner's own
-- role cannot be reassigned, even by the owner, to prevent lockout.
-- ============================================================================

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check
  check (role in ('user', 'helper', 'admin', 'owner'));

create or replace function public.admin_set_role(p_user_id uuid, p_role text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller_role text;
  v_target_role text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select role into v_caller_role from public.profiles where id = auth.uid();
  if v_caller_role not in ('admin', 'owner') then
    raise exception 'Only admins or the owner can change roles';
  end if;

  if p_role not in ('user', 'helper', 'admin', 'owner') then
    raise exception 'Invalid role';
  end if;

  select role into v_target_role from public.profiles where id = p_user_id;
  if v_target_role = 'owner' then
    raise exception 'The owner account cannot be changed';
  end if;

  if p_role = 'owner' then
    if v_caller_role <> 'owner' then
      raise exception 'Only the owner can assign the owner role';
    end if;
    if exists (
      select 1 from public.profiles
      where role = 'owner' and id <> p_user_id
    ) then
      raise exception 'An owner account already exists';
    end if;
  end if;

  perform set_config('app.internal', 'on', true);
  update public.profiles set role = p_role where id = p_user_id;
end;
$$;
