-- M3 foundation: server-owned lending, returns, losses, evidence access and RLS.
-- Apply only after 202609280001_identity_inventory.sql on a dedicated Perpus DB.
begin;

create function private.is_member_account() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles p
    join public.student_registry s on s.id = p.claimed_student_id
    where p.id = auth.uid() and p.role = 'member'
      and p.status in ('active','inactive') and s.linked_user_id = p.id
  );
$$;

create function private.is_eligible_member(p_user_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles p
    join public.student_registry s on s.id = p.claimed_student_id
    where p.id = p_user_id and p.role = 'member' and p.status = 'active'
      and s.active and s.linked_user_id = p.id
  );
$$;
revoke all on function private.is_member_account(), private.is_eligible_member(uuid) from public, anon, authenticated;
grant execute on function private.is_member_account() to authenticated;

create table public.loan_requests (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(id),
  idempotency_key uuid not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected','cancelled')),
  decision_reason text,
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (member_id,idempotency_key)
);
create index loan_requests_member_created on public.loan_requests(member_id,created_at desc);
create index loan_requests_pending on public.loan_requests(created_at) where status='pending';

create table public.loan_request_items (
  request_id uuid not null references public.loan_requests(id),
  copy_id uuid not null references public.book_copies(id),
  primary key (request_id,copy_id)
);
create index loan_request_items_copy on public.loan_request_items(copy_id);

create table public.transaction_evidence (
  request_id uuid primary key references public.loan_requests(id),
  member_id uuid not null references public.profiles(id),
  method text not null check (method in ('selfie','student_card')),
  bucket_id text not null default 'loan-evidence' check (bucket_id='loan-evidence'),
  object_path text not null unique,
  retention_policy text not null check (retention_policy in ('3_days','7_days','30_days','1_year')),
  uploaded_at timestamptz not null default now(),
  retention_started_at timestamptz,
  delete_after timestamptz,
  deleted_at timestamptz,
  check ((retention_started_at is null and delete_after is null) or
         (retention_started_at is not null and delete_after is not null))
);

