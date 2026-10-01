# Serah-terima proyek Perpus

Dokumen ini merangkum konteks agar pekerjaan dapat dilanjutkan dari akun/sesi lain. Diperbarui 1 Oktober 2026.

## Tujuan dan batasan

- Proyek aplikasi perpustakaan Flutter dalam monorepo, backend Supabase self-hosted.
- README.md adalah PRD. Pertahankan layout demo yang sudah dipresentasikan.
- Jangan reset database nyata, jangan seed data nyata, jangan edit migrasi yang sudah diterapkan, jangan ekspos rahasia.
- Pemeriksaan server pada tahap ini harus read-only. Jika menguji integrasi, gunakan Supabase disposable dengan data sintetis.
- Dokumentasikan perubahan dan hasil verifikasi di `docs/analysis/`.

## Hasil terkini

- Full verifier terbaru lulus: Flutter analyze, 9 widget tests, 10 data-access tests, SQL/PGlite, 7 guard tests integrasi, dan 4 helper tests Edge Function.
- Migrasi baru `supabase/migrations/202609300003_inventory_lock_protocol.sql` menyamakan urutan lock buku lalu eksemplar untuk approval, arsip, stok, dan pinjaman kelas.
- Regression PostgreSQL 18 dua koneksi: race approval/archive direproduksi sebelum fix (`borrowed` sekaligus terarsip); setelah fix, archive menolak; dua approval pada copy sama hanya menghasilkan satu pinjaman; multi-item urutan berbeda selesai atomik tanpa deadlock.
- Pesan timeout signup sudah menyebut hasil belum diketahui; tidak ada retry otomatis atau endpoint lookup identitas publik.
- Bukti utama: `docs/analysis/verification-2026-09-30.md`.
- Kebijakan claim sudah diputuskan dan diimplementasikan secara lokal: satu claim `pending`/`active` per siswa, penolakan melepas claim, dan pengajuan ulang memakai akun yang sama.
- Pemulihan akun tanpa akses email memakai verifikasi langsung pengurus dan kode sekali pakai 15 menit. Bukti: `docs/analysis/08-claim-dan-pemulihan-akun.md`.
- Preflight server aktif menemukan 0 kelompok claim ganda; tabel pemulihan dan indeks claim baru belum diterapkan.
- Log: `baseline-2026-09-30.log`, `verification-after-fixes-2026-09-30.log`, `postgres-before-fix-2026-09-30.log`, `postgres-after-fix-2026-09-30.log` di folder ini.

## Blocker dan pekerjaan berikutnya

1. **Supabase aktif sudah diperiksa read-only melalui Cloudflare SSH.** Archive, covers, classroom loans, serta bucket evidence ditemukan. Migrasi `202609300003_inventory_lock_protocol.sql` dan `202610010001_member_claim_recovery.sql` belum aktif. Tidak ada perubahan server yang dilakukan.
2. **Integrasi Auth/RLS/RPC/Storage/Edge Function nyata BLOCKED.** Runner aman sudah ada di `scripts/supabase-integration`, tetapi masih memerlukan Supabase disposable, anon key, service-role khusus uji, dan marker environment. Jangan gunakan kredensial production.
3. Setelah environment tersedia: terapkan seluruh migrasi dan deploy fungsi hanya pada stack disposable, jalankan runner, lalu simpan bukti. Penerapan ke server aktif harus memakai backup, review, dan rencana perubahan terpisah.

## Cara mengulang verifikasi lokal

- `scripts/verify.ps1`
- `scripts/postgres-concurrency/run.ps1`
- Regression sebelum fix: `scripts/postgres-concurrency/run.ps1 -BeforeFix` (diharapkan gagal assertion approval/archive).

## Navigasi

- Indeks: `docs/analysis/README.md`
- Status implementasi: `docs/implementation-status.md`
- Rincian audit per topik: `docs/analysis/01-*.md` sampai `07-*.md`
