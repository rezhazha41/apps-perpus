# Audit kesiapan M1–M2 dan fondasi M3

> Catatan 1 Oktober 2026: temuan claim pending pada audit ini sudah diperbaiki secara lokal. Lihat [analisis claim dan pemulihan](analysis/08-claim-dan-pemulihan-akun.md). Isi di bawah dipertahankan sebagai bukti kondisi saat audit awal.

> Dokumen ini adalah laporan gabungan sesi audit. Versi tematik yang lebih mudah dinavigasi tersedia di [docs/analysis/](analysis/README.md); gunakan indeks tersebut untuk membuka analisis per bidang.

**Tanggal:** 30 September 2026  
**Cakupan:** pembacaan README sebagai PRD, dokumentasi proyek, kode Flutter, paket, migrasi Supabase, RLS/RPC, dan sumber test.  
**Jenis audit:** read-only. Tidak ada kode atau kebijakan database yang diubah. Test tidak dijalankan ulang dalam audit ini.

## Kesimpulan

Fondasi M1–M2 sudah memiliki implementasi untuk autentikasi, aktivasi anggota, katalog/inventaris, QR, dan pembatasan akses backend. Akan tetapi, pembacaan kode dan fixture saja belum membuktikan semua alur lulus pada aplikasi/perangkat atau Supabase server saat ini.

> [!IMPORTANT]
> Ditemukan race condition antara persetujuan pinjaman dan pengarsipan buku. Selesaikan dan uji konkurensi ini sebelum mengandalkan alur persetujuan M3. Terdapat pula celah beberapa akun pending dapat mengklaim siswa yang sama; aturan bisnis untuk akun yang ditolak/perlu daftar ulang perlu dipastikan sebelum memilih constraint database.

M3 bukan sepenuhnya belum dikerjakan: migrasi dan UI sudah memuat pengajuan pinjaman, bukti foto privat, persetujuan, pengembalian per eksemplar, dan pelaporan kehilangan. Namun, test PGlite yang tersedia tidak mencakup GoTrue, Storage nyata, atau konkurensi multi-koneksi.

## Batas bukti

- Status “terbukti secara statis” berarti struktur kode, kebijakan, atau fixture mendukung kebutuhan tersebut. Itu bukan klaim test runtime terbaru berhasil.
- `scripts/verify.ps1` mendefinisikan rangkaian Flutter, data-access, dan SQL. Audit ini tidak menjalankannya.
- `scripts/sql-tests/test.mjs` menyiapkan Auth dan Storage sebagai fixture PGlite; file tersebut sendiri menyatakan GoTrue, Storage API nyata, pengiriman email, dan konkurensi multi-koneksi memerlukan test integrasi Supabase.
- Kondisi migrasi yang benar-benar terpasang di server tidak diverifikasi melalui koneksi server dalam audit ini.
- Pemeriksaan rahasia hanya memindai sumber yang diperiksa; tidak memindai APK atau seluruh riwayat Git.

## Status kebutuhan

| Kebutuhan | Status audit | Catatan bukti/batas |
|---|---|---|
| Signup anggota dengan NIS/NISN terdaftar | Terbukti secara statis; runtime belum diuji | Trigger membuat profil pending berdasarkan registry; alur GoTrue dan email nyata belum diuji. |
| Aktivasi anggota oleh pengurus dan verifikasi email | Terbukti secara statis; runtime belum diuji | `review_member` mengecek admin dan email terkonfirmasi serta mengunci profil dan siswa. |
| Login anggota/pengurus terpisah | Terbukti sebagian | UI mencocokkan role profil dengan jalur masuk dan sign out jika salah. Otorisasi backend tetap harus diuji pada server. |
| Reset password dan callback | Belum diuji end-to-end | UI memakai callback recovery; SMTP, deep link, GoTrue, dan pergantian kata sandi nyata belum dibuktikan. |
| Provisioning admin pertama | Implementasi tersedia; runtime belum diverifikasi | Ada skrip bootstrap/aktivasi, tetapi belum ada bukti audit bahwa alur skrip tersebut diuji lengkap. |
| Maksimal satu akun aktif per siswa | Terbukti secara statis | Aktivasi mengunci registry dan `linked_user_id` memiliki perlindungan unik. |
| Maksimal satu akun/claim pending per siswa | Bermasalah | Tidak ada keunikan claim pending; pendaftaran memakai NIS dan NISN dapat menghasilkan beberapa profil pending. |
| Perubahan role, link identitas, dan stok hanya oleh backend berotorisasi | Terbukti pada grant/RPC yang diperiksa | Perlu verifikasi ulang pada skema server aktual. |
| Inventaris dan kode QR eksemplar unik | Terbukti secara statis; data aktual belum diuji | Skema menggunakan kode unik dan membatasi perubahan status melalui RPC. Konflik kode pada data server belum diuji. |
| Error, offline, timeout, async lifecycle | Bermasalah sebagian | Ada loading/retry dan banyak pemeriksaan `mounted`; pesan timeout signup menyatakan hasil gagal padahal hasil server bisa belum diketahui. Offline/timeout menyeluruh belum diuji. |
| Rahasia backend di sumber/log | Tidak ditemukan pada pemindaian sumber yang diperiksa | URL dan publishable key klien bukan service-role secret; RLS tetap wajib. APK dan riwayat Git tidak dipindai. |

