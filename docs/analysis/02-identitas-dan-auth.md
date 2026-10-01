# Analisis identitas dan autentikasi

> **Addendum 1 Oktober 2026:** kebijakan claim sudah dipilih dan diimplementasikan melalui migrasi baru. Satu siswa dibatasi satu claim `pending`/`active`; penolakan melepas claim; pengajuan ulang memakai akun yang sama. Pemulihan terbantu tersedia untuk siswa yang tidak dapat mengakses email. Detail dan bukti terbaru ada di [08-claim-dan-pemulihan-akun.md](08-claim-dan-pemulihan-akun.md). GoTrue/Edge Function nyata masih belum diuji.

**Status:** audit read-only, 30 September 2026.

## Hasil per kebutuhan

| Area | Status | Bukti dan batas |
|---|---|---|
| Signup anggota NIS/NISN | Terbukti statis; runtime belum diuji | Trigger mencocokkan nomor identitas dengan registry dan membuat profil pending. |
| Aktivasi anggota | Terbukti statis; runtime belum diuji | RPC memeriksa admin/email terkonfirmasi, mengunci profil/siswa, lalu menghubungkan akun. |
| Maksimal satu akun aktif per siswa | Terbukti statis | Baris siswa dikunci saat aktivasi dan linked_user_id memiliki perlindungan unik. |
| Satu claim pending per siswa | Terbukti lokal | Migrasi baru memakai lock registry dan indeks unik parsial; race PostgreSQL dua koneksi hanya menghasilkan satu pemenang. |
| Login berdasarkan role | Terbukti sebagian | UI memeriksa role profil sesuai jalur login; hasil runtime belum diuji. |
| Reset password | Belum diuji end-to-end | UI memakai callback; SMTP, GoTrue, deep link, dan update password nyata belum diverifikasi. |
| Admin pertama | Implementasi tersedia; runtime belum terverifikasi | Ada skrip bootstrap/aktivasi. Audit tidak memastikan skrip tersebut sukses pada lingkungan yang dipakai. |

## Temuan P1 historis: beberapa pendaftaran pending dapat mengklaim siswa yang sama

**Lokasi:** supabase/migrations/202609280001_identity_inventory.sql, fungsi private.create_member_profile; trigger diperbarui pada supabase/migrations/202609290002_staff_invites.sql.

Trigger memeriksa siswa aktif dan belum tertaut, lalu membuat profil berstatus pending. Identitas baru dikunci saat admin mengaktifkan profil. Karena itu NIS dan NISN milik siswa yang sama berpotensi membuat lebih dari satu akun pending.

Aktivasi tetap mencegah dua akun aktif tertaut ke siswa yang sama. Risiko adalah pendaftaran pending ganda, beban moderasi, dan konflik akun Auth.

**Tindak lanjut selesai secara lokal:** migrasi `202610010001_member_claim_recovery.sql` menolak claim kedua. Penolakan melepaskan claim dan akun yang sama dapat memakai `resubmit_member_application()`. Perubahan belum diterapkan ke server aktif.

## Test lanjutan

### Keputusan kebijakan

Pendaftaran kedua ditolak selama ada claim menunggu/aktif. Penolakan admin melepaskan claim, tetapi siswa diarahkan memperbaiki dan mengajukan ulang menggunakan akun Auth yang sama. Jika akses email hilang, pengurus memverifikasi identitas langsung dan menerbitkan kode pemulihan sekali pakai.

- Signup NIS dan NISN untuk satu siswa secara berurutan dan bersamaan.
- Dua akun pending mencoba aktivasi serentak; hanya satu boleh aktif.
- Reject lalu daftar ulang sesuai aturan yang disepakati.
- Akun belum/sudah konfirmasi email dan login melalui jalur role yang salah.
- Reset password melalui email dan deep link pada Supabase terisolasi.
- Bootstrap admin pertama di lingkungan uji.

PGlite bukan pengganti GoTrue/email nyata. Test SQL, Flutter, helper Edge Function, dan race PostgreSQL dua koneksi sudah dijalankan ulang pada 1 Oktober 2026; integrasi stack Supabase disposable masih BLOCKED.
