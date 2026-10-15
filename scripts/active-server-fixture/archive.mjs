import { apiRequest } from '../supabase-integration/lib/http.mjs';
import {
  ensureApply,
  loadFixtureConfig,
  patchRows,
  printError,
  selectRows,
} from './lib.mjs';

let config;
try {
  ensureApply();
  config = loadFixtureConfig();

  const students = await selectRows(config, 'student_registry', {
    select: 'id,linked_user_id,active',
    nis: `eq.${config.nis}`,
    full_name: `eq.${config.tag} AKUN SINTETIS`,
  });
  const books = await selectRows(config, 'books', {
    select: 'id,title,description,archived_at',
    title: `eq.${config.title}`,
  });
  if (students.length > 1 || books.length > 1 ||
      (books.length === 1 && books[0].description !== config.description) ||
      (students.length === 0 && books.length === 0)) {
    throw new Error('Fixture exact tidak ditemukan; archive dihentikan agar data nyata tidak tersentuh.');
  }

  const student = students[0] ?? null;
  const book = books[0] ?? null;
  const copies = book ? await selectRows(config, 'book_copies', {
      select: 'id,code,status,archived_at',
      book_id: `eq.${book.id}`,
    }) : [];
  if (copies.some((copy) => !config.qrCodes.includes(copy.code))) {
    throw new Error('Daftar QR fixture tidak cocok; archive dihentikan.');
  }
  if (copies.some((copy) => copy.status === 'borrowed')) {
    throw new Error('Masih ada QR fixture dipinjam. Selesaikan pengembalian sebelum archive.');
  }

  const profiles = student ? await selectRows(config, 'profiles', {
    select: 'id,status',
    claimed_student_id: `eq.${student.id}`,
    order: 'created_at.desc',
    limit: '1',
  }) : [];
  const accountId = student?.linked_user_id ?? profiles[0]?.id ?? null;
  const pending = accountId
    ? await selectRows(config, 'loan_requests', {
        select: 'id',
        member_id: `eq.${accountId}`,
        status: 'eq.pending',
      })
    : [];
  if (pending.length > 0) {
    throw new Error('Masih ada pengajuan pending. Tolak/batalkan melalui aplikasi sebelum archive.');
  }

  const archivedAt = new Date().toISOString();
  if (accountId) {
    await patchRows(config, 'profiles', { id: `eq.${accountId}` }, { status: 'inactive' });
  }
  if (book) {
    await patchRows(config, 'book_copies', { book_id: `eq.${book.id}` }, { archived_at: archivedAt });
    await patchRows(config, 'books', { id: `eq.${book.id}` }, { archived_at: archivedAt });
  }
  if (student) {
    await patchRows(config, 'student_registry', { id: `eq.${student.id}` }, { active: false });
  }
  if (accountId) {
    await apiRequest(config, `/auth/v1/admin/users/${accountId}`, {
      service: true,
      method: 'PUT',
      body: { ban_duration: '876000h' },
    });
  }

  process.stdout.write(`FIXTURE ARCHIVED\ntag=${config.tag}\narchived_at=${archivedAt}\n`);
} catch (error) {
  printError(error, config?.serviceRoleKey ?? process.env.PERPUS_ACTIVE_SERVICE_ROLE_KEY ?? '');
  process.exitCode = 1;
}
