-- Read-only checks for 202609290001_staff_admin_operations.sql.
do $$
begin
  if to_regclass('public.staff_registry') is null then
    raise exception 'staff_registry is missing';
  end if;
  if not (select relrowsecurity from pg_class where oid='public.staff_registry'::regclass) then
    raise exception 'staff_registry RLS is disabled';
  end if;
  if has_table_privilege('authenticated','public.staff_registry','INSERT')
     or has_table_privilege('authenticated','public.staff_registry','UPDATE') then
    raise exception 'Authenticated clients can modify staff identities';
  end if;
  if has_column_privilege('authenticated','public.staff_registry','invite_token','SELECT') then
    raise exception 'Authenticated clients can read invitation tokens';
  end if;
  if not has_function_privilege('authenticated','public.archive_available_copy(uuid)','EXECUTE')
     or has_function_privilege('anon','public.archive_available_copy(uuid)','EXECUTE') then
    raise exception 'archive_available_copy grants are invalid';
  end if;
  if not exists (select 1 from pg_constraint where conname='profiles_identity_role_check'
                 and conrelid='public.profiles'::regclass) then
    raise exception 'Profiles identity-role constraint is missing';
  end if;
  if not has_function_privilege('authenticated','public.create_staff_invite(text,text,text,text)','EXECUTE')
     or has_function_privilege('anon','public.create_staff_invite(text,text,text,text)','EXECUTE') then
    raise exception 'Staff invitation RPC grants are invalid';
  end if;
end $$;

select json_build_object(
  'result','PASS: staff identity separation, admin linkage, RLS and archive RPC',
  'student_rows',(select count(*) from public.student_registry),
  'profiles',(select count(*) from public.profiles),
  'admins',(select count(*) from public.profiles where role='admin' and status='active')
);
