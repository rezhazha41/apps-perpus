-- Allow an operator-created Auth user to be linked by a database operator
-- after email verification. Unclassified users receive no public profile and
-- therefore no application access. Member signup remains explicitly tagged.
begin;

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
  -- Studio-created users have no signup metadata. They remain unprivileged
  -- until a trusted operator links their verified email to a registry row.
  if account_kind is null or account_kind = '' then
    return new;
  end if;

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
    set linked_user_id=new.id, invite_token=null, invite_expires_at=null
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

commit;
