begin;

-- Member borrowing is completed in a dedicated RPC. Keep staff approval for
-- requests created before this migration, and mark new loans explicitly.
alter table public.loans alter column approved_by drop not null;
alter table public.loans
  add column approval_mode text not null default 'staff'
  check (approval_mode in ('staff', 'self_service'));
comment on column public.loans.approved_by is
  'Null for a member self-service loan; set to the operator for legacy staff-approved loans.';

create function public.borrow_books(
  p_idempotency_key uuid,
  p_copy_ids uuid[],
  p_evidence_method text,
  p_evidence_path text
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_existing public.loan_requests;
  v_has_existing boolean := false;
  v_request_id uuid;
  v_settings public.library_settings;
  v_count integer;
  v_distinct integer;
  v_open_count integer;
  v_requested_ids uuid[];
  v_existing_ids uuid[];
  v_loan_id uuid;
  v_now timestamptz := now();
begin
  if v_user is null then raise exception 'Akun anggota aktif diperlukan.'; end if;

  if p_idempotency_key is null or p_copy_ids is null or cardinality(p_copy_ids)=0 then
    raise exception 'Pilih minimal satu eksemplar.';
  end if;
  select count(*), count(distinct x) into v_count, v_distinct
    from unnest(p_copy_ids) x;
  if v_count<>v_distinct then
    raise exception 'Eksemplar yang sama tidak boleh dikirim dua kali.';
  end if;
  if p_evidence_method is null or p_evidence_method not in ('selfie','student_card') then
    raise exception 'Jenis bukti tidak valid.';
  end if;
  if p_evidence_path is null
     or split_part(p_evidence_path,'/',1)<>v_user::text
     or split_part(p_evidence_path,'/',2) !~ ('^'||p_idempotency_key::text||'\.(jpg|jpeg|png)$')
     or split_part(p_evidence_path,'/',3)<>'' then
    raise exception 'Lokasi bukti tidak valid.';
  end if;
  if not exists (
    select 1 from storage.objects o
    where o.bucket_id='loan-evidence' and o.name=p_evidence_path
      and o.owner_id=v_user::text
  ) then raise exception 'Unggah bukti terlebih dahulu.'; end if;

  select id into v_request_id from public.loan_requests
    where member_id=v_user and idempotency_key=p_idempotency_key;
  if found then
    -- Existing requests are locked before the member row, matching staff
    -- review and preventing a request/member lock inversion.
    select * into v_existing from public.loan_requests where id=v_request_id for update;
    v_has_existing := true;
  end if;

  -- Serialize the member's outstanding-loan limit and obligation checks.
  perform 1 from public.profiles p where p.id=v_user for update;
  if not private.is_eligible_member(v_user) then
    raise exception 'Akun anggota aktif diperlukan.';
  end if;

  -- A concurrent submission with the same key may have committed while this
  -- call waited for the member lock; those requests are self-service approved.
  if not v_has_existing then
    select * into v_existing from public.loan_requests
      where member_id=v_user and idempotency_key=p_idempotency_key;
    v_has_existing := found;
  end if;
  if v_has_existing then
    select array_agg(i.copy_id order by i.copy_id) into v_existing_ids
      from public.loan_request_items i where i.request_id=v_existing.id;
    select array_agg(q.copy_id order by q.copy_id) into v_requested_ids
      from (select distinct unnest(p_copy_ids) copy_id) q;
    if v_existing_ids is distinct from v_requested_ids
       or not exists (
         select 1 from public.transaction_evidence e
         where e.request_id=v_existing.id and e.method=p_evidence_method
           and e.object_path=p_evidence_path
       ) then
      raise exception 'Kunci permintaan sudah dipakai untuk isi yang berbeda.';
    end if;
    if v_existing.status='approved' then return v_existing.id; end if;
    raise exception 'Permintaan dengan kunci ini sudah diproses.';
  end if;

  select * into v_settings from public.library_settings where id=true;
  if not found or not v_settings.policy_confirmed
     or v_settings.evidence_retention is null then
    raise exception 'Pengurus belum mengonfirmasi kebijakan peminjaman dan penyimpanan bukti.';
  end if;
  if v_count>v_settings.max_books then
    raise exception 'Jumlah buku melebihi batas pinjaman.';
  end if;

  -- Keep the same parent-book then copy lock order as archive and staff review.
  perform private.lock_inventory_copies(p_copy_ids);
  if (select count(*) from public.book_copies c where c.id=any(p_copy_ids))<>v_count
     or exists (
       select 1 from public.book_copies c join public.books b on b.id=c.book_id
       where c.id=any(p_copy_ids)
         and (c.status<>'available' or c.archived_at is not null or b.archived_at is not null)
     ) then
    raise exception 'Satu atau beberapa eksemplar tidak tersedia.';
  end if;

  select count(*) into v_open_count from public.loan_items li
    join public.loans l on l.id=li.loan_id
    where l.member_id=v_user and li.returned_at is null and li.resolved_at is null;
  if exists (
    select 1 from public.loan_items li join public.loans l on l.id=li.loan_id
    where l.member_id=v_user and li.returned_at is null and li.resolved_at is null
      and li.due_at<=v_now
  ) then raise exception 'Kembalikan buku yang terlambat sebelum meminjam lagi.'; end if;
  if exists (
    select 1 from public.loss_reports lr
    join public.loan_items li on li.id=lr.loan_item_id
    join public.loans l on l.id=li.loan_id
    where l.member_id=v_user and lr.status in ('reported','verified')
  ) then raise exception 'Selesaikan laporan kehilangan sebelum meminjam lagi.'; end if;
  if v_open_count+v_count>v_settings.max_books then
    raise exception 'Batas buku aktif akan terlampaui.';
  end if;

  insert into public.loan_requests(member_id,idempotency_key,status)
    values (v_user,p_idempotency_key,'approved') returning id into v_request_id;
  insert into public.loan_request_items(request_id,copy_id)
    select v_request_id,x from unnest(p_copy_ids) x;
  insert into public.transaction_evidence(
    request_id,member_id,method,object_path,retention_policy
  ) values (
    v_request_id,v_user,p_evidence_method,p_evidence_path,v_settings.evidence_retention
  );
  insert into public.loans(request_id,member_id,approved_by,approved_at,approval_mode)
    values (v_request_id,v_user,null,v_now,'self_service') returning id into v_loan_id;
  insert into public.loan_items(loan_id,copy_id,due_at)
    select v_loan_id,x,v_now+v_settings.loan_days*interval '1 day'
    from unnest(p_copy_ids) x;
  update public.book_copies set status='borrowed' where id=any(p_copy_ids);
  return v_request_id;
end;
$$;
revoke all on function public.borrow_books(uuid,uuid[],text,text) from public,anon;
grant execute on function public.borrow_books(uuid,uuid[],text,text) to authenticated;

commit;
