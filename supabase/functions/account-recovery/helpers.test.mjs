import assert from 'node:assert/strict';
import test from 'node:test';

import {
  generateRecoveryCode,
  normalizeRecoveryCode,
  recoveryInputError,
  sha256Hex,
} from './helpers.mjs';

test('normalizes a code without ambiguous separators', () => {
  assert.equal(normalizeRecoveryCode('abcd-efgh ijkl'), 'ABCDEFGHIJKL');
});

test('generates a grouped twelve-character code', () => {
  const code = generateRecoveryCode((bytes) => {
    bytes.fill(0);
    return bytes;
  });
  assert.equal(code, '2222-2222-2222');
});

test('hashes normalized codes using SHA-256', async () => {
  assert.equal(
    await sha256Hex('ABCDEFGHIJKL'),
    '922429ccdb7045d11143e2e3982a11afc11b537bf259d88d2425fa8806e86e78',
  );
});

test('validates challenge id, code, and password boundaries', () => {
  const valid = {
    challengeId: '123e4567-e89b-42d3-a456-426614174000',
    code: 'ABCD-EFGH-IJKL',
    password: 'kata-sandi-baru',
  };
  assert.equal(recoveryInputError(valid), null);
  assert.match(recoveryInputError({ ...valid, challengeId: 'bad' }), /ID/);
  assert.match(recoveryInputError({ ...valid, code: 'short' }), /Kode/);
  assert.match(recoveryInputError({ ...valid, password: 'short' }), /8/);
});
