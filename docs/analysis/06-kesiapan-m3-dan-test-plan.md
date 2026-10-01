# Kesiapan M3 dan test plan

> **Addendum 30 September 2026:** suite lokal PASS. Concurrency PostgreSQL dua koneksi PASS setelah migrasi lock baru; lihat [bukti verifikasi](verification-2026-09-30.md). Pemeriksaan Supabase aktif dan integrasi GoTrue/Storage BLOCKED.

Status pada bagian audit awal di bawah mencatat temuan sebelum tindak lanjut. Kondisi terbaru: race inventory diperbaiki dan diuji lokal; runner SQL sudah mencakup archive/covers/classroom/lock; verifier full PASS. Claim siswa menunggu keputusan aturan, sedangkan integrasi Supabase terisolasi dan pemeriksaan server aktif BLOCKED.

**Status:** audit read-only, 30 September 2026. Tidak ada test dijalankan ulang.

## Cakupan M3 yang terlihat

Migrasi dan aplikasi memiliki struktur untuk loan request, evidence metadata/bucket private, approval RPC, return request per item, pelaporan kehilangan, serta pinjaman pembelajaran. Ketersediaan kode tidak membuktikan integrasi server berhasil.

## Penghalang sebelum mengandalkan M3

1. Atasi race approval–archive dan buktikan dengan dua koneksi.
2. Putuskan aturan claim pending/daftar ulang siswa dan tambah test NIS/NISN.
3. Jalankan suite Flutter, data-access, dan SQL saat ini; simpan hasil.
4. Cocokkan migration/RLS/RPC aktif di server secara read-only.
5. Uji bucket evidence dengan Storage nyata pada Supabase terisolasi.

## Gap test saat ini

scripts/sql-tests/test.mjs menyiapkan Auth dan Storage sebagai fixture PGlite. Runner menyatakan GoTrue transport, Storage API, email, dan concurrency multi-koneksi memerlukan test integrasi. Runner yang diperiksa tidak memuat migrasi archive book, book covers, atau classroom loans. supabase/verify_migration.sql juga belum memeriksa resource classroom/covers.

scripts/verify.ps1 mendefinisikan Flutter analyze/test, data-access test, dan SQL runner; hasilnya tidak dijalankan ulang dalam audit.

## Test plan berurutan

### Lokal

- Jalankan scripts/verify.ps1 dan simpan hasil aktual.
- Tambahkan test auth untuk confirmation, login role salah, reset callback, dan timeout dengan hasil ambigu.
- Tambahkan fixture SQL claim pending ganda, reject/retry, activation race, direct-write denial, dan unique QR/code.
- Perluas runner/verifier agar archive, covers, dan classroom migrations ikut diperiksa.

### Supabase terisolasi dengan data sintetis

- Uji GoTrue signup, konfirmasi email, aktivasi/reject, reset, undangan staf, dan admin pertama.
- Uji RLS/RPC dengan anon, member A/B, dan admin.
- Uji Storage private evidence: upload pemilik, akses anggota lain ditolak, admin review, MIME/size, dan retensi.
- Uji dua koneksi untuk approval copy sama dan approval melawan archive.

### Perangkat

- Uji multi-QR, duplikat/tidak tersedia, pengajuan banyak eksemplar, dan status request.
- Uji partial lalu full return, kondisi baik/rusak, dan pengajuan ulang idempotent.
- Uji offline, timeout, app background/dispose, dan retry.

Gunakan identitas/data fiktif di environment uji. Jangan menjalankan fixture/seed pada database dengan data nyata.

## Langkah implementasi M3

1. **Fondasi:** selesaikan aturan claim pending dan race archive/approval, beserta regression test.
2. **Evidence privat:** sepakati MIME/size, path per-user dan idempotency key, upload/cleanup, akses admin, serta retensi.
3. **Pengajuan:** multi-select/scan, validasi copy, idempotency, status dan pesan anggota.
4. **Approval atomik:** lock order konsisten, batas pinjaman, approval ganda, dan policy aktif.
5. **Return parsial/penuh:** tiap item diproses sekali, status/condition konsisten, pinjaman ditutup setelah semua item selesai.
6. **Integrasi:** jalankan end-to-end di Supabase terisolasi dan simpan bukti sebelum penerapan terpisah.
