\set ON_ERROR_STOP on
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','20000000-0000-4000-8000-000000000011',true);
select public.review_loan_request((select id from public.loan_requests
  where member_id='20000000-0000-4000-8000-000000000012'
    and idempotency_key='50000000-0000-4000-8000-000000000104'),true,null);
commit;

