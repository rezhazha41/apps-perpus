begin;

-- A student identity can have one open claim. Rejected profiles remain as
-- audit history and no longer reserve the identity.
do $$
begin
  if exists (
    select claimed_student_id
    from public.profiles
    where role='member' and status in ('pending','active')
    group by claimed_student_id
    having count(*)>1
  ) then
    raise exception 'Resolve duplicate pending member claims before applying this migration.';
  end if;
end;
$$;

create unique index profiles_one_open_member_claim
  on public.profiles(claimed_student_id)
  where role='member' and status in ('pending','active');

create or replace function private.create_member_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  student_id uuid;
  staff_id uuid;
  identity_kind text := new.raw_user_meta_data ->> 'identity_kind';
  identity_number text := btrim(new.raw_user_meta_data ->> 'identity_number');
  v_invite_token uuid;
  account_kind text := new.raw_user_meta_data ->> 'account_kind';
begin
  if account_kind is null or account_kind = '' then return new; end if;

  if account_kind='staff' then
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
      set linked_user_id=new.id,invite_token=null,invite_expires_at=null
      where id=staff_id;
    insert into public.profiles(id,staff_id,role,status,contact)
      values(new.id,staff_id,'admin','pending',left(new.raw_user_meta_data->>'contact',200));
    return new;
  end if;

  if account_kind<>'member' or identity_kind not in ('nis','nisn')
     or identity_number is null or identity_number !~ '^[0-9]+$' then
    raise exception 'Pendaftaran tidak dapat diproses. Hubungi admin perpustakaan.';
  end if;

  select id into student_id from public.student_registry
  where active and linked_user_id is null and
    ((identity_kind='nis' and nis=identity_number) or
     (identity_kind='nisn' and nisn=identity_number))
  for update;
  if student_id is null or exists (
      select 1 from public.profiles
      where claimed_student_id=student_id and role='member'
        and status in ('pending','active')) then
    raise exception 'Pendaftaran tidak dapat diproses. Hubungi admin perpustakaan.';
  end if;

  begin
    insert into public.profiles(id,claimed_student_id,role,status,contact)
      values(new.id,student_id,'member','pending',left(new.raw_user_meta_data->>'contact',200));
  exception when unique_violation then
    raise exception 'Pendaftaran tidak dapat diproses. Hubungi admin perpustakaan.';
  end;
  return new;
end;
$$;
revoke all on function private.create_member_profile() from public;

create or replace function public.review_member(
  p_user_id uuid,p_approve boolean,p_reason text default null
) returns void language plpgsql security definer set search_path = '' as $$
declare
  p public.profiles;
  s public.student_registry;
begin
  if not private.is_admin() then raise exception 'Akses admin diperlukan.'; end if;
  select * into p from public.profiles where id=p_user_id for update;
  if p.id is null or p.role<>'member' or p.status<>'pending' then
    raise exception 'Akun tidak dapat diproses.';
  end if;
  if p_approve is null then raise exception 'Keputusan wajib diisi.'; end if;

  if p_approve then
    if not exists(select 1 from auth.users where id=p_user_id and email_confirmed_at is not null) then
      raise exception 'Email akun belum dikonfirmasi.';
    end if;
    select * into s from public.student_registry where id=p.claimed_student_id for update;
    if s.id is null or not s.active or s.linked_user_id is not null then
      raise exception 'Identitas tidak dapat diaktifkan.';
    end if;
    update public.student_registry set linked_user_id=p_user_id where id=s.id;
    update public.profiles set status='active',reviewed_by=auth.uid(),reviewed_at=now(),
      rejection_reason=null where id=p_user_id;
  else
    if p_reason is null or length(btrim(p_reason))=0 then
      raise exception 'Alasan wajib diisi.';
    end if;
    -- Moving out of pending releases the partial unique-index reservation.
    update public.profiles set status='rejected',rejection_reason=left(btrim(p_reason),1000),
      reviewed_by=auth.uid(),reviewed_at=now() where id=p_user_id;
  end if;
end;
$$;
revoke all on function public.review_member(uuid,boolean,text) from public,anon;
grant execute on function public.review_member(uuid,boolean,text) to authenticated;

create function public.resubmit_member_application()
returns void language plpgsql security definer set search_path = '' as $$
declare
  p public.profiles;
  s public.student_registry;
begin
  if auth.uid() is null then raise exception 'Akun anggota diperlukan.'; end if;
  select * into p from public.profiles where id=auth.uid() for update;
  if p.id is null or p.role<>'member' or p.status<>'rejected' then
    raise exception 'Pendaftaran tidak dapat diajukan ulang.';
  end if;
  select * into s from public.student_registry where id=p.claimed_student_id for update;
  if s.id is null or not s.active or s.linked_user_id is not null then
    raise exception 'Identitas tidak dapat diajukan ulang.';
  end if;
  if exists(select 1 from public.profiles where claimed_student_id=s.id
      and id<>p.id and role='member' and status in ('pending','active')) then
    raise exception 'Identitas sedang digunakan oleh pengajuan lain.';
  end if;
  begin
    update public.profiles set status='pending',rejection_reason=null,
      reviewed_by=null,reviewed_at=null where id=p.id;
  exception when unique_violation then
    raise exception 'Identitas sedang digunakan oleh pengajuan lain.';
  end;
