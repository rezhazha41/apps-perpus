# Ringkasan status dan temuan

> **Pembaruan 30 September 2026:** suite lokal PASS; race approval/archive diperbaiki dan regression dua koneksi PASS. Claim pending belum diubah. Pemeriksaan server aktif serta integrasi GoTrue/Storage BLOCKED. Lihat [bukti verifikasi](verification-2026-09-30.md).

**Tanggal:** 30 September 2026  
**Cakupan:** PRD, dokumentasi, Flutter/mobile, packages, migrasi, RLS/RPC, dan sumber test. Read-only; test tidak dijalankan ulang.

## Kesimpulan

Implementasi M1–M2 tersedia untuk autentikasi, aktivasi anggota, katalog/inventaris, QR, serta pembatasan backend. Pembacaan kode dan fixture tidak membuktikan semua alur lulus pada Supabase server/perangkat saat ini.

M3 sudah memiliki bagian implementasi: pengajuan pinjaman, bukti foto privat, persetujuan, pengembalian per eksemplar, dan pelaporan kehilangan. Race condition approval–archive serta kurangnya test multi-koneksi perlu dibereskan sebelum mengandalkan approval.

## Status kebutuhan

| Kebutuhan | Status | Catatan |
|---|---|---|
| Signup NIS/NISN | Terbukti statis; runtime belum diuji | Trigger mencocokkan registry; GoTrue/email nyata belum dibuktikan. |
| Aktivasi anggota dan konfirmasi email | Terbukti statis; runtime belum diuji | RPC mengecek admin dan email serta mengunci profil/siswa. |
| Jalur login anggota/pengurus | Terbukti sebagian | UI memeriksa role; backend server perlu diverifikasi. |
| Reset password/callback | Belum diuji end-to-end | SMTP, deep link dan GoTrue nyata belum dibuktikan. |
| Admin pertama | Implementasi ada; runtime belum diverifikasi | Ada skrip bootstrap/aktivasi, tetapi hasil runtime belum menjadi bukti audit. |
| Maksimal satu akun aktif per siswa | Terbukti statis | Aktivasi mengunci registry dan link memiliki unique protection. |
| Maksimal satu claim pending per siswa | Bermasalah | Dapat ada beberapa profil pending untuk siswa yang sama. |
| RLS dan pembatasan write | Terbukti pada grant/RPC yang diperiksa | Perlu cocokkan dengan skema server aktif. |
| Inventaris dan QR unik | Terbukti statis; data aktual belum diuji | Unique copy code dan status dikelola backend. |
| Error/offline/timeout/lifecycle | Bermasalah sebagian | Pesan timeout signup mengasumsikan akun tidak tercatat. |
| Rahasia backend | Tidak ditemukan di sumber yang diperiksa | APK dan seluruh riwayat Git belum dipindai. |

## Temuan prioritas

- **P1 — Approval melawan archive:** lock kedua RPC tidak diserialisasi melalui baris/urutan yang sama. Detail di [inventaris dan QR](04-inventaris-dan-qr.md).
- **P1 — Claim pending ganda:** beberapa akun dapat mengklaim siswa sama sebelum aktivasi. Detail di [identitas dan autentikasi](02-identitas-dan-auth.md).
- **P1 — Gap cakupan test:** runner tidak memuat semua migrasi terbaru dan tidak menguji Supabase nyata/multi-koneksi. Detail di [kesiapan M3](06-kesiapan-m3-dan-test-plan.md).
- **P2 — Pesan timeout signup keliru:** hasil timeout tidak memastikan akun gagal dibuat. Detail di [reliability Flutter](05-reliability-flutter.md).
- **P2 — CRUD buku parsial:** insert buku, upload cover, dan insert eksemplar adalah operasi terpisah. Detail di [inventaris dan QR](04-inventaris-dan-qr.md).

## Penghalang M3

1. Perbaiki dan uji concurrency approval–archive dengan dua koneksi.
2. Putuskan aturan claim pending/daftar ulang, lalu uji NIS dan NISN siswa yang sama.
3. Jalankan test suite saat ini dan simpan hasil aktual.
4. Verifikasi skema/RLS/RPC server secara read-only.
5. Uji bucket bukti dengan Storage Supabase nyata di environment terisolasi.
