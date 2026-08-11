-- ============================================================================
-- Backfill profiles for auth users created before handle_new_user existed.
-- Idempotent: only fills gaps, never overwrites.
-- ============================================================================

insert into public.profiles (id, display_name, role)
select
  u.id,
  coalesce(nullif(u.raw_user_meta_data ->> 'display_name', ''), 'Friend'),
  'user'
from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id)
on conflict (id) do nothing;
