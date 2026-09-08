-- ============================================================================
-- 1% Better — Rename the default profile role to 'member'.
--
-- The base role was 'user'; everyone without a privileged role is now a
-- 'member'. Steps:
--   * role check constraint allows 'member' instead of 'user'.
--   * handle_new_user creates new profiles as 'member'.
--   * admin_set_role accepts 'member' instead of 'user'.
--   * the column default becomes 'member'.
--   * existing profiles that are 'user' or have no role are switched to
--     'member' (privileged roles: helper/admin/owner/testing/wanniya are kept).
-- ============================================================================

-- 1) Rebuild the role check with 'member'. Migrate legacy rows first so the
-- new constraint is satisfied by existing data.
begin;

alter table public.profiles drop constraint if exists profiles_role_check;

-- The protect_profile_fields trigger blocks role changes unless app.internal
-- is set, exactly like admin_set_role does.
select set_config('app.internal', 'on', true);

update public.profiles
   set role = 'member'
 where role is null or role = 'user';

alter table public.profiles
  add constraint profiles_role_check
  check (role in ('member', 'helper', 'admin', 'owner', 'testing', 'wanniya'));

commit;

-- 2) New users are members by default (function is the only profile-creation path).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, role, profession)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), 'Friend'),
    'member',
    coalesce(nullif(new.raw_user_meta_data ->> 'profession', ''), 'other')
  )
  on conflict (id) do nothing;
  return new;
end
$$;

-- 3) admin_set_role accepts the new base role name.
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

  if p_role not in ('member', 'helper', 'admin', 'owner', 'testing', 'wanniya') then
    raise exception 'Invalid role';
  end if;

  select role into v_target_role from public.profiles where id = p_user_id;
  if v_target_role = 'owner' then
    raise exception 'The owner account cannot be changed';
  end if;

  -- The testing and wanniya roles are owner-only: neither assigning them to
  -- someone nor changing a holder's role is allowed for admins.
  if p_role in ('testing', 'wanniya') or v_target_role in ('testing', 'wanniya') then
    if v_caller_role <> 'owner' then
      raise exception 'Only the owner can manage the testing and wanniya roles';
    end if;
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

-- 4) Column default: member.
alter table public.profiles alter column role set default 'member';