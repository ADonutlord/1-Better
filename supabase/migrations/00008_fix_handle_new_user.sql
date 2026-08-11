-- ============================================================================
-- Fix: handle_new_user must run as SECURITY DEFINER.
-- The trigger fires on auth.users inserts performed by supabase_auth_admin,
-- which has no INSERT grant on public.profiles and is subject to RLS (there is
-- deliberately no client insert policy). Running as the owner (postgres)
-- bypasses RLS and has the needed privileges.
-- ============================================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, role)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), 'Friend'),
    'user'
  )
  on conflict (id) do nothing;
  return new;
end
$$;
