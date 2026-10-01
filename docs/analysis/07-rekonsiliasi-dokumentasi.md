# Rekonsiliasi dokumentasi proyek

> **Pembaruan 30 September 2026:** klaim status server pada dokumen ini tetap historis sampai ledger migrasi diverifikasi ulang secara read-only. Akses tersebut BLOCKED; lihat [bukti verifikasi](verification-2026-09-30.md).

**Status:** audit read-only, 30 September 2026.

## Perbedaan

- README.md adalah PRD, tetapi pernyataan status/provisioning di bagian awal berpotensi tertinggal dari progres yang dilaporkan. Kriteria M1–M5 adalah target, bukan bukti test.
- docs/implementation-status.md mencatat fitur dan hasil analyze/build terdahulu. Audit ini tidak mengulang test/build tersebut.
- docs/architecture.md dan docs/self-hosted-supabase.md masih menyebut alur transaksi, evidence, scanner, atau integrasi tertentu belum tersedia, padahal source saat ini memiliki implementasi terkait.
- docs/database.md menyebut transaksi/M3 belum diterapkan, sementara implementation-status menyatakan transaksi, covers, dan classroom loans diterapkan. Database server tidak diperiksa dalam audit.
- README menyebut belum ada admin diprovision; percakapan pengguna menyebut akun admin sudah aktif dan menyetujui anggota. Perbarui setelah jalur dan keadaan server diverifikasi.

## Rekonsiliasi aman

1. Periksa skema dan migration ledger server secara read-only; jangan berasumsi dari dokumentasi.
2. Jangan menjalankan migration, seed, atau fixture pada data nyata.
3. Catat migration aktif beserta tanggal/bukti pemeriksaan tanpa secret.
4. Perbarui satu dokumen status kanonis, lalu selaraskan arsitektur, database, dan runbook.
5. Simpan hasil test baru terpisah dari klaim implementasi.
