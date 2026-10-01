# Serah-terima proyek Perpus

Dokumen ini merangkum konteks agar pekerjaan dapat dilanjutkan dari akun/sesi lain. Diperbarui 1 Oktober 2026.

## Tujuan dan batasan

- Proyek aplikasi perpustakaan Flutter dalam monorepo, backend Supabase self-hosted.
- README.md adalah PRD. Pertahankan layout demo yang sudah dipresentasikan.
- Jangan reset database nyata, jangan seed data nyata, jangan edit migrasi yang sudah diterapkan, jangan ekspos rahasia.
- Pemeriksaan server pada tahap ini harus read-only. Jika menguji integrasi, gunakan Supabase disposable dengan data sintetis.
- Dokumentasikan perubahan dan hasil verifikasi di `docs/analysis/`.

## Hasil terkini

- Baseline dan full verifier setelah perubahan lulus: Flutter analyze, 7 widget tests, 9 data-access tests, SQL/PGlite.
- Migrasi baru `supabase/migrations/202609300003_inventory_lock_protocol.sql` menyamakan urutan lock buku lalu eksemplar untuk approval, arsip, stok, dan pinjaman kelas.
- Regression PostgreSQL 18 dua koneksi: race approval/archive direproduksi sebelum fix (`borrowed` sekaligus terarsip); setelah fix, archive menolak; dua approval pada copy sama hanya menghasilkan satu pinjaman; multi-item urutan berbeda selesai atomik tanpa deadlock.
- Pesan timeout signup sudah menyebut hasil belum diketahui; tidak ada retry otomatis atau endpoint lookup identitas publik.
- Bukti utama: `docs/analysis/verification-2026-09-30.md`.
- Log: `baseline-2026-09-30.log`, `verification-after-fixes-2026-09-30.log`, `postgres-before-fix-2026-09-30.log`, `postgres-after-fix-2026-09-30.log` di folder ini.

## Blocker dan pekerjaan berikutnya

1. **Aturan claim siswa belum dipilih. Jangan ubah policy/migrasi claim sebelum pengguna memilih.** Pilihan yang ditanyakan:
   - lepaskan claim otomatis saat akun ditolak agar siswa dapat daftar ulang;
   - tahan claim sampai pengurus melepas;
   - pertahankan akun yang sama dan minta siswa menghubungi pengurus.
   Aturan pendaftaran pending kedua atas siswa yang sama juga perlu disepakati.
2. **Supabase aktif sudah diperiksa read-only melalui Cloudflare SSH.** Archive, covers, classroom loans, serta bucket evidence ditemukan. Verifier FAIL karena migrasi `202609300003_inventory_lock_protocol.sql` belum aktif; RPC lock/add copies belum ada dan hak tulis lama masih tersisa. Tidak ada perubahan server yang dilakukan. Lihat [bukti 1 Oktober](verification-2026-10-01.md).
3. **Integrasi Auth/RLS/RPC/Storage nyata BLOCKED.** Runner aman sudah ada di `scripts/supabase-integration`, tetapi masih memerlukan Supabase disposable, anon key, service-role khusus uji, dan marker environment. Jangan gunakan kredensial production.
4. Setelah environment tersedia: terapkan seluruh migrasi hanya pada stack disposable, jalankan runner, lalu simpan bukti. Penerapan migrasi lock ke server aktif harus memakai review dan rencana perubahan terpisah.

## Cara mengulang verifikasi lokal

- `scripts/verify.ps1`
- `scripts/postgres-concurrency/run.ps1`
- Regression sebelum fix: `scripts/postgres-concurrency/run.ps1 -BeforeFix` (diharapkan gagal assertion approval/archive).

## Navigasi

- Indeks: `docs/analysis/README.md`
- Status implementasi: `docs/implementation-status.md`
- Rincian audit per topik: `docs/analysis/01-*.md` sampai `07-*.md`
