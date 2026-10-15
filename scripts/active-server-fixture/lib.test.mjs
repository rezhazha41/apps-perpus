import assert from 'node:assert/strict';
import test from 'node:test';

import { ensureApply, loadFixtureConfig } from './lib.mjs';

const env = {
  PERPUS_ACTIVE_SUPABASE_URL: 'https://sup.example.test',
  PERPUS_ACTIVE_FIXTURE_CONFIRM: 'reviewed-active:sup.example.test',
  PERPUS_ACTIVE_SERVICE_ROLE_KEY: 'secret',
  PERPUS_FIXTURE_TAG: 'TEST-MGR-001',
  PERPUS_FIXTURE_NIS: '990001',
  PERPUS_FIXTURE_EMAIL: 'test-mgr-001@example.invalid',
  PERPUS_FIXTURE_PASSWORD: 'Test-password-123!',
};

test('requires manager confirmation tied to the exact active hostname', () => {
  assert.throws(() => loadFixtureConfig({ ...env, PERPUS_ACTIVE_FIXTURE_CONFIRM: 'yes' }), /reviewed-active/);
});

test('requires visibly synthetic identifiers', () => {
  assert.throws(() => loadFixtureConfig({ ...env, PERPUS_FIXTURE_TAG: 'MGR-001' }), /TEST-XXX/);
  assert.throws(() => loadFixtureConfig({ ...env, PERPUS_FIXTURE_EMAIL: 'boss@example.com' }), /alamat sintetis/);
});

test('builds exact markers and never accepts execution without --apply', () => {
  const config = loadFixtureConfig(env, { password: true });
  assert.deepEqual(config.qrCodes, ['TEST-MGR-001-QR-01', 'TEST-MGR-001-QR-02']);
  assert.throws(() => ensureApply([]), /Tidak ada perubahan/);
  assert.doesNotThrow(() => ensureApply(['--apply']));
});
