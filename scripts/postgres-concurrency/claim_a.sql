\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at) values
 ('20000000-0000-4000-8000-000000000014','claim-race-a@fixture.invalid',
  '{"account_kind":"member","identity_kind":"nis","identity_number":"981104"}',now());
select pg_sleep(1.5);
commit;
