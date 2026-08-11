-- ============================================================================
-- 1% Better — Profile pictures
--
-- Adds profiles.avatar_url and a public "avatars" storage bucket. Users upload
-- their own avatar to avatars/<user_id>/ and store the public URL.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. profiles.avatar_url (client-updatable, like display_name)
-- ----------------------------------------------------------------------------
alter table public.profiles
  add column if not exists avatar_url text;

-- ----------------------------------------------------------------------------
-- 2. Avatars storage bucket (public read, owner-only write)
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit)
values ('avatars', 'avatars', true, 5242880)
on conflict (id) do nothing;

drop policy if exists "avatars_select_all" on storage.objects;
create policy "avatars_select_all"
  on storage.objects for select
  to public
  using (bucket_id = 'avatars');

drop policy if exists "avatars_insert_own" on storage.objects;
create policy "avatars_insert_own"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

drop policy if exists "avatars_update_own" on storage.objects;
create policy "avatars_update_own"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

drop policy if exists "avatars_delete_own" on storage.objects;
create policy "avatars_delete_own"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );
