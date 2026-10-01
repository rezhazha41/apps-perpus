# Migrasi pertama lewat Supabase Studio

Target yang diberikan pengguna: `https://sup.tunneladguard.xyz`, berjalan di server lokal/LAN. Migrasi `202609280001_identity_inventory.sql` sudah diterapkan dari laptop melalui SSH ke `/opt/stacks/supabase/supabase-project`, pada database Supabase `postgres` (28 September 2026).

Preflight sebelum migrasi menemukan seluruh layanan Docker sehat, database memiliki nol tabel di `public`/`private`, nol akun Auth, nol trigger Auth eksternal, dan belum ada nama tabel Perpus yang digunakan. Migrasi selesai dengan `COMMIT`. `verify_migration.sql` kemudian menghasilkan `PASS`: keenam tabel ada, RLS aktif, policies tersedia, akses anon ditolak, kolom role/link/status stok dibatasi, trigger signup aktif, RPC admin tersedia, dan baris pengaturan awal tercatat.

Pada 29 September 2026, migrasi aditif `202609290001_staff_admin_operations.sql`, `202609290002_staff_invites.sql`, dan `202609290003_operator_provisioned_auth_users.sql` diterapkan setelah backup database. Backup privat berada di `/opt/stacks/supabase/backups/perpus-pre-admin-operations-20260929.dump` (mode 600). `verify_staff_admin.sql` lulus: registry staf dan RLS tersedia, klien tidak dapat mengubah identitas/token staf, RPC undangan dan arsip tersedia, dan 100 data siswa tetap utuh. Admin `rezhazha314@gmail.com` sudah memiliki undangan registry bootstrap yang masih berlaku, tetapi belum ada Auth user/profil tertaut. Operator perlu mengundang email tersebut melalui Studio, lalu menjalankan `activate_first_admin.sql` setelah email dikonfirmasi.

Gunakan SQL Editor pada Studio instance yang khusus Perpus. Akun Studio/operator database diperlukan untuk menjalankan DDL; publishable/anon key tidak memberikan hak migrasi.

1. Buka SQL Editor → query baru, tempel seluruh isi [preflight.sql](../supabase/preflight.sql), lalu Run. Ini pemeriksaan baca saja. Jika ada tabel aplikasi lain, trigger signup lain, atau tabel Perpus yang sudah ada, tinjau hasil sebelum menerapkan migrasi. Jangan menghapus atau menimpa tabel untuk mengatasi konflik.
2. Pada instance khusus Perpus dengan target yang belum dimigrasi, buat query baru dan jalankan **seluruh** isi [migrasi awal](../supabase/migrations/202609280001_identity_inventory.sql), termasuk `begin` dan `commit`. Migrasi memasang aturan pendaftaran NIS/NISN pada Auth instance tersebut.
3. Jalankan [verify_migration.sql](../supabase/verify_migration.sql). Hasil harus PASS, enam tabel memiliki RLS aktif, dan masing-masing memiliki policy. Ini pemeriksaan struktur dan privilege, bukan pengujian integrasi seluruh aplikasi.
4. Data fiktif [seed.sql](../supabase/seed.sql) hanya dimasukkan jika diperlukan pada database pengembangan. Tidak wajib untuk memasang skema. Bootstrap akun admin dijelaskan pada [database.md](database.md).

Migrasi ini dijalankan sekali. Bila muncul error, simpan teks error dan hentikan; jangan jalankan bagian-bagian sisanya secara terpisah. SQL berada dalam transaksi sehingga kegagalan membatalkan perubahan transaksi. Bila SQL Editor masih menyimpan transaksi gagal, jalankan `rollback;` sebelum query baru. Akun Auth yang sudah ada tidak otomatis mendapat profil dari trigger baru.

Jangan menempelkan `supabase/tests/identity_inventory.sql` langsung ke Studio: file itu untuk psql/database pengembangan terisolasi dan berisi perintah khusus psql. Gunakan verify_migration.sql untuk pemeriksaan Studio.
