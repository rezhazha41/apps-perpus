# Database tahap M2

## Keputusan terbaru - 6 Oktober 2026

Peminjaman anggota memerlukan persetujuan pengurus setelah pemeriksaan siswa dan buku fisik. Aplikasi memakai `submit_loan_request`, kemudian pengurus memakai `review_loan_request`. Pengajuan belum mengurangi stok. Migrasi `202610060001_staff_approval_required.sql` menolak pengajuan ganda anggota/QR yang masih pending, memvalidasi jenis bukti, dan mencabut akses klien ke `borrow_books`. Pinjaman lama tidak diubah. Migrasi sudah diterapkan dan diverifikasi pada server aktif setelah backup. Masa kedaluwarsa otomatis belum ditentukan.


## Model identitas dan hak admin

Data identitas siswa dan pengurus dipisahkan. `student_registry` menyimpan siswa yang boleh mendaftar sebagai anggota; `staff_registry` menyimpan pengurus, email, jabatan, status, dan akun Auth tertaut. `profiles` menunjuk ke tepat satu identitas. Pendaftaran pengurus memerlukan email terdaftar dan token undangan satu kali; peran admin tidak dapat dinaikkan dari aplikasi anggota.

Admin adalah peran dengan kewenangan tertinggi pada aplikasi saat ini. Belum perlu menambah tingkatan super-admin sampai ada kebutuhan operasional yang nyata. Akun pengurus pertama dan pengurus berikutnya dibuat melalui proses operator tepercaya, dengan identitas staf terdaftar dan audit; kredensial tidak dibuat atau dibagikan lewat SQL/chat.

Migrasi pemisahan identitas dan undangan telah diterapkan secara aditif pada server LAN setelah backup. Data 100 siswa tetap utuh dan belum ada profil yang perlu dikonversi. Migrasi berikutnya tetap perlu diuji pada database salinan sebelum diterapkan pada server.

Pengurus dapat membuat/mengubah/menghapus buku dari katalog, mengelola stok eksemplar, melihat audit, mengatur kebijakan pinjaman, dan membuat undangan staf. Penghapusan katalog memakai soft delete agar hubungan transaksi lama tetap utuh; ini terpisah dari laporan jurnal tahunan dan arsip PDF/CSV lembaga. Setiap eksemplar memiliki kode unik permanen; QR mengodekan kode eksemplar saja, bukan status stok atau data anggota. Cetak QR satuan dan scan QR anggota untuk memeriksa buku tersedia; cetak massal dan scan QR untuk alur transaksi penuh belum tersedia.

Tindakan **Hapus dari katalog** menggunakan RPC `archive_book` sebagai soft delete: RPC menolak penghapusan bila masih ada QR berstatus dipinjam, lalu menandai judul dan QR-nya tidak aktif dalam satu transaksi agar riwayat pinjaman tetap utuh. Arsip jurnal peminjaman/pengembalian untuk penilaian sekolah adalah keluaran laporan tahunan yang berbeda dan belum tersedia.

Migrasi `202609280001_identity_inventory.sql` ditujukan untuk database Supabase pengembangan yang kosong. Tabel bawaan `auth.users` dan fungsi `auth.uid()` harus sudah tersedia. Jangan menerapkannya ke database yang dipakai aplikasi lain: trigger pendaftaran ini khusus Perpus.

Migrasi M2 menyediakan registry siswa/staf, profil akun, buku, QR buku, pengaturan, audit, pemeriksaan akses, undangan staf, dan RPC review. Migrasi M3 menambahkan tabel/RPC peminjaman, Storage privat, dan deadline retensi bukti. Migrasi `202609300003_inventory_lock_protocol.sql` menyatukan urutan lock buku lalu QR buku. Migrasi `202610010001_member_claim_recovery.sql` menambahkan claim eksklusif, pengajuan ulang akun yang sama, serta challenge pemulihan akun. Migrasi `202610020001_self_service_borrowing.sql` dahulu menambahkan pinjaman langsung. Sejak keputusan 6 Oktober, aplikasi kembali memakai `submit_loan_request`; migrasi `202610060001_staff_approval_required.sql` sudah mencabut akses klien ke `borrow_books` pada server aktif. Notifikasi, worker penghapusan, laporan, dan arsip belum tersedia.

## Pendaftaran dan aktivasi

Signup siswa memakai `identity_kind` (`nis`/`nisn`), `identity_number` (string), dan `contact`. Signup pengurus memakai token undangan acak yang diikat ke email dan kedaluwarsa 48 jam. Trigger auth membuat profil anggota/pengurus berstatus pending; role/status dari metadata klien tidak dipercaya. Registry tidak punya endpoint lookup publik dan token undangan tersembunyi dari akses tabel maupun audit snapshot.

