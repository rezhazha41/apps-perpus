# Checklist setup Supabase disposable — 17 Oktober 2026

Status tahap implementasi test M3: **BLOCKED**.

## Bukti environment saat audit

- `PERPUS_TEST_CONFIRM`: **UNSET**
- `PERPUS_TEST_SUPABASE_URL`: **UNSET**
- `PERPUS_TEST_ANON_KEY`: **UNSET**
- `PERPUS_TEST_SERVICE_ROLE_KEY`: **UNSET**
- `PERPUS_TEST_REMOTE_ISOLATED`: **UNSET**
- `.env` proyek: **tidak ada**
- Server aktif `sup.tunneladguard.xyz`: tidak digunakan dan tetap ditolak runner.

Runner berhenti pada guard sebelum membuat data apa pun karena `PERPUS_TEST_CONFIRM` belum diset. Jangan mengarahkan runner ke server aktif.

## Prasyarat yang harus disiapkan

- [ ] Docker Desktop aktif atau host Supabase disposable terpisah.
- [ ] Project Supabase disposable baru, boleh di-reset/dibuang, tidak berisi data siswa nyata.
- [ ] URL API hanya origin, misalnya `http://127.0.0.1:54321` atau hostname stack uji yang terisolasi.
- [ ] Publishable/anon key dan service-role key stack uji tersedia dari secret manager atau output lokal; jangan ditulis ke repository/log.
- [ ] Migrasi diterapkan sesuai urutan di `supabase/MIGRATIONS.md`.
- [ ] `supabase/verify_migration.sql` dan `supabase/verify_staff_admin.sql` lulus.
- [ ] Edge Function `account-recovery` dideploy pada stack uji bila pengujian recovery ikut dijalankan.
- [ ] Dua akun anggota sintetis, satu pengurus sintetis, satu buku sintetis, dan QR sintetis disiapkan.
- [ ] SMTP/konfirmasi email disposable tersedia untuk pengujian GoTrue.

## Environment sementara

> Set hanya pada terminal uji. Jangan commit atau menampilkan nilainya.

```powershell
$env:PERPUS_TEST_CONFIRM = 'isolated-disposable'
$env:PERPUS_TEST_SUPABASE_URL = 'http://127.0.0.1:54321'
$env:PERPUS_TEST_ANON_KEY = '<anon-key-stack-uji>'
$env:PERPUS_TEST_SERVICE_ROLE_KEY = '<service-role-key-stack-uji>'
# Wajib `yes` bila URL bukan localhost.
$env:PERPUS_TEST_REMOTE_ISOLATED = 'yes'
```

## Command setelah environment siap

```powershell
node --test scripts/supabase-integration/config.test.mjs scripts/active-server-fixture/lib.test.mjs
node scripts/supabase-integration/run.mjs
```

## Kriteria hasil

- **PASS:** request nyata ke GoTrue, PostgREST/RPC, dan Storage privat berhasil sesuai assertion.
- **FAIL:** assertion runtime gagal pada stack disposable; buat regression test minimal sebelum memperbaiki kode.
- **BLOCKED:** stack, key, SMTP, atau Edge Function belum tersedia.
- **NOT RUN:** kasus yang bergantung pada fitur yang belum disiapkan.

## Test M3 yang menunggu environment

- GoTrue: signup, konfirmasi email, login, reset password, session expired, timeout tanpa retry berulang.
- Storage: anggota A upload/read miliknya, anggota B ditolak, anon ditolak, pengurus sesuai policy.
- RPC: approval, return, classroom loan, stok kurang, idempotensi, dua permintaan bersamaan.

Tidak ada perubahan production code atau kebijakan backend pada tahap BLOCKED ini.
