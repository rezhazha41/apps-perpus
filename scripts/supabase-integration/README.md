# Supabase integration test (disposable only)

Runner ini menguji GoTrue, RLS/RPC, dan Storage privat memakai data sintetis. Runner **tidak boleh** diarahkan ke server Perpus aktif dan sengaja tidak membersihkan data karena targetnya harus berupa stack disposable.

## Guard wajib

- `PERPUS_TEST_CONFIRM=isolated-disposable`
- `PERPUS_TEST_SUPABASE_URL`
- `PERPUS_TEST_ANON_KEY`
- `PERPUS_TEST_SERVICE_ROLE_KEY`
- `PERPUS_TEST_REMOTE_ISOLATED=yes` bila stack uji bukan localhost

Hostname aktif `sup.tunneladguard.xyz` selalu ditolak. Key hanya dibaca dari environment dan disensor dari error. Jangan menyimpan nilai key di file proyek atau log.

## Prasyarat

1. Gunakan Supabase terpisah yang boleh dibuang seluruhnya.
2. Terapkan semua migrasi sesuai `supabase/MIGRATIONS.md`, termasuk migrasi lock inventaris dan claim/pemulihan.
3. Deploy `supabase/functions/account-recovery` pada stack disposable sesuai README fungsi.
4. Pastikan GoTrue, PostgREST, Storage, dan Edge Function dapat diakses melalui URL uji.
5. Jalankan `npm test` untuk menguji guard lokal.
6. Jalankan `npm run integration` setelah semua environment variable terpasang.

## Cakupan runtime

- identitas NIS acak ditolak;
- signup, konfirmasi, persetujuan, dan login anggota A/B;
- pemisahan anon, anggota A, anggota B, dan admin melalui RLS;
- upload/read bukti privat serta penolakan akses lintas anggota;
- peminjaman langsung melalui RPC baru, status aktif, idempotensi, dan perubahan status QR buku.
- penolakan claim kedua, pelepasan claim setelah penolakan, dan pengajuan ulang akun yang sama;
- penerbitan serta penukaran kode pemulihan, kegagalan kata sandi lama, keberhasilan kata sandi baru, dan penolakan reuse kode.

Data memakai alamat `example.invalid` dan penanda unik per run. Bukti concurrency dua koneksi tetap berasal dari `scripts/postgres-concurrency/run.ps1`.

## Staff approval flow ? 6 October 2026

Apply migrations through `202610060001_staff_approval_required.sql` in the disposable stack before running. The runner expects direct borrowing to be denied, pending requests to preserve stock, member review to fail, and admin approval to create a staff-approved loan. Previous self-service test results describe the historical flow only. No active-server execution is authorized by this test runner.
