# Verifikasi dan tindak lanjut fondasi M3 — 30 September 2026

## Ringkasan bukti

`scripts/verify.ps1` hanya menargetkan Flutter/Dart tests dan `scripts/sql-tests` lokal; tidak memuat URL Supabase, SSH, Docker, reset database, atau seed server. `npm ci` mengelola dependencies di `scripts/sql-tests/node_modules`. Karena itu baseline lokal aman dijalankan tanpa menyentuh database aktif.

| Pemeriksaan | Hasil | Bukti dan batas |
|---|---|---|
| Baseline `scripts/verify.ps1` | PASS | [Log baseline](baseline-2026-09-30.log): Flutter analyze/test, data-access, dan SQL/PGlite lulus sebelum perbaikan. |
| Flutter setelah perubahan | PASS | Full verifier terbaru: analyze dan Flutter tests lulus, termasuk regression timeout signup. |
| Data-access dan SQL/PGlite setelah perubahan | PASS | Full verifier terbaru: tests lulus; runner memuat archive, covers, classroom loans, dan inventory lock dengan assertion perilaku. PGlite bukan bukti concurrency atau integrasi GoTrue/Storage. |
| PostgreSQL dua koneksi — approval/archive | PASS setelah fix; FAIL sebelum fix | Cluster PostgreSQL 18 sementara. Sebelum migrasi lock, approval menghasilkan copy `borrowed` yang terarsip. Sesudahnya archive menolak dengan `Buku masih memiliki QR yang sedang dipinjam`; state `borrowed|false|false|1`. |
| PostgreSQL dua koneksi — approval pada copy sama | PASS | Satu request disetujui, satu active loan pada copy, status `borrowed`; request lain gagal tanpa loan kedua. |
| PostgreSQL dua koneksi — item ganda urutan berbeda | PASS | Satu approval pemenang, dua item active milik pemenang, kedua copy `borrowed`; kedua proses selesai dalam batas 20 detik, tidak ada deadlock. |
| Supabase aktif read-only | BLOCKED | SSH LAN `192.168.20.6:22` timeout. Jalur Access yang pernah diberikan tidak dapat meluncurkan `cloudflared.exe` (`CreateProcessW error 2`). Tidak ada query yang berhasil dijalankan di server. |
| Supabase terisolasi: GoTrue, RLS/RPC melalui API, Storage privat | BLOCKED | Tidak tersedia stack disposable/kredensial API uji. PGlite fixtures tidak menggantikan layanan nyata. |
| Pemindaian pola rahasia di source | PASS terbatas | Tidak ditemukan pola service-role/private-key/password dalam URL PostgreSQL pada `apps/mobile`, `packages`, `scripts`, `supabase`, atau `infra`. APK dan seluruh riwayat Git tidak dipindai; nama secret hanya muncul pada dokumentasi. |
| Kebijakan claim pending | MENUNGGU KEPUTUSAN | Tidak diubah. Pilihan yang perlu diputuskan ada pada [analisis identitas](02-identitas-dan-auth.md). |

Pemeriksaan tambahan selama pengerjaan: test cover upload awal di PGlite gagal dengan `permission denied for function is_eligible_member`; migrasi lock baru mengganti policy dengan predicate current-user terbatas, dan verifier akhir PASS. Percobaan pertama menyimpan log full verifier memakai path relatif gagal karena verifier berpindah direktori; dijalankan ulang dengan path log absolut dan seluruh tahap PASS. Kegagalan tooling tersebut tidak dihitung sebagai PASS.

## Perubahan kode

- Migrasi baru `supabase/migrations/202609300003_inventory_lock_protocol.sql` menetapkan urutan lock buku lalu copy dengan UUID menaik, mengunci seluruh item sebelum validasi, dan memvalidasi status sesudah lock. Approval, arsip buku/copy, serta pinjaman kelas memakai protokol tersebut. Migrasi terdahulu tidak diedit.
- Migrasi baru membatasi penambahan copy dan pengarsipan ke RPC berizin; RPC penambahan copy mengunci serta memeriksa buku sebelum memasukkan kode.
- `scripts/sql-tests/test.mjs` dan `supabase/verify_migration.sql` memeriksa migrasi dan perilaku archive, covers, classroom loans, serta grants/RLS terkait.
- Pesan timeout signup menyebut hasil belum dapat dipastikan dan mengarahkan cek email/pengurus. Tidak ditambah retry otomatis ataupun pencarian identitas publik.
- Detail concurrency harness ada di `scripts/postgres-concurrency/`; cluster uji sementara dibuat dan dihapus oleh runner, bukan memakai service PostgreSQL yang sudah berjalan.

## Cara mengulang

- Full verifier lokal: `scripts/verify.ps1`.
- PostgreSQL multi-connection: `scripts/postgres-concurrency/run.ps1`.
- Reproduksi regression sebelum fix (melewati hanya migrasi lock baru): `scripts/postgres-concurrency/run.ps1 -BeforeFix`. Hasil yang diharapkan adalah kegagalan assertion approval/archive, bukan PASS.
- Verifikasi server menggunakan `supabase/verify_migration.sql` hanya setelah jalur SSH pulih; SQL berisi assertion baca-saja.

## Langkah berikut

1. Pulihkan akses SSH read-only dan catat ledger migrasi/RLS/RPC server; jangan menerapkan migrasi saat verifikasi.
2. Siapkan Supabase Compose disposable dengan Auth, Storage, SMTP test inbox dan data sintetis. Uji anon, anggota A/B, admin, pemilik evidence, akses lintas anggota, dan RPC.
3. Minta keputusan aturan claim pending sebelum mengubah migrasi/policy identitas.
4. Setelah gerbang tersebut lulus, lanjutkan integrasi M3 di environment uji dan siapkan rencana penerapan terpisah.
