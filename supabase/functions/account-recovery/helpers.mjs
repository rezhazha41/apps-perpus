const CODE_ALPHABET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

export function normalizeRecoveryCode(value) {
  return String(value ?? '').toUpperCase().replace(/[^A-Z0-9]/g, '');
}

export function generateRecoveryCode(randomValues = crypto.getRandomValues.bind(crypto)) {
  const bytes = new Uint8Array(12);
  randomValues(bytes);
  const raw = Array.from(bytes, (value) => CODE_ALPHABET[value % CODE_ALPHABET.length]).join('');
  return `${raw.slice(0, 4)}-${raw.slice(4, 8)}-${raw.slice(8)}`;
}

export async function sha256Hex(value) {
  const bytes = new TextEncoder().encode(String(value));
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('');
}

export function recoveryInputError({ challengeId, code, password }) {
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(String(challengeId ?? ''))) {
    return 'ID pemulihan tidak valid.';
  }
  if (normalizeRecoveryCode(code).length !== 12) return 'Kode pemulihan tidak valid.';
  if (typeof password !== 'string' || password.length < 8 || password.length > 128) {
    return 'Kata sandi harus terdiri dari 8–128 karakter.';
  }
  return null;
}
