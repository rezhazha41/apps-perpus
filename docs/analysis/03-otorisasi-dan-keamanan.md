# Analisis otorisasi backend dan keamanan

> **Pembaruan 30 September 2026:** assertions RLS/RPC lokal lulus untuk fixture SQL/PGlite. Pemindaian pola service-role/private key di source tidak menemukan kecocokan; APK dan riwayat Git belum dipindai. Supabase API/Storage nyata dan konfigurasi server aktif belum terverifikasi; detail dan blocker ada di [bukti verifikasi](verification-2026-09-30.md).

**Status:** audit read-only, 30 September 2026.

## Hasil

- Migrasi yang dibaca memakai RPC terotorisasi untuk aktivasi anggota, persetujuan, perubahan status copy, dan operasi pinjaman.
- Grant yang diperiksa membatasi client dari mengubah role, menautkan siswa langsung, mengubah status stok, atau menulis pinjaman di luar RPC.
- RLS mengisolasi profil/request/evidence anggota dan memberi admin akses review sesuai kebijakan.
- Bucket loan-evidence didefinisikan private; kebijakan select membatasi pemilik dan admin. Insert mengikat owner dan folder ke akun anggota.
- Grants/policies aktif pada server tidak diverifikasi langsung.

## Status kontrol

| Kontrol | Status |
|---|---|
| Klien tidak dapat menaikkan role sendiri | Terbukti pada grant/RPC yang dibaca; server belum diverifikasi |
| Klien tidak dapat menautkan registry siswa langsung | Terbukti pada grant/RPC yang dibaca; server belum diverifikasi |
| Status copy hanya diubah lewat backend | Terbukti pada grant/RPC yang dibaca; server belum diverifikasi |
| Evidence tidak publik | Terbukti pada definisi migrasi; Storage API nyata belum diuji |
| Service-role secret di sumber yang diperiksa | Tidak ditemukan |
| Secret di APK/riwayat Git | Belum diperiksa |

Mobile config memuat URL Supabase dan publishable key untuk client. Kunci publik bukan service-role secret dan bukan lapisan otorisasi; RLS tetap wajib. Nilai kunci tidak disalin ke dokumen ini.

## Test yang disarankan

1. Uji role anon, member A, member B, dan admin pada Supabase terisolasi.
2. Coba direct update role, link siswa, stock status, loan request, dan loan items sebagai member; operasi harus ditolak.
3. Uji akses metadata dan object Storage antaranggota serta oleh admin.
4. Periksa grants, policies, bucket visibility, dan function privileges server secara read-only.
5. Scan source/config dan APK untuk service-role key, JWT rahasia, password database, SMTP credentials, dan secret backend.
