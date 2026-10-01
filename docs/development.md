# Pengembangan Perpus

## Menjalankan fondasi demo

Dari PowerShell:

```powershell
cd D:\apps\Perpus\apps\mobile
& C:\flutter\bin\flutter.bat pub get
& C:\flutter\bin\flutter.bat run -d 108071544J008323
```

ID di atas adalah perangkat uji itel A665L, Android 13. Untuk HP lain lihat `flutter devices`. Minimum Android mengikuti template Flutter yang dicatat dalam proyek; uji perangkat versi minimum belum dilakukan.

```powershell
& C:\flutter\bin\flutter.bat analyze
& C:\flutter\bin\flutter.bat test
& C:\flutter\bin\flutter.bat build apk --debug
cd ..\..\packages\data_access
& C:\flutter\bin\dart.bat pub get
& C:\flutter\bin\dart.bat test
```

APK: `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`. APK debug hanya untuk pengujian, bukan distribusi produksi. Dependensi dikunci melalui pubspec.lock. Folder cache/build dan kredensial tidak masuk repository.

Untuk menjalankan rangkaian pemeriksaan aplikasi, aturan domain, dan SQL dari root repository: `powershell -File scripts/verify.ps1`. Pengujian SQL memakai Node.js/PGlite dan tidak memerlukan Docker; lihat batasannya pada database.md.

Pada mesin uji, wrapper sdkmanager terbaru gagal memasang NDK otomatis. Versi Flutter ini membutuhkan NDK 28.2.13676358. Pemasangan langsung berhasil mengekstrak paket yang diperlukan dengan:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\cmdline-tools\latest\bin\android.exe" sdk install 'ndk;28.2.13676358' --sdk "$env:LOCALAPPDATA\Android\Sdk"
```

Periksa `ndk/28.2.13676358/source.properties` setelah pemasangan; Android CLI pada mesin uji mengembalikan exit 1 meskipun file paket telah terpasang. Build Flutter berikutnya menentukan apakah instalasi bisa dipakai.

## Skenario tinjauan demo

1. Masuk sebagai anggota, cari Algoritma Dasar di Katalog.
2. Tambahkan BK-008 atau ketik kode pada simulasi scan. Pilih selfie/kartu OSIS dan gunakan bukti contoh.
3. Kirim pengajuan. Stok belum berubah.
4. Menu titik tiga → Demo: lihat sebagai admin → Transaksi → Setujui demo.
5. Kembali ke anggota. Pinjaman dan tenggat baru terlihat.
6. Ajukan kembali untuk satu buku. Admin memasukkan kode buku yang diterima, lalu pilih kondisi baik/rusak.
7. Pastikan buku lain masih dipinjam. Buku rusak tidak tersedia.
8. Laporan kehilangan tetap menjadi kewajiban hingga admin memverifikasi dan mencatat penyelesaian.

Simulasi tidak melakukan scan kamera, menyimpan foto, mengirim push, atau mempertahankan data setelah restart. Label demo tampil pada seluruh layar utama.

## Koneksi Supabase dan autentikasi

Aplikasi mobile sudah memakai `supabase_flutter`. URL API dan publishable key klien ditetapkan di `apps/mobile/lib/app/supabase_config.dart`; kunci tersebut memang kunci publik dan akses data tetap dibatasi oleh RLS. `main.dart` menginisialisasi Supabase dengan alur PKCE. Android memakai `id.perpus.perpus-mobile://login-callback` untuk konfirmasi akun dan callback khusus `id.perpus.perpus-mobile://reset-password` untuk pemulihan kata sandi, termasuk saat aplikasi dibuka dari keadaan tertutup. Form recovery mengenali callback PKCE meski event sesi selesai sebelum widget tampil. Sesi lokal anggota/pengurus berakhir otomatis setelah 24 jam tanpa aktivitas; waktunya tersimpan agar masa tidak aktif saat aplikasi ditutup ikut dihitung.

Layar email/kata sandi dan pendaftaran NIS/NISN ada di menu Masuk/Daftar. Tautan konfirmasi dan reset dikirim ke email; tautan reset membuka layar untuk menetapkan kata sandi baru. Pendaftaran memerlukan identitas siswa terdaftar, email terkonfirmasi, dan aktivasi admin sebelum profil bisa dipakai. Setelah aktif, peran diambil dari profil server: anggota membuka katalog server; admin dapat mengelola registry anggota, meninjau permintaan aktivasi, melihat katalog, menambah/mengubah judul, menambah eksemplar, dan melihat stok. Transaksi peminjaman/pengembalian masih demo dan belum boleh dipakai untuk pencatatan nyata.

Akun admin pertama harus disiapkan operator di server sesuai [panduan database](database.md); jangan mengisi identitas contoh ke server nyata. Admin selanjutnya dapat mengelola data anggota lewat aplikasi.

Server menggunakan `https://sup.tunneladguard.xyz`. Perubahan URL HTTPS dan callback allowlist Auth sudah diterapkan di `.env` Supabase server. Pada 29 September 2026, SMTP Brevo dikonfigurasi di server dan container Auth direcreate. Nilai runtime diverifikasi, koneksi TCP/TLS serta autentikasi berhasil, dan satu email uji terkirim serta dikonfirmasi masuk oleh pengguna. Alur konfirmasi/reset Supabase belum diuji.

Brevo SMTP relay memakai `SMTP_HOST=smtp-relay.brevo.com`, `SMTP_PORT=587`, nilai Login dari tab SMTP, SMTP key (bukan API key), alamat From terverifikasi, dan nama pengirim. Supabase mengambil nilai ini dari `.env` dan perlu me-recreate container `auth` setelah perubahan ([panduan SMTP Brevo](https://help.brevo.com/hc/en-us/articles/7924908994450-Send-transactional-emails-using-Brevo-SMTP), [panduan self-host Supabase](https://supabase.com/docs/guides/self-hosting/docker)). Jangan kirim SMTP key lewat chat atau simpan di repository. Pengiriman satu email uji sudah dikonfirmasi masuk; konfirmasi signup dan reset password Supabase tetap perlu diuji terpisah.

Tidak ada fallback otomatis dari mode server ke data contoh. Layar demo tetap tersedia terpisah.
