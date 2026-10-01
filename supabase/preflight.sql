-- Read-only: run in Supabase Studio SQL Editor before the first migration.
-- Share the result tables, not database passwords or keys.
select current_database() as database_name, current_user as database_role,
  to_regclass('auth.users') is not null as supabase_auth_exists,
  to_regprocedure('auth.uid()') is not null as supabase_auth_uid_exists;

select schemaname, tablename from pg_catalog.pg_tables
where schemaname in ('public', 'private') order by schemaname, tablename;

select count(*) as existing_auth_accounts from auth.users;

select t.tgname as existing_auth_trigger
from pg_catalog.pg_trigger t
where t.tgrelid = 'auth.users'::regclass and not t.tgisinternal
order by t.tgname;

select name, to_regclass('public.' || name) is not null as already_exists
from unnest(array['student_registry','profiles','books','book_copies',
  'library_settings','audit_logs']) as name;
