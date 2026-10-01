import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

// PostgreSQL smoke tests without a server. Auth schema below is a fixture,
// not a replacement for integration tests against self-hosted Supabase.
const db = new PGlite();
try {
  await db.exec(`
    create role anon nologin;
    create role authenticated nologin;
    create role service_role nologin bypassrls;
    create schema auth;
    create schema storage;
    create table auth.users (
      id uuid primary key, email text,
      raw_user_meta_data jsonb default '{}', email_confirmed_at timestamptz
    );
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid;
    $$;
    create table storage.buckets (
      id text primary key,name text not null,public boolean not null,
      file_size_limit bigint,allowed_mime_types text[]
    );
    create table storage.objects (
      id uuid primary key default gen_random_uuid(),bucket_id text not null,
      name text not null,owner_id text not null,
      unique(bucket_id,name)
    );
    alter table storage.objects enable row level security;
    create function storage.foldername(name text) returns text[] language sql immutable as $$
      select case when array_length(string_to_array(name,'/'),1)>1
        then (string_to_array(name,'/'))[1:array_length(string_to_array(name,'/'),1)-1]
        else array[]::text[] end;
    $$;
    grant usage on schema auth to authenticated;
    grant execute on function auth.uid() to authenticated;
    grant usage on schema storage to authenticated;
    grant select,insert on storage.objects to authenticated;
    grant execute on function storage.foldername(text) to authenticated;
  `);
  const preflight = await readFile(new URL('../../supabase/preflight.sql', import.meta.url), 'utf8');
  await db.exec(preflight);
  const migration = await readFile(new URL('../../supabase/migrations/202609280001_identity_inventory.sql', import.meta.url), 'utf8');
  await db.exec(migration);
  const transactions = await readFile(new URL('../../supabase/migrations/202609280002_transactions.sql', import.meta.url), 'utf8');
  await db.exec(transactions);
  const adminOperations = await readFile(new URL('../../supabase/migrations/202609290001_staff_admin_operations.sql', import.meta.url), 'utf8');
  await db.exec(adminOperations);
  const staffInvites = await readFile(new URL('../../supabase/migrations/202609290002_staff_invites.sql', import.meta.url), 'utf8');
  await db.exec(staffInvites);
  const operatorProvisioning = await readFile(new URL('../../supabase/migrations/202609290003_operator_provisioned_auth_users.sql', import.meta.url), 'utf8');
  await db.exec(operatorProvisioning);
  const archiveBook = await readFile(new URL('../../supabase/migrations/202609290004_archive_book.sql', import.meta.url), 'utf8');
  await db.exec(archiveBook);
  const bookCovers = await readFile(new URL('../../supabase/migrations/202609300001_book_covers.sql', import.meta.url), 'utf8');
  await db.exec(bookCovers);
  const classroomLoans = await readFile(new URL('../../supabase/migrations/202609300002_classroom_loans.sql', import.meta.url), 'utf8');
  await db.exec(classroomLoans);
  const inventoryLockProtocol = await readFile(new URL('../../supabase/migrations/202609300003_inventory_lock_protocol.sql', import.meta.url), 'utf8');
  await db.exec(inventoryLockProtocol);
  const memberClaimRecovery = await readFile(new URL('../../supabase/migrations/202610010001_member_claim_recovery.sql', import.meta.url), 'utf8');
  await db.exec(memberClaimRecovery);
  const verification = await readFile(new URL('../../supabase/verify_migration.sql', import.meta.url), 'utf8');
  await db.exec(verification);
  const staffVerification = await readFile(new URL('../../supabase/verify_staff_admin.sql', import.meta.url), 'utf8');
  await db.exec(staffVerification);
  const tests = await readFile(new URL('../../supabase/tests/identity_inventory.sql', import.meta.url), 'utf8');
  await db.exec(tests.replace(/^\\set.*$/gm, ''));
  const transactionTests = await readFile(new URL('../../supabase/tests/transactions.sql', import.meta.url), 'utf8');
  await db.exec(transactionTests);
  const claimRecoveryTests = await readFile(new URL('../../supabase/tests/member_claim_recovery.sql', import.meta.url), 'utf8');
  await db.exec(claimRecoveryTests);
  console.log('PASS: identity/claim/recovery + transaction + staff/admin + invitation + operator-provisioned Auth + archive + covers + classroom + inventory-lock migrations; exclusive pending claim, rejection release, same-account resubmission, one-time recovery codes, archive behavior, class loan idempotency/partial/full return, request idempotency, approval, loss resolution, RLS isolation and evidence/cover-object access.');
  console.log('GoTrue transport, real Storage API, email delivery and multi-connection concurrency still require Supabase integration tests.');
} catch (error) {
  console.error(`FAIL: SQLSTATE ${error.code ?? 'unknown'}: ${error.message}`);
  if (error.where) console.error(error.where);
  throw error;
} finally {
  await db.close();
}
