# Analisis inventaris, arsip, dan QR

> **Addendum 30 September 2026:** race approval/archive sudah ditangani dengan migrasi baru dan diuji di PostgreSQL dua koneksi, termasuk approval pada copy yang sama dan item multi-book dalam urutan terbalik. Migrasi belum diverifikasi pada server aktif. Lihat [bukti verifikasi](verification-2026-09-30.md).

**Status:** audit read-only, 30 September 2026.

## Status

| Area | Status | Catatan |
|---|---|---|
| Model buku dan eksemplar | Terbukti statis | Copy terpisah dari judul buku; copy code unik. |
| Status available/borrowed/damaged/lost | Terbukti statis | Constraint status ada; write dibatasi lewat RPC. |
| QR unik per eksemplar | Terbukti statis | QR merepresentasikan kode copy. Konflik kode custom pada data aktual belum diuji. |
| Scan dan administrasi QR | Implementasi terlihat; perangkat belum diuji ulang | Ada UI pemindaian dan administrasi eksemplar. |
| Soft archive buku/copy | Implementasi ada; concurrency bermasalah | Archive dapat berlomba dengan approval pinjaman. |
| CRUD buku konsisten | Bermasalah sebagian | Buku, cover, dan copies dibuat lewat operasi terpisah. |

## Temuan P1: approval–archive tidak memiliki lock bersama

**Lokasi:** supabase/migrations/202609280002_transactions.sql, fungsi review_loan_request; supabase/migrations/202609290004_archive_book.sql, fungsi archive_book.

Review mengunci baris copy lalu memeriksa buku/copy belum diarsipkan. Archive mengunci buku, memeriksa apakah ada copy borrowed, lalu mengarsipkan copy dan buku. Kedua lock tidak memakai baris dan urutan yang sama, sehingga transaksi dapat melewati pemeriksaan masing-masing secara bersamaan.

**Dampak:** status akhir dapat tidak konsisten, misalnya pinjaman aktif pada buku/copy terarsip atau archive sukses saat approval sedang berjalan.

**Prioritas:** P1, penghalang sebelum approval M3 diandalkan. Perbaikan memerlukan urutan lock konsisten dan regression test PostgreSQL multi-koneksi.

## Temuan P2: tambah buku bisa gagal sebagian

**Lokasi:** apps/mobile/lib/features/server/server_shell.dart, fungsi _addBook.

Urutannya: insert buku, upload/update cover, lalu insert eksemplar. Jika langkah berikutnya gagal, langkah sebelumnya tidak otomatis rollback. Buku tanpa copy atau tanpa cover dapat tertinggal dan retry berisiko membuat data ganda.

## Test inventaris

- Kode copy otomatis/custom unik di seluruh katalog sesuai aturan normalisasi.
- QR tetap terikat ke copy dengan status tersedia, dipinjam, rusak, hilang, dan arsip.
- Member tidak dapat mengubah status copy langsung.
- Archive buku dengan copy borrowed harus ditolak.
- Approval dan archive bersamaan menghasilkan keadaan konsisten.
- Tambah/edit buku dipulihkan dengan aman saat upload cover atau insert copy gagal.
