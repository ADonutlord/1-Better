-- ============================================================================
-- 1% Better — Fix handle_new_user security
--
-- Migration 0013 re-created handle_new_user with `security invoker`, reverting
-- the SECURITY DEFINER fix from 00008. Because the trigger fires as
-- supabase_auth_admin (not the new user), RLS on profiles blocks the insert
-- and signup fails with "Database error saving new user".
--
-- Restore SECURITY DEFINER with a fixed search_path, keeping the profession
-- capture from 0013.
-- ============================================================================

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
    'user',
    coalesce(nullif(new.raw_user_meta_data ->> 'profession', ''), 'other')
  )
  on conflict (id) do nothing;
  return new;
end
$$;