## Temuan

### P1 — Race antara persetujuan pinjaman dan pengarsipan buku

**Lokasi:** [migrasi transaksi](../supabase/migrations/202609280002_transactions.sql), fungsi `review_loan_request`; [migrasi arsip](../supabase/migrations/202609290004_archive_book.sql), fungsi `archive_book`.

**Bukti:** `review_loan_request` mengunci eksemplar lalu memeriksa status buku/eksemplar. `archive_book` mengunci buku, memeriksa eksemplar yang dipinjam, lalu mengarsipkan seluruh eksemplar dan bukunya. Kedua operasi tidak mengambil kunci pada baris yang sama dengan urutan bersama.

**Dampak:** dalam kondisi serentak, persetujuan dan pengarsipan dapat saling melewati pemeriksaan awal sehingga buku atau eksemplar berpotensi menjadi arsip sementara memiliki pinjaman aktif.

**Prioritas:** penghalang sebelum alur persetujuan M3 diandalkan. Tentukan urutan lock yang konsisten dan buktikan dengan test dua koneksi.

### P1 — Beberapa pendaftaran pending dapat mengklaim siswa yang sama

**Lokasi:** [migrasi identitas](../supabase/migrations/202609280001_identity_inventory.sql), fungsi `private.create_member_profile`; trigger penggantinya berada di [migrasi undangan staf](../supabase/migrations/202609290002_staff_invites.sql).

**Bukti:** trigger memilih siswa aktif yang belum tertaut lalu membuat profil berstatus pending. Klaim pending tidak mengunci baris siswa dan kolom klaim profil tidak unik. Penguncian dilakukan saat admin mengaktifkan akun.

**Dampak:** NIS dan NISN siswa yang sama dapat dipakai untuk membuat lebih dari satu akun pending. Perlindungan aktivasi masih mencegah dua akun aktif tertaut ke siswa yang sama.

**Prioritas:** tinggi untuk integritas pendaftaran. Sebelum menambah constraint, sepakati bagaimana akun yang ditolak atau pendaftaran ulang ditangani agar siswa yang sah tidak terkunci dari proses daftar ulang.

### P2 — Timeout signup memberi kepastian yang tidak didukung

**Lokasi:** [auth_pages.dart](../apps/mobile/lib/features/auth/auth_pages.dart), fungsi pemetaan pesan autentikasi.

**Bukti:** pesan timeout menyebut akun “belum tercatat”. Server mungkin sudah membuat akun tetapi respons tidak diterima aplikasi.

**Dampak:** pengguna bisa mengulang pendaftaran dan menghadapi konflik akun/email yang sudah terdaftar.

**Prioritas:** normal; ubah pesan menjadi hasil belum diketahui dan berikan arahan aman untuk memeriksa email atau meminta admin memeriksa status.

### P2 — Pembuatan buku dan eksemplar terdiri dari beberapa operasi

**Lokasi:** [server_shell.dart](../apps/mobile/lib/features/server/server_shell.dart), fungsi `_addBook`.

**Bukti:** buku dibuat lebih dahulu, lalu sampul diunggah/dihubungkan, lalu eksemplar dimasukkan. Jika langkah berikutnya gagal, buku yang sudah dibuat tidak otomatis dibatalkan.

**Dampak:** input yang gagal sebagian dapat meninggalkan buku tanpa stok atau tanpa sampul. Retry perlu menghindari data ganda.

**Prioritas:** normal; dapat dikerjakan setelah penghalang keamanan/transaksi, tetapi perlu ditangani sebelum input inventaris besar.

### P1 — Test/verifikasi belum mencakup migrasi dan integrasi terbaru

**Lokasi:** [runner SQL](../scripts/sql-tests/test.mjs) dan [verify_migration.sql](../supabase/verify_migration.sql).

**Bukti:** runner memuat migrasi identitas, transaksi, staf, undangan, dan provisioning, tetapi tidak memuat migrasi arsip buku, sampul, atau pinjaman kelas. Verifikasi skema juga tidak mencantumkan tabel sesi/eksemplar kelas dan resource sampul.

**Dampak:** PASS runner tidak membuktikan seluruh migrasi terbaru teruji. Runner juga menyebutkan bahwa GoTrue, Storage nyata, email, dan konkurensi multi-koneksi perlu test integrasi.

**Prioritas:** tutup gap ini sebelum menyatakan kesiapan M3/produksi. Ini gap cakupan verifikasi, bukan bukti bahwa fitur yang tidak diuji pasti gagal.

