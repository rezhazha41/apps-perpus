-- Allocate a quantity of available copies for classroom learning atomically.
begin;

create function public.create_class_loan_by_book(
  p_idempotency_key uuid,
  p_responsible_name text,
  p_class_name text,
  p_activity text,
  p_due_at timestamptz,
  p_book_id uuid,
  p_quantity integer
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_session_id uuid;
  v_copy_ids uuid[];
begin
  if not private.is_admin() then raise exception 'Akses pengurus diperlukan.'; end if;
  if p_idempotency_key is null or p_book_id is null or p_quantity is null or p_quantity < 1 then
    raise exception 'Pilih judul buku dan jumlah minimal satu.';
  end if;
  if length(btrim(coalesce(p_responsible_name,''))) not between 1 and 160
     or length(btrim(coalesce(p_class_name,''))) not between 1 and 80
     or length(btrim(coalesce(p_activity,''))) not between 1 and 240 then
    raise exception 'Penanggung jawab, kelas, dan kegiatan wajib diisi.';
  end if;
  if p_due_at is null or p_due_at <= now() then raise exception 'Tenggat harus di waktu mendatang.'; end if;
  if exists(select 1 from public.class_loan_sessions where created_by=auth.uid() and idempotency_key=p_idempotency_key) then
    select id into v_session_id from public.class_loan_sessions where created_by=auth.uid() and idempotency_key=p_idempotency_key;
    return v_session_id;
  end if;

  select array_agg(q.id order by q.id) into v_copy_ids
  from (
    select c.id
    from public.book_copies c
    join public.books b on b.id=c.book_id
    where c.book_id=p_book_id and c.status='available'
      and c.archived_at is null and b.archived_at is null
    order by c.id
    limit p_quantity
    for update of c
  ) q;
  if coalesce(cardinality(v_copy_ids),0) <> p_quantity then
    raise exception 'Jumlah eksemplar tersedia tidak mencukupi.';
  end if;

  insert into public.class_loan_sessions(idempotency_key,responsible_name,class_name,activity,due_at,created_by)
  values (p_idempotency_key,btrim(p_responsible_name),btrim(p_class_name),btrim(p_activity),p_due_at,auth.uid())
  returning id into v_session_id;
  insert into public.class_loan_items(session_id,copy_id)
    select v_session_id,x from unnest(v_copy_ids) x;
  update public.book_copies set status='borrowed' where id=any(v_copy_ids);
  return v_session_id;
end;
$$;

revoke all on function public.create_class_loan_by_book(uuid,text,text,text,timestamptz,uuid,integer) from public, anon;
grant execute on function public.create_class_loan_by_book(uuid,text,text,text,timestamptz,uuid,integer) to authenticated;

commit;
