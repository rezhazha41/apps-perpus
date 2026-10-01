-- Secure one-time invitation flow for staff accounts.
-- Apply after 202609290001_staff_admin_operations.sql.
begin;

alter table public.staff_registry
  add column email text,
  add column invite_token uuid,
  add column invite_expires_at timestamptz,
  add constraint staff_invite_pair_check check (
    (invite_token is null and invite_expires_at is null)
    or (invite_token is not null and invite_expires_at is not null)
  );
create unique index staff_registry_email_lower on public.staff_registry(lower(email))
  where email is not null;
create unique index profiles_staff_unique on public.profiles(staff_id)
  where staff_id is not null;

-- Do not preserve one-time invitation secrets in the general audit snapshot.
create or replace function private.audit_change() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  old_row jsonb;
  new_row jsonb;
begin
  old_row := case when tg_op='INSERT' then null else to_jsonb(old) end;
  new_row := case when tg_op='DELETE' then null else to_jsonb(new) end;
  if tg_table_name='staff_registry' then
    old_row := old_row - 'invite_token';
    new_row := new_row - 'invite_token';
  end if;
  insert into public.audit_logs(actor_id,action,table_name,record_id,old_data,new_data)
  values (auth.uid(),tg_op,tg_table_name,
    coalesce(new_row->>'id',old_row->>'id'),old_row,new_row);
  return coalesce(new,old);
end;
$$;

create or replace function private.create_member_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  student_id uuid;
  staff_id uuid;
  identity_kind text := new.raw_user_meta_data ->> 'identity_kind';
  identity_number text := btrim(new.raw_user_meta_data ->> 'identity_number');
  v_invite_token uuid;
begin
  if new.raw_user_meta_data ->> 'account_kind'='staff' then
    begin
      v_invite_token := nullif(new.raw_user_meta_data ->> 'staff_invite_token','')::uuid;
    exception when invalid_text_representation then
      raise exception 'Pendaftaran tidak dapat diproses. Hubungi admin perpustakaan.';
    end;
    select s.id into staff_id from public.staff_registry s
    where lower(s.email)=lower(new.email) and s.active and s.linked_user_id is null
      and s.invite_token=v_invite_token and s.invite_expires_at>now()
    for update of s;
    if staff_id is null then
      raise exception 'Pendaftaran tidak dapat diproses. Hubungi admin perpustakaan.';
    end if;
    update public.staff_registry
    set linked_user_id=new.id, invite_token=null, invite_expires_at=null
    where id=staff_id;
    insert into public.profiles(id,staff_id,role,status,contact)
      values(new.id,staff_id,'admin','pending',left(new.raw_user_meta_data->>'contact',200));
    return new;
  end if;

  if identity_kind not in ('nis','nisn') or identity_number is null or identity_number !~ '^[0-9]+$' then
    raise exception 'Pendaftaran tidak dapat diproses. Hubungi admin perpustakaan.';
  end if;
  select id into student_id from public.student_registry
  where active and linked_user_id is null and
    ((identity_kind='nis' and nis=identity_number) or (identity_kind='nisn' and nisn=identity_number));
  if student_id is null then
    raise exception 'Pendaftaran tidak dapat diproses. Hubungi admin perpustakaan.';
  end if;
  insert into public.profiles(id,claimed_student_id,role,status,contact)
    values(new.id,student_id,'member','pending',left(new.raw_user_meta_data->>'contact',200));
  return new;
end;
$$;
revoke all on function private.create_member_profile() from public;

create function public.create_staff_invite(
  p_email text,p_full_name text,p_position text default 'Pengurus Perpustakaan',p_staff_no text default null
) returns table(staff_id uuid,invite_token uuid)
language plpgsql security definer set search_path = '' as $$
declare token uuid := gen_random_uuid();
begin
  if not private.is_admin() then raise exception 'Akses admin diperlukan.'; end if;
  if p_email is null or position('@' in p_email)<2 or p_full_name is null or length(btrim(p_full_name))=0 then
    raise exception 'Email dan nama pengurus wajib diisi.';
  end if;
  insert into public.staff_registry(email,full_name,position,staff_no,invite_token,invite_expires_at)
  values(lower(btrim(p_email)),left(btrim(p_full_name),200),left(coalesce(nullif(btrim(p_position),''),'Pengurus Perpustakaan'),120),
    nullif(btrim(p_staff_no),''),token,now()+interval '48 hours')
  returning id into staff_id;
  invite_token := token;
  return next;
end;
$$;
revoke all on function public.create_staff_invite(text,text,text,text) from public,anon;
grant execute on function public.create_staff_invite(text,text,text,text) to authenticated;

create function public.review_staff_account(p_user_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_admin() then raise exception 'Akses admin diperlukan.'; end if;
  if not exists (
    select 1 from public.profiles p join auth.users u on u.id=p.id
    join public.staff_registry s on s.id=p.staff_id and s.linked_user_id=p.id and s.active
    where p.id=p_user_id and p.role='admin' and p.status='pending' and u.email_confirmed_at is not null
  ) then raise exception 'Akun pengurus belum terkonfirmasi atau tidak dapat diaktifkan.'; end if;
  update public.profiles set status='active',reviewed_by=auth.uid(),reviewed_at=now()
  where id=p_user_id and role='admin' and status='pending';
end;
$$;
revoke all on function public.review_staff_account(uuid) from public,anon;
grant execute on function public.review_staff_account(uuid) to authenticated;

revoke select on public.staff_registry from authenticated;
grant select (id,staff_no,full_name,position,active,linked_user_id,created_at,email)
  on public.staff_registry to authenticated;

commit;