## Kesiapan M3

### Penghalang sebelum mengandalkan alur M3

1. Atasi race approval–archive dan tambahkan uji dua koneksi.
2. Tentukan aturan klaim pending, termasuk pendaftaran ulang setelah ditolak; uji NIS/NISN yang sama dan pendaftaran bersamaan.
3. Jalankan test yang saat ini didefinisikan proyek dan simpan hasil aktual.
4. Cocokkan skema/RLS/RPC server dengan migrasi yang seharusnya aktif, secara baca-saja.
5. Uji bucket bukti privat dengan Storage Supabase nyata sebelum menggunakan foto anggota.

### Bisa ditunda dari gerbang integritas M3

- Perbaikan pesan timeout signup.
- Penanganan rollback/recovery untuk CRUD buku yang gagal sebagian.
- Test SMTP/reset/deep link end-to-end pada stack Supabase terisolasi.
- Audit artefak APK dan riwayat Git untuk memastikan tidak ada kredensial privat.

## Test plan fondasi M1–M2

Jalankan hanya pada checkout saat ini dan lingkungan uji yang aman. Jangan jalankan fixture/seed pada database dengan data nyata.

1. Jalankan `scripts/verify.ps1`; simpan hasil Flutter analyze/test, data-access test, dan SQL test.
2. Tambahkan fixture identitas untuk dua claim pending atas satu siswa, penolakan/daftar ulang, dua aktivasi bersamaan, dan percobaan menaikkan role.
3. Uji RLS tiap role: anggota hanya melihat profil/data sendiri; anggota tidak bisa menulis status stok atau data pinjaman langsung; admin dapat memproses operasi yang memang diizinkan.
4. Uji keunikan kode eksemplar dan QR, konflik kode custom, pengarsipan eksemplar/buku, dan perlindungan buku yang sedang dipinjam.
5. Pada Supabase terisolasi dengan identitas sintetis, uji GoTrue signup, email confirmation, aktivasi/reject, reset dan callback, undangan staf, serta provisioning admin pertama.
6. Uji Storage nyata untuk akses bukti: anggota pemilik, anggota lain, admin, bucket privat, tipe/ukuran file, dan penghapusan sesuai retensi yang disepakati.
7. Jalankan test dua koneksi untuk approval melawan archive dan approval serentak atas eksemplar sama.
8. Uji perangkat: offline, timeout signup dengan hasil server ambigu, keluar aplikasi saat request berjalan, QR invalid/duplikat, serta retry setelah koneksi pulih.

PGlite berguna untuk test SQL terisolasi, tetapi bukan pengganti pengujian GoTrue, email, Storage, dan konkurensi PostgreSQL multi-koneksi.

## Rencana implementasi M3 bertahap

1. **Kunci fondasi identitas dan inventaris.** Putuskan aturan klaim pending; perbaiki race arsip/persetujuan; tambah regression test.
2. **Bukti foto privat.** Tegaskan validasi MIME/ukuran, struktur path per pengguna dan idempotency key, upload ke bucket privat, kegagalan upload, akses tinjauan, dan retensi.
3. **Pengajuan anggota.** Uji pemilihan beberapa eksemplar, pemindaian QR, duplikasi/tidak tersedia, pengajuan ulang idempotent, dan status yang jelas bagi anggota.
4. **Persetujuan atomik.** Terapkan urutan penguncian yang konsisten untuk anggota, buku, dan eksemplar; uji batas jumlah pinjaman, approval ganda, serta archive bersamaan.
5. **Pengembalian sebagian/penuh.** Pastikan setiap item hanya diproses sekali, kondisi eksemplar tersimpan, stok konsisten, dan pinjaman selesai hanya setelah semua item ditangani.
6. **Integrasi dan dokumentasi.** Uji di Supabase terisolasi, simpan hasil, rekonsiliasi dokumentasi dengan skema server, lalu rencanakan penerapan terpisah setelah verifikasi.

## Rekonsiliasi dokumentasi proyek

- [README.md](../README.md) adalah PRD, tetapi beberapa pernyataan status/provisioning di bagian awal dapat tertinggal dari keadaan yang dilaporkan pengguna. Gunakan kriteria M1–M5 sebagai target, bukan bukti test.
- [implementation-status.md](implementation-status.md) mencatat fitur yang tersedia dan hasil analyze/build pada tanggal sebelumnya; audit ini tidak mengulang verifikasi tersebut.
- [architecture.md](architecture.md), [database.md](database.md), dan [self-hosted-supabase.md](self-hosted-supabase.md) memuat pernyataan yang bertentangan dengan implementasi M3 terbaru, terutama tentang integrasi transaksi, bukti, kamera, dan migrasi server.
- Status penerapan migrasi di server belum diperiksa dalam audit ini. Rekonsiliasi dokumen server harus menunggu verifikasi skema baca-saja, bukan diasumsikan dari status dokumentasi.
