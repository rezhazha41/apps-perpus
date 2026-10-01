# Analisis identitas dan autentikasi

> **Addendum 30 September 2026:** test SQL lokal lulus; GoTrue nyata belum diuji. Perubahan claim ditahan sampai kebijakan berikut dipilih.

**Status:** audit read-only, 30 September 2026.

## Hasil per kebutuhan

| Area | Status | Bukti dan batas |
|---|---|---|
| Signup anggota NIS/NISN | Terbukti statis; runtime belum diuji | Trigger mencocokkan nomor identitas dengan registry dan membuat profil pending. |
| Aktivasi anggota | Terbukti statis; runtime belum diuji | RPC memeriksa admin/email terkonfirmasi, mengunci profil/siswa, lalu menghubungkan akun. |
| Maksimal satu akun aktif per siswa | Terbukti statis | Baris siswa dikunci saat aktivasi dan linked_user_id memiliki perlindungan unik. |
| Satu claim pending per siswa | Bermasalah | Claim pending tidak mengunci registry dan profiles.claimed_student_id tidak unique. |
| Login berdasarkan role | Terbukti sebagian | UI memeriksa role profil sesuai jalur login; hasil runtime belum diuji. |
| Reset password | Belum diuji end-to-end | UI memakai callback; SMTP, GoTrue, deep link, dan update password nyata belum diverifikasi. |
| Admin pertama | Implementasi tersedia; runtime belum terverifikasi | Ada skrip bootstrap/aktivasi. Audit tidak memastikan skrip tersebut sukses pada lingkungan yang dipakai. |

## Temuan P1: beberapa pendaftaran pending dapat mengklaim siswa yang sama

**Lokasi:** supabase/migrations/202609280001_identity_inventory.sql, fungsi private.create_member_profile; trigger diperbarui pada supabase/migrations/202609290002_staff_invites.sql.

Trigger memeriksa siswa aktif dan belum tertaut, lalu membuat profil berstatus pending. Identitas baru dikunci saat admin mengaktifkan profil. Karena itu NIS dan NISN milik siswa yang sama berpotensi membuat lebih dari satu akun pending.

Aktivasi tetap mencegah dua akun aktif tertaut ke siswa yang sama. Risiko adalah pendaftaran pending ganda, beban moderasi, dan konflik akun Auth.

**Tindak lanjut:** sebelum menambah constraint, sepakati apakah siswa boleh daftar ulang setelah ditolak dan bagaimana claim lama dilepas. Perubahan kebijakan belum dilakukan.

## Test lanjutan

### Keputusan kebijakan yang diperlukan — belum diubah

Pilih aturan untuk akun yang ditolak dan claim siswa sebelum perubahan migrasi:

1. **Lepas claim saat ditolak:** siswa dapat mendaftar lagi dengan NIS/NISN yang sama.
2. **Tahan sampai admin melepas:** penolakan mempertahankan claim; hanya tindakan admin eksplisit yang membuka pendaftaran ulang.
3. **Gunakan akun yang sama:** claim tetap terikat; siswa menghubungi pengurus untuk memperbaiki/mengaktifkan ulang akun tanpa akun Auth baru.

Untuk beberapa pendaftaran pending atas siswa yang sama, pilih juga: menolak pendaftaran kedua, atau mengizinkan beberapa claim tetapi hanya satu yang dapat diaktifkan. Sampai keputusan dibuat, behavior claim tidak diubah.

- Signup NIS dan NISN untuk satu siswa secara berurutan dan bersamaan.
- Dua akun pending mencoba aktivasi serentak; hanya satu boleh aktif.
- Reject lalu daftar ulang sesuai aturan yang disepakati.
- Akun belum/sudah konfirmasi email dan login melalui jalur role yang salah.
- Reset password melalui email dan deep link pada Supabase terisolasi.
- Bootstrap admin pertama di lingkungan uji.

PGlite bukan pengganti GoTrue/email nyata. Tidak ada test dijalankan ulang dalam audit ini.
