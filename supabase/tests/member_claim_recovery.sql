-- Claim and recovery policy fixtures are synthetic and always rolled back.
begin;

insert into public.student_registry(id,nis,full_name,class_name) values
 ('91000000-0000-4000-8000-000000000001','771001','Claim Test','X UJI');

insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at) values
 ('92000000-0000-4000-8000-000000000001','claim-a@example.invalid',
  '{"account_kind":"member","identity_kind":"nis","identity_number":"771001"}',now());

do $$ begin
  begin
    insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at) values
     ('92000000-0000-4000-8000-000000000002','claim-b@example.invalid',
      '{"account_kind":"member","identity_kind":"nis","identity_number":"771001"}',now());
    raise exception 'Second pending claim accepted';
  exception when raise_exception then
    if sqlerrm <> 'Pendaftaran tidak dapat diproses. Hubungi admin perpustakaan.' then raise; end if;
  end;
end $$;

-- Build an active admin fixture without client-side role escalation.
insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at) values
 ('92000000-0000-4000-8000-000000000009','claim-admin@example.invalid','{}',now());
insert into public.staff_registry(id,full_name,linked_user_id) values
 ('93000000-0000-4000-8000-000000000009','Claim Admin','92000000-0000-4000-8000-000000000009');
insert into public.profiles(id,staff_id,role,status) values
 ('92000000-0000-4000-8000-000000000009','93000000-0000-4000-8000-000000000009','admin','active');

set local role authenticated;
select set_config('request.jwt.claim.sub','92000000-0000-4000-8000-000000000009',true);
select public.review_member('92000000-0000-4000-8000-000000000001',false,'Data perlu diperbaiki');
reset role;

-- Rejection releases the database claim, so a new signup can reserve it.
insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at) values
 ('92000000-0000-4000-8000-000000000002','claim-b@example.invalid',
  '{"account_kind":"member","identity_kind":"nis","identity_number":"771001"}',now());

set local role authenticated;
select set_config('request.jwt.claim.sub','92000000-0000-4000-8000-000000000001',true);
do $$ begin
  begin
    perform public.resubmit_member_application();
    raise exception 'Rejected account reclaimed an identity reserved by another pending account';
  exception when raise_exception then
    if sqlerrm <> 'Identitas sedang digunakan oleh pengajuan lain.' then raise; end if;
  end;
end $$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','92000000-0000-4000-8000-000000000009',true);
select public.review_member('92000000-0000-4000-8000-000000000002',false,'Gunakan akun sebelumnya');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','92000000-0000-4000-8000-000000000001',true);
select public.resubmit_member_application();
do $$ begin
  if not exists(select 1 from public.profiles where id=auth.uid() and status='pending'
      and rejection_reason is null and reviewed_at is null and reviewed_by is null) then
    raise exception 'Rejected account was not returned to pending';
  end if;
end $$;
reset role;

-- Recovery challenges are private from clients and consumed atomically.
set local role authenticated;
select set_config('request.jwt.claim.sub','92000000-0000-4000-8000-000000000001',true);
do $$ begin
  begin
    perform id from public.account_recovery_challenges;
    raise exception 'Member can read recovery challenges';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

set local role service_role;
do $$
declare
  challenge record;
  consumed record;
  reused record;
begin
  select * into challenge from public.issue_account_recovery_challenge(
    '92000000-0000-4000-8000-000000000009',
    '92000000-0000-4000-8000-000000000001',
    repeat('a',64),
    'new-mail@example.invalid'
  );
  if challenge.challenge_id is null or challenge.expires_at is null then
    raise exception 'Recovery challenge was not issued';
  end if;
  perform * from public.consume_account_recovery_challenge(challenge.challenge_id,repeat('b',64));
  select * into consumed from public.consume_account_recovery_challenge(
    challenge.challenge_id,repeat('a',64));
  if not consumed.success or consumed.user_id<>'92000000-0000-4000-8000-000000000001' then
    raise exception 'Valid recovery challenge was not consumed';
  end if;
  select * into reused from public.consume_account_recovery_challenge(
    challenge.challenge_id,repeat('a',64));
  if reused.success then raise exception 'Recovery challenge reused'; end if;
end;
$$;
reset role;

rollback;
