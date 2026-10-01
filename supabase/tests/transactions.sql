-- Transaction/RLS smoke tests against the local PGlite Supabase fixtures.
-- Test users, book copies and storage objects are fictional and rolled back.
begin;
insert into public.student_registry(id,nis,full_name,class_name) values
 ('10000000-0000-4000-8000-000000000011','991101','Test Admin','Staff'),
 ('10000000-0000-4000-8000-000000000012','991102','Test Member A','X'),
 ('10000000-0000-4000-8000-000000000013','991103','Test Member B','XI'),
 ('10000000-0000-4000-8000-000000000014','991104','Test Inactive','X');
insert into auth.users(id,email,raw_user_meta_data) values
 ('20000000-0000-4000-8000-000000000011','admin-tx@example.invalid','{"account_kind":"member","identity_kind":"nis","identity_number":"991101"}'),
 ('20000000-0000-4000-8000-000000000012','member-a@example.invalid','{"account_kind":"member","identity_kind":"nis","identity_number":"991102"}'),
 ('20000000-0000-4000-8000-000000000013','member-b@example.invalid','{"account_kind":"member","identity_kind":"nis","identity_number":"991103"}'),
 ('20000000-0000-4000-8000-000000000014','inactive@example.invalid','{"account_kind":"member","identity_kind":"nis","identity_number":"991104"}');
insert into public.staff_registry(id,full_name,linked_user_id) values
 ('30000000-0000-4000-8000-000000000011','Test Admin','20000000-0000-4000-8000-000000000011');
update public.profiles set role='admin',status='active',claimed_student_id=null,
  staff_id='30000000-0000-4000-8000-000000000011'
where id='20000000-0000-4000-8000-000000000011';
update public.student_registry set linked_user_id='20000000-0000-4000-8000-000000000012' where id='10000000-0000-4000-8000-000000000012';
update public.profiles set status='active' where id='20000000-0000-4000-8000-000000000012';
update public.student_registry set linked_user_id='20000000-0000-4000-8000-000000000013' where id='10000000-0000-4000-8000-000000000013';
update public.profiles set status='active' where id='20000000-0000-4000-8000-000000000013';
update public.student_registry set linked_user_id='20000000-0000-4000-8000-000000000014',active=false where id='10000000-0000-4000-8000-000000000014';
update public.profiles set status='inactive' where id='20000000-0000-4000-8000-000000000014';
update public.library_settings set policy_confirmed=true,evidence_retention='7_days',loan_days=7,max_books=3 where id=true;

insert into public.books(id,title,author,category) values
 ('30000000-0000-4000-8000-000000000011','Transaction Test','Test Author','Test'),
 ('30000000-0000-4000-8000-000000000012','Class Loan Test','Test Author','Test'),
 ('30000000-0000-4000-8000-000000000013','Archive Test','Test Author','Test');
insert into public.book_copies(id,book_id,code) values
 ('40000000-0000-4000-8000-000000000011','30000000-0000-4000-8000-000000000011','TX-001'),
 ('40000000-0000-4000-8000-000000000012','30000000-0000-4000-8000-000000000011','TX-002'),
 ('40000000-0000-4000-8000-000000000013','30000000-0000-4000-8000-000000000011','TX-003'),
 ('40000000-0000-4000-8000-000000000014','30000000-0000-4000-8000-000000000011','TX-004'),
 ('40000000-0000-4000-8000-000000000015','30000000-0000-4000-8000-000000000012','CLASS-001'),
 ('40000000-0000-4000-8000-000000000016','30000000-0000-4000-8000-000000000012','CLASS-002'),
 ('40000000-0000-4000-8000-000000000017','30000000-0000-4000-8000-000000000013','ARCHIVE-001');
insert into storage.objects(bucket_id,name,owner_id) values
 ('loan-evidence','20000000-0000-4000-8000-000000000012/50000000-0000-4000-8000-000000000011.jpg','20000000-0000-4000-8000-000000000012'),
 ('loan-evidence','20000000-0000-4000-8000-000000000013/50000000-0000-4000-8000-000000000012.jpg','20000000-0000-4000-8000-000000000013'),
 ('loan-evidence','20000000-0000-4000-8000-000000000013/50000000-0000-4000-8000-000000000013.jpg','20000000-0000-4000-8000-000000000013');

set local role authenticated;
do $$
declare
  request_a uuid;
  request_b uuid;
  request_after_loss uuid;
  loan_a uuid;
  loan_item_a uuid;
  loan_item_b uuid;
  return_request uuid;
  return_item uuid;
  report_id uuid;
  class_session uuid;
  class_item_a uuid;
  class_item_b uuid;
  class_retry uuid;
  visible_count integer;
