-- Run as database operator on a dedicated development Supabase instance.
-- Raises on failed assertion; always rolls back fixtures on success.
\set ON_ERROR_STOP on
begin;
insert into public.student_registry(id,nis,nisn,full_name,class_name) values
 ('10000000-0000-4000-8000-000000000001','990001','880001','Test Admin','Staff'),
 ('10000000-0000-4000-8000-000000000002','990002','880002','Test Member','X'),
 ('10000000-0000-4000-8000-000000000003','990003','880003','Test Other','XI');
insert into auth.users(id,email,raw_user_meta_data) values
 ('20000000-0000-4000-8000-000000000001','admin@example.invalid','{"account_kind":"member","identity_kind":"nis","identity_number":"990001"}'),
 ('20000000-0000-4000-8000-000000000002','member@example.invalid','{"account_kind":"member","identity_kind":"nis","identity_number":"990002","role":"admin"}'),
 ('20000000-0000-4000-8000-000000000003','other@example.invalid','{"account_kind":"member","identity_kind":"nis","identity_number":"990003"}'),
 ('20000000-0000-4000-8000-000000000004','duplicate@example.invalid','{"account_kind":"member","identity_kind":"nisn","identity_number":"880002"}');
-- Operator-created Studio Auth user is intentionally unprivileged until linked.
insert into auth.users(id,email,raw_user_meta_data)
values ('20000000-0000-4000-8000-000000000008','studio-admin@example.invalid','{}');
do $$ begin
 if exists(select 1 from public.profiles where id='20000000-0000-4000-8000-000000000008') then
   raise exception 'Unlinked Studio Auth user received a profile';
 end if;
end $$;
update auth.users set email_confirmed_at = now() where id::text like '20000000-0000-4000-8000-%';
insert into public.staff_registry(id,full_name,linked_user_id) values
 ('30000000-0000-4000-8000-000000000001','Test Admin','20000000-0000-4000-8000-000000000001');
insert into public.staff_registry(id,full_name,email,invite_token,invite_expires_at) values
 ('30000000-0000-4000-8000-000000000002','Invited Staff','invited-staff@example.invalid',
  '40000000-0000-4000-8000-000000000002',now()+interval '1 day');
insert into auth.users(id,email,raw_user_meta_data) values
 ('20000000-0000-4000-8000-000000000007','invited-staff@example.invalid',
  '{"account_kind":"staff","staff_invite_token":"40000000-0000-4000-8000-000000000002"}');
update auth.users set email_confirmed_at=now()
where id='20000000-0000-4000-8000-000000000007';
update public.profiles set role='admin',status='active',claimed_student_id=null,
  staff_id='30000000-0000-4000-8000-000000000001'
where id='20000000-0000-4000-8000-000000000001';

do $$ begin
 begin
   insert into auth.users(id,email,raw_user_meta_data) values
     ('20000000-0000-4000-8000-000000000005','unknown@example.invalid','{"account_kind":"member","identity_kind":"nis","identity_number":"not-registered"}');
   raise exception 'Unknown student registered';
 exception when raise_exception then
   if sqlerrm <> 'Pendaftaran tidak dapat diproses. Hubungi admin perpustakaan.' then raise; end if;
 end;
 begin
   insert into auth.users(id,email,raw_user_meta_data) values
     ('20000000-0000-4000-8000-000000000006','nobody@example.invalid',
      '{"account_kind":"staff","staff_invite_token":"40000000-0000-4000-8000-000000000002"}');
   raise exception 'Invalid staff claim accepted';
 exception when raise_exception then
   if sqlerrm <> 'Pendaftaran tidak dapat diproses. Hubungi admin perpustakaan.' then raise; end if;
 end;
end $$;

set local role anon;
do $$ begin
 begin
   perform id from public.student_registry;
   raise exception 'Anonymous registry leak';
 exception when insufficient_privilege then null; end;
 begin
   perform id from public.staff_registry;
   raise exception 'Anonymous staff registry leak';
 exception when insufficient_privilege then null; end;
