import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';

import { loadIntegrationConfig, redactErrorText } from './lib/config.mjs';
import { apiRequest, restInsert, rpc } from './lib/http.mjs';

const config = loadIntegrationConfig();
const secrets = [config.anonKey, config.serviceRoleKey];
const runId = `${Date.now()}-${randomBytes(3).toString('hex')}`;
const password = `Perpus-${randomBytes(12).toString('base64url')}!9a`;
const log = (name, status, detail = '') => {
  process.stdout.write(`${status.padEnd(7)} ${name}${detail ? ` - ${detail}` : ''}\n`);
};

async function createAuthUser(email, metadata = undefined) {
  const body = { email, password, email_confirm: true };
  if (metadata) body.user_metadata = metadata;
  const response = await apiRequest(config, '/auth/v1/admin/users', {
    service: true,
    method: 'POST',
    body,
  });
  assert.ok(response.data.id, 'Admin Auth API did not return a user id.');
  return response.data;
}

async function signUpMember(email, identityKind, identityNumber) {
  const response = await apiRequest(config, '/auth/v1/signup', {
    method: 'POST',
    body: {
      email,
      password,
      data: {
        account_kind: 'member',
        identity_kind: identityKind,
        identity_number: identityNumber,
        contact: `synthetic-${runId}`,
      },
    },
  });
  assert.ok(response.data.user?.id, 'Signup did not return a user id.');
  await apiRequest(config, `/auth/v1/admin/users/${response.data.user.id}`, {
    service: true,
    method: 'PUT',
    body: { email_confirm: true },
  });
  return response.data.user;
}

async function login(email) {
  const response = await apiRequest(config, '/auth/v1/token?grant_type=password', {
    method: 'POST',
    body: { email, password },
  });
  assert.ok(response.data.access_token, `Login failed for ${email}.`);
  return response.data.access_token;
}

async function list(path, token) {
  const response = await apiRequest(config, path, { token });
  assert.ok(Array.isArray(response.data), `${path} did not return a row array.`);
  return response.data;
}