end;
$$;
revoke all on function public.resubmit_member_application() from public,anon;
grant execute on function public.resubmit_member_application() to authenticated;

create table public.account_recovery_challenges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id),
  issued_by uuid not null references auth.users(id),
  code_hash text not null check (code_hash ~ '^[0-9a-f]{64}$'),
  expected_email text check (
    expected_email is null or
    (length(expected_email) between 3 and 320 and expected_email=lower(btrim(expected_email)))
  ),
  expires_at timestamptz not null,
  failed_attempts integer not null default 0 check (failed_attempts between 0 and 5),
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  check (expires_at>created_at)
);
create index account_recovery_user_created
  on public.account_recovery_challenges(user_id,created_at desc);
alter table public.account_recovery_challenges enable row level security;
revoke all on public.account_recovery_challenges from public,anon,authenticated;
grant select,insert,update on public.account_recovery_challenges to service_role;

create function public.issue_account_recovery_challenge(
  p_issued_by uuid,p_user_id uuid,p_code_hash text,p_expected_email text default null
) returns table(challenge_id uuid,expires_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
  v_expires timestamptz := now()+interval '15 minutes';
  v_email text := nullif(lower(btrim(p_expected_email)),'');
begin
  if not exists(select 1 from public.profiles p join public.staff_registry s on s.id=p.staff_id
      where p.id=p_issued_by and p.role='admin' and p.status='active'
        and s.active and s.linked_user_id=p.id) then
    raise exception 'Pengurus aktif diperlukan.';
  end if;
  if not exists(select 1 from public.profiles where id=p_user_id and role='member'
      and status in ('pending','active','rejected')) then
    raise exception 'Akun anggota tidak dapat dipulihkan.';
  end if;
  if p_code_hash is null or p_code_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'Hash kode pemulihan tidak valid.';
  end if;
  if v_email is not null and (length(v_email) not between 3 and 320 or position('@' in v_email)<2) then
    raise exception 'Email baru tidak valid.';
  end if;

  update public.account_recovery_challenges arc set consumed_at=now()
    where arc.user_id=p_user_id and arc.consumed_at is null and arc.expires_at>now();
  insert into public.account_recovery_challenges(user_id,issued_by,code_hash,expected_email,expires_at)
    values(p_user_id,p_issued_by,p_code_hash,v_email,v_expires) returning id into v_id;
  insert into public.audit_logs(actor_id,action,table_name,record_id,new_data)
    values(p_issued_by,'ACCOUNT_RECOVERY_ISSUED','profiles',p_user_id::text,
      jsonb_build_object('challenge_id',v_id,'expires_at',v_expires,'email_change',v_email is not null));
  return query select v_id,v_expires;
end;
$$;

create function public.consume_account_recovery_challenge(
  p_challenge_id uuid,p_code_hash text
) returns table(
  success boolean,user_id uuid,expected_email text,issued_by uuid,error_code text
) language plpgsql security definer set search_path = '' as $$
declare
  c public.account_recovery_challenges;
begin
  select * into c from public.account_recovery_challenges
    where id=p_challenge_id for update;
  if c.id is null or c.consumed_at is not null or c.expires_at<=now()
     or c.failed_attempts>=5 then
    return query select false,null::uuid,null::text,null::uuid,'invalid_or_expired'::text;
    return;
  end if;
  if p_code_hash is null or c.code_hash<>p_code_hash then
    update public.account_recovery_challenges
      set failed_attempts=least(failed_attempts+1,5),
          consumed_at=case when failed_attempts+1>=5 then now() else null end
      where id=c.id;
    return query select false,null::uuid,null::text,null::uuid,'invalid_or_expired'::text;
    return;
  end if;
  update public.account_recovery_challenges set consumed_at=now() where id=c.id;
  insert into public.audit_logs(actor_id,action,table_name,record_id,new_data)
    values(c.issued_by,'ACCOUNT_RECOVERY_CODE_ACCEPTED','profiles',c.user_id::text,
      jsonb_build_object('challenge_id',c.id,'email_change',c.expected_email is not null));
  return query select true,c.user_id,c.expected_email,c.issued_by,null::text;
end;
$$;

create function public.revoke_member_sessions(p_user_id uuid)
returns integer language plpgsql security definer set search_path = '' as $$
declare changed integer := 0;
begin
  if to_regclass('auth.sessions') is not null then
    execute 'delete from auth.sessions where user_id=$1' using p_user_id;
    get diagnostics changed=row_count;
  end if;
  return changed;
end;
$$;

revoke all on function public.issue_account_recovery_challenge(uuid,uuid,text,text),
  public.consume_account_recovery_challenge(uuid,text),
  public.revoke_member_sessions(uuid) from public,anon,authenticated;
grant execute on function public.issue_account_recovery_challenge(uuid,uuid,text,text),
  public.consume_account_recovery_challenge(uuid,text),
  public.revoke_member_sessions(uuid) to service_role;

commit;
