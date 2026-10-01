-- Staff-managed, multi-copy circulation sessions for classroom learning.
begin;

create table public.class_loan_sessions (
  id uuid primary key default gen_random_uuid(),
  idempotency_key uuid not null,
  responsible_name text not null check (length(btrim(responsible_name)) between 1 and 160),
  class_name text not null check (length(btrim(class_name)) between 1 and 80),
  activity text not null check (length(btrim(activity)) between 1 and 240),
  due_at timestamptz not null,
  returned_at timestamptz,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  unique (created_by, idempotency_key),
  check (returned_at is null or returned_at >= created_at)
);

create table public.class_loan_items (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.class_loan_sessions(id),
  copy_id uuid not null references public.book_copies(id),
  returned_at timestamptz,
  return_condition text check (return_condition in ('good','damaged')),
  created_at timestamptz not null default now(),
  unique (session_id, copy_id),
  check ((returned_at is null and return_condition is null) or
         (returned_at is not null and return_condition is not null))
);
create index class_loan_sessions_recent on public.class_loan_sessions(created_at desc);
create index class_loan_items_session on public.class_loan_items(session_id);
create unique index class_loan_items_one_open_copy on public.class_loan_items(copy_id)
  where returned_at is null;

alter table public.class_loan_sessions enable row level security;
alter table public.class_loan_items enable row level security;
revoke all on public.class_loan_sessions, public.class_loan_items from anon, authenticated;
grant select on public.class_loan_sessions, public.class_loan_items to authenticated;
create policy class_loan_sessions_admin_read on public.class_loan_sessions
  for select to authenticated using (private.is_admin());
create policy class_loan_items_admin_read on public.class_loan_items
  for select to authenticated using (private.is_admin());
create trigger audit_class_loan_sessions after insert or update or delete on public.class_loan_sessions
  for each row execute function private.audit_change();
create trigger audit_class_loan_items after insert or update or delete on public.class_loan_items
  for each row execute function private.audit_change();

create function public.create_class_loan(
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
  if p_due_at is null or p_due_at <= now() then raise exception 'Tenggat harus di waktu mendatang.'; end if;
  select count(*), count(distinct x) into v_count, v_distinct from unnest(p_copy_ids) x;
  if v_count <> v_distinct then raise exception 'QR yang sama terpindai lebih dari sekali.'; end if;
  if exists(select 1 from public.class_loan_sessions
      where created_by=auth.uid() and idempotency_key=p_idempotency_key) then
    select id into v_session_id from public.class_loan_sessions
      where created_by=auth.uid() and idempotency_key=p_idempotency_key;
    return v_session_id;
  end if;

  perform c.id from public.book_copies c join unnest(p_copy_ids) q(id) on q.id=c.id
    order by c.id for update of c;
  if (select count(*) from public.book_copies c join unnest(p_copy_ids) q(id) on q.id=c.id) <> v_count
     or exists(select 1 from public.book_copies c join unnest(p_copy_ids) q(id) on q.id=c.id
       join public.books b on b.id=c.book_id
       where c.status<>'available' or c.archived_at is not null or b.archived_at is not null)
     or exists(select 1 from public.loan_items li join unnest(p_copy_ids) q(id) on q.id=li.copy_id
       where li.returned_at is null and li.resolved_at is null)
     or exists(select 1 from public.class_loan_items ci join unnest(p_copy_ids) q(id) on q.id=ci.copy_id
       where ci.returned_at is null) then
    raise exception 'Satu atau beberapa eksemplar sudah tidak tersedia.';
  end if;

  insert into public.class_loan_sessions(
    idempotency_key,responsible_name,class_name,activity,due_at,created_by
  ) values (
    p_idempotency_key,btrim(p_responsible_name),btrim(p_class_name),btrim(p_activity),p_due_at,auth.uid()
  ) returning id into v_session_id;
  insert into public.class_loan_items(session_id,copy_id)
    select v_session_id,x from unnest(p_copy_ids) x;
  update public.book_copies c set status='borrowed'
    where c.id=any(p_copy_ids);
  return v_session_id;
end;
$$;
revoke all on function public.create_class_loan(uuid,text,text,text,timestamptz,uuid[]) from public, anon;
grant execute on function public.create_class_loan(uuid,text,text,text,timestamptz,uuid[]) to authenticated;

create function public.return_class_loan_copy(p_item_id uuid,p_condition text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_copy_id uuid;
  v_session_id uuid;
  v_changed integer;
begin
  if not private.is_admin() then raise exception 'Akses pengurus diperlukan.'; end if;
  if p_condition not in ('good','damaged') then raise exception 'Kondisi buku tidak valid.'; end if;
  select copy_id,session_id into v_copy_id,v_session_id from public.class_loan_items
    where id=p_item_id and returned_at is null for update;
  if v_copy_id is null then raise exception 'Eksemplar tidak tercatat sebagai pinjaman pembelajaran aktif.'; end if;
  perform 1 from public.book_copies where id=v_copy_id for update;
  update public.class_loan_items set returned_at=now(),return_condition=p_condition
    where id=p_item_id and returned_at is null;
  get diagnostics v_changed=row_count;
  if v_changed<>1 then raise exception 'Pengembalian sudah diproses.'; end if;
  update public.book_copies set status=case p_condition when 'good' then 'available' else 'damaged' end
    where id=v_copy_id;
  update public.class_loan_sessions s set returned_at=now()
    where s.id=v_session_id and s.returned_at is null
      and not exists(select 1 from public.class_loan_items i where i.session_id=s.id and i.returned_at is null);
end;
$$;
revoke all on function public.return_class_loan_copy(uuid,text) from public, anon;
grant execute on function public.return_class_loan_copy(uuid,text) to authenticated;

commit;
