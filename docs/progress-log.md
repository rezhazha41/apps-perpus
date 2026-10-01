# Catatan progres per sesi

Catatan ini diperbarui pada setiap sesi yang mengubah implementasi atau keputusan produk agar mudah dirujuk saat demo dan presentasi akhir.

## 1 Oktober 2026 — Claim siswa dan pemulihan akses akun

### Keputusan produk

- Satu siswa hanya dapat mempunyai satu claim anggota berstatus menunggu atau aktif.
- Pendaftaran kedua ditolak oleh backend. Jika pengurus menolak pendaftaran, claim dilepas dan siswa mengajukan ulang memakai akun yang sama.
- Jika siswa lupa kata sandi dan tidak dapat membuka email, pengurus memverifikasi identitas secara langsung lalu memberikan kode pemulihan sekali pakai yang berlaku 15 menit.

### Perubahan

- Menambahkan migrasi `202610010001_member_claim_recovery.sql` untuk claim eksklusif, pengajuan ulang, challenge pemulihan privat, batas percobaan, dan pencabutan sesi.
- Menambahkan Edge Function `account-recovery`; service-role key hanya dipakai pada fungsi server.
- Menambahkan jalur pemulihan pada login anggota, tombol pengajuan ulang untuk akun ditolak, dan penerbitan kode dari menu anggota pengurus tanpa mengubah susunan navigasi demo.
- Memperluas SQL test, verifier migrasi, runner integrasi disposable, dan regression PostgreSQL dua koneksi.
- Memperbaiki `scripts/verify.ps1` agar menemukan tool Windows dan Git pada environment PATH minimal.

### Verifikasi dan batas

- Full verifier PASS: Flutter analyze, 9 widget test, 10 data-access test, SQL/RLS/RPC, 7 guard test integrasi, dan 4 helper test Edge Function.
- PostgreSQL dua koneksi PASS untuk race claim dan seluruh regression lock inventaris.
- Server aktif diperiksa read-only: 0 kelompok claim ganda; migrasi claim/pemulihan belum diterapkan.
- Integrasi GoTrue, Storage, dan Edge Function pada stack disposable masih BLOCKED karena environment/kredensial uji belum tersedia.

## 30 September 2026 — Penyesuaian app flow PRD

### Perubahan dokumentasi

- Memperbarui status awal PRD berdasarkan hasil audit dan pengujian terakhir: M1/M2 tersedia, alur M3 ada pada kode dan lulus verifier lokal, sedangkan integrasi GoTrue/Storage serta migrasi lock pada server aktif belum terverifikasi.
- Mengganti diagram app flow lama dengan empat alur yang sesuai aplikasi saat ini: masuk dan aktivasi anggota; peminjaman anggota; katalog/inventaris pengurus; serta peminjaman pembelajaran.
- Menyesuaikan navigasi dengan tampilan yang sudah dipresentasikan. Pengurus tetap memakai **Dashboard, Buku, Aktivitas, Anggota**; anggota memakai **Katalog, Scan, Akun, Pinjaman**.
- Mencatat CRUD buku, sampul opsional, awalan QR custom, QR unik per eksemplar, cetak QR, stok +1/-1 melalui arsip lunak, pengembalian sebagian, kehilangan, dan sesi pembelajaran.
- Menambahkan tabel batas pembuktian agar fitur yang tersedia pada kode tidak keliru dianggap sudah lulus integrasi Supabase nyata.

### Keputusan yang masih terbuka

- Aturan pelepasan claim siswa setelah akun ditolak belum diputuskan. PRD menyatakan alur daftar ulang belum final dan tidak menetapkan kebijakan baru.
- Notifikasi, penghapusan bukti terjadwal, serta laporan/arsip PDF dan CSV tetap berada pada tahap M4.

### Verifikasi

- App flow dicocokkan dengan navigasi dan halaman pada `apps/mobile/lib/features/server/server_shell.dart` serta `apps/mobile/lib/app/perpus_app.dart`.
- Tidak ada kode aplikasi atau database yang diubah pada sesi dokumentasi ini.

## 30 September 2026 — QR, sampul buku, dan peminjaman pembelajaran

### Perubahan

- Memperbaiki layar tampil QR eksemplar agar terbuka sebagai halaman tersendiri, dengan tombol cetak.
- Menambahkan kolom awalan QR khusus pada formulir tambah buku. Nomor eksemplar ditambahkan otomatis dan tetap unik.
- Menghilangkan spinner pencarian QR setelah hasil ditemukan, tidak ditemukan, atau pencarian gagal.
- Menambahkan pemilihan gambar sampul buku yang opsional. Jika gambar kosong, katalog memakai ikon bawaan demo. Gambar disimpan di bucket publik `book-covers`; upload dibatasi untuk pengurus.
- Menambahkan **Aktivitas → Pembelajaran** untuk membuat sesi kelas, memindai banyak buku, mencatat kelas/kegiatan/penanggung jawab/tenggat, dan memproses pengembalian per eksemplar dengan kondisi baik atau rusak.
- Mengganti label UI **Transaksi** menjadi **Aktivitas** di menu pengurus dan demo. Teks layar lain memakai istilah peminjaman/pengembalian yang lebih sesuai konteks perpustakaan. Nama teknis database tidak diubah.

### Database dan server

- Migrasi `202609300001_book_covers.sql` menambahkan `cover_path` dan bucket sampul.
- Migrasi `202609300002_classroom_loans.sql` menambahkan sesi pembelajaran, item eksemplar, akses admin, pencatatan audit, RPC pembuatan sesi, dan RPC pengembalian.
- Sebelum migrasi sampul dibuat backup `/opt/backups/perpus/pre-book-covers-20260930.dump`.
- Sebelum migrasi sesi pembelajaran dibuat backup `/opt/backups/perpus/pre-classroom-loans-20260930.dump`.
- Kedua migrasi diterapkan ke Supabase self-hosted. Keberadaan kolom, bucket, tabel, indeks, dan RPC sesi pembelajaran telah diperiksa.

### Verifikasi

- `flutter analyze`: tanpa temuan.
- APK debug berhasil dibangun dan dipasang pada perangkat Android terhubung.
- Pengguna sebelumnya mengonfirmasi alur scan QR dan pengajuan pinjaman anggota berhasil. Alur sesi kelas baru perlu dicoba pada perangkat.

### Keputusan produk

- Batas pinjaman anggota biasa tidak dinaikkan untuk mengakomodasi peminjaman kelas. Sesi pembelajaran adalah alur pengurus terpisah agar 20 atau lebih buku untuk kegiatan kelas tidak mengubah batas tiap anggota.
- Dokumentasi progres akan diperbarui pada setiap sesi perubahan selanjutnya.

## Catatan istilah untuk presentasi

Gunakan **Aktivitas** sebagai label menu. Di dalamnya gunakan **Pinjaman**, **Pengembalian**, **Kehilangan**, dan **Pembelajaran**. Hindari label bernuansa keuangan seperti *Transaksi* pada tampilan pengguna.