create table public.loans (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique references public.loan_requests(id),
  member_id uuid not null references public.profiles(id),
  approved_by uuid not null references public.profiles(id),
  approved_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index loans_member_approved on public.loans(member_id,approved_at desc);

create table public.return_requests (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(id),
  idempotency_key uuid not null,
  status text not null default 'pending' check (status in ('pending','partial','completed','rejected','cancelled')),
  created_at timestamptz not null default now(),
  unique (member_id,idempotency_key)
);
create index return_requests_member_created on public.return_requests(member_id,created_at desc);

create table public.loan_items (
  id uuid primary key default gen_random_uuid(),
  loan_id uuid not null references public.loans(id),
  copy_id uuid not null references public.book_copies(id),
  due_at timestamptz not null,
  returned_at timestamptz,
  return_condition text check (return_condition in ('good','damaged')),
  return_request_id uuid references public.return_requests(id),
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  check ((returned_at is null and return_condition is null) or
         (returned_at is not null and return_condition is not null))
);
create index loan_items_loan on public.loan_items(loan_id);
create index loan_items_open_member on public.loan_items(loan_id,due_at) where returned_at is null and resolved_at is null;
create unique index loan_items_one_open_copy on public.loan_items(copy_id)
  where returned_at is null and resolved_at is null;
create index loan_items_return_request on public.loan_items(return_request_id) where return_request_id is not null;

create table public.return_request_items (
  id uuid primary key default gen_random_uuid(),
  return_request_id uuid not null references public.return_requests(id),
  loan_item_id uuid not null references public.loan_items(id),
  status text not null default 'pending' check (status in ('pending','received','rejected','cancelled')),
  received_condition text check (received_condition in ('good','damaged')),
  decision_reason text,
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  unique (return_request_id,loan_item_id),
  check ((status='received' and received_condition is not null) or
         (status<>'received' and received_condition is null))
);
create index return_request_items_loan_item on public.return_request_items(loan_item_id);

create table public.loss_reports (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(id),
  loan_item_id uuid not null references public.loan_items(id),
  idempotency_key uuid not null,
  description text not null check (length(btrim(description)) between 1 and 2000),
  status text not null default 'reported' check (status in ('reported','verified','rejected','resolved')),
  review_reason text,
  resolution_note text,
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  resolved_by uuid references public.profiles(id),
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  unique (member_id,idempotency_key),
  check ((status='resolved' and resolved_at is not null and resolved_by is not null and resolution_note is not null) or
         (status<>'resolved' and resolved_at is null and resolved_by is null))
);
create unique index loss_reports_one_open_per_item on public.loss_reports(loan_item_id)
  where status in ('reported','verified');
create index loss_reports_member_created on public.loss_reports(member_id,created_at desc);

-- The object store is private. Client paths must be owned by the current member.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('loan-evidence','loan-evidence',false,10485760,array['image/jpeg','image/png'])
on conflict (id) do update set public=false,file_size_limit=excluded.file_size_limit,
  allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists perpus_evidence_read on storage.objects;
drop policy if exists perpus_evidence_insert on storage.objects;
create policy perpus_evidence_read on storage.objects for select to authenticated
  using (bucket_id='loan-evidence' and
    (private.is_admin() or (private.is_member_account() and owner_id=auth.uid()::text)));
create policy perpus_evidence_insert on storage.objects for insert to authenticated
  with check (bucket_id='loan-evidence' and private.is_eligible_member(auth.uid())
    and owner_id=auth.uid()::text and (storage.foldername(name))[1]=auth.uid()::text);
-- There is deliberately no client UPDATE or DELETE policy for evidence objects.

create function private.retention_deadline(p_started_at timestamptz,p_policy text)
returns timestamptz language sql immutable set search_path = '' as $$
  select p_started_at + case p_policy
    when '3_days' then interval '3 days'
    when '7_days' then interval '7 days'
    when '30_days' then interval '30 days'
    when '1_year' then interval '1 year'
    else null end;
$$;
revoke all on function private.retention_deadline(timestamptz,text) from public,anon,authenticated;

create function private.start_evidence_retention(p_request_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare e public.transaction_evidence;
begin
  select * into e from public.transaction_evidence where request_id=p_request_id for update;
  if e.request_id is null or e.retention_started_at is not null then return; end if;
  update public.transaction_evidence
    set retention_started_at=now(),delete_after=private.retention_deadline(now(),e.retention_policy)
    where request_id=p_request_id;
end;
$$;
revoke all on function private.start_evidence_retention(uuid) from public,anon,authenticated;

create function public.submit_loan_request(
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
  if v_user is null or not private.is_eligible_member(v_user) then raise exception 'Akun anggota aktif diperlukan.'; end if;
  if p_idempotency_key is null or p_copy_ids is null or cardinality(p_copy_ids)=0 then raise exception 'Pilih minimal satu eksemplar.'; end if;
  select count(*),count(distinct x) into v_count,v_distinct from unnest(p_copy_ids) x;
  if v_count<>v_distinct then raise exception 'Eksemplar yang sama tidak boleh dikirim dua kali.'; end if;
  if p_evidence_method not in ('selfie','student_card') then raise exception 'Jenis bukti tidak valid.'; end if;
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
    where member_id=v_user and idempotency_key=p_idempotency_key for update;
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

create function public.cancel_loan_request(p_request_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_request public.loan_requests;
begin
  select * into v_request from public.loan_requests where id=p_request_id for update;
  if v_request.id is null or v_request.member_id<>auth.uid() or v_request.status<>'pending' then
    raise exception 'Pengajuan tidak dapat dibatalkan.';
  end if;
  update public.loan_requests set status='cancelled' where id=p_request_id;
  perform private.start_evidence_retention(p_request_id);
end;
$$;

create function public.review_loan_request(p_request_id uuid,p_approve boolean,p_reason text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare
  r public.loan_requests;
  s public.library_settings;
  v_open_count integer;
  v_requested_count integer;
  v_loan_id uuid;
  v_now timestamptz := now();
begin
  if not private.is_admin() then raise exception 'Akses admin diperlukan.'; end if;
  if p_approve is null then raise exception 'Keputusan wajib diisi.'; end if;
  select * into r from public.loan_requests where id=p_request_id for update;
  if r.id is null or r.status<>'pending' then raise exception 'Pengajuan sudah atau tidak dapat diproses.'; end if;
  if not p_approve then
    if p_reason is null or length(btrim(p_reason))=0 then raise exception 'Alasan penolakan wajib diisi.'; end if;
    update public.loan_requests set status='rejected',decision_reason=left(btrim(p_reason),1000),reviewed_by=auth.uid(),reviewed_at=v_now where id=r.id;
    perform private.start_evidence_retention(r.id);
    return;
  end if;
  -- Serialize approvals for this member before checking the outstanding-loan cap.
  -- Without this lock, two admins could approve different requests concurrently.
  perform 1 from public.profiles p where p.id=r.member_id for update;
  if not private.is_eligible_member(r.member_id) then raise exception 'Akun anggota tidak lagi aktif.'; end if;
  select * into s from public.library_settings where id=true;
  if not found or not s.policy_confirmed then raise exception 'Kebijakan pinjaman belum dikonfirmasi.'; end if;
  perform c.id from public.book_copies c join public.loan_request_items i on i.copy_id=c.id
    where i.request_id=r.id order by c.id for update of c;
  select count(*) into v_requested_count from public.loan_request_items where request_id=r.id;
  if v_requested_count=0 or v_requested_count>s.max_books then raise exception 'Isi pengajuan tidak valid atau melewati batas buku.'; end if;
  if exists(select 1 from public.loan_request_items i join public.book_copies c on c.id=i.copy_id
      join public.books b on b.id=c.book_id where i.request_id=r.id
      and (c.status<>'available' or c.archived_at is not null or b.archived_at is not null)) then
    raise exception 'Satu atau beberapa buku sudah tidak tersedia.';
  end if;
  select count(*) into v_open_count from public.loan_items li join public.loans l on l.id=li.loan_id
    where l.member_id=r.member_id and li.returned_at is null and li.resolved_at is null;
  if exists(select 1 from public.loan_items li join public.loans l on l.id=li.loan_id
      where l.member_id=r.member_id and li.returned_at is null and li.resolved_at is null and li.due_at<=v_now) then
    raise exception 'Kembalikan buku yang terlambat sebelum meminjam lagi.';
  end if;
  if exists(select 1 from public.loss_reports lr join public.loan_items li on li.id=lr.loan_item_id
      join public.loans l on l.id=li.loan_id where l.member_id=r.member_id and lr.status in ('reported','verified')) then
    raise exception 'Selesaikan laporan kehilangan sebelum meminjam lagi.';
  end if;
  if v_open_count+v_requested_count>s.max_books then raise exception 'Batas buku aktif akan terlampaui.'; end if;
  insert into public.loans(request_id,member_id,approved_by,approved_at)
    values (r.id,r.member_id,auth.uid(),v_now) returning id into v_loan_id;
  insert into public.loan_items(loan_id,copy_id,due_at)
    select v_loan_id,i.copy_id,v_now+s.loan_days*interval '1 day'
      from public.loan_request_items i where i.request_id=r.id;
  update public.book_copies c set status='borrowed'
    from public.loan_request_items i where i.request_id=r.id and c.id=i.copy_id;
  update public.loan_requests set status='approved',reviewed_by=auth.uid(),reviewed_at=v_now where id=r.id;
end;
$$;

create function public.request_return(p_idempotency_key uuid,p_loan_item_ids uuid[])
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_existing public.return_requests;
  v_has_existing boolean;
  v_request_id uuid;
  v_count integer;
  v_distinct integer;
  v_existing_ids uuid[];
  v_requested_ids uuid[];
begin
  if v_user is null or not private.is_member_account() then raise exception 'Akun anggota diperlukan.'; end if;
  if p_idempotency_key is null or p_loan_item_ids is null or cardinality(p_loan_item_ids)=0 then raise exception 'Pilih minimal satu buku pinjaman.'; end if;
  select count(*),count(distinct x) into v_count,v_distinct from unnest(p_loan_item_ids) x;
  if v_count<>v_distinct then raise exception 'Buku yang sama tidak boleh dikirim dua kali.'; end if;
  select * into v_existing from public.return_requests where member_id=v_user and idempotency_key=p_idempotency_key for update;
  v_has_existing := found;
  select array_agg(q.id order by q.id) into v_requested_ids from (select distinct unnest(p_loan_item_ids) as id) q;
  if v_has_existing then
    select array_agg(i.loan_item_id order by i.loan_item_id) into v_existing_ids from public.return_request_items i where i.return_request_id=v_existing.id;
    if v_existing_ids is distinct from v_requested_ids then raise exception 'Kunci permintaan sudah dipakai untuk isi yang berbeda.'; end if;
    return v_existing.id;
  end if;
  perform li.id from public.loan_items li join public.loans l on l.id=li.loan_id
    where li.id=any(p_loan_item_ids) and l.member_id=v_user order by li.id for update of li;
  if (select count(*) from public.loan_items li join public.loans l on l.id=li.loan_id
      where li.id=any(p_loan_item_ids) and l.member_id=v_user
        and li.returned_at is null and li.resolved_at is null and li.return_request_id is null)<>v_count then
    raise exception 'Satu atau beberapa buku tidak dapat diajukan untuk pengembalian.';
  end if;
  if exists(select 1 from public.loss_reports lr where lr.loan_item_id=any(p_loan_item_ids) and lr.status in ('reported','verified')) then
    raise exception 'Selesaikan peninjauan laporan kehilangan terlebih dahulu.';
  end if;
  insert into public.return_requests(member_id,idempotency_key) values (v_user,p_idempotency_key) returning id into v_request_id;
  insert into public.return_request_items(return_request_id,loan_item_id)
    select v_request_id,x from unnest(p_loan_item_ids) x;
  update public.loan_items set return_request_id=v_request_id where id=any(p_loan_item_ids);
  return v_request_id;
end;
$$;

create function public.cancel_return_request(p_return_request_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare r public.return_requests;
begin
  select * into r from public.return_requests where id=p_return_request_id for update;
  if r.id is null or r.member_id<>auth.uid() or r.status not in ('pending','partial') then raise exception 'Pengajuan pengembalian tidak dapat dibatalkan.'; end if;
  if exists(select 1 from public.return_request_items where return_request_id=r.id and status<>'pending') then raise exception 'Pengembalian yang sudah diproses tidak dapat dibatalkan.'; end if;
  update public.return_request_items set status='cancelled' where return_request_id=r.id;
  update public.loan_items set return_request_id=null where return_request_id=r.id;
  update public.return_requests set status='cancelled' where id=r.id;
end;
$$;

create function public.review_return_item(p_return_item_id uuid,p_accept boolean,p_condition text default null,p_reason text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare
  ri public.return_request_items;
  rr public.return_requests;
  li public.loan_items;
  v_now timestamptz := now();
  v_status text;
begin
  if not private.is_admin() then raise exception 'Akses admin diperlukan.'; end if;
  select * into ri from public.return_request_items where id=p_return_item_id for update;
  select * into rr from public.return_requests where id=ri.return_request_id for update;
  if ri.id is null or rr.id is null or ri.status<>'pending' or rr.status not in ('pending','partial') then raise exception 'Item pengembalian sudah diproses.'; end if;
  select * into li from public.loan_items where id=ri.loan_item_id for update;
  if li.returned_at is not null or li.resolved_at is not null or li.return_request_id<>rr.id then raise exception 'Pinjaman tidak lagi dapat dikembalikan.'; end if;
  if p_accept then
    if p_condition not in ('good','damaged') then raise exception 'Kondisi buku wajib dipilih.'; end if;
    update public.loan_items set returned_at=v_now,return_condition=p_condition where id=li.id;
    update public.book_copies set status=case p_condition when 'good' then 'available' else 'damaged' end where id=li.copy_id;
    update public.return_request_items set status='received',received_condition=p_condition,reviewed_by=auth.uid(),reviewed_at=v_now where id=ri.id;
  else
    if p_reason is null or length(btrim(p_reason))=0 then raise exception 'Alasan penolakan wajib diisi.'; end if;
    update public.loan_items set return_request_id=null where id=li.id;
    update public.return_request_items set status='rejected',decision_reason=left(btrim(p_reason),1000),reviewed_by=auth.uid(),reviewed_at=v_now where id=ri.id;
  end if;
  if exists(select 1 from public.return_request_items where return_request_id=rr.id and status='pending') then
    if exists(select 1 from public.return_request_items where return_request_id=rr.id and status='received') then v_status:='partial'; else v_status:='pending'; end if;
  elsif exists(select 1 from public.return_request_items where return_request_id=rr.id and status='received') then v_status:='completed';
  else v_status:='rejected'; end if;
  update public.return_requests set status=v_status where id=rr.id;
  if p_accept and not exists(select 1 from public.loan_items where loan_id=li.loan_id and returned_at is null and resolved_at is null) then
    perform private.start_evidence_retention((select request_id from public.loans where id=li.loan_id));
  end if;
end;
$$;

create function public.report_loss(p_idempotency_key uuid,p_loan_item_id uuid,p_description text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_existing public.loss_reports;
  v_id uuid;
  li public.loan_items;
begin
  if v_user is null or not private.is_member_account() then raise exception 'Akun anggota diperlukan.'; end if;
  if p_idempotency_key is null or p_loan_item_id is null or p_description is null or length(btrim(p_description)) not between 1 and 2000 then raise exception 'Isi laporan kehilangan tidak valid.'; end if;
  select * into v_existing from public.loss_reports where member_id=v_user and idempotency_key=p_idempotency_key for update;
  if found then
    if v_existing.loan_item_id<>p_loan_item_id or v_existing.description<>btrim(p_description) then raise exception 'Kunci laporan sudah dipakai untuk isi yang berbeda.'; end if;
    return v_existing.id;
  end if;
  select item.* into li from public.loan_items item join public.loans l on l.id=item.loan_id
    where item.id=p_loan_item_id and l.member_id=v_user for update of item;
  if li.id is null or li.returned_at is not null or li.resolved_at is not null or li.return_request_id is not null then raise exception 'Pinjaman tidak dapat dilaporkan hilang.'; end if;
  insert into public.loss_reports(member_id,loan_item_id,idempotency_key,description)
    values (v_user,p_loan_item_id,p_idempotency_key,btrim(p_description)) returning id into v_id;
  return v_id;
end;
$$;

create function public.review_loss_report(p_report_id uuid,p_verify boolean,p_reason text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare lr public.loss_reports; li public.loan_items;
begin
  if not private.is_admin() then raise exception 'Akses admin diperlukan.'; end if;
  if p_verify is null then raise exception 'Keputusan wajib diisi.'; end if;
  select * into lr from public.loss_reports where id=p_report_id for update;
  if lr.id is null or lr.status<>'reported' then raise exception 'Laporan sudah diproses.'; end if;
  select * into li from public.loan_items where id=lr.loan_item_id for update;
  if li.returned_at is not null or li.resolved_at is not null then raise exception 'Pinjaman sudah selesai.'; end if;
  if p_verify then
    update public.loss_reports set status='verified',reviewed_by=auth.uid(),reviewed_at=now(),review_reason=null where id=lr.id;
    update public.book_copies set status='lost' where id=li.copy_id;
  else
    if p_reason is null or length(btrim(p_reason))=0 then raise exception 'Alasan penolakan wajib diisi.'; end if;
    update public.loss_reports set status='rejected',reviewed_by=auth.uid(),reviewed_at=now(),review_reason=left(btrim(p_reason),1000) where id=lr.id;
  end if;
end;
$$;

create function public.resolve_loss(p_report_id uuid,p_note text)
returns void language plpgsql security definer set search_path = '' as $$
declare lr public.loss_reports; li public.loan_items;
begin
  if not private.is_admin() then raise exception 'Akses admin diperlukan.'; end if;
  if p_note is null or length(btrim(p_note))=0 then raise exception 'Catatan penyelesaian wajib diisi.'; end if;
  select * into lr from public.loss_reports where id=p_report_id for update;
  if lr.id is null or lr.status<>'verified' then raise exception 'Laporan belum diverifikasi atau sudah selesai.'; end if;
  select * into li from public.loan_items where id=lr.loan_item_id for update;
  if li.returned_at is not null or li.resolved_at is not null then raise exception 'Kewajiban sudah selesai.'; end if;
  update public.loan_items set resolved_at=now() where id=li.id;
  update public.loss_reports set status='resolved',resolution_note=left(btrim(p_note),1000),resolved_by=auth.uid(),resolved_at=now() where id=lr.id;
  if not exists(select 1 from public.loan_items where loan_id=li.loan_id and returned_at is null and resolved_at is null) then
    perform private.start_evidence_retention((select request_id from public.loans where id=li.loan_id));
  end if;
end;
$$;

create function private.audit_transaction_change() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.audit_logs(actor_id,action,table_name,record_id,old_data,new_data)
  values (auth.uid(),tg_op,tg_table_name,coalesce(to_jsonb(new)->>'id',to_jsonb(old)->>'id'),
    case when tg_op='INSERT' then null else to_jsonb(old) end,
    case when tg_op='DELETE' then null else to_jsonb(new) end);
  return coalesce(new,old);
end;
$$;
revoke all on function private.audit_transaction_change() from public,anon,authenticated;
create trigger audit_loan_requests after insert or update on public.loan_requests for each row execute function private.audit_transaction_change();
create trigger audit_loans after insert on public.loans for each row execute function private.audit_transaction_change();
create trigger audit_loan_items after insert or update on public.loan_items for each row execute function private.audit_transaction_change();
create trigger audit_return_requests after insert or update on public.return_requests for each row execute function private.audit_transaction_change();
create trigger audit_loss_reports after insert or update on public.loss_reports for each row execute function private.audit_transaction_change();

alter table public.loan_requests enable row level security;
alter table public.loan_request_items enable row level security;
alter table public.transaction_evidence enable row level security;
alter table public.loans enable row level security;
alter table public.loan_items enable row level security;
alter table public.return_requests enable row level security;
alter table public.return_request_items enable row level security;
alter table public.loss_reports enable row level security;
revoke all on public.loan_requests,public.loan_request_items,public.transaction_evidence,public.loans,
  public.loan_items,public.return_requests,public.return_request_items,public.loss_reports from anon,authenticated;
grant select on public.loan_requests,public.loan_request_items,public.transaction_evidence,public.loans,
  public.loan_items,public.return_requests,public.return_request_items,public.loss_reports to authenticated;

create policy loan_requests_read on public.loan_requests for select to authenticated using (member_id=auth.uid() or private.is_admin());
create policy loan_request_items_read on public.loan_request_items for select to authenticated using (
  private.is_admin() or exists(select 1 from public.loan_requests r where r.id=request_id and r.member_id=auth.uid()));
create policy evidence_read on public.transaction_evidence for select to authenticated using (
  private.is_admin() or (member_id=auth.uid() and private.is_member_account()));
create policy loans_read on public.loans for select to authenticated using (member_id=auth.uid() or private.is_admin());
create policy loan_items_read on public.loan_items for select to authenticated using (
  private.is_admin() or exists(select 1 from public.loans l where l.id=loan_id and l.member_id=auth.uid()));
create policy return_requests_read on public.return_requests for select to authenticated using (member_id=auth.uid() or private.is_admin());
create policy return_request_items_read on public.return_request_items for select to authenticated using (
  private.is_admin() or exists(select 1 from public.return_requests r where r.id=return_request_id and r.member_id=auth.uid()));
create policy loss_reports_read on public.loss_reports for select to authenticated using (member_id=auth.uid() or private.is_admin());

revoke all on function public.submit_loan_request(uuid,uuid[],text,text),public.cancel_loan_request(uuid),
  public.review_loan_request(uuid,boolean,text),public.request_return(uuid,uuid[]),
  public.cancel_return_request(uuid),public.review_return_item(uuid,boolean,text,text),
  public.report_loss(uuid,uuid,text),public.review_loss_report(uuid,boolean,text),public.resolve_loss(uuid,text)
  from public,anon;
grant execute on function public.submit_loan_request(uuid,uuid[],text,text),public.cancel_loan_request(uuid),
  public.review_loan_request(uuid,boolean,text),public.request_return(uuid,uuid[]),
  public.cancel_return_request(uuid),public.review_return_item(uuid,boolean,text,text),
  public.report_loss(uuid,uuid,text),public.review_loss_report(uuid,boolean,text),public.resolve_loss(uuid,text)
  to authenticated;

commit;
