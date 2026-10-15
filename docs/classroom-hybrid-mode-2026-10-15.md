# Mode Hybrid Sesi Pembelajaran — 15 Oktober 2026

## Keputusan produk

Sesi pembelajaran memiliki dua cara pemilihan buku:

1. **QR fisik satu per satu** untuk pengurus yang perlu menentukan eksemplar tertentu.
2. **Judul dan jumlah** untuk mengambil beberapa buku dari judul yang sama tanpa memindai setiap QR.

Mode kedua tetap memilih QR fisik yang tersedia di server. Jadi pencatatan inventaris tetap per eksemplar, sementara proses kelas menjadi lebih cepat.

## Perubahan implementasi

- Migrasi baru `supabase/migrations/202610150001_classroom_book_quantity.sql` menambahkan RPC `create_class_loan_by_book`.
- RPC memeriksa peran pengurus, idempotency key, metadata sesi, tenggat, buku aktif, dan jumlah tersedia.
- Eksemplar dikunci dan dialokasikan atomik berdasarkan `book_id`; jika jumlah tidak cukup, seluruh operasi gagal tanpa perubahan parsial.
- `apps/mobile/lib/features/server/server_shell.dart` menambahkan pilihan mode, dropdown judul, input jumlah, dan tetap mempertahankan pemindaian QR fisik.
- `scripts/sql-tests/test.mjs` sekarang memuat migrasi baru pada runner SQL.

## Verifikasi

- `dart analyze apps/mobile`: **PASS**, exit code 0. Satu info deprecation pada `DropdownButtonFormField.value`; tidak ada error.
- `node scripts/sql-tests/test.mjs`: **PASS**. Smoke test migrasi dan perilaku yang ada tetap lulus.
- Server aktif: fungsi `public.create_class_loan_by_book(...)` terdeteksi dan memiliki signature yang sesuai.
- Build APK dan instalasi ke HP: **TIDAK DIJALANKAN** sesuai instruksi pengguna.

## Catatan migrasi server

Validasi awal memakai pembungkus transaksi, tetapi file migrasi memiliki `BEGIN/COMMIT` internal. PostgreSQL memperingatkan transaksi bersarang dan fungsi akhirnya tetap terpasang di server aktif. Tidak ada data buku atau sesi pembelajaran yang dibuat oleh validasi tersebut. Migrasi tidak dijalankan ulang.

## Belum diverifikasi

- Uji runtime mode judul dan jumlah pada server aktif dengan data sintetis.
- Uji konkurensi dua sesi yang meminta eksemplar terakhir.
- Uji UI pada perangkat Android setelah APK dibangun dan dipasang.

## Langkah berikutnya

Setelah pengguna mengizinkan build/install, jalankan uji manual sesi pembelajaran: pilih satu judul, jumlah lebih kecil dari stok, pastikan sesi tercatat dan stok berkurang sesuai jumlah; lalu uji jumlah melebihi stok dan pastikan transaksi ditolak tanpa perubahan parsial.
