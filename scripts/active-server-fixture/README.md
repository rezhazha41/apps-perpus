# Fixture manual pada server aktif

Script ini khusus keputusan hybrid manager: membuat satu akun anggota sintetis, satu buku, dan dua QR pada server aktif; setelah test, data dinonaktifkan/diarsipkan tanpa menghapus riwayat. Script **tidak berjalan tanpa** argumen `--apply` dan konfirmasi yang terikat ke hostname server.

Setup memakai Auth Admin API dan PostgREST service-role. Akun langsung dibuat aktif agar sesi manual berfokus pada pengajuan pinjaman → persetujuan pengurus, bukan pengujian pendaftaran anggota. Service-role key dan password hanya dibaca dari environment dan tidak dicetak.

## Review sebelum eksekusi

1. Review `setup.mjs`, `archive.mjs`, dan [checklist manager](../../docs/checklist-manual-server-aktif.md).
2. Pastikan backup server aktif tersedia.
3. Pilih tag, NIS, dan email baru yang jelas sintetis. Jangan menggunakan domain/email milik siswa nyata.
4. Eksekusi hanya setelah manager menyetujui. Jangan menjalankan script melalui terminal yang direkam atau dibagikan.

## Environment runtime

```powershell
$env:PERPUS_ACTIVE_SUPABASE_URL = 'https://HOST-SUPABASE-AKTIF'
$env:PERPUS_ACTIVE_FIXTURE_CONFIRM = 'reviewed-active:host-supabase-aktif'
$env:PERPUS_ACTIVE_SERVICE_ROLE_KEY = '<ambil dari secret manager saat eksekusi>'
$env:PERPUS_FIXTURE_TAG = 'TEST-MGR-001'
$env:PERPUS_FIXTURE_NIS = '990001'
$env:PERPUS_FIXTURE_EMAIL = 'test-mgr-001@example.invalid'
$env:PERPUS_FIXTURE_PASSWORD = '<password sementara minimal 12 karakter>'
```

Nilai konfirmasi memakai hostname huruf kecil tanpa `https://`. Contoh URL `https://sup.example.id` membutuhkan `reviewed-active:sup.example.id`.

## Perintah setelah approval manager

```powershell
node scripts/active-server-fixture/setup.mjs --apply
```

Jika setup gagal setelah sebagian data dibuat, simpan tag/NIS/email yang sama dan jalankan archive. Script archive juga menangani fixture parsial yang masih memiliki penanda exact.

Sesudah seluruh checklist selesai, pastikan tidak ada pengajuan pending atau QR yang masih dipinjam, logout akun fixture dari HP, lalu:

```powershell
node scripts/active-server-fixture/archive.mjs --apply
```

Archive mengubah profil menjadi `inactive`, registry siswa menjadi tidak aktif, buku dan QR menjadi arsip lunak, serta mem-ban akun Auth selama 100 tahun. Riwayat transaksi dan bukti tidak dihapus; retensinya tetap mengikuti kebijakan server.

## Pemeriksaan lokal tanpa server

```powershell
node --test scripts/active-server-fixture/lib.test.mjs
node --check scripts/active-server-fixture/setup.mjs
node --check scripts/active-server-fixture/archive.mjs
```
