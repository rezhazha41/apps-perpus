# Status implementasi - 6 Oktober 2026

## Keputusan terbaru - 6 Oktober 2026

Verifikasi lokal sesi ini: `flutter analyze --no-pub` PASS, seluruh 24 tes Flutter PASS, SQL smoke tests PGlite PASS, dan pemeriksaan sintaks runner integrasi PASS. Integrasi Supabase nyata dan concurrency dua koneksi untuk perubahan baru belum dijalankan. Lihat [catatan sesi](progress-log.md).

Peminjaman anggota memerlukan persetujuan pengurus setelah pemeriksaan siswa dan buku fisik. Aplikasi memakai `submit_loan_request`, kemudian pengurus memakai `review_loan_request`. Pengajuan belum mengurangi stok. Migrasi `202610060001_staff_approval_required.sql` menolak pengajuan ganda anggota/QR yang masih pending, memvalidasi jenis bukti, dan mencabut akses klien ke `borrow_books`. Pinjaman lama tidak diubah. Migrasi sudah diterapkan dan diverifikasi pada server setelah backup; APK debug terbaru sudah dipasang pada perangkat. Masa kedaluwarsa otomatis belum ditentukan.


## Addendum perubahan alur pinjaman — 2 Oktober 2026

Pengguna memilih peminjaman langsung tanpa persetujuan sebelum stok berkurang. Form mewajibkan pilihan bukti dan foto; deteksi lokal memeriksa keberadaan wajah, bukan identitas atau liveness. Migrasi `202610020001_self_service_borrowing.sql` menyediakan RPC `borrow_books` yang mencatat pinjaman dan mengurangi stok secara atomik. Pada 2 Oktober, stack Supabase lokal disposable lulus integrasi GoTrue, RLS/RPC, Storage privat, dan peminjaman; uji perangkat juga lulus dari scan QR hingga bukti tersimpan dan pinjaman terlihat pada riwayat. Uji tersebut memakai stack lokal; penerapan ke server dicatat pada addendum berikutnya. Pengembalian sebagian/penuh dan retensi bukti masih perlu dibuktikan. Lihat [progress log](progress-log.md) untuk bukti sesi.

## Addendum penerapan ke Supabase server - 2 Oktober 2026

Atas instruksi pengguna, migrasi `202609300003_inventory_lock_protocol.sql`, `202610010001_member_claim_recovery.sql`, dan `202610020001_self_service_borrowing.sql` diterapkan berurutan ke database `postgres` pada server Perpus. Sebelum perubahan dibuat dump tervalidasi `/opt/backups/perpus/perpus-pre-m3-20261002.dump` (481.019 byte, mode 600). `verify_migration.sql` dan `verify_staff_admin.sql` lulus; grant `borrow_books` tersedia untuk `authenticated` dan tidak tersedia untuk `anon`. Jumlah profil/siswa/buku/QR tetap 2/100/8/26; belum ada loan/request/evidence row. Endpoint Auth merespons HTTP 200 dengan client key. APK debug berkonfigurasi server berhasil dibangun dan dipasang pada perangkat; login dan transaksi pinjaman terhadap server belum diuji agar tidak menulis transaksi uji ke data aktif. Edge Function `account-recovery` belum terpasang di runtime server dan perlu deployment terpisah.

## Addendum verifikasi 1 Oktober 2026

Akses server aktif secara read-only melalui Cloudflare SSH sudah PASS. Archive, cover, classroom loans, dan bucket bukti privat ditemukan, tetapi verifier FAIL karena migrasi protokol lock inventaris terbaru belum aktif. Kebijakan claim kini ditetapkan: satu claim menunggu/aktif per siswa, penolakan melepas claim, dan pengajuan ulang memakai akun yang sama. Pemulihan terbantu memakai verifikasi langsung pengurus serta kode sekali pakai 15 menit. Implementasi dan test lokal sudah tersedia; migrasi serta Edge Function belum diterapkan ke server aktif. Preflight server menemukan 0 kelompok claim ganda. Runner integrasi GoTrue/RLS/RPC/Storage/Edge Function menolak server aktif dan runtime tetap BLOCKED sampai tersedia stack Supabase disposable. Lihat [analisis claim dan pemulihan](analysis/08-claim-dan-pemulihan-akun.md).

## Addendum verifikasi 30 September 2026

Catatan historis: baseline lokal dan verifier setelah perubahan lulus. Regression concurrency approval/archive, approval ganda pada copy sama, dan urutan multi-item berbeda lulus pada PostgreSQL 18 sementara dua koneksi. Sebelum migrasi lock baru, test approval/archive mereproduksi copy `borrowed` sekaligus terarsip. Pada tanggal tersebut akses SSH dan keputusan claim masih BLOCKED; kondisi itu telah digantikan oleh addendum 1 Oktober di atas. Lihat [bukti verifikasi saat itu](analysis/verification-2026-09-30.md).

Catatan status historis di bawah merekam kondisi pada tanggal masing-masing; status server terbaru ada pada addendum 2 Oktober di atas.

Dokumen ini merangkum kondisi aplikasi untuk persiapan demo dan presentasi. Catatan tiap sesi perubahan ada di [progress-log.md](progress-log.md).

