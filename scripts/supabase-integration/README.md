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
2. Terapkan semua migrasi sesuai `supabase/MIGRATIONS.md`, termasuk migrasi lock inventaris.
3. Pastikan GoTrue, PostgREST, dan Storage dapat diakses melalui URL uji.
4. Jalankan `npm test` untuk menguji guard lokal.
5. Jalankan `npm run integration` setelah semua environment variable terpasang.

## Cakupan runtime

- identitas NIS acak ditolak;
- signup, konfirmasi, persetujuan, dan login anggota A/B;
- pemisahan anon, anggota A, anggota B, dan admin melalui RLS;
- upload/read bukti privat serta penolakan akses lintas anggota;
- pengajuan pinjaman, persetujuan RPC, dan perubahan status QR buku.

Data memakai alamat `example.invalid` dan penanda unik per run. Bukti concurrency dua koneksi tetap berasal dari `scripts/postgres-concurrency/run.ps1`.
