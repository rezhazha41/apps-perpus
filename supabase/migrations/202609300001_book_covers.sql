-- Optional book cover images. A missing cover keeps the built-in catalog icon.
begin;

alter table public.books add column if not exists cover_path text;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('book-covers', 'book-covers', true, 3145728, array['image/jpeg', 'image/png']);

drop policy if exists book_covers_admin_insert on storage.objects;
create policy book_covers_admin_insert on storage.objects
for insert to authenticated
with check (bucket_id = 'book-covers' and private.is_admin());

commit;
