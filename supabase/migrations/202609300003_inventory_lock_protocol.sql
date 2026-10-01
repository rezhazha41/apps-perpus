begin;

-- RLS must call a current-user predicate. Do not grant the arbitrary-user
-- eligibility helper to clients because it would expose an account oracle.
create or replace function private.current_user_is_eligible_member()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.profiles p
    join public.student_registry s on s.id=p.claimed_student_id
    where p.id=auth.uid() and p.role='member' and p.status='active'
      and s.active and s.linked_user_id=p.id
  );
$$;
revoke all on function private.current_user_is_eligible_member() from public,anon;
grant execute on function private.current_user_is_eligible_member() to authenticated;

drop policy if exists perpus_evidence_insert on storage.objects;
create policy perpus_evidence_insert on storage.objects for insert to authenticated
  with check (bucket_id='loan-evidence' and private.current_user_is_eligible_member()
    and owner_id=auth.uid()::text and (storage.foldername(name))[1]=auth.uid()::text);

-- Global inventory lock order: parent books ordered by UUID, then copies
-- ordered by UUID. Every operation that creates an active loan or archives
-- inventory follows this order before validating current status.
create function private.lock_inventory_copies(p_copy_ids uuid[])
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_copy_ids is null or cardinality(p_copy_ids)=0 then return; end if;

  perform b.id
  from public.books b
  join (
    select distinct c.book_id
    from public.book_copies c
    where c.id=any(p_copy_ids)
  ) requested on requested.book_id=b.id
  order by b.id
  for update of b;

  perform c.id
  from public.book_copies c
  where c.id=any(p_copy_ids)
  order by c.id
  for update of c;
end;
$$;
revoke all on function private.lock_inventory_copies(uuid[]) from public,anon,authenticated;

-- Stock creation must serialize with archive_book on the parent book row.
revoke insert (book_id,code) on public.book_copies from authenticated;
revoke update (archived_at) on public.books from authenticated;

create function public.add_book_copies(p_book_id uuid,p_codes text[])
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_count integer;
  v_distinct integer;
begin
  if not private.is_admin() then raise exception 'Akses admin diperlukan.'; end if;
  if p_book_id is null or p_codes is null or cardinality(p_codes)=0 then
    raise exception 'Masukkan minimal satu kode eksemplar.';
  end if;
  select count(*),count(distinct btrim(x)) into v_count,v_distinct
  from unnest(p_codes) x;
  if v_count<>v_distinct or exists(select 1 from unnest(p_codes) x where length(btrim(x))=0) then
    raise exception 'Kode eksemplar kosong atau duplikat.';
  end if;

  perform 1 from public.books
  where id=p_book_id and archived_at is null
  for update;
  if not found then raise exception 'Buku tidak ditemukan atau sudah diarsipkan.'; end if;

  insert into public.book_copies(book_id,code)
    select p_book_id,btrim(x) from unnest(p_codes) x;
end;
$$;
revoke all on function public.add_book_copies(uuid,text[]) from public,anon;
grant execute on function public.add_book_copies(uuid,text[]) to authenticated;

