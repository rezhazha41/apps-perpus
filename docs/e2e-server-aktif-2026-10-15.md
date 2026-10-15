# Laporan E2E Server Aktif — 2026-10-15

## Lingkup

Pengujian dilakukan pada aplikasi Flutter terpasang di perangkat Android `itel A665L` terhadap Supabase self-hosted aktif melalui LAN/Nginx Proxy Manager. Data uji memakai fixture sintetis bertanda `TEST-E2E-20261015`; data nyata tidak diubah.

Backup sebelum pengujian: `/opt/backups/perpus/perpus-pre-e2e-20261015132200.dump` (dibuat dan tervalidasi di server).

## Hasil

| Kasus | Status | Bukti |
|---|---|---|
| Login anggota sintetis | PASS | Akun fixture berhasil masuk dan identitas tampil di header. |
| QR katalog dan scan anggota | PASS | Dua QR fixture terdeteksi; detail buku tampil. |
| Wajib memilih jenis bukti | PASS | Tombol kirim tetap nonaktif sebelum selfie/kartu dipilih. |
| Selfie dan penyimpanan bukti privat | PASS | Selfie diterima; pengurus dapat membuka bukti melalui aktivitas. |
| Pengajuan pinjaman | PASS | Baris request `pending`; stok tetap `2/2`. |
| Persetujuan pengurus | PASS | Request menjadi `approved`; QR-01 menjadi `borrowed`; stok `1 available/1 borrowed`. |
| Permintaan pengembalian | PASS | Request pengembalian tampil dan diproses melalui scanner kondisi baik. |
| Pengembalian kondisi baik | PASS | QR-01 menjadi `available`; loan item `completed/received`; stok kembali `2 available`. |
| Lapor kehilangan anggota | PASS | Laporan berstatus `reported` dengan deskripsi sintetis. |
| Verifikasi dan penyelesaian kehilangan | PASS | Laporan `resolved`; QR-01 berubah menjadi `lost`; catatan penyelesaian tersimpan. |
| Pinjaman pembelajaran | BLOCKED | Form sesi terbuka, tetapi pemindaian QR-02 memerlukan kamera/perangkat kedua; hanya satu perangkat ADB tersedia sehingga sesi tidak disimpan. |
| Arsip fixture | PASS | QR-01 dan QR-02 diarsipkan; akun/profil dan student registry fixture dinonaktifkan. |

## Bukti artefak

Artefak layar dan XML berada di `artifacts/e2e-2026-10-15/`, termasuk `12-request-submitted.png`, `17-staff-evidence-view.png`, `22-return-scanner-current.png`, `24-after-return-scan.png`, `26-loss-loan-pending.png`, `27-qr02.png`, dan `28-learning-scanner.png`.

## Catatan risiko

- Kasus pembelajaran belum terbukti end-to-end karena keterbatasan perangkat, bukan kegagalan backend.
- Akun admin yang dipakai untuk pengujian pernah dibagikan di percakapan; ganti kata sandinya setelah sesi ini.
- Pengujian ini tidak membuktikan concurrency dua operator atau pemulihan jaringan offline.

## Tindak lanjut

1. Jalankan ulang sesi pembelajaran dengan perangkat kamera kedua dan verifikasi tabel `classroom_loans`/`classroom_loan_items`.
2. Tambahkan regression test untuk refresh setelah persetujuan/peminjaman agar status tidak dapat dispam dari UI lama.
3. Pertahankan backup dan arsip fixture sebagai bukti audit presentasi.
