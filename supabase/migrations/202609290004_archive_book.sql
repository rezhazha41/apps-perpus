begin;

create or replace function public.archive_book(p_book_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_admin() then
    raise exception 'Akses admin diperlukan.';
  end if;

  perform 1
  from public.books
  where id = p_book_id and archived_at is null
  for update;
  if not found then
    raise exception 'Buku tidak ditemukan atau sudah diarsipkan.';
  end if;

  if exists (
    select 1
    from public.book_copies
    where book_id = p_book_id
      and archived_at is null
      and status = 'borrowed'
  ) then
    raise exception 'Buku masih memiliki QR yang sedang dipinjam.';
  end if;

  update public.book_copies
  set archived_at = now()
  where book_id = p_book_id and archived_at is null;

  update public.books
  set archived_at = now()
  where id = p_book_id;
end;
$$;

revoke all on function public.archive_book(uuid) from public, anon;
grant execute on function public.archive_book(uuid) to authenticated;

commit;