end $$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','20000000-0000-4000-8000-000000000002',true);
do $$ begin
 if (select count(*) from public.profiles) <> 1 then raise exception 'Cross-member profile leak'; end if;
 if (select role from public.profiles limit 1) <> 'member' then raise exception 'Role metadata escalation'; end if;
 if (select count(*) from public.student_registry) <> 0 then raise exception 'Pending registry leak'; end if;
 if (select count(*) from public.staff_registry) <> 0 then raise exception 'Member can read staff registry'; end if;
 if (select count(*) from public.audit_logs) <> 0 then raise exception 'Member can read audit logs'; end if;
 update public.library_settings set max_books=4 where id=true;
 if found then raise exception 'Member changed library settings'; end if;
 begin
   perform public.create_staff_invite('other-staff@example.invalid','Other Staff');
   raise exception 'Member created staff invitation';
 exception when raise_exception then
   if sqlerrm<>'Akses admin diperlukan.' then raise; end if;
 end;
 begin
   update public.profiles set role='admin' where id=auth.uid();
   raise exception 'Profile escalation allowed';
 exception when insufficient_privilege then null; end;
 begin
   perform public.review_member(auth.uid(),true);
   raise exception 'Member can review';
 exception when raise_exception then
   if sqlerrm <> 'Akses admin diperlukan.' then raise; end if;
 end;
end $$;

select set_config('request.jwt.claim.sub','20000000-0000-4000-8000-000000000001',true);
do $$ declare invite record;
begin
 if (select count(*) from public.staff_registry) <> 2 then raise exception 'Admin cannot read staff registry'; end if;
 if (select count(*) from public.audit_logs) = 0 then raise exception 'Admin cannot read audit logs'; end if;
 if exists(select 1 from public.audit_logs where table_name='staff_registry'
           and coalesce(new_data,'{}'::jsonb) ? 'invite_token') then
   raise exception 'Staff invite token leaked into audit history';
 end if;
 perform public.review_staff_account('20000000-0000-4000-8000-000000000007');
 if not exists(select 1 from public.profiles where id='20000000-0000-4000-8000-000000000007'
               and role='admin' and status='active') then
   raise exception 'Admin could not activate invited staff';
 end if;
  select * into invite from public.create_staff_invite(
    'new-invite@example.invalid','New Invite','Koordinator',null);
  if invite.staff_id is null or invite.invite_token is null then
    raise exception 'Admin could not create staff invitation';
  end if;
  begin
    perform invite_token from public.staff_registry where id=invite.staff_id;
    raise exception 'Client can read staff invite token';
  exception when insufficient_privilege then null; end;
 update public.library_settings set loan_days=8 where id=true;
 if not found then raise exception 'Admin cannot update library settings'; end if;
 if not exists(select 1 from public.audit_logs where table_name='library_settings') then
   raise exception 'Library setting changes are not audited';
 end if;
end $$;
reset role;
update auth.users set email_confirmed_at = null where id='20000000-0000-4000-8000-000000000002';
set local role authenticated;
do $$ begin
 begin
   perform public.review_member('20000000-0000-4000-8000-000000000002',true);
   raise exception 'Unconfirmed email activated';
 exception when raise_exception then
   if sqlerrm <> 'Email akun belum dikonfirmasi.' then raise; end if;
 end;
end $$;
reset role;
update auth.users set email_confirmed_at = now() where id='20000000-0000-4000-8000-000000000002';
set local role authenticated;
select public.review_member('20000000-0000-4000-8000-000000000002',true);
select public.review_member('20000000-0000-4000-8000-000000000003',true);
do $$ begin
 begin
   perform public.review_member('20000000-0000-4000-8000-000000000004',true);
   raise exception 'Duplicate identity activated';
 exception when raise_exception then
   if sqlerrm <> 'Identitas tidak dapat diaktifkan.' then raise; end if;
 end;
end $$;
select set_config('request.jwt.claim.sub','20000000-0000-4000-8000-000000000002',true);
do $$ begin
 if (select count(*) from public.student_registry) <> 1 then raise exception 'Member registry isolation failed'; end if;
 if exists(select 1 from public.profiles where id <> auth.uid()) then raise exception 'Profile leak'; end if;
 begin
   insert into public.books(title,author,category) values ('Unauthorized','Test','Test');
   raise exception 'Member inventory write allowed';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