## Sudah tersedia

- **M1 — Demo:** aplikasi Flutter Android dengan susunan Dashboard, Buku, Aktivitas, dan Anggota untuk pengurus. Mode demo tetap terpisah dari data server.
- **M2 — Identitas dan katalog:** login/daftar anggota dengan NIS/NISN yang terdaftar, persetujuan aktivasi pengurus, pengelolaan anggota, CRUD buku, pengelolaan eksemplar, penyesuaian stok, dan arsip katalog lunak.
- **Claim anggota:** database membatasi satu akun menunggu/aktif per siswa. Penolakan melepas claim; anggota dapat memperbaiki dan mengajukan ulang menggunakan akun yang sama.
- **Pemulihan akses terbantu:** anggota yang tidak dapat membuka email dapat meminta pengurus memeriksa identitas fisik. Pengurus menerbitkan kode sekali pakai 15 menit; siswa memasukkan kode dan kata sandi baru tanpa endpoint pencarian identitas publik.
- **Sesi login:** sesi anggota dan pengurus logout otomatis setelah 24 jam tanpa aktivitas. Waktu tidak aktif saat aplikasi tertutup tetap dihitung. Header server menunjukkan peran aktif.
- **QR buku:** setiap eksemplar punya kode unik. Kode otomatis mengikuti kategori/judul; saat menambahkan buku pengurus dapat memberi awalan QR khusus. QR dapat ditampilkan dan dicetak satuan. Setelah scan, anggota melihat sampul besar, judul, kategori, kode, dan status; sampul ikut tampil pada pengajuan serta riwayat pinjaman.
- **Sampul katalog:** pengurus dapat memilih gambar sampul saat menambah atau mengubah buku. Jika tidak memilih gambar, katalog mempertahankan ikon bawaan demo.
- **M3 - Peminjaman anggota:** pengajuan dengan bukti foto, menunggu persetujuan pengurus, lalu stok berubah atomik saat disetujui. Pengembalian, kehilangan, dan pinjaman pembelajaran tetap tersedia. Migrasi penutupan pinjam langsung sudah diterapkan; verifier server lulus. Pengujian transaksi nyata alur baru masih perlu dilakukan.
- **Pengembalian pengurus:** pengurus dapat meninjau pengembalian per eksemplar serta mencatat kondisi baik/rusak.
- **Peminjaman pembelajaran:** menu Aktivitas → Pembelajaran membuat satu sesi untuk kelas/kegiatan, memindai banyak eksemplar, mencatat penanggung jawab dan tenggat, serta mengembalikan eksemplar satu per satu.
- **Server:** Supabase self-hosted digunakan sebagai backend. Migrasi inventaris, claim/pemulihan, dan pinjaman langsung kini diterapkan serta diverifikasi di server setelah backup; Edge Function `account-recovery` masih belum terpasang.

## Hal yang perlu dilanjutkan

- Uji pengembalian sebagian/penuh di perangkat, termasuk keputusan pengurus dan kondisi buku; uji retensi serta penghapusan bukti privat.
- Uji sesi pembelajaran menyeluruh pada perangkat dengan data sintetis.
- Uji login, unggah bukti privat, dan peminjaman ke server dengan akun serta buku sintetis yang disiapkan untuk uji; jangan memakai buku/data operasional sebagai fixture.
- Deploy dan verifikasi Edge Function `account-recovery` sebelum mengandalkan pemulihan akun pada server.
- Tambahkan laporan jurnal peminjaman/pengembalian yang dapat dicetak untuk arsip dan presentasi, sesuai kebutuhan PRD.
- Implementasikan notifikasi dan pengingat jatuh tempo.
- Tinjau seluruh kriteria PRD sebelum menyatakan MVP selesai; build debug bukan build rilis.

## Verifikasi terakhir

- `scripts/verify.ps1`: PASS pada 1 Oktober 2026; Flutter analyze, 9 widget test, 10 data-access test, SQL/RLS/RPC, 7 guard test integrasi, dan 4 helper test pemulihan lulus.
- Supabase lokal disposable: PASS untuk migrasi, GoTrue, RLS/RPC, Storage privat, peminjaman atomik, serta uji perangkat scan QR sampai riwayat. Data dan foto hanya pada stack lokal.
- PostgreSQL dua koneksi: PASS untuk race claim, approval/archive, dua approval pada QR buku sama, serta multi-item dengan urutan terbalik.
- Supabase server: `verify_migration.sql` dan `verify_staff_admin.sql` PASS setelah migrasi; backup tersedia. Login dan peminjaman langsung belum diuji pada server dengan akun/buku sintetis.
- APK debug berhasil dibuat dan dipasang pada perangkat Android terhubung pada 30 September 2026.
- Struktur tabel dan RPC sesi pembelajaran telah diperiksa pada Supabase server.

## Istilah antarmuka

Label **Aktivitas** digunakan pada UI untuk bagian peminjaman, pengembalian, kehilangan, dan pembelajaran. Istilah teknis seperti `transactions` atau `transaction_evidence` yang sudah menjadi nama skema/backend dapat tetap digunakan di kode dan dokumentasi teknis; istilah tersebut tidak tampil sebagai label menu anggota/pengurus.
