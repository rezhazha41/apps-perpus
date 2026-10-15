begin;

-- Preserve existing loans; only new member borrowing requires staff review.
create or replace function public.submit_loan_request(
  p_idempotency_key uuid,p_copy_ids uuid[],p_evidence_method text,p_evidence_path text
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_existing public.loan_requests;
  v_has_existing boolean;
  v_request_id uuid;
  v_settings public.library_settings;
  v_count integer;
  v_distinct integer;
  v_existing_ids uuid[];
  v_requested_ids uuid[];
begin
  -- Only the member row is locked here. Do not lock request rows while holding
  -- it: review locks request -> member -> ordered inventory rows.
  perform 1 from public.profiles where id=v_user for update;
  if v_user is null or not private.is_eligible_member(v_user) then raise exception 'Akun anggota aktif diperlukan.'; end if;
  if p_idempotency_key is null or p_copy_ids is null or cardinality(p_copy_ids)=0 then raise exception 'Pilih minimal satu eksemplar.'; end if;
  select count(*),count(distinct x) into v_count,v_distinct from unnest(p_copy_ids) x;
  if v_count<>v_distinct then raise exception 'Eksemplar yang sama tidak boleh dikirim dua kali.'; end if;
  if p_evidence_method is null or p_evidence_method not in ('selfie','student_card') then raise exception 'Jenis bukti tidak valid.'; end if;
  if p_evidence_path is null or split_part(p_evidence_path,'/',1)<>v_user::text
     or split_part(p_evidence_path,'/',2) !~ ('^'||p_idempotency_key::text||'\.(jpg|jpeg|png)$')
     or split_part(p_evidence_path,'/',3)<>'' then raise exception 'Lokasi bukti tidak valid.'; end if;
  if not exists(select 1 from storage.objects o where o.bucket_id='loan-evidence'
      and o.name=p_evidence_path and o.owner_id=v_user::text) then raise exception 'Unggah bukti terlebih dahulu.'; end if;
  select * into v_settings from public.library_settings where id=true;
  if not found or not v_settings.policy_confirmed or v_settings.evidence_retention is null then
    raise exception 'Pengurus belum mengonfirmasi kebijakan peminjaman dan penyimpanan bukti.';
  end if;

  select * into v_existing from public.loan_requests
    where member_id=v_user and idempotency_key=p_idempotency_key;
  v_has_existing := found;
  select array_agg(q.copy_id order by q.copy_id) into v_requested_ids
    from (select distinct unnest(p_copy_ids) as copy_id) q;
  if v_has_existing then
    select array_agg(i.copy_id order by i.copy_id) into v_existing_ids
      from public.loan_request_items i where i.request_id=v_existing.id;
    if v_existing_ids is distinct from v_requested_ids
       or not exists(select 1 from public.transaction_evidence e where e.request_id=v_existing.id
         and e.method=p_evidence_method and e.object_path=p_evidence_path) then
      raise exception 'Kunci permintaan sudah dipakai untuk isi yang berbeda.';
    end if;
    return v_existing.id;
  end if;

  if exists (
    select 1 from public.loan_requests r
    join public.loan_request_items i on i.request_id=r.id
    where r.member_id=v_user and r.status='pending' and i.copy_id=any(p_copy_ids)
  ) then
    raise exception 'Buku ini sudah ada dalam pengajuan yang menunggu pengurus.';
  end if;

  if v_count>v_settings.max_books then raise exception 'Jumlah buku melebihi batas pinjaman.'; end if;
  if exists(select 1 from public.book_copies c join unnest(p_copy_ids) q(id) on q.id=c.id
      join public.books b on b.id=c.book_id
      where c.status<>'available' or c.archived_at is not null or b.archived_at is not null)
     or (select count(*) from public.book_copies c join unnest(p_copy_ids) q(id) on q.id=c.id)<>v_count then
    raise exception 'Satu atau beberapa eksemplar tidak tersedia.';
  end if;
  insert into public.loan_requests(member_id,idempotency_key) values (v_user,p_idempotency_key) returning id into v_request_id;
  insert into public.loan_request_items(request_id,copy_id) select v_request_id,x from unnest(p_copy_ids) x;
  insert into public.transaction_evidence(request_id,member_id,method,object_path,retention_policy)
    values (v_request_id,v_user,p_evidence_method,p_evidence_path,v_settings.evidence_retention);
  return v_request_id;
end;
$$;


-- Old mobile builds must not bypass approval through the direct-borrow RPC.
revoke all on function public.borrow_books(uuid,uuid[],text,text) from public,anon,authenticated;
revoke all on function public.submit_loan_request(uuid,uuid[],text,text) from public,anon;
grant execute on function public.submit_loan_request(uuid,uuid[],text,text) to authenticated;
notify pgrst, 'reload schema';
commit;