async function main() {
  log('safety guard', 'PASS', `disposable run ${runId}`);

  // Preflight fails before creating synthetic data when required migrations are absent.
  const preflight = await apiRequest(config, '/rest/v1/rpc/add_book_copies', {
    service: true,
    method: 'POST',
    body: { p_book_id: randomUUID(), p_codes: ['PREFLIGHT'] },
    allowStatus: [400, 404],
  });
  assert.notEqual(preflight.status, 404, 'Migration 202609300003_inventory_lock_protocol.sql is missing.');
  log('inventory-lock migration preflight', 'PASS');

  const invalidSignup = await apiRequest(config, '/auth/v1/signup', {
    method: 'POST',
    body: {
      email: `invalid-${runId}@example.invalid`,
      password,
      data: { account_kind: 'member', identity_kind: 'nis', identity_number: `999${Date.now()}` },
    },
    allowStatus: [400, 422, 500],
  });
  assert.equal(invalidSignup.ok, false, 'A random student identity unexpectedly registered.');
  log('random NIS signup rejected', 'PASS');

  const adminEmail = `admin-${runId}@example.invalid`;
  const memberAEmail = `member-a-${runId}@example.invalid`;
  const memberBEmail = `member-b-${runId}@example.invalid`;
  const adminUser = await createAuthUser(adminEmail);
  const staff = await restInsert(config, 'staff_registry', {
    staff_no: `TEST-${runId}`,
    full_name: 'Admin Uji Perpus',
    position: 'Pengurus Perpustakaan',
    active: true,
    linked_user_id: adminUser.id,
    email: adminEmail,
  }, { service: true });
  await restInsert(config, 'profiles', {
    id: adminUser.id,
    claimed_student_id: null,
    staff_id: staff.id,
    role: 'admin',
    status: 'active',
    contact: 'synthetic integration test',
  }, { service: true });

  const nisA = `81${String(Date.now()).slice(-8)}1`;
  const nisB = `82${String(Date.now()).slice(-8)}2`;
  const studentA = await restInsert(config, 'student_registry', {
    nis: nisA,
    full_name: 'Anggota Uji A',
    class_name: 'X UJI A',
    active: true,
  }, { service: true });
  const studentB = await restInsert(config, 'student_registry', {
    nis: nisB,
    full_name: 'Anggota Uji B',
    class_name: 'X UJI B',
    active: true,
  }, { service: true });
  const memberA = await signUpMember(memberAEmail, 'nis', nisA);
  const memberB = await signUpMember(memberBEmail, 'nis', nisB);
  const adminToken = await login(adminEmail);
  await rpc(config, 'review_member', {
    p_user_id: memberA.id,
    p_approve: true,
    p_reason: null,
  }, { token: adminToken });
  await rpc(config, 'review_member', {
    p_user_id: memberB.id,
    p_approve: true,
    p_reason: null,
  }, { token: adminToken });
  const memberAToken = await login(memberAEmail);
  const memberBToken = await login(memberBEmail);
  log('GoTrue signup, confirmation, approval, login', 'PASS');

  const anonRegistry = await apiRequest(config, '/rest/v1/student_registry?select=id', {
    allowStatus: [401, 403],
  });
  assert.equal(anonRegistry.ok, false, 'Anon unexpectedly read student_registry.');
  const aProfiles = await list('/rest/v1/profiles?select=id', memberAToken);
  assert.deepEqual(aProfiles.map((row) => row.id), [memberA.id]);
  const aCannotSeeB = await list(
    `/rest/v1/student_registry?select=id&id=eq.${encodeURIComponent(studentB.id)}`,
    memberAToken,
  );
  assert.equal(aCannotSeeB.length, 0, 'Member A can read member B registry row.');
  const adminMembers = await list(
    `/rest/v1/profiles?select=id&id=in.(${memberA.id},${memberB.id})`,
    adminToken,
  );
  assert.equal(adminMembers.length, 2, 'Admin cannot read both synthetic member profiles.');
  log('anon/member/admin RLS separation', 'PASS');

  await apiRequest(config, '/rest/v1/library_settings?id=eq.true', {
    token: adminToken,
    method: 'PATCH',
    body: { policy_confirmed: true, evidence_retention: '7_days', max_books: 3 },
  });
  const book = await restInsert(config, 'books', {
    title: `Buku Integrasi ${runId}`,
    author: 'Tim Uji',
    category: 'Pengujian',
    description: 'Data sintetis pada stack disposable',
  }, { token: adminToken });
  const copyCode = `TEST-${runId}`;
  await rpc(config, 'add_book_copies', {
    p_book_id: book.id,
    p_codes: [copyCode],
  }, { token: adminToken });
  const copies = await list(
    `/rest/v1/book_copies?select=id,code,status&code=eq.${encodeURIComponent(copyCode)}`,
    adminToken,
  );
  assert.equal(copies.length, 1);
  const copy = copies[0];

  const idempotencyKey = randomUUID();
  const evidencePath = `${memberA.id}/${idempotencyKey}.jpg`;
  // Minimal JPEG markers; Storage validates configured MIME and size at this boundary.
  const jpeg = Uint8Array.from([0xff, 0xd8, 0xff, 0xd9]);
  await apiRequest(config, `/storage/v1/object/loan-evidence/${evidencePath}`, {
    token: memberAToken,
    method: 'POST',
    body: jpeg,
    headers: { 'Content-Type': 'image/jpeg', 'x-upsert': 'false' },
  });
  const ownEvidence = await apiRequest(
    config,
    `/storage/v1/object/authenticated/loan-evidence/${evidencePath}`,
    { token: memberAToken, expect: 'bytes' },
  );
  assert.ok(ownEvidence.data.length > 0);
  const crossEvidence = await apiRequest(
    config,
    `/storage/v1/object/authenticated/loan-evidence/${evidencePath}`,
    { token: memberBToken, expect: 'bytes', allowStatus: [400, 401, 403, 404] },
  );
  assert.equal(crossEvidence.ok, false, 'Member B unexpectedly read member A evidence.');
  const adminEvidence = await apiRequest(
    config,
    `/storage/v1/object/authenticated/loan-evidence/${evidencePath}`,
    { token: adminToken, expect: 'bytes' },
  );
  assert.ok(adminEvidence.data.length > 0);
  log('private Storage owner/cross-member/admin access', 'PASS');

  const submitted = await rpc(config, 'submit_loan_request', {
    p_idempotency_key: idempotencyKey,
    p_copy_ids: [copy.id],
    p_evidence_method: 'student_card',
    p_evidence_path: evidencePath,
  }, { token: memberAToken });
  const requestId = typeof submitted.data === 'string'
    ? submitted.data
    : submitted.data;
  assert.match(requestId, /^[0-9a-f-]{36}$/i);
  await rpc(config, 'review_loan_request', {
    p_request_id: requestId,
    p_approve: true,
    p_reason: null,
  }, { token: adminToken });
  const aLoans = await list(`/rest/v1/loans?select=id,member_id&request_id=eq.${requestId}`, memberAToken);
  assert.equal(aLoans.length, 1);
  const bLoans = await list(`/rest/v1/loans?select=id&request_id=eq.${requestId}`, memberBToken);
  assert.equal(bLoans.length, 0, 'Member B unexpectedly read member A loan.');
  const finalCopies = await list(`/rest/v1/book_copies?select=status&id=eq.${copy.id}`, adminToken);
  assert.equal(finalCopies[0]?.status, 'borrowed');
  log('loan request and atomic approval through RPC', 'PASS');

  log('isolated Supabase integration', 'PASS', 'synthetic data intentionally retained in disposable stack');
}

main().catch((error) => {
  const safe = redactErrorText(error?.stack ?? error, secrets);
  process.stderr.write(`FAIL    isolated Supabase integration - ${safe}\n`);
  process.exitCode = 1;
});
