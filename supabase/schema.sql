-- ShareBox v1.1 database + Storage setup
-- Run this entire file once in Supabase Dashboard -> SQL Editor.

create table if not exists public.shared_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null check (type in ('text', 'image', 'file')),
  text_content text,
  storage_path text,
  file_name text,
  mime_type text,
  file_size bigint,
  device_name text not null default 'Unknown device',
  created_at timestamptz not null default now(),
  constraint shared_items_payload_check check (
    (type = 'text' and text_content is not null and storage_path is null)
    or
    (type in ('image', 'file') and storage_path is not null and text_content is null)
  )
);

create index if not exists shared_items_user_created_idx
  on public.shared_items (user_id, created_at desc);

alter table public.shared_items enable row level security;

-- Client API privileges. RLS below is the actual per-user protection.
revoke all on table public.shared_items from anon;
grant usage on schema public to authenticated;
grant select, insert, update, delete on table public.shared_items to authenticated;
grant all on table public.shared_items to service_role;

-- Recreate policies so rerunning this script is safe.
drop policy if exists "sharebox_select_own" on public.shared_items;
drop policy if exists "sharebox_insert_own" on public.shared_items;
drop policy if exists "sharebox_update_own" on public.shared_items;
drop policy if exists "sharebox_delete_own" on public.shared_items;

create policy "sharebox_select_own"
on public.shared_items for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "sharebox_insert_own"
on public.shared_items for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "sharebox_update_own"
on public.shared_items for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "sharebox_delete_own"
on public.shared_items for delete
to authenticated
using ((select auth.uid()) = user_id);

-- Private attachment bucket, max 50 MB per file.
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'sharebox',
  'sharebox',
  false,
  52428800,
  null
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- A user's objects are always stored under: <(select auth.uid())>/<uuid>.<ext>
drop policy if exists "sharebox_storage_select_own" on storage.objects;
drop policy if exists "sharebox_storage_insert_own" on storage.objects;
drop policy if exists "sharebox_storage_update_own" on storage.objects;
drop policy if exists "sharebox_storage_delete_own" on storage.objects;

create policy "sharebox_storage_select_own"
on storage.objects for select
to authenticated
using (
  bucket_id = 'sharebox'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "sharebox_storage_insert_own"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'sharebox'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "sharebox_storage_update_own"
on storage.objects for update
to authenticated
using (
  bucket_id = 'sharebox'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'sharebox'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "sharebox_storage_delete_own"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'sharebox'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

-- Enable Postgres Changes for the table if it is not already published.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'shared_items'
  ) then
    alter publication supabase_realtime add table public.shared_items;
  end if;
end $$;
