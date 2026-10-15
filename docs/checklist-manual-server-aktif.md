# Checklist manual test — server aktif

**Fixture:** `TEST-________`  
**Tester:** manager (remote pada HP boss)  
**Tanggal/Jam WIB:** `________`  
**Versi aplikasi:** `________`

> Gunakan hanya akun, buku, kartu bukti, dan QR berlabel `TEST-...`. Jangan memakai identitas/foto siswa nyata. Password dan service-role key tidak boleh ditempel ke chat, screenshot, atau dokumen hasil test.

## Persiapan dan bukti awal

- [ ] Manager sudah mereview `scripts/active-server-fixture/setup.mjs` dan `archive.mjs`.
- [ ] Backup server terbaru tersedia dan aplikasi HP boss terhubung ke server aktif melalui Wi-Fi/LAN → NPM/HTTPS → Supabase.
- [ ] Setup dijalankan oleh operator tepercaya dengan tag/NIS/email unik; output `FIXTURE READY` disimpan tanpa password/key.
- [ ] Dua QR terlihat jelas sebagai `TEST-...-QR-01` dan `TEST-...-QR-02` (boleh dicetak atau ditampilkan di layar lain).
- [ ] Siapkan kartu bukti sintetis bertuliskan tag fixture; jangan gunakan selfie atau kartu siswa nyata.
- [ ] Catat stok awal buku fixture: **2 tersedia**.

## Alur anggota dan persetujuan pengurus

- [ ] Login sebagai akun anggota `TEST-...`; halaman anggota terbuka tanpa status pending/error.
- [ ] Katalog menampilkan buku `TEST-... BUKU UJI` dengan stok **2**.
- [ ] Scan `QR-01`; hasil menampilkan buku fixture dan status tersedia, tanpa data pribadi anggota.
- [ ] Ajukan pinjaman `QR-01` dengan metode **kartu pelajar** memakai kartu bukti sintetis.
- [ ] Aplikasi menampilkan bahwa pengajuan menunggu verifikasi pengurus.
- [ ] Sebelum disetujui, stok tetap **2** dan `QR-01` tetap tersedia.
- [ ] Logout anggota, login sebagai pengurus, lalu buka antrean pengajuan.
- [ ] Detail pengajuan menunjukkan akun/buku/QR fixture yang tepat; bukti sintetis hanya dapat dilihat pengurus.
- [ ] Setujui pengajuan `QR-01`; antrean hilang dan riwayat mencatat persetujuan pengurus.
- [ ] Stok berubah menjadi **1** dan `QR-01` berstatus dipinjam.
- [ ] Login kembali sebagai anggota; pinjaman aktif, judul, kode QR, dan jatuh tempo tampil benar.

## Pengembalian dan jalur penolakan

- [ ] Ajukan pengembalian `QR-01`, lalu proses sebagai pengurus dengan scan QR fisik.
- [ ] Pinjaman selesai; stok kembali **2** dan `QR-01` tersedia.
- [ ] Sebagai anggota, ajukan pinjaman `QR-02` memakai kartu bukti sintetis.
- [ ] Sebagai pengurus, tolak pengajuan `QR-02` dengan alasan `TEST - jalur penolakan`.
- [ ] Stok tetap **2**, `QR-02` tersedia, dan keputusan penolakan tampil pada riwayat/status anggota.
- [ ] Tidak ada pengajuan fixture berstatus pending dan tidak ada QR fixture berstatus dipinjam.

## Hasil dan archive wajib

- [ ] Catat hasil tiap langkah: **LULUS/GAGAL**, waktu WIB, dan pesan error persis bila gagal.
- [ ] Screenshot hanya layar yang diperlukan; pastikan tidak memuat password, key, atau data siswa nyata.
- [ ] Jika ada kegagalan, hentikan alur terkait dan jangan mengubah data nyata untuk “memperbaiki” fixture.
- [ ] Logout akun fixture dari HP.
- [ ] Operator menjalankan `archive.mjs --apply`; harus keluar `FIXTURE ARCHIVED`.
- [ ] Verifikasi akun fixture tidak dapat login, buku/QR tidak tampil di katalog aktif, dan riwayat transaksi fixture tetap tersedia bagi pengurus.

## Ringkasan

- **Hasil keseluruhan:** `LULUS / GAGAL / TERHAMBAT`
- **Langkah gagal:** `________`
- **Pesan error:** `________`
- **Bukti/screenshot:** `________`
- **Archive selesai (WIB):** `________`
