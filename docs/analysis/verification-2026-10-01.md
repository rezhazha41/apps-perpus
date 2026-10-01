# Verifikasi fondasi M3 — 1 Oktober 2026

## Addendum claim dan pemulihan akun

Setelah kebijakan pengguna disetujui, migrasi claim/pemulihan, Edge Function, UI anggota/pengurus, dan test terkait ditambahkan. `scripts/verify.ps1` PASS setelah runner dibuat mandiri terhadap PATH minimal Windows. Hasil gabungan: Flutter analyze bersih, 9/9 widget test, 10/10 data-access test, SQL/RLS/RPC PASS, 7/7 guard integrasi PASS, serta 4/4 helper Edge Function PASS. PostgreSQL dua koneksi juga membuktikan dua signup atas siswa yang sama hanya menghasilkan satu claim menunggu.

Preflight server aktif hanya menjalankan SELECT dan menemukan `duplicate_open_claim_groups=0`, `recovery_table_present=false`, serta `claim_index_present=false`. Migrasi dan Edge Function tidak diterapkan. Detail ada di [08-claim-dan-pemulihan-akun.md](08-claim-dan-pemulihan-akun.md).

## Ringkasan

Pemeriksaan server read-only kini dapat dijalankan melalui Cloudflare SSH. Hasilnya menunjukkan migrasi archive, cover, dan classroom loans sudah tersedia, tetapi migrasi `202609300003_inventory_lock_protocol.sql` belum aktif. Tidak ada migrasi, seed, atau perubahan data yang dijalankan di server.

Runner integrasi GoTrue/RLS/RPC/Storage nyata sudah disiapkan dengan guard yang menolak server aktif. Runtime end-to-end masih **BLOCKED** karena belum tersedia URL, anon key, dan service-role key untuk stack Supabase disposable.

## Hasil aktual

| Pemeriksaan | Status | Bukti |
|---|---|---|
| SSH Cloudflare menuju server aktif | PASS | Perintah read-only mencapai container database. Jalur memakai executable Cloudflared Windows dengan short path. |
| `supabase/verify_migration.sql` pada server aktif | FAIL | Berhenti pada `Client can add copies outside the inventory RPC`. Exit psql 3. |
| Migrasi archive book | PASS tersedia | RPC `archive_book(uuid)` ditemukan. |
| Migrasi cover buku | PASS tersedia | Kolom `books.cover_path` dan bucket publik `book-covers` ditemukan. |
| Migrasi classroom loans | PASS tersedia | Tabel classroom dan RPC `create_class_loan` ditemukan. |
| Migrasi lock inventaris terbaru | FAIL belum aktif | `private.lock_inventory_copies(uuid[])` dan `public.add_book_copies(uuid,text[])` tidak ditemukan. Hak insert kolom `book_copies.book_id/code`, policy `copies_insert`, dan hak update `books.archived_at` masih ada. |
| Bucket bukti pinjaman privat | PASS konfigurasi | Bucket `loan-evidence` ditemukan dengan `public=false`; perilaku API lintas pengguna belum diuji. |
| Full verifier lokal | PASS | Flutter analyze bersih; 7 test mobile, 9 test data-access, SQL/PGlite, dan test guard integrasi lulus. |
| Unit test guard runner integrasi | PASS | 7/7 test lulus; line coverage 100%, branch coverage 91,30%, function coverage 100%. Mencakup marker disposable, URL/protokol, penolakan hostname aktif, konfirmasi remote, key berbeda, normalisasi URL, dan sensor secret/token. |
| Syntax runner integrasi | PASS | `node --check` lulus untuk runner dan helper. |
| Eksekusi runner tanpa kredensial uji | BLOCKED aman | Berhenti sebelum network dengan pesan marker disposable belum diberikan. |
| GoTrue/RLS/RPC/Storage nyata pada stack terisolasi | BLOCKED | Membutuhkan environment uji terpisah dan tiga variabel koneksi. |
| Kebijakan claim siswa ditolak/daftar ulang | PASS lokal | Satu claim terbuka, penolakan melepas claim, dan akun yang sama dapat mengajukan ulang. Server aktif belum dimigrasi. |
| Pemulihan tanpa akses email | PASS lokal / BLOCKED integrasi | UI, SQL, Edge Function, dan unit test tersedia; GoTrue/Edge Function nyata menunggu stack disposable. |

Output mentah server: [server-read-only-2026-10-01.log](server-read-only-2026-10-01.log).

## Perubahan

- `scripts/supabase-integration/` menambahkan runner data sintetis untuk anon, anggota A, anggota B, dan admin.
- Runner memeriksa signup dengan identitas acak, aktivasi anggota, isolasi RLS, Storage evidence privat, pengajuan pinjaman, persetujuan RPC, dan status QR buku.
- Guard selalu menolak hostname server Perpus aktif, meminta konfirmasi tambahan untuk target remote, mengambil key dari environment, dan menyensor key/bearer token pada error.
- `scripts/verify.ps1` kini menjalankan unit test guard tanpa mencoba integrasi jaringan.
- `supabase/MIGRATIONS.md` kini memuat urutan archive, covers, classroom loans, dan inventory lock sesuai dependensi aktual.

## Kebutuhan konkret agar integration test dapat berjalan

Siapkan satu stack Supabase yang terpisah dan boleh dibuang, terapkan seluruh migrasi, kemudian pasang environment berikut hanya pada proses test:

- `PERPUS_TEST_CONFIRM=isolated-disposable`
- `PERPUS_TEST_SUPABASE_URL`
- `PERPUS_TEST_ANON_KEY`
- `PERPUS_TEST_SERVICE_ROLE_KEY`
- `PERPUS_TEST_REMOTE_ISOLATED=yes` jika bukan localhost

Nilai key tidak boleh dimasukkan ke Git, dokumentasi, Flutter, atau log.

## Penilaian kesiapan M3

Fondasi kode dan concurrency lokal siap untuk tahap integrasi, tetapi server aktif belum siap memakai protokol lock terbaru. Integrasi M3 belum dapat dinyatakan lulus sampai migrasi lock diterapkan melalui rencana perubahan terpisah dan seluruh test GoTrue/RLS/RPC/Storage pada stack disposable PASS.
