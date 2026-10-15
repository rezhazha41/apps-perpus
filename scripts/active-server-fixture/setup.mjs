import { apiRequest } from '../supabase-integration/lib/http.mjs';
import {
  ensureApply,
  insertRow,
  loadFixtureConfig,
  patchRows,
  printError,
  requireUnused,
} from './lib.mjs';

let config;
try {
  ensureApply();
  config = loadFixtureConfig(process.env, { password: true });
  await requireUnused(config);

  const student = await insertRow(config, 'student_registry', {
    nis: config.nis,
    full_name: `${config.tag} AKUN SINTETIS`,
    class_name: `${config.tag} / UJI`,
  });
  const book = await insertRow(config, 'books', {
    title: config.title,
    author: `${config.tag} SINTETIS`,
    category: `${config.tag} / UJI`,
    description: config.description,
  });
  for (const code of config.qrCodes) {
    await insertRow(config, 'book_copies', { book_id: book.id, code });
  }

  const auth = await apiRequest(config, '/auth/v1/admin/users', {
    service: true,
    method: 'POST',
    body: {
      email: config.email,
      password: config.password,
      email_confirm: true,
      user_metadata: {
        account_kind: 'member',
        identity_kind: 'nis',
        identity_number: config.nis,
        contact: `fixture:${config.tag}`,
      },
    },
  });
  if (!auth.data?.id) throw new Error('Auth Admin API tidak mengembalikan user id.');

  const linked = await patchRows(config, 'student_registry', { id: `eq.${student.id}` }, {
    linked_user_id: auth.data.id,
  });
  const activated = await patchRows(config, 'profiles', { id: `eq.${auth.data.id}`, status: 'eq.pending' }, {
    status: 'active',
    reviewed_at: new Date().toISOString(),
  });
  if (linked.length !== 1 || activated.length !== 1) {
    throw new Error(`Aktivasi fixture tidak lengkap. Jalankan archive dengan tag ${config.tag} untuk merapikan data parsial.`);
  }

  process.stdout.write([
    'FIXTURE READY',
    `tag=${config.tag}`,
    `email=${config.email}`,
    `nis=${config.nis}`,
    `qr=${config.qrCodes.join(',')}`,
    'password=[tidak dicetak; gunakan nilai environment yang disepakati]',
  ].join('\n') + '\n');
} catch (error) {
  printError(error, config?.serviceRoleKey ?? process.env.PERPUS_ACTIVE_SERVICE_ROLE_KEY ?? '');
  process.exitCode = 1;
}
