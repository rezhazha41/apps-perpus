# Database tahap M2

## Model identitas dan hak admin

Data identitas siswa dan pengurus dipisahkan. `student_registry` menyimpan siswa yang boleh mendaftar sebagai anggota; `staff_registry` menyimpan pengurus, email, jabatan, status, dan akun Auth tertaut. `profiles` menunjuk ke tepat satu identitas. Pendaftaran pengurus memerlukan email terdaftar dan token undangan satu kali; peran admin tidak dapat dinaikkan dari aplikasi anggota.

Admin adalah peran dengan kewenangan tertinggi pada aplikasi saat ini. Belum perlu menambah tingkatan super-admin sampai ada kebutuhan operasional yang nyata. Akun pengurus pertama dan pengurus berikutnya dibuat melalui proses operator tepercaya, dengan identitas staf terdaftar dan audit; kredensial tidak dibuat atau dibagikan lewat SQL/chat.

Migrasi pemisahan identitas dan undangan telah diterapkan secara aditif pada server LAN setelah backup. Data 100 siswa tetap utuh dan belum ada profil yang perlu dikonversi. Migrasi berikutnya tetap perlu diuji pada database salinan sebelum diterapkan pada server.

Pengurus dapat membuat/mengubah/menghapus buku dari katalog, mengelola stok eksemplar, melihat audit, mengatur kebijakan pinjaman, dan membuat undangan staf. Penghapusan katalog memakai soft delete agar hubungan transaksi lama tetap utuh; ini terpisah dari laporan jurnal tahunan dan arsip PDF/CSV lembaga. Setiap eksemplar memiliki kode unik permanen; QR mengodekan kode eksemplar saja, bukan status stok atau data anggota. Cetak QR satuan dan scan QR anggota untuk memeriksa buku tersedia; cetak massal dan scan QR untuk alur transaksi penuh belum tersedia.

Tindakan **Hapus dari katalog** menggunakan RPC `archive_book` sebagai soft delete: RPC menolak penghapusan bila masih ada QR berstatus dipinjam, lalu menandai judul dan QR-nya tidak aktif dalam satu transaksi agar riwayat pinjaman tetap utuh. Arsip jurnal peminjaman/pengembalian untuk penilaian sekolah adalah keluaran laporan tahunan yang berbeda dan belum tersedia.

Migrasi `202609280001_identity_inventory.sql` ditujukan untuk database Supabase pengembangan yang kosong. Tabel bawaan `auth.users` dan fungsi `auth.uid()` harus sudah tersedia. Jangan menerapkannya ke database yang dipakai aplikasi lain: trigger pendaftaran ini khusus Perpus.

Migrasi M2 menyediakan registry siswa/staf, profil akun, buku, eksemplar, pengaturan, audit, pemeriksaan akses, undangan staf, dan RPC review. Migrasi M3 lokal menambahkan tabel/RPC transaksi, Storage privat, dan deadline retensi bukti; belum diterapkan ke server. Notifikasi, worker penghapusan, laporan, dan arsip belum tersedia.

## Pendaftaran dan aktivasi

Signup siswa memakai `identity_kind` (`nis`/`nisn`), `identity_number` (string), dan `contact`. Signup pengurus memakai token undangan acak yang diikat ke email dan kedaluwarsa 48 jam. Trigger auth membuat profil anggota/pengurus berstatus pending; role/status dari metadata klien tidak dipercaya. Registry tidak punya endpoint lookup publik dan token undangan tersembunyi dari akses tabel maupun audit snapshot.

Klaim pending tidak mengunci identitas siswa. Admin memeriksa bukti kepemilikan lalu memanggil `review_member(p_user_id, p_approve, p_reason)`. RPC mengunci profil dan registry; satu siswa hanya ditautkan ke satu akun. Klaim lain tidak bisa diaktifkan setelah penautan. Penolakan membutuhkan alasan; akun ditolak dapat ditinjau kembali admin. Email yang terkonfirmasi dan keabsahan identitas adalah pemeriksaan terpisah.

Klien tidak memperoleh UPDATE profiles, `linked_user_id`, atau identitas staf. Penautan staf terjadi hanya saat token cocok dan dikonsumsi trigger Auth; aktivasi oleh admin memakai RPC setelah email terkonfirmasi. Registry dan profil pending hanya dibaca admin/pemilik profil sesuai RLS. Member hanya membaca registry yang tertaut ke dirinya.

## Provisioning admin

Anggota tetap bisa mendaftar memakai NIS/NISN yang telah dimasukkan pengurus. Admin tidak memiliki pendaftaran mandiri; jalur pengurus pada aplikasi hanya menerima undangan satu kali yang dibuat admin aktif. Untuk admin pertama, operator menjalankan [bootstrap_first_admin.sql](../supabase/bootstrap_first_admin.sql) di Studio dengan email/nama resmi, lalu mengundang email yang sama lewat Authentication > Users dan mengonfirmasi emailnya. Jalankan [activate_first_admin.sql](../supabase/activate_first_admin.sql) setelah mengganti placeholder email untuk menautkan Auth user terverifikasi ke identitas staf dan mengaktifkan admin pertama. Token undangan tetap tersimpan privat di database. Script berhenti dengan pesan jelas jika akun belum ada, email belum dikonfirmasi, atau undangan kedaluwarsa. Setelah itu admin dapat membuat undangan staf lewat aplikasi dan menyetujui akun setelah email terkonfirmasi. Jangan menyimpan password/service-role key di SQL, aplikasi, atau repository. Token tidak disimpan di audit log.

## Batas akses

RLS diaktifkan pada seluruh tabel aplikasi. anon tidak mendapat akses tabel; authenticated memperoleh SELECT dengan policy. Perubahan transaksi dan status eksemplar hanya melalui RPC yang mengotorisasi caller. Tidak ada direct-write client untuk tabel transaksi atau delete client; kolom administrasi identitas/inventaris dibatasi grant per kolom dan policy admin. Audit disimpan oleh trigger dan tidak dapat diubah client.

Pengaturan 7 hari/3 buku masih default pengembangan; `policy_confirmed=false` dan `evidence_retention=null`. Retensi nyata harus dipilih sekolah sebelum unggah foto. Waktu memakai timestamptz; zona waktu sekolah harus diverifikasi sebelum scheduler.

## Verifikasi sebelum integrasi

Smoke test lokal untuk kedua migrasi dapat dijalankan dari `scripts/sql-tests` dengan `npm ci` lalu `npm test`. Runner memakai PostgreSQL embedded PGlite dan fixture Auth/Storage. Migrasi dan uji isolasi role sudah lolos; hasilnya belum membuktikan integrasi GoTrue, email, jaringan, Storage sungguhan, atau konkurensi lintas koneksi.

Sebelum server, terapkan migrasi M3 pada Supabase lokal kosong dan jalankan `supabase/verify_migration.sql`. Tes fixture transaksi ada pada `supabase/tests/transactions.sql`; untuk Auth, rate limiting, konfirmasi email, pemulihan SMTP, Storage sungguhan, dan konkurensi multi-sesi diperlukan stack Supabase terisolasi.

Audit berisi perubahan data siswa sehingga bersifat privat dan hanya admin berwenang yang dapat membacanya. Backup database dan file storage harus terkoordinasi; retensi arsip terpisah dari retensi foto.
