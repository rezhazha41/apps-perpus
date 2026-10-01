import assert from 'node:assert/strict';
import test from 'node:test';

import { loadIntegrationConfig, redactErrorText } from './lib/config.mjs';

const baseEnv = {
  PERPUS_TEST_CONFIRM: 'isolated-disposable',
  PERPUS_TEST_SUPABASE_URL: 'http://127.0.0.1:54321',
  PERPUS_TEST_ANON_KEY: 'anon-test-key',
  PERPUS_TEST_SERVICE_ROLE_KEY: 'service-role-test-key',
};

test('requires an explicit disposable-environment confirmation', () => {
  assert.throws(
    () => loadIntegrationConfig({ ...baseEnv, PERPUS_TEST_CONFIRM: '' }),
    /PERPUS_TEST_CONFIRM=isolated-disposable/,
  );
});

test('always refuses the active Perpus production hostname', () => {
  assert.throws(
    () => loadIntegrationConfig({
      ...baseEnv,
      PERPUS_TEST_SUPABASE_URL: 'https://sup.tunneladguard.xyz',
      PERPUS_TEST_REMOTE_ISOLATED: 'yes',
    }),
    /refuses the active Perpus server/i,
  );
});

test('requires an extra confirmation for a remote isolated stack', () => {
  assert.throws(
    () => loadIntegrationConfig({
      ...baseEnv,
      PERPUS_TEST_SUPABASE_URL: 'https://supabase-test.example.invalid',
    }),
    /PERPUS_TEST_REMOTE_ISOLATED=yes/,
  );
});

test('accepts a local disposable stack and normalizes its base URL', () => {
  const config = loadIntegrationConfig({
    ...baseEnv,
    PERPUS_TEST_SUPABASE_URL: 'http://localhost:54321/',
  });

  assert.equal(config.baseUrl, 'http://localhost:54321');
  assert.equal(config.anonKey, baseEnv.PERPUS_TEST_ANON_KEY);
  assert.equal(config.serviceRoleKey, baseEnv.PERPUS_TEST_SERVICE_ROLE_KEY);
});

test('redacts configured keys and bearer tokens from error text', () => {
  const text = redactErrorText(
    `key=${baseEnv.PERPUS_TEST_SERVICE_ROLE_KEY} Authorization: Bearer abc.def.ghi`,
    [baseEnv.PERPUS_TEST_SERVICE_ROLE_KEY],
  );

  assert.doesNotMatch(text, /service-role-test-key|abc\.def\.ghi/);
  assert.match(text, /\[REDACTED\]/);
});
