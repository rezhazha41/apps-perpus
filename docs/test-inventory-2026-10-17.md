# Test inventory dan baseline M3 — 17 Oktober 2026

Audit ini hanya menambah dokumentasi. Tidak ada perubahan pada kode produksi, UI, schema, RLS, atau RPC.

## Baseline aktual

| Target | Perintah | Hasil |
|---|---|---|
| Flutter app analyzer | `flutter analyze --no-pub apps/mobile` | **PASS**, no issues found |
| Flutter unit/widget suite | `cd apps/mobile; flutter test --no-pub` | **PASS**, 28 test |
| `packages/data_access` | `dart test` | **PASS**, 10 test |
| `packages/domain` | `dart analyze packages/domain` | **PASS**, no issues; belum memiliki direktori test |
| `packages/ui_kit` | `dart analyze packages/ui_kit` | **PASS**, no issues; belum memiliki direktori test |
| Supabase guard tests | `node --test scripts/supabase-integration/config.test.mjs scripts/active-server-fixture/lib.test.mjs` | **PASS**, 10 test |
| SQL/PGlite migration runner | `node scripts/sql-tests/test.mjs` | **PASS**; bukan bukti GoTrue/Storage/concurrency nyata |

Perintah `flutter analyze` dari root tidak dipakai sebagai bukti karena root monorepo tidak memiliki `pubspec.yaml`; analyzer package mobile dijalankan secara eksplisit.

## Inventory fitur

| Fitur | Test yang ada | Jenis | Risiko | Prioritas |
|---|---|---|---|---|
| Validasi signup/login dan route recovery | `widget_test.dart` | Widget/unit | Tinggi | P1 |
| Reset password dan assisted recovery | `widget_test.dart` | Widget | Tinggi | P1 |
| Signup timeout tidak auto-retry | `widget_test.dart` | Widget regression | Tinggi | P1 |
| Profil member pending/admin dan identitas tertaut | `profile_identity_test.dart`, `widget_test.dart` | Unit/widget | Tinggi | P1 |
| Refresh status akun | `account_status_refresh_test.dart` | Widget regression | Tinggi | P1 |
| Claim satu siswa per akun | SQL tests/migrasi | SQL/PGlite | Tinggi | P1 |
| RLS dan grant RPC | `verify_migration.sql`, SQL runner | SQL/PGlite | Tinggi | P1 |
| Katalog, stok, QR, duplicate scan | `demo_library_test.dart`, SQL tests | Unit/SQL | Tinggi | P1 |
| Keterlambatan dan batas pinjaman | `loan_predicates_test.dart`, `demo_library_test.dart` | Unit | Tinggi | P1 |
| Pengajuan bukti selfie/kartu | `loan_request_evidence_test.dart` | Widget | Tinggi | P1 |
| Persetujuan dan refresh status | SQL tests, redirect/widget tests | SQL/widget | Tinggi | P1 |
| Pengembalian sebagian/kondisi rusak | `demo_library_test.dart`, SQL tests | Unit/SQL | Tinggi | P1 |
| Kehilangan dan penyelesaian | `demo_library_test.dart`, SQL tests | Unit/SQL | Tinggi | P1 |
| Sesi pembelajaran QR fisik | SQL tests; E2E server aktif BLOCKED | SQL/manual | Tinggi | P1 |
| Sesi pembelajaran judul + jumlah | Migration loaded; runtime belum diuji | SQL/schema | Tinggi | P1 |
| Error timeout/offline Supabase nyata | Belum ada test runtime | Integrasi | Tinggi | P1 |
| GoTrue signup/confirm/reset nyata | Guard saja; disposable runtime belum dijalankan | Integrasi | Tinggi | P1 |
| Storage privat lintas anggota | SQL/PGlite guard; runtime nyata belum dijalankan | Integrasi | Tinggi | P1 |
| `packages/domain` business rules | Tidak ada test package khusus | Unit | Sedang | P2 |
| `packages/ui_kit` theme/widgets | Tidak ada test package khusus | Widget/golden | Sedang | P2 |
| PDF/cetak QR dan laporan | Belum ada test otomatis | Widget/integration | Sedang | P2 |
| Notifikasi dan scheduler | Belum diimplementasikan | Integrasi | Rendah untuk M3 | P3 |

## Gap dan rencana penambahan test

### P1 — sebelum mengandalkan integrasi M3

1. Tambahkan test integrasi pada Supabase disposable untuk GoTrue: signup, konfirmasi, login, reset, timeout, dan sesi kedaluwarsa.
2. Tambahkan test Storage privat: upload anggota A, akses A, penolakan anggota B/anon, dan pengurus.
3. Uji RPC approval/return/classroom pada PostgreSQL dua koneksi dengan data sintetis.
4. Uji mode classroom judul + jumlah: stok cukup, stok kurang, retry idempotensi, dan dua permintaan bersamaan.
5. Tambahkan test error mapping untuk timeout, offline, permission denied, dan respons malformed tanpa mengubah pesan produk yang sudah disetujui.

### P2 — penguatan package dan widget

1. Buat test unit `packages/domain` untuk `borrowingBlock`, status pinjaman, kehilangan, dan batas jumlah.
2. Buat widget test `packages/ui_kit` untuk tema, status pill, empty state, dan ukuran target interaksi.
3. Tambahkan test form katalog untuk field wajib, kategori, QR custom, stok `-1/+1`, dan error duplicate QR.

### P3 — pelengkap

- Golden test layout yang sudah dipresentasikan.
- Test PDF A4/F4 dan QR massal.
- Test notifikasi setelah scheduler tersedia.

## Penilaian baseline

- **PASS:** analyzer semua package, suite Flutter, test data access, guard test, dan SQL/PGlite runner.
- **BLOCKED/NOT RUN:** integrasi GoTrue, Storage, Edge Function, timeout jaringan nyata, serta concurrency pada server Supabase disposable.
- **Tidak ada FAIL production code** pada baseline ini. Karena tidak ada kegagalan yang direproduksi, tidak dibuat regression test baru pada fase audit ini.

## Batas verifikasi

PGlite dan SQL smoke test membuktikan parsing migrasi serta sebagian perilaku database, tetapi tidak membuktikan GoTrue, Storage, jaringan, atau lock PostgreSQL multi-koneksi nyata. Build APK dan pengujian perangkat tidak dijalankan pada audit ini.