create or replace function public.archive_available_copy(p_copy_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_book_id uuid;
  v_copy public.book_copies;
begin
  if not private.is_admin() then raise exception 'Akses admin diperlukan.'; end if;
  select book_id into v_book_id from public.book_copies where id=p_copy_id;
  if v_book_id is null then raise exception 'Eksemplar tidak tersedia untuk diarsipkan.'; end if;

  perform 1 from public.books where id=v_book_id and archived_at is null for update;
  if not found then raise exception 'Buku tidak ditemukan atau sudah diarsipkan.'; end if;
  select * into v_copy from public.book_copies where id=p_copy_id for update;
  if v_copy.id is null or v_copy.book_id<>v_book_id or
     v_copy.archived_at is not null or v_copy.status<>'available' then
    raise exception 'Eksemplar tidak tersedia untuk diarsipkan.';
  end if;
  update public.book_copies set archived_at=now() where id=v_copy.id;
end;
$$;
revoke all on function public.archive_available_copy(uuid) from public,anon;
grant execute on function public.archive_available_copy(uuid) to authenticated;

create or replace function public.archive_book(p_book_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_now timestamptz := now();
begin
  if not private.is_admin() then raise exception 'Akses admin diperlukan.'; end if;

  perform 1 from public.books
    where id=p_book_id and archived_at is null
    for update;
  if not found then raise exception 'Buku tidak ditemukan atau sudah diarsipkan.'; end if;

  perform c.id from public.book_copies c
    where c.book_id=p_book_id
    order by c.id
    for update of c;

  if exists(select 1 from public.book_copies
      where book_id=p_book_id and archived_at is null and status='borrowed') then
    raise exception 'Buku masih memiliki QR yang sedang dipinjam.';
  end if;

  update public.book_copies set archived_at=v_now
    where book_id=p_book_id and archived_at is null;
  update public.books set archived_at=v_now where id=p_book_id;
end;
$$;
revoke all on function public.archive_book(uuid) from public,anon;
grant execute on function public.archive_book(uuid) to authenticated;

create or replace function public.review_loan_request(
  p_request_id uuid,p_approve boolean,p_reason text default null
) returns void language plpgsql security definer set search_path = '' as $$
declare
  r public.loan_requests;
  s public.library_settings;
  v_open_count integer;
  v_requested_count integer;
  v_copy_ids uuid[];
  v_loan_id uuid;
  v_now timestamptz := now();
begin
  if not private.is_admin() then raise exception 'Akses admin diperlukan.'; end if;
  if p_approve is null then raise exception 'Keputusan wajib diisi.'; end if;
  select * into r from public.loan_requests where id=p_request_id for update;
  if r.id is null or r.status<>'pending' then
    raise exception 'Pengajuan sudah atau tidak dapat diproses.';
  end if;
  if not p_approve then
    if p_reason is null or length(btrim(p_reason))=0 then raise exception 'Alasan penolakan wajib diisi.'; end if;
    update public.loan_requests set status='rejected',
      decision_reason=left(btrim(p_reason),1000),reviewed_by=auth.uid(),reviewed_at=v_now
      where id=r.id;
    perform private.start_evidence_retention(r.id);
    return;
  end if;

  -- Per member lock serializes the outstanding-loan cap. Inventory locks then
  -- follow books UUID order and copies UUID order for all items in the request.
  perform 1 from public.profiles p where p.id=r.member_id for update;
  if not private.is_eligible_member(r.member_id) then
    raise exception 'Akun anggota tidak lagi aktif.';
  end if;
  select * into s from public.library_settings where id=true;
  if not found or not s.policy_confirmed then raise exception 'Kebijakan pinjaman belum dikonfirmasi.'; end if;

  select array_agg(i.copy_id) into v_copy_ids
  from public.loan_request_items i where i.request_id=r.id;
  perform private.lock_inventory_copies(v_copy_ids);

  select count(*) into v_requested_count
    from public.loan_request_items where request_id=r.id;
  if v_requested_count=0 or v_requested_count>s.max_books then
    raise exception 'Isi pengajuan tidak valid atau melewati batas buku.';
  end if;
  if exists(select 1 from public.loan_request_items i
      join public.book_copies c on c.id=i.copy_id
      join public.books b on b.id=c.book_id
      where i.request_id=r.id
        and (c.status<>'available' or c.archived_at is not null or b.archived_at is not null)) then
    raise exception 'Satu atau beberapa buku sudah tidak tersedia.';
  end if;
  select count(*) into v_open_count from public.loan_items li
    join public.loans l on l.id=li.loan_id
    where l.member_id=r.member_id and li.returned_at is null and li.resolved_at is null;
  if exists(select 1 from public.loan_items li join public.loans l on l.id=li.loan_id
      where l.member_id=r.member_id and li.returned_at is null and li.resolved_at is null
        and li.due_at<=v_now) then
    raise exception 'Kembalikan buku yang terlambat sebelum meminjam lagi.';
  end if;
  if exists(select 1 from public.loss_reports lr join public.loan_items li on li.id=lr.loan_item_id
      join public.loans l on l.id=li.loan_id
      where l.member_id=r.member_id and lr.status in ('reported','verified')) then
    raise exception 'Selesaikan laporan kehilangan sebelum meminjam lagi.';
  end if;
  if v_open_count+v_requested_count>s.max_books then
    raise exception 'Batas buku aktif akan terlampaui.';
  end if;

  insert into public.loans(request_id,member_id,approved_by,approved_at)
    values(r.id,r.member_id,auth.uid(),v_now) returning id into v_loan_id;
  insert into public.loan_items(loan_id,copy_id,due_at)
    select v_loan_id,i.copy_id,v_now+s.loan_days*interval '1 day'
    from public.loan_request_items i where i.request_id=r.id;
  update public.book_copies c set status='borrowed'
    from public.loan_request_items i where i.request_id=r.id and c.id=i.copy_id;
  update public.loan_requests set status='approved',reviewed_by=auth.uid(),reviewed_at=v_now
    where id=r.id;
end;
$$;
revoke all on function public.review_loan_request(uuid,boolean,text) from public,anon;
grant execute on function public.review_loan_request(uuid,boolean,text) to authenticated;

create or replace function public.create_class_loan(
  p_idempotency_key uuid,
  p_responsible_name text,
  p_class_name text,
  p_activity text,
  p_due_at timestamptz,
  p_copy_ids uuid[]
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_session_id uuid;
  v_count integer;
  v_distinct integer;
begin
  if not private.is_admin() then raise exception 'Akses pengurus diperlukan.'; end if;
  if p_idempotency_key is null or p_copy_ids is null or cardinality(p_copy_ids)=0 then
    raise exception 'Pindai minimal satu eksemplar.';
  end if;
  if length(btrim(coalesce(p_responsible_name,''))) not between 1 and 160
     or length(btrim(coalesce(p_class_name,''))) not between 1 and 80
     or length(btrim(coalesce(p_activity,''))) not between 1 and 240 then
    raise exception 'Penanggung jawab, kelas, dan kegiatan wajib diisi.';
  end if;
  if p_due_at is null or p_due_at<=now() then raise exception 'Tenggat harus di waktu mendatang.'; end if;
  select count(*),count(distinct x) into v_count,v_distinct from unnest(p_copy_ids) x;
  if v_count<>v_distinct then raise exception 'QR yang sama terpindai lebih dari sekali.'; end if;
  if exists(select 1 from public.class_loan_sessions
      where created_by=auth.uid() and idempotency_key=p_idempotency_key) then
    select id into v_session_id from public.class_loan_sessions
      where created_by=auth.uid() and idempotency_key=p_idempotency_key;
    return v_session_id;
  end if;

  perform private.lock_inventory_copies(p_copy_ids);
  if (select count(*) from public.book_copies c where c.id=any(p_copy_ids))<>v_count
     or exists(select 1 from public.book_copies c join public.books b on b.id=c.book_id
       where c.id=any(p_copy_ids)
         and (c.status<>'available' or c.archived_at is not null or b.archived_at is not null))
     or exists(select 1 from public.loan_items li where li.copy_id=any(p_copy_ids)
       and li.returned_at is null and li.resolved_at is null)
     or exists(select 1 from public.class_loan_items ci where ci.copy_id=any(p_copy_ids)
       and ci.returned_at is null) then
    raise exception 'Satu atau beberapa eksemplar sudah tidak tersedia.';
  end if;

  insert into public.class_loan_sessions(
    idempotency_key,responsible_name,class_name,activity,due_at,created_by
  ) values(
    p_idempotency_key,btrim(p_responsible_name),btrim(p_class_name),btrim(p_activity),p_due_at,auth.uid()
  ) returning id into v_session_id;
  insert into public.class_loan_items(session_id,copy_id)
    select v_session_id,x from unnest(p_copy_ids) x;
  update public.book_copies set status='borrowed' where id=any(p_copy_ids);
  return v_session_id;
end;
$$;
revoke all on function public.create_class_loan(uuid,text,text,text,timestamptz,uuid[]) from public,anon;
grant execute on function public.create_class_loan(uuid,text,text,text,timestamptz,uuid[]) to authenticated;

commit;

