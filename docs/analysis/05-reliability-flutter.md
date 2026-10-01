# Analisis reliability Flutter

> **Addendum 30 September 2026:** pesan timeout signup sudah diubah agar menyatakan hasil belum pasti; regression widget test dan full Flutter analyze/test lulus. Tidak ada retry otomatis atau endpoint lookup identitas publik.

**Status:** audit read-only, 30 September 2026.

## Temuan P2: pesan timeout signup memberi kepastian keliru

**Lokasi:** apps/mobile/lib/features/auth/auth_pages.dart, fungsi _authMessage.

Pesan timeout menyatakan akun belum tercatat. Timeout hanya menunjukkan aplikasi tidak menerima hasil tepat waktu; server mungkin sudah membuat akun dan mengirim/menjadwalkan konfirmasi. Pengguna dapat mencoba lagi dan mendapat konflik akun/email sudah terdaftar.

**Saran:** nyatakan hasil signup belum dapat dipastikan dan arahkan pengguna memeriksa email atau meminta admin memeriksa status. Jangan menambahkan endpoint lookup identitas publik.

## Observasi yang belum terkonfirmasi sebagai bug

- Banyak handler async mengecek mounted sebelum setState atau navigasi.
- Scanner dan form meng-dispose controller.
- Beberapa halaman data menyediakan loading, error, dan retry.
- Tidak terlihat timeout aplikasi yang konsisten untuk seluruh permintaan Supabase. Tidak ada request menggantung yang direproduksi, sehingga ini gap verifikasi, bukan bug runtime terkonfirmasi.
- Offline/timeout upload foto, pengajuan, approval, dan QR belum diuji end-to-end.
- Sign out saat idle dan offline perlu diuji agar state lokal tidak membingungkan pengguna.

## Test plan

1. Putuskan jaringan saat signup, login, reset, upload bukti, dan baca katalog.
2. Simulasikan timeout setelah server menerima signup; UI harus menyatakan hasil belum pasti dan tidak retry otomatis.
3. Tutup halaman saat request berlangsung; pastikan tidak ada setState setelah dispose atau navigasi dari context tidak mounted.
4. Kembali dari background setelah idle dan jaringan putus; pastikan sesi dan error konsisten.
5. Uji retry operasi idempotent dan pastikan operasi lain tidak diduplikasi.
