-- ShareBox 1.1: extend existing data without deleting any records.
begin;
alter table public.shared_items drop constraint shared_items_type_check;
alter table public.shared_items add constraint shared_items_type_check
  check (type in ('text', 'image', 'file'));
alter table public.shared_items drop constraint shared_items_payload_check;
alter table public.shared_items add constraint shared_items_payload_check check (
  (type = 'text' and text_content is not null and storage_path is null)
  or (type in ('image', 'file') and storage_path is not null and text_content is null)
);
update storage.buckets set file_size_limit = 52428800, allowed_mime_types = null
where id = 'sharebox';
commit;