begin
  perform set_config('request.jwt.claim.sub','20000000-0000-4000-8000-000000000012',true);
  request_a := public.submit_loan_request(
    '50000000-0000-4000-8000-000000000011',
    array['40000000-0000-4000-8000-000000000011'::uuid,'40000000-0000-4000-8000-000000000012'::uuid],
    'selfie','20000000-0000-4000-8000-000000000012/50000000-0000-4000-8000-000000000011.jpg');
  if request_a <> public.submit_loan_request(
    '50000000-0000-4000-8000-000000000011',
    array['40000000-0000-4000-8000-000000000012'::uuid,'40000000-0000-4000-8000-000000000011'::uuid],
    'selfie','20000000-0000-4000-8000-000000000012/50000000-0000-4000-8000-000000000011.jpg') then
    raise exception 'Loan request retry was not idempotent';
  end if;
  select count(*) into visible_count from public.loan_requests;
  if visible_count<>1 then raise exception 'Member A cannot read exactly own request'; end if;
  select count(*) into visible_count from storage.objects;
  if visible_count<>1 then raise exception 'Member A can read another member evidence object'; end if;
  insert into storage.objects(bucket_id,name,owner_id)
    values('loan-evidence','20000000-0000-4000-8000-000000000012/80000000-0000-4000-8000-000000000012.jpg',
      '20000000-0000-4000-8000-000000000012');
  begin
    insert into public.loan_requests(member_id,idempotency_key)
      values ('20000000-0000-4000-8000-000000000012',gen_random_uuid());
    raise exception 'Direct loan request insert was allowed';
  exception when insufficient_privilege then null; end;
  begin
    perform public.archive_available_copy('40000000-0000-4000-8000-000000000014');
    raise exception 'Member could archive inventory';
  exception when raise_exception then
    if sqlerrm<>'Akses admin diperlukan.' then raise; end if;
  end;

  perform set_config('request.jwt.claim.sub','20000000-0000-4000-8000-000000000013',true);
  request_b := public.submit_loan_request(
    '50000000-0000-4000-8000-000000000012',array['40000000-0000-4000-8000-000000000011'::uuid],
    'student_card','20000000-0000-4000-8000-000000000013/50000000-0000-4000-8000-000000000012.jpg');
  select count(*) into visible_count from public.loan_requests;
  if visible_count<>1 then raise exception 'Member B can read another member request'; end if;
  select count(*) into visible_count from public.transaction_evidence;
  if visible_count<>1 then raise exception 'Member B can read another member evidence metadata'; end if;

  perform set_config('request.jwt.claim.sub','20000000-0000-4000-8000-000000000011',true);
  perform public.archive_available_copy('40000000-0000-4000-8000-000000000014');
  if (select archived_at is null from public.book_copies where id='40000000-0000-4000-8000-000000000014') then
    raise exception 'Admin could not archive available copy';
  end if;
  begin
    insert into public.book_copies(book_id,code)
      values('30000000-0000-4000-8000-000000000012','DIRECT-INSERT');
    raise exception 'Admin inserted a copy outside the inventory RPC';
  exception when insufficient_privilege then null; end;
  begin
    update public.books set archived_at=now()
      where id='30000000-0000-4000-8000-000000000012';
    raise exception 'Admin archived a book outside the archive RPC';
  exception when insufficient_privilege then null; end;
  perform public.add_book_copies(
    '30000000-0000-4000-8000-000000000012',array['CLASS-003']);
  if not exists(select 1 from public.book_copies
      where book_id='30000000-0000-4000-8000-000000000012' and code='CLASS-003') then
    raise exception 'Authorized stock RPC did not add the copy';
  end if;
  perform public.review_loan_request(request_a,true,null);
  select id into loan_a from public.loans where request_id=request_a;
  select id into loan_item_a from public.loan_items where loan_id=loan_a and copy_id='40000000-0000-4000-8000-000000000011';
  select id into loan_item_b from public.loan_items where loan_id=loan_a and copy_id='40000000-0000-4000-8000-000000000012';
  begin
    perform public.review_loan_request(request_b,true,null);
    raise exception 'Same copy was approved to two members';
  exception when raise_exception then
    if sqlerrm='Same copy was approved to two members' then raise; end if;
    if sqlerrm<>'Satu atau beberapa buku sudah tidak tersedia.' then raise; end if;
  end;

  perform set_config('request.jwt.claim.sub','20000000-0000-4000-8000-000000000012',true);
  return_request := public.request_return('60000000-0000-4000-8000-000000000011',array[loan_item_a]);
  if return_request <> public.request_return('60000000-0000-4000-8000-000000000011',array[loan_item_a]) then
    raise exception 'Return request retry was not idempotent';
  end if;
  select id into return_item from public.return_request_items where return_request_id=return_request;
  perform set_config('request.jwt.claim.sub','20000000-0000-4000-8000-000000000011',true);
  perform public.review_return_item(return_item,true,'good',null);
  if (select status from public.book_copies where id='40000000-0000-4000-8000-000000000011')<>'available' then
    raise exception 'Received copy did not return to available stock';
  end if;
  if (select status from public.book_copies where id='40000000-0000-4000-8000-000000000012')<>'borrowed' then
    raise exception 'Partial return changed the copy not received';
  end if;
  if (select count(*) from public.loan_items where loan_id=loan_a and returned_at is null and resolved_at is null)<>1 then
    raise exception 'Partial return closed more than the received book';
  end if;
  perform public.review_loan_request(request_b,true,null);
  select li.id into loan_item_b from public.loan_items li join public.loans l on l.id=li.loan_id where l.request_id=request_b;

  perform set_config('request.jwt.claim.sub','20000000-0000-4000-8000-000000000013',true);
  report_id := public.report_loss('70000000-0000-4000-8000-000000000011',loan_item_b,'Buku tidak ditemukan setelah dibawa pulang.');
  perform set_config('request.jwt.claim.sub','20000000-0000-4000-8000-000000000011',true);
  perform public.review_loss_report(report_id,true,null);
  if (select status from public.book_copies where id='40000000-0000-4000-8000-000000000011')<>'lost' then
    raise exception 'Verified loss did not keep copy unavailable';
  end if;
  perform set_config('request.jwt.claim.sub','20000000-0000-4000-8000-000000000013',true);
  request_after_loss := public.submit_loan_request(
    '50000000-0000-4000-8000-000000000013',array['40000000-0000-4000-8000-000000000013'::uuid],
    'selfie','20000000-0000-4000-8000-000000000013/50000000-0000-4000-8000-000000000013.jpg');
  perform set_config('request.jwt.claim.sub','20000000-0000-4000-8000-000000000011',true);
  begin
    perform public.review_loan_request(request_after_loss,true,null);
    raise exception 'Unresolved loss did not block another loan';
  exception when raise_exception then
    if sqlerrm='Unresolved loss did not block another loan' then raise; end if;
    if sqlerrm<>'Selesaikan laporan kehilangan sebelum meminjam lagi.' then raise; end if;
  end;
  perform public.resolve_loss(report_id,'Sudah diganti dengan buku pengganti.');
  perform public.review_loan_request(request_after_loss,true,null);
  if (select status from public.book_copies where id='40000000-0000-4000-8000-000000000013')<>'borrowed' then
    raise exception 'Loan after loss resolution did not update inventory';
  end if;

  class_session := public.create_class_loan(
    '80000000-0000-4000-8000-000000000011','Guru Uji','X TKJ','Praktik jaringan',
    now()+interval '1 day',array[
      '40000000-0000-4000-8000-000000000015'::uuid,
      '40000000-0000-4000-8000-000000000016'::uuid]);
  class_retry := public.create_class_loan(
    '80000000-0000-4000-8000-000000000011','Guru Uji','X TKJ','Praktik jaringan',
    now()+interval '1 day',array[
      '40000000-0000-4000-8000-000000000015'::uuid,
      '40000000-0000-4000-8000-000000000016'::uuid]);
  if class_retry<>class_session then raise exception 'Class loan retry was not idempotent'; end if;
  if (select count(*) from public.class_loan_items where session_id=class_session)<>2 then
    raise exception 'Class loan did not create both copy items';
  end if;
  select id into class_item_a from public.class_loan_items
    where session_id=class_session and copy_id='40000000-0000-4000-8000-000000000015';
  select id into class_item_b from public.class_loan_items
    where session_id=class_session and copy_id='40000000-0000-4000-8000-000000000016';
  perform public.return_class_loan_copy(class_item_a,'damaged');
  if (select returned_at from public.class_loan_sessions where id=class_session) is not null then
    raise exception 'Partial classroom return closed the session early';
  end if;
  if (select status from public.book_copies where id='40000000-0000-4000-8000-000000000015')<>'damaged'
     or (select status from public.book_copies where id='40000000-0000-4000-8000-000000000016')<>'borrowed' then
    raise exception 'Partial classroom return changed the wrong copy status';
  end if;
  perform public.return_class_loan_copy(class_item_b,'good');
  if (select returned_at from public.class_loan_sessions where id=class_session) is null
     or (select status from public.book_copies where id='40000000-0000-4000-8000-000000000016')<>'available' then
    raise exception 'Full classroom return did not close session and restore stock';
  end if;

  perform public.archive_book('30000000-0000-4000-8000-000000000013');
  if (select archived_at from public.books where id='30000000-0000-4000-8000-000000000013') is null
     or (select archived_at from public.book_copies where id='40000000-0000-4000-8000-000000000017') is null then
    raise exception 'Book archive did not archive its available copy';
  end if;

  insert into storage.objects(bucket_id,name,owner_id)
    values('book-covers','admin/uploaded-cover.jpg','20000000-0000-4000-8000-000000000011');
  perform set_config('request.jwt.claim.sub','20000000-0000-4000-8000-000000000012',true);
  begin
    insert into storage.objects(bucket_id,name,owner_id)
      values('book-covers','forbidden/member-cover.jpg','20000000-0000-4000-8000-000000000012');
    raise exception 'Member was allowed to upload a book cover';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
