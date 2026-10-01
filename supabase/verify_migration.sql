-- Read-only assertions for both identity/inventory and transactions migrations.
-- Runs in SQL Editor or psql after applying both migrations.
-- An exception means verification failed; do not assume success from table creation alone.
do $$
declare table_name text; table_id regclass;
begin
  foreach table_name in array array['student_registry','staff_registry','profiles','books',
    'book_copies','library_settings','audit_logs','loan_requests',
    'loan_request_items','transaction_evidence','loans','loan_items',
    'return_requests','return_request_items','loss_reports',
    'class_loan_sessions','class_loan_items','account_recovery_challenges'] loop
    table_id := to_regclass('public.' || table_name);
    if table_id is null then raise exception 'Missing table: %', table_name; end if;
    if not (select relrowsecurity from pg_class where oid = table_id) then
      raise exception 'RLS not enabled: %', table_name;
    end if;
    if has_table_privilege('anon', table_id, 'SELECT') or
      has_table_privilege('anon', table_id, 'INSERT') or
      has_table_privilege('anon', table_id, 'UPDATE') or
      has_table_privilege('anon', table_id, 'DELETE') then
      raise exception 'Unexpected anonymous access: %', table_name;
    end if;
  end loop;
  if has_column_privilege('authenticated','public.profiles','role','UPDATE') then
    raise exception 'Client can change profile role';
  end if;
  if has_table_privilege('authenticated','public.staff_registry','INSERT')
     or has_table_privilege('authenticated','public.staff_registry','UPDATE') then
    raise exception 'Client can provision or modify staff identities';
  end if;
  if has_column_privilege('authenticated','public.student_registry','linked_user_id','UPDATE') then
    raise exception 'Client can link identity directly';
  end if;
  if has_column_privilege('authenticated','public.book_copies','status','UPDATE') then
    raise exception 'Client can change stock directly';
  end if;
  if has_column_privilege('authenticated','public.book_copies','book_id','INSERT') or
     has_column_privilege('authenticated','public.book_copies','code','INSERT') then
    raise exception 'Client can add copies outside the inventory RPC';
  end if;
  if has_column_privilege('authenticated','public.books','archived_at','UPDATE') then
    raise exception 'Client can archive books outside the archive RPC';
  end if;
  if has_table_privilege('authenticated','public.loan_requests','INSERT') or
     has_table_privilege('authenticated','public.loan_requests','UPDATE') or
     has_table_privilege('authenticated','public.loan_requests','DELETE') then
    raise exception 'Client can write loan requests outside RPCs';
  end if;
  if has_table_privilege('authenticated','public.loan_items','INSERT') or
     has_table_privilege('authenticated','public.loan_items','UPDATE') or
     has_table_privilege('authenticated','public.loan_items','DELETE') then
    raise exception 'Client can write loans outside RPCs';
  end if;
  if not exists(select 1 from pg_trigger where tgrelid = 'auth.users'::regclass
    and tgname = 'perpus_new_auth_user' and tgenabled = 'O') then
    raise exception 'Auth trigger missing or disabled';
  end if;
  if to_regprocedure('public.review_member(uuid,boolean,text)') is null then
    raise exception 'review_member RPC missing';
  end if;
  if has_function_privilege('anon','public.review_member(uuid,boolean,text)','EXECUTE') then
    raise exception 'Anonymous role can call member review';
  end if;
  if to_regprocedure('public.resubmit_member_application()') is null or
     not has_function_privilege('authenticated','public.resubmit_member_application()','EXECUTE') or
     has_function_privilege('anon','public.resubmit_member_application()','EXECUTE') then
    raise exception 'Member resubmission RPC missing or grants invalid';
  end if;
  if not exists(select 1 from pg_indexes where schemaname='public'
      and indexname='profiles_one_open_member_claim'
      and indexdef ilike '%status%pending%active%') then
    raise exception 'Exclusive pending/active member claim index missing';
  end if;
  if has_table_privilege('authenticated','public.account_recovery_challenges','SELECT') or
     has_table_privilege('authenticated','public.account_recovery_challenges','INSERT') or
     has_table_privilege('anon','public.account_recovery_challenges','SELECT') then
    raise exception 'Recovery challenge table exposed to clients';
  end if;
  if to_regprocedure('public.issue_account_recovery_challenge(uuid,uuid,text,text)') is null or
     to_regprocedure('public.consume_account_recovery_challenge(uuid,text)') is null or
     to_regprocedure('public.revoke_member_sessions(uuid)') is null then
    raise exception 'Trusted recovery RPC missing';
  end if;
  if has_function_privilege('authenticated',
       'public.issue_account_recovery_challenge(uuid,uuid,text,text)','EXECUTE') or
     has_function_privilege('authenticated',
       'public.consume_account_recovery_challenge(uuid,text)','EXECUTE') or
     has_function_privilege('anon',
       'public.consume_account_recovery_challenge(uuid,text)','EXECUTE') then
    raise exception 'Trusted recovery RPC exposed to a client role';
  end if;
  if to_regprocedure('public.submit_loan_request(uuid,uuid[],text,text)') is null or
     to_regprocedure('public.review_loan_request(uuid,boolean,text)') is null or
     to_regprocedure('public.review_return_item(uuid,boolean,text,text)') is null or
     to_regprocedure('public.resolve_loss(uuid,text)') is null then
    raise exception 'Transaction RPC missing';
  end if;
  if has_function_privilege('anon','public.review_loan_request(uuid,boolean,text)','EXECUTE') or
     has_function_privilege('anon','public.review_return_item(uuid,boolean,text,text)','EXECUTE') or
     has_function_privilege('anon','public.resolve_loss(uuid,text)','EXECUTE') then
    raise exception 'Anonymous role can call a transaction RPC';
  end if;
  if to_regprocedure('public.archive_book(uuid)') is null or
     to_regprocedure('public.archive_available_copy(uuid)') is null then
    raise exception 'Archive RPC missing';
  end if;
  if to_regprocedure('public.add_book_copies(uuid,text[])') is null then
    raise exception 'Add book copies RPC missing';
  end if;
  if to_regprocedure('public.create_class_loan(uuid,text,text,text,timestamptz,uuid[])') is null or
     to_regprocedure('public.return_class_loan_copy(uuid,text)') is null then
    raise exception 'Classroom loan RPC missing';
  end if;
  if has_table_privilege('authenticated','public.class_loan_sessions','INSERT') or
     has_table_privilege('authenticated','public.class_loan_sessions','UPDATE') or
     has_table_privilege('authenticated','public.class_loan_items','INSERT') or
     has_table_privilege('authenticated','public.class_loan_items','UPDATE') then
    raise exception 'Client can write classroom loans outside RPCs';
  end if;
  if not exists(select 1 from storage.buckets where id='loan-evidence' and not public
      and file_size_limit=10485760 and allowed_mime_types @> array['image/jpeg','image/png']) then
    raise exception 'Private loan evidence bucket missing';
  end if;
  if not exists(select 1 from storage.buckets where id='book-covers' and public
      and file_size_limit=3145728 and allowed_mime_types @> array['image/jpeg','image/png']) then
    raise exception 'Public book cover bucket configuration missing';
  end if;
  if not exists(select 1 from pg_policy where polname='book_covers_admin_insert'
      and polrelid='storage.objects'::regclass) then
    raise exception 'Book cover upload policy missing';
  end if;
  if not has_function_privilege('authenticated',
      'private.current_user_is_eligible_member()','EXECUTE') or
     has_function_privilege('anon','private.current_user_is_eligible_member()','EXECUTE') then
    raise exception 'Current-user Storage eligibility helper grants invalid';
  end if;
  if (select count(*) from public.library_settings where id) <> 1 then
    raise exception 'Library settings row missing';
  end if;
end $$;

select 'PASS: identity/claim/recovery, inventory, archive/stock, transactions, classroom loans, Storage, RLS and RPC grants' as result;
select c.relname as table_name, c.relrowsecurity as rls_enabled,
  (select count(*) from pg_policy p where p.polrelid = c.oid) as policy_count
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname in ('student_registry','profiles','books',
  'book_copies','library_settings','audit_logs','loan_requests',
  'loan_request_items','transaction_evidence','loans','loan_items',
  'return_requests','return_request_items','loss_reports','class_loan_sessions',
  'class_loan_items','account_recovery_challenges') order by c.relname;
