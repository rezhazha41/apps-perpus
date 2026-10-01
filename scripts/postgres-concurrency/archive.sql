\set ON_ERROR_STOP on
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','20000000-0000-4000-8000-000000000011',true);
select public.archive_book('30000000-0000-4000-8000-000000000101');
commit;

