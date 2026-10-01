\set ON_ERROR_STOP on
insert into public.student_registry(id,nis,full_name,class_name) values
 ('10000000-0000-4000-8000-000000000011','981101','Admin Test','Staff'),
 ('10000000-0000-4000-8000-000000000012','981102','Member A','X'),
 ('10000000-0000-4000-8000-000000000013','981103','Member B','XI');
insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at) values
 ('20000000-0000-4000-8000-000000000011','admin-test@fixture.invalid','{}',now()),
 ('20000000-0000-4000-8000-000000000012','member-a@fixture.invalid',
  '{"account_kind":"member","identity_kind":"nis","identity_number":"981102"}',now()),
 ('20000000-0000-4000-8000-000000000013','member-b@fixture.invalid',
  '{"account_kind":"member","identity_kind":"nis","identity_number":"981103"}',now());
insert into public.staff_registry(id,full_name,email,linked_user_id) values
 ('30000000-0000-4000-8000-000000000011','Admin Test','admin-test@fixture.invalid',
  '20000000-0000-4000-8000-000000000011');
insert into public.profiles(id,staff_id,role,status)
 values('20000000-0000-4000-8000-000000000011',
  '30000000-0000-4000-8000-000000000011','admin','active');
update public.student_registry set linked_user_id='20000000-0000-4000-8000-000000000012'
 where id='10000000-0000-4000-8000-000000000012';
update public.student_registry set linked_user_id='20000000-0000-4000-8000-000000000013'
 where id='10000000-0000-4000-8000-000000000013';
update public.profiles set status='active'
 where id in ('20000000-0000-4000-8000-000000000012',
              '20000000-0000-4000-8000-000000000013');
update public.library_settings set policy_confirmed=true,evidence_retention='7_days',
  loan_days=7,max_books=10 where id=true;
insert into public.books(id,title,author,category) values
 ('30000000-0000-4000-8000-000000000101','Race Archive','Test','Concurrency'),
 ('30000000-0000-4000-8000-000000000102','Race Approval','Test','Concurrency'),
 ('30000000-0000-4000-8000-000000000103','Multi A','Test','Concurrency'),
 ('30000000-0000-4000-8000-000000000104','Multi B','Test','Concurrency');
insert into public.book_copies(id,book_id,code) values
 ('40000000-0000-4000-8000-000000000101','30000000-0000-4000-8000-000000000101','RACE-ARCHIVE'),
 ('40000000-0000-4000-8000-000000000102','30000000-0000-4000-8000-000000000102','RACE-APPROVAL'),
 ('40000000-0000-4000-8000-000000000103','30000000-0000-4000-8000-000000000103','MULTI-A'),
 ('40000000-0000-4000-8000-000000000104','30000000-0000-4000-8000-000000000104','MULTI-B');
insert into storage.objects(bucket_id,name,owner_id) values
 ('loan-evidence','20000000-0000-4000-8000-000000000012/50000000-0000-4000-8000-000000000101.jpg',
  '20000000-0000-4000-8000-000000000012'),
 ('loan-evidence','20000000-0000-4000-8000-000000000013/50000000-0000-4000-8000-000000000105.jpg',
  '20000000-0000-4000-8000-000000000013'),
 ('loan-evidence','20000000-0000-4000-8000-000000000012/50000000-0000-4000-8000-000000000103.jpg',
  '20000000-0000-4000-8000-000000000012'),
 ('loan-evidence','20000000-0000-4000-8000-000000000013/50000000-0000-4000-8000-000000000104.jpg',
  '20000000-0000-4000-8000-000000000013'),
 ('loan-evidence','20000000-0000-4000-8000-000000000012/50000000-0000-4000-8000-000000000104.jpg',
  '20000000-0000-4000-8000-000000000012'),
 ('loan-evidence','20000000-0000-4000-8000-000000000013/50000000-0000-4000-8000-000000000106.jpg',
  '20000000-0000-4000-8000-000000000013');

set role authenticated;
select set_config('request.jwt.claim.sub','20000000-0000-4000-8000-000000000012',false);
select public.submit_loan_request('50000000-0000-4000-8000-000000000101',
  array['40000000-0000-4000-8000-000000000101'::uuid],'selfie',
  '20000000-0000-4000-8000-000000000012/50000000-0000-4000-8000-000000000101.jpg');
select public.submit_loan_request('50000000-0000-4000-8000-000000000103',
  array['40000000-0000-4000-8000-000000000102'::uuid],'selfie',
  '20000000-0000-4000-8000-000000000012/50000000-0000-4000-8000-000000000103.jpg');
select public.submit_loan_request('50000000-0000-4000-8000-000000000104',
  array['40000000-0000-4000-8000-000000000103'::uuid,
        '40000000-0000-4000-8000-000000000104'::uuid],'selfie',
  '20000000-0000-4000-8000-000000000012/50000000-0000-4000-8000-000000000104.jpg');
select set_config('request.jwt.claim.sub','20000000-0000-4000-8000-000000000013',false);
select public.submit_loan_request('50000000-0000-4000-8000-000000000105',
  array['40000000-0000-4000-8000-000000000102'::uuid],'selfie',
  '20000000-0000-4000-8000-000000000013/50000000-0000-4000-8000-000000000105.jpg');
select public.submit_loan_request('50000000-0000-4000-8000-000000000106',
  array['40000000-0000-4000-8000-000000000104'::uuid,
        '40000000-0000-4000-8000-000000000103'::uuid],'selfie',
  '20000000-0000-4000-8000-000000000013/50000000-0000-4000-8000-000000000106.jpg');
reset role;

create function public.test_pause_approval_update() returns trigger language plpgsql as $$
begin
  if old.status='available' and new.status='borrowed' then
    perform pg_sleep(1.5);
  end if;
  return new;
end;
$$;
create trigger test_pause_approval before update of status on public.book_copies
for each row execute function public.test_pause_approval_update();
