import { apiRequest } from '../supabase-integration/lib/http.mjs';

const TAG_PATTERN = /^TEST-[A-Z0-9]+(?:-[A-Z0-9]+)*$/;

function required(env, name) {
  const value = env[name]?.trim();
  if (!value) throw new Error(`${name} wajib diisi.`);
  return value;
}

export function loadFixtureConfig(env = process.env, { password = false } = {}) {
  const rawUrl = required(env, 'PERPUS_ACTIVE_SUPABASE_URL');
  const url = new URL(rawUrl);
  if (url.protocol !== 'https:' || url.username || url.password || url.pathname !== '/' || url.search || url.hash) {
    throw new Error('PERPUS_ACTIVE_SUPABASE_URL harus berupa origin HTTPS tanpa path/query.');
  }
  const expectedConfirmation = `reviewed-active:${url.hostname.toLowerCase()}`;
  if (env.PERPUS_ACTIVE_FIXTURE_CONFIRM !== expectedConfirmation) {
    throw new Error(`Set PERPUS_ACTIVE_FIXTURE_CONFIRM=${expectedConfirmation} setelah manager menyetujui eksekusi.`);
  }

  const tag = required(env, 'PERPUS_FIXTURE_TAG').toUpperCase();
  if (!TAG_PATTERN.test(tag) || tag.length > 40) {
    throw new Error('PERPUS_FIXTURE_TAG harus TEST-XXX, huruf/angka/tanda minus, maksimal 40 karakter.');
  }
  const nis = required(env, 'PERPUS_FIXTURE_NIS');
  if (!/^\d{6,20}$/.test(nis)) throw new Error('PERPUS_FIXTURE_NIS harus 6-20 digit.');

  const email = required(env, 'PERPUS_FIXTURE_EMAIL').toLowerCase();
  if (!/^test[._+-][^@]+@[^@]+\.[^@]+$/.test(email)) {
    throw new Error('PERPUS_FIXTURE_EMAIL harus alamat sintetis dengan local-part diawali test-, test_, test+, atau test.');
  }

  const value = {
    baseUrl: url.origin,
    serviceRoleKey: required(env, 'PERPUS_ACTIVE_SERVICE_ROLE_KEY'),
    anonKey: '',
    tag,
    nis,
    email,
    title: `${tag} BUKU UJI`,
    description: `FIXTURE SINTETIS ${tag} - JANGAN DIGUNAKAN UNTUK DATA NYATA`,
    qrCodes: [`${tag}-QR-01`, `${tag}-QR-02`],
  };
  if (password) {
    value.password = required(env, 'PERPUS_FIXTURE_PASSWORD');
    if (value.password.length < 12) throw new Error('PERPUS_FIXTURE_PASSWORD minimal 12 karakter.');
  }
  return value;
}

export function ensureApply(argv = process.argv.slice(2)) {
  if (argv.length !== 1 || argv[0] !== '--apply') {
    throw new Error('Tidak ada perubahan. Jalankan ulang dengan satu argumen --apply setelah review manager.');
  }
}

function queryString(params) {
  return new URLSearchParams(params).toString();
}

export async function selectRows(config, table, params) {
  const response = await apiRequest(config, `/rest/v1/${table}?${queryString(params)}`, {
    service: true,
  });
  if (!Array.isArray(response.data)) throw new Error(`Respons ${table} bukan array.`);
  return response.data;
}

export async function insertRow(config, table, row) {
  const response = await apiRequest(config, `/rest/v1/${table}`, {
    service: true,
    method: 'POST',
    body: row,
    headers: { Prefer: 'return=representation' },
  });
  if (!Array.isArray(response.data) || response.data.length !== 1) {
    throw new Error(`Insert ${table} tidak mengembalikan tepat satu baris.`);
  }
  return response.data[0];
}

export async function patchRows(config, table, filters, body) {
  const response = await apiRequest(config, `/rest/v1/${table}?${queryString(filters)}`, {
    service: true,
    method: 'PATCH',
    body,
    headers: { Prefer: 'return=representation' },
  });
  if (!Array.isArray(response.data)) throw new Error(`Patch ${table} tidak mengembalikan array.`);
  return response.data;
}

export async function requireUnused(config) {
  const checks = await Promise.all([
    selectRows(config, 'student_registry', { select: 'id', nis: `eq.${config.nis}` }),
    selectRows(config, 'books', { select: 'id', title: `eq.${config.title}` }),
    selectRows(config, 'book_copies', { select: 'id', code: `in.(${config.qrCodes.join(',')})` }),
  ]);
  if (checks.some((rows) => rows.length > 0)) {
    throw new Error('Tag/NIS/QR fixture sudah ada. Gunakan tag dan NIS baru atau jalankan archive untuk fixture lama.');
  }
}

export function printError(error, secret) {
  const raw = String(error?.stack ?? error);
  const clean = secret ? raw.split(secret).join('[REDACTED]') : raw;
  process.stderr.write(`${clean}\n`);
}
