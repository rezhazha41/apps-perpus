# Status implementasi — 1 Oktober 2026

## Addendum verifikasi 1 Oktober 2026

Akses server aktif secara read-only melalui Cloudflare SSH sudah PASS. Archive, cover, classroom loans, dan bucket bukti privat ditemukan, tetapi verifier FAIL karena migrasi protokol lock inventaris terbaru belum aktif. Kebijakan claim kini ditetapkan: satu claim menunggu/aktif per siswa, penolakan melepas claim, dan pengajuan ulang memakai akun yang sama. Pemulihan terbantu memakai verifikasi langsung pengurus serta kode sekali pakai 15 menit. Implementasi dan test lokal sudah tersedia; migrasi serta Edge Function belum diterapkan ke server aktif. Preflight server menemukan 0 kelompok claim ganda. Runner integrasi GoTrue/RLS/RPC/Storage/Edge Function menolak server aktif dan runtime tetap BLOCKED sampai tersedia stack Supabase disposable. Lihat [analisis claim dan pemulihan](analysis/08-claim-dan-pemulihan-akun.md).

## Addendum verifikasi 30 September 2026

Catatan historis: baseline lokal dan verifier setelah perubahan lulus. Regression concurrency approval/archive, approval ganda pada copy sama, dan urutan multi-item berbeda lulus pada PostgreSQL 18 sementara dua koneksi. Sebelum migrasi lock baru, test approval/archive mereproduksi copy `borrowed` sekaligus terarsip. Pada tanggal tersebut akses SSH dan keputusan claim masih BLOCKED; kondisi itu telah digantikan oleh addendum 1 Oktober di atas. Lihat [bukti verifikasi saat itu](analysis/verification-2026-09-30.md).

Catatan status historis di bawah bukan bukti kondisi server saat ini; klaim deployment perlu dikonfirmasi ulang sebelum penerapan.

Dokumen ini merangkum kondisi aplikasi untuk persiapan demo dan presentasi. Catatan tiap sesi perubahan ada di [progress-log.md](progress-log.md).

## Sudah tersedia

- **M1 — Demo:** aplikasi Flutter Android dengan susunan Dashboard, Buku, Aktivitas, dan Anggota untuk pengurus. Mode demo tetap terpisah dari data server.
- **M2 — Identitas dan katalog:** login/daftar anggota dengan NIS/NISN yang terdaftar, persetujuan aktivasi pengurus, pengelolaan anggota, CRUD buku, pengelolaan eksemplar, penyesuaian stok, dan arsip katalog lunak.
- **Claim anggota:** database membatasi satu akun menunggu/aktif per siswa. Penolakan melepas claim; anggota dapat memperbaiki dan mengajukan ulang menggunakan akun yang sama.
- **Pemulihan akses terbantu:** anggota yang tidak dapat membuka email dapat meminta pengurus memeriksa identitas fisik. Pengurus menerbitkan kode sekali pakai 15 menit; siswa memasukkan kode dan kata sandi baru tanpa endpoint pencarian identitas publik.
- **QR buku:** setiap eksemplar punya kode unik. Kode otomatis mengikuti kategori/judul; saat menambahkan buku pengurus dapat memberi awalan QR khusus. QR dapat ditampilkan dan dicetak satuan. Anggota dapat memindai QR dari aplikasi.
- **Sampul katalog:** pengurus dapat memilih gambar sampul saat menambah atau mengubah buku. Jika tidak memilih gambar, katalog mempertahankan ikon bawaan demo.
- **M3 — Peminjaman anggota:** pengajuan dengan bukti foto, persetujuan pengurus, riwayat pinjaman, permintaan pengembalian, dan pelaporan kehilangan. Aturan akses dan perubahan stok dijaga oleh Supabase.
- **Pengembalian pengurus:** pengurus dapat meninjau pengembalian per eksemplar serta mencatat kondisi baik/rusak.
- **Peminjaman pembelajaran:** menu Aktivitas → Pembelajaran membuat satu sesi untuk kelas/kegiatan, memindai banyak eksemplar, mencatat penanggung jawab dan tenggat, serta mengembalikan eksemplar satu per satu.
- **Server:** Supabase self-hosted pada server digunakan sebagai backend. Migrasi transaksi, sampul, dan sesi pembelajaran sudah diterapkan setelah backup. Migrasi lock inventaris dan claim/pemulihan terbaru belum diterapkan.

## Hal yang perlu dilanjutkan

- Uji alur peminjaman anggota dan sesi pembelajaran menyeluruh dengan akun serta buku uji di perangkat.
- Jalankan integrasi claim dan pemulihan akun pada Supabase disposable, termasuk GoTrue dan Edge Function, sebelum menjadwalkan deployment server aktif.
- Tambahkan laporan jurnal peminjaman/pengembalian yang dapat dicetak untuk arsip dan presentasi, sesuai kebutuhan PRD.
- Implementasikan notifikasi dan pengingat jatuh tempo.
- Tinjau seluruh kriteria PRD sebelum menyatakan MVP selesai; build debug bukan build rilis.

## Verifikasi terakhir

- `scripts/verify.ps1`: PASS pada 1 Oktober 2026; Flutter analyze, 9 widget test, 10 data-access test, SQL/RLS/RPC, 7 guard test integrasi, dan 4 helper test pemulihan lulus.
- PostgreSQL dua koneksi: PASS untuk race claim, approval/archive, dua approval pada QR buku sama, serta multi-item dengan urutan terbalik.
- Server read-only: 0 kelompok claim ganda; tabel pemulihan dan indeks claim baru belum ada.
- APK debug berhasil dibuat dan dipasang pada perangkat Android terhubung pada 30 September 2026.
- Struktur tabel dan RPC sesi pembelajaran telah diperiksa pada Supabase server.

## Istilah antarmuka

Label **Aktivitas** digunakan pada UI untuk bagian peminjaman, pengembalian, kehilangan, dan pembelajaran. Istilah teknis seperti `transactions` atau `transaction_evidence` yang sudah menjadi nama skema/backend dapat tetap digunakan di kode dan dokumentasi teknis; istilah tersebut tidak tampil sebagai label menu anggota/pengurus.