Indeks unik parsial `profiles_one_open_member_claim` membatasi satu profil anggota berstatus `pending` atau `active` per siswa. Pembuatan profil mengunci registry dan menolak claim kedua dengan pesan umum agar tidak menjadi sarana pencarian identitas. Admin memeriksa bukti kepemilikan lalu memanggil `review_member(p_user_id, p_approve, p_reason)`. Penolakan membutuhkan alasan dan melepaskan reservasi indeks; siswa memakai `resubmit_member_application()` pada akun yang sama setelah memperbaiki data. Persetujuan mengunci profil dan registry lalu menautkan akun secara atomik. Email terkonfirmasi dan keabsahan identitas tetap merupakan pemeriksaan terpisah.

Tabel `account_recovery_challenges` menyimpan hash kode, bukan kode mentah. Challenge berlaku 15 menit, maksimal 5 percobaan, sekali pakai, dan tidak dapat dibaca client karena RLS serta grant dibatasi untuk `service_role`. Edge Function menerbitkan challenge hanya setelah JWT pengurus aktif diverifikasi oleh database. Penukaran kode dapat dilakukan sebelum login, mengubah kata sandi atau email yang telah dimasukkan pengurus setelah verifikasi langsung, lalu mencabut sesi lama. Endpoint tidak menyediakan pencarian NIS/NISN atau email publik.

Klien tidak memperoleh UPDATE profiles, `linked_user_id`, atau identitas staf. Penautan staf terjadi hanya saat token cocok dan dikonsumsi trigger Auth; aktivasi oleh admin memakai RPC setelah email terkonfirmasi. Registry dan profil pending hanya dibaca admin/pemilik profil sesuai RLS. Member hanya membaca registry yang tertaut ke dirinya.

## Provisioning admin

Anggota tetap bisa mendaftar memakai NIS/NISN yang telah dimasukkan pengurus. Admin tidak memiliki pendaftaran mandiri; jalur pengurus pada aplikasi hanya menerima undangan satu kali yang dibuat admin aktif. Untuk admin pertama, operator menjalankan [bootstrap_first_admin.sql](../supabase/bootstrap_first_admin.sql) di Studio dengan email/nama resmi, lalu mengundang email yang sama lewat Authentication > Users dan mengonfirmasi emailnya. Jalankan [activate_first_admin.sql](../supabase/activate_first_admin.sql) setelah mengganti placeholder email untuk menautkan Auth user terverifikasi ke identitas staf dan mengaktifkan admin pertama. Token undangan tetap tersimpan privat di database. Script berhenti dengan pesan jelas jika akun belum ada, email belum dikonfirmasi, atau undangan kedaluwarsa. Setelah itu admin dapat membuat undangan staf lewat aplikasi dan menyetujui akun setelah email terkonfirmasi. Jangan menyimpan password/service-role key di SQL, aplikasi, atau repository. Token tidak disimpan di audit log.

## Batas akses

RLS diaktifkan pada seluruh tabel aplikasi. anon tidak mendapat akses tabel; authenticated memperoleh SELECT dengan policy. Perubahan transaksi dan status eksemplar hanya melalui RPC yang mengotorisasi caller. `borrow_books` memvalidasi bukti Storage, profil aktif, batas dan kewajiban pinjaman, lalu mengunci inventaris serta mencatat bukti/pinjaman/stok dalam satu transaksi. `loans.approval_mode='self_service'` menandai pinjaman langsung dan `approved_by` bernilai null; pinjaman staf lama tetap mencatat pengurus. Tidak ada direct-write client untuk tabel transaksi atau delete client; kolom administrasi identitas/inventaris dibatasi grant per kolom dan policy admin. Audit disimpan oleh trigger dan tidak dapat diubah client.

Pengaturan 7 hari/3 buku masih default pengembangan; `policy_confirmed=false` dan `evidence_retention=null`. Retensi nyata harus dipilih sekolah sebelum unggah foto. Waktu memakai timestamptz; zona waktu sekolah harus diverifikasi sebelum scheduler.

## Verifikasi sebelum integrasi

Smoke test lokal seluruh migrasi dapat dijalankan dari `scripts/sql-tests` dengan `npm ci` lalu `npm test`. Runner memakai PostgreSQL embedded PGlite dan fixture Auth/Storage. Migrasi, claim lifecycle, challenge sekali pakai, dan isolasi role sudah lolos. PostgreSQL sementara dua koneksi juga membuktikan race claim dan transaksi inventaris. Hasil tersebut belum membuktikan integrasi GoTrue, email, jaringan, Storage, atau Edge Function sungguhan.

Sebelum server aktif, terapkan seluruh migrasi pada Supabase disposable dan jalankan `supabase/verify_migration.sql` serta `scripts/supabase-integration`. Untuk Auth, rate limiting, konfirmasi email, pemulihan SMTP, Storage, dan Edge Function sungguhan diperlukan stack Supabase terisolasi. Pemeriksaan read-only server aktif pada 1 Oktober 2026 menemukan 0 kelompok claim ganda, tetapi tabel/index claim-pemulihan baru belum ada.

Audit berisi perubahan data siswa sehingga bersifat privat dan hanya admin berwenang yang dapat membacanya. Backup database dan file storage harus terkoordinasi; retensi arsip terpisah dari retensi foto.
