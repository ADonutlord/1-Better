-- ============================================================================
-- 1% Better — Protect suspension expiry from client writes
--
-- suspended_until was not in protect_profile_fields, and RLS lets a user
-- update their own profile row — so a suspended user could clear their own
-- suspension by patching suspended_until directly. Protect it the same way
-- as role/xp: only SECURITY DEFINER functions (admin_suspend_account) may
-- change it.
-- ============================================================================

create or replace function public.protect_profile_fields()
returns trigger
language plpgsql
security invoker
as $$
begin
  if new.role                is distinct from old.role
     or new.level            is distinct from old.level
     or new.total_xp         is distinct from old.total_xp
     or new.current_streak   is distinct from old.current_streak
     or new.longest_streak   is distinct from old.longest_streak
     or new.last_action_date is distinct from old.last_action_date
     or new.suspended_until  is distinct from old.suspended_until then
    if current_setting('app.internal', true) = 'on' then
      return new;
    end if;
    raise exception 'Protected profile fields cannot be changed by the client';
  end if;
  return new;
end
$$;
