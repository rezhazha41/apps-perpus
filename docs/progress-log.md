# Catatan progres per sesi

Catatan ini diperbarui pada setiap sesi yang mengubah implementasi atau keputusan produk agar mudah dirujuk saat demo dan presentasi akhir.

## 6 Oktober 2026 - Pengajuan kembali memerlukan persetujuan pengurus

- Keputusan pengguna: scan tidak meminjamkan buku. Anggota memilih bukti dan mengambil foto, lalu **Ajukan pinjaman**. Pengurus memeriksa siswa dan buku sebelum **Setujui & serahkan buku**. Stok berubah atomik saat disetujui.
- Aplikasi memakai kembali `submit_loan_request`; hasil scan tidak lagi menganggap buku dipinjam setelah pengajuan berhasil. Tombol kamera tetap terkunci sebelum memilih jenis bukti. Pengiriman ulang selama proses diblokir di handler.
- Migrasi baru `202610060001_staff_approval_required.sql` menyerialkan pengajuan per anggota, mempertahankan idempotensi, menolak QR yang sudah ada dalam pengajuan pending milik anggota yang sama, memvalidasi jenis bukti null, dan mencabut izin klien untuk `borrow_books`. Pengajuan tidak mengunci baris request sambil memegang lock anggota, agar tidak membalik urutan lock review. Pinjaman historis tidak diubah.
- Antrean pengurus yang sudah tersedia dipakai kembali. Pengajuan bukan reservasi; review tetap memeriksa ulang ketersediaan semua buku. Pengajuan dapat dibatalkan atau ditolak. Masa kedaluwarsa otomatis belum ditetapkan dan belum diimplementasikan.
- Runner SQL dan integrasi diperbarui agar memeriksa alur persetujuan dan penolakan akses pinjam langsung. PRD/appflow, arsitektur, database, dan status implementasi diperbarui.

Verifikasi sesi ini:

- PASS: `scripts/sql-tests/test.mjs`, menggunakan fixture PGlite lokal sintetis; mencakup pending tanpa perubahan stok, penolakan duplikat, retry, larangan persetujuan oleh anggota, persetujuan admin, pengembalian, kehilangan, RLS, dan pembelajaran.
- PASS: `flutter analyze --no-pub`, tanpa temuan. Percobaan pertama di sandbox dihentikan karena tidak menghasilkan output; percobaan ulang dengan akses SDK selesai.
- PASS: pemeriksaan sintaks runner integrasi (`node --check`) dan `git diff --check`.
- PASS: `flutter test --no-pub`, seluruh 24 tes lulus, termasuk tes baru yang membuktikan pilihan jenis bukti membuka tombol kamera sementara pengajuan tetap nonaktif sampai foto tersedia.
- NOT RUN: integrasi GoTrue/Storage nyata dan concurrency PostgreSQL dua koneksi untuk perubahan baru. PGlite bukan bukti keduanya.
- PASS: backup server `/opt/backups/perpus/perpus-pre-staff-approval-20261006-141337.dump` tervalidasi dengan `pg_restore --list`, ukuran 510.276 byte, mode 600.
- PASS: migrasi `202610060001_staff_approval_required.sql` diterapkan ke database `postgres`; `verify_migration.sql` dan `verify_staff_admin.sql` lulus. Data registry tetap 100 siswa, 2 profil, dan 1 admin.
- PASS: APK debug berhasil dibangun dan dipasang dengan `adb install -r` pada itel A665L. Versi terpasang `0.1.0`, pembaruan `2026-10-06 14:29:19`.
- NOT RUN: transaksi nyata pengajuan anggota sampai persetujuan pengurus setelah migrasi. Pengujian ini memerlukan tindakan pengguna di dua peran.

Langkah berikutnya: uji satu transaksi nyata dari akun anggota hingga pengurus memilih **Setujui & serahkan buku**, lalu pastikan stok dan riwayat kedua peran diperbarui. APK lama akan gagal memakai jalur pinjam langsung karena izin RPC tersebut sudah dicabut.

## 1 Oktober 2026 — Status sesi aktif dan konsistensi sampul buku

### Perubahan

- Menegaskan aturan sesi yang sudah ada: anggota maupun pengurus otomatis logout setelah 24 jam tanpa aktivitas; waktu saat aplikasi tertutup tetap dihitung.
- Menampilkan badge peran **ANGGOTA/PENGURUS** di header server, dengan keterangan batas idle pada tooltip, sehingga tampilan setelah login jelas berbeda dari halaman awal.
- Membuat widget `PerpusBookCover` bersama untuk demo dan data server. Sampul tanpa gambar kini memakai artwork tipografi demo, dan gambar gagal dimuat kembali ke artwork yang sama.

### Verifikasi

- `flutter analyze`: PASS tanpa temuan.
- Build APK debug: PASS; terpasang pada perangkat itel A665L yang tersambung.
- Tidak ada perubahan backend atau data server.

## 1 Oktober 2026 — Sampul buku pada hasil scan dan pinjaman

### Perubahan

- Mengacu pada screenshot `Capture.PNG`, setelah scan berhasil preview kamera dipendekkan dan artwork sampul ditampilkan besar di tengah, tepat di atas kartu judul, kategori, kode QR, dan status.
- Hasil scan dan halaman pengajuan menampilkan gambar sampul pilihan pengurus, atau artwork tipografi demo bila gambar kosong/gagal dimuat.
- Sampul ikut ditampilkan pada pinjaman anggota, antrean pengajuan pengurus, daftar pilihan sesi pembelajaran, dan catatan sesi kelas.
- Form tambah/ubah buku tetap menyediakan pilihan **Logo / sampul buku**; pratinjau kosong kini menggunakan artwork demo yang sama.

### Verifikasi

- `flutter analyze`: PASS tanpa temuan.
- Build APK debug: PASS.
- APK terpasang pada perangkat itel A665L (`108071544J008323`).
- Integrasi runtime scan dengan data server perlu dicoba di perangkat setelah login; tidak ada perubahan atau penulisan data server.

## 1 Oktober 2026 — Claim siswa dan pemulihan akses akun

### Keputusan produk

- Satu siswa hanya dapat mempunyai satu claim anggota berstatus menunggu atau aktif.
- Pendaftaran kedua ditolak oleh backend. Jika pengurus menolak pendaftaran, claim dilepas dan siswa mengajukan ulang memakai akun yang sama.
- Jika siswa lupa kata sandi dan tidak dapat membuka email, pengurus memverifikasi identitas secara langsung lalu memberikan kode pemulihan sekali pakai yang berlaku 15 menit.

### Perubahan

- Menambahkan migrasi `202610010001_member_claim_recovery.sql` untuk claim eksklusif, pengajuan ulang, challenge pemulihan privat, batas percobaan, dan pencabutan sesi.
- Menambahkan Edge Function `account-recovery`; service-role key hanya dipakai pada fungsi server.
- Menambahkan jalur pemulihan pada login anggota, tombol pengajuan ulang untuk akun ditolak, dan penerbitan kode dari menu anggota pengurus tanpa mengubah susunan navigasi demo.
- Memperluas SQL test, verifier migrasi, runner integrasi disposable, dan regression PostgreSQL dua koneksi.
- Memperbaiki `scripts/verify.ps1` agar menemukan tool Windows dan Git pada environment PATH minimal.

### Verifikasi dan batas

- Full verifier PASS: Flutter analyze, 9 widget test, 10 data-access test, SQL/RLS/RPC, 7 guard test integrasi, dan 4 helper test Edge Function.
- PostgreSQL dua koneksi PASS untuk race claim dan seluruh regression lock inventaris.
- Server aktif diperiksa read-only: 0 kelompok claim ganda; migrasi claim/pemulihan belum diterapkan.
- Integrasi GoTrue, Storage, dan Edge Function pada stack disposable masih BLOCKED karena environment/kredensial uji belum tersedia.

## 30 September 2026 — Penyesuaian app flow PRD

### Perubahan dokumentasi

- Memperbarui status awal PRD berdasarkan hasil audit dan pengujian terakhir: M1/M2 tersedia, alur M3 ada pada kode dan lulus verifier lokal, sedangkan integrasi GoTrue/Storage serta migrasi lock pada server aktif belum terverifikasi.
- Mengganti diagram app flow lama dengan empat alur yang sesuai aplikasi saat ini: masuk dan aktivasi anggota; peminjaman anggota; katalog/inventaris pengurus; serta peminjaman pembelajaran.
- Menyesuaikan navigasi dengan tampilan yang sudah dipresentasikan. Pengurus tetap memakai **Dashboard, Buku, Aktivitas, Anggota**; anggota memakai **Katalog, Scan, Akun, Pinjaman**.
- Mencatat CRUD buku, sampul opsional, awalan QR custom, QR unik per eksemplar, cetak QR, stok +1/-1 melalui arsip lunak, pengembalian sebagian, kehilangan, dan sesi pembelajaran.
- Menambahkan tabel batas pembuktian agar fitur yang tersedia pada kode tidak keliru dianggap sudah lulus integrasi Supabase nyata.

### Keputusan yang masih terbuka

- Aturan pelepasan claim siswa setelah akun ditolak belum diputuskan. PRD menyatakan alur daftar ulang belum final dan tidak menetapkan kebijakan baru.
- Notifikasi, penghapusan bukti terjadwal, serta laporan/arsip PDF dan CSV tetap berada pada tahap M4.

### Verifikasi

- App flow dicocokkan dengan navigasi dan halaman pada `apps/mobile/lib/features/server/server_shell.dart` serta `apps/mobile/lib/app/perpus_app.dart`.
- Tidak ada kode aplikasi atau database yang diubah pada sesi dokumentasi ini.

## 30 September 2026 — QR, sampul buku, dan peminjaman pembelajaran

### Perubahan

- Memperbaiki layar tampil QR eksemplar agar terbuka sebagai halaman tersendiri, dengan tombol cetak.
- Menambahkan kolom awalan QR khusus pada formulir tambah buku. Nomor eksemplar ditambahkan otomatis dan tetap unik.
- Menghilangkan spinner pencarian QR setelah hasil ditemukan, tidak ditemukan, atau pencarian gagal.
- Menambahkan pemilihan gambar sampul buku yang opsional. Jika gambar kosong, katalog memakai ikon bawaan demo. Gambar disimpan di bucket publik `book-covers`; upload dibatasi untuk pengurus.
- Menambahkan **Aktivitas → Pembelajaran** untuk membuat sesi kelas, memindai banyak buku, mencatat kelas/kegiatan/penanggung jawab/tenggat, dan memproses pengembalian per eksemplar dengan kondisi baik atau rusak.
- Mengganti label UI **Transaksi** menjadi **Aktivitas** di menu pengurus dan demo. Teks layar lain memakai istilah peminjaman/pengembalian yang lebih sesuai konteks perpustakaan. Nama teknis database tidak diubah.

### Database dan server

- Migrasi `202609300001_book_covers.sql` menambahkan `cover_path` dan bucket sampul.
- Migrasi `202609300002_classroom_loans.sql` menambahkan sesi pembelajaran, item eksemplar, akses admin, pencatatan audit, RPC pembuatan sesi, dan RPC pengembalian.
- Sebelum migrasi sampul dibuat backup `/opt/backups/perpus/pre-book-covers-20260930.dump`.
- Sebelum migrasi sesi pembelajaran dibuat backup `/opt/backups/perpus/pre-classroom-loans-20260930.dump`.
- Kedua migrasi diterapkan ke Supabase self-hosted. Keberadaan kolom, bucket, tabel, indeks, dan RPC sesi pembelajaran telah diperiksa.

### Verifikasi

- `flutter analyze`: tanpa temuan.
- APK debug berhasil dibangun dan dipasang pada perangkat Android terhubung.
- Pengguna sebelumnya mengonfirmasi alur scan QR dan pengajuan pinjaman anggota berhasil. Alur sesi kelas baru perlu dicoba pada perangkat.

### Keputusan produk

- Batas pinjaman anggota biasa tidak dinaikkan untuk mengakomodasi peminjaman kelas. Sesi pembelajaran adalah alur pengurus terpisah agar 20 atau lebih buku untuk kegiatan kelas tidak mengubah batas tiap anggota.
- Dokumentasi progres akan diperbarui pada setiap sesi perubahan selanjutnya.

## Catatan istilah untuk presentasi

Gunakan **Aktivitas** sebagai label menu. Di dalamnya gunakan **Pinjaman**, **Pengembalian**, **Kehilangan**, dan **Pembelajaran**. Hindari label bernuansa keuangan seperti *Transaksi* pada tampilan pengguna.

## 1 Oktober 2026 — Hasil scan dan nama anggota

- Hasil QR anggota kini berpindah ke tampilan khusus setelah pemindaian. Sampul buku dan detailnya dikelompokkan di tengah area konten; aksi pengajuan pinjaman dan pemindaian buku lain berada di bagian bawah.
- Label kecil di samping logo `perpus.` menampilkan nama siswa yang tertaut pada akun anggota. Jika nama registry tidak dapat dibaca, halaman tetap terbuka dan memakai fallback email; label pengurus tetap menandai perannya.
- `flutter analyze` bersih, APK debug berhasil dibangun, dan berhasil dipasang pada perangkat itel A665L. Posisi visual hasil scan dan pengambilan nama dari registry belum diuji langsung setelah login pada perangkat.

### Penyempurnaan jarak tombol hasil scan — 1 Oktober 2026

- Menambahkan jarak vertikal yang jelas antara tombol utama **Ajukan pinjaman** dan tombol sekunder **Scan buku lain** agar keduanya terbaca sebagai aksi terpisah.

### Penyempurnaan isian email — 1 Oktober 2026

- Menghapus contoh alamat `nama@email.com` pada isian login/pendaftaran dan mengganti labelnya menjadi **Alamat email**.
- Mengganti contoh email di dialog undangan pengurus dengan petunjuk **Email penerima undangan**.

### Perapian pemilihan bukti pengajuan pinjaman — 1 Oktober 2026

- Mengganti dropdown **Jenis bukti** dengan dua pilihan langsung yang responsif (**Selfie** dan **Kartu siswa**), berikut ikon dan penanda pilihan aktif. Ini menghindari menu dropdown yang terasa memenuhi layar atau keluar frame.

### Refactor kecil validator dan format tanggal — 1 Oktober 2026

- Menghapus wrapper autentikasi yang hanya meneruskan pesan ke `authErrorMessage` tanpa mengganti isi pesan.
- Menyatukan validator wajib isi. Pesan form autentikasi tetap **Bagian ini wajib diisi.**, sedangkan form buku dan siswa tetap **Wajib diisi.**
- Mengekstrak formatter tanggal server dan menghindari parse tanggal dua kali pada format tanggal-waktu. Format tanggal, jam lokal, dan penanda tanggal tidak valid tetap sama.
- Test karakterisasi menunjukkan RED sebelum helper tersedia; test widget terkait dan suite `flutter test` lulus setelah perubahan. `flutter analyze` juga bersih.

### Overdue predicate extraction - 1 October 2026

- Mengekstrak predicate item pinjaman terbuka dan terlambat ke `apps/mobile/lib/features/server/loan_predicates.dart`, lalu memakainya pada ringkasan dashboard dan daftar pinjaman anggota.
- Aturan tetap sama: item yang sudah dikembalikan/diselesaikan tidak dianggap terlambat; tanggal jatuh tempo harus valid dan lebih awal dari waktu saat ini. Query Supabase, route, tampilan, dan pesan tidak diubah.
- Tes karakterisasi helper sempat RED karena file helper belum ada, lalu GREEN setelah ekstraksi. Suite penuh `flutter test` lulus (16 tes) dan `flutter analyze` bersih.

### Member profile identity mapping - 1 October 2026

- Mengekstrak pemetaan role dan ID registry dari profile aktif ke `apps/mobile/lib/features/auth/profile_identity.dart`.
- Query profile dan registry, kondisi akun aktif, fallback jika lookup nama gagal, UI, route, serta pesan tetap dipertahankan.
- Test karakterisasi pemetaan member/admin dan tautan kosong lulus. Suite penuh `flutter test` lulus (19 tes), `flutter analyze` bersih, dan `git diff --check` lulus.

### Account status refresh - 1 October 2026

- Tombol **Perbarui status akun** kini memuat ulang profil akun dan meminta `SessionRouter` memuat ulang profil aktif. `refreshSession()` tetap dipanggil untuk mempertahankan pembaruan sesi.
- Query Supabase, route, teks status, dan tampilan tidak diubah. Pemuatan ulang lokal di halaman akun tetap mendukung status penolakan dan alasan penolakan.
- Tes widget membuktikan profil berubah dari pending menjadi active setelah tombol ditekan dan callback router dipanggil. Suite `flutter test` lulus (20 tes) dan `flutter analyze` bersih.

### Offline notice and account status retry - 2 October 2026

- Menambahkan pemeriksaan koneksi ke URL server saat aplikasi dibuka dan saat kembali aktif. Jika server tidak terjangkau, aplikasi menampilkan pemberitahuan dengan aksi **Coba lagi** dan mencoba ulang otomatis saat aplikasi aktif.
- Tombol **Perbarui status akun** kini menunggu pembaruan sesi, lalu memuat ulang profil di halaman akun dan router aktif. Pesan status tidak lagi menyebut keberhasilan login Supabase atau kesiapan katalog/pinjaman.
- Query profil tidak diubah. `flutter analyze` bersih. Uji runtime pada perangkat dengan koneksi mati lalu pulih masih perlu dilakukan.

### Peminjaman langsung, bukti wajib, dan deteksi wajah - 2 Oktober 2026

- Menelusuri error Storage 403: kebijakan lama memakai `private.is_eligible_member(auth.uid())` yang tidak diberi izin eksekusi kepada authenticated. Perbaikan kebijakan berbasis helper current-user ada di migrasi `202609300003_inventory_lock_protocol.sql`; catatan verifikasi server 1 Oktober menyebut migrasi tersebut belum aktif di server. Pesan error klien kini menyamarkan nama helper dan mengarahkan pengecekan ke status akun/kebijakan Storage.
- Mengubah form agar jenis bukti tidak terpilih otomatis; tombol **Pinjam sekarang** nonaktif sampai pilihan bukti dan foto tersedia. Foto wajib menampilkan wajah yang terdeteksi lokal. Deteksi ini bukan pencocokan identitas atau pemeriksaan liveness.
- Menambahkan dependency Google ML Kit Face Detection untuk Android/iOS. Dependency dan alur belum diverifikasi dengan Flutter analyze atau perangkat.
- Menambahkan migrasi `202610020001_self_service_borrowing.sql` dan RPC `borrow_books`. RPC mengunci profil, buku, dan QR; memeriksa status akun, kebijakan, stok, batas, keterlambatan, dan kehilangan; lalu mencatat bukti/pinjaman serta mengurangi stok dalam satu transaksi. RPC permintaan/review lama tetap ada untuk data pending yang sudah tersimpan.
- Memperbarui README/PRD, dokumentasi database, runbook migrasi, verifier skema, runner SQL, dan status implementasi. Tidak ada koneksi tulis ke server aktif.
- `scripts/verify.ps1`: PASS — Flutter analyze; 20 widget test; 9 data-access test; SQL/PGlite termasuk RPC langsung (idempotensi, status, mode, dan stok); 7 guard integrasi; 4 helper recovery.
- APK debug berhasil dibangun. Perangkat itel A665L terdeteksi, tetapi APK belum dipasang karena server aktif belum memiliki migrasi/RPC baru.
- Integrasi GoTrue/Storage nyata BLOCKED — environment disposable (`PERPUS_TEST_*`) tidak tersedia. Tidak ada akses tulis ke server aktif.

### Supabase lokal disposable — 2 Oktober 2026

- Menambahkan `supabase/config.toml` untuk stack lokal dan menonaktifkan seed otomatis (`db.seed.enabled = false`). Docker Desktop lokal terdeteksi dengan 4 CPU dan sekitar 4 GB RAM.
- `supabase start` berhasil menyalakan Supabase lokal dan menerapkan 11 migrasi sampai `202610020001_self_service_borrowing.sql`. Stack ini memakai volume lokal terpisah dan tidak mengakses `sup.tunneladguard.xyz`.
- Runner guard integrasi lulus 7/7. Runner integrasi lokal juga lulus: preflight migrasi, signup/konfirmasi GoTrue, validasi identitas siswa, approval/login, isolasi RLS anon/anggota/admin, pemulihan akun satu kali, Storage privat lintas anggota, dan peminjaman langsung dengan pengurangan stok atomik.
- Runner sengaja mempertahankan data sintetis di stack disposable. Edge Function lokal dihentikan setelah uji; stack Supabase lokal tetap menyala. `supabase_vector` masih restart, sementara database, Auth, REST, Storage, Realtime, Gateway, Studio, dan Analytics terdeteksi aktif.
- Tidak ada migrasi, seed, atau perubahan pada server Supabase aktif.

### Uji UI langsung pada perangkat - Supabase lokal - 2 Oktober 2026

- Login pengurus ke stack lokal berhasil. Daftar anggota menampilkan akun sintetis pending; aksi **Setujui** berhasil dan jumlah menunggu aktivasi berkurang.
- Login anggota sintetis berhasil pada perangkat dan badge menampilkan nama anggota yang tertaut.
- Pengurus menambah buku sintetis `Buku Uji Lokal`; kartu katalog tampil dengan kode QR otomatis `BUA-BUL-01`, stok 1 tersedia dari 1 total. Tidak mengunggah gambar sehingga ikon fallback demo dipakai.
- Tab inventaris menampilkan dua QR buku dan statusnya: satu dipinjam, satu tersedia. Aksi **Tampilkan QR** membuka QR `BUA-BUL-01`; tombol **Cetak QR** membuka dialog cetak Android dengan ukuran A4, 1 halaman, dan opsi **Simpan ke PDF**. Tidak menyimpan hasil cetak.
- Anggota melihat buku tersebut di katalog dengan stok 1 tersedia / 1 total dan nama akun tertaut pada header. Tab Scan meminta izin kamera; setelah izin diberikan, preview kamera aktif.
- Pengujian lanjutan dengan QR yang difoto lalu ditampilkan pada ponsel kedua berhasil: aplikasi anggota mendekode `BUA-BUL-01`, menampilkan buku tersedia, menolak tombol **Pinjam sekarang** sebelum metode/foto bukti dipilih, lalu menerima foto dan mencatat pinjaman setelah tombol ditekan.
- Bukti dan pinjaman masuk melalui Storage privat/RPC lokal. UI menampilkan sukses; inventaris berubah menjadi dipinjam dan menu Pinjaman anggota menampilkan buku, tanggal jatuh tempo, serta aksi pengembalian. Verifikasi database lokal menunjukkan satu item aktif, satu record bukti, dan `approval_mode=self_service`.
- Pengiriman memakai akun dan data uji pada stack disposable. Foto tidak disalin ke dokumentasi. Server aktif tidak disentuh.
- Seluruh interaksi database memakai stack lokal dan data sintetis. Server aktif tidak disentuh; Supabase lokal dibiarkan menyala untuk uji lanjutan.

### Perapian riwayat pinjaman dan kesiapan integrasi server - 2 Oktober 2026

- Panel pada menu **Pinjaman** kini hanya memuat pengajuan berstatus `pending`; pinjaman yang sudah disetujui tidak ditampilkan lagi sebagai kartu pengajuan sekaligus kartu riwayat. Permintaan pending tetap dapat dilihat meski anggota belum memiliki pinjaman.
- Menambahkan test untuk memastikan panel mempertahankan status pending dan mengabaikan status approved, rejected, serta cancelled. `flutter analyze` lulus dan `flutter test` lulus (23 tes).
- APK debug lokal dipasang dan dibuka di itel A665L. Menu **Riwayat pinjaman** menampilkan dua pinjaman sintetis masing-masing satu kali; panel pengajuan tidak menggandakan pinjaman aktif.
- Alur scan QR dan peminjaman sudah dapat menggunakan Supabase self-hosted melalui URL dan publishable key. Untuk server utama, migrasi/RPC `borrow_books` serta kebijakan Storage terkait harus tersedia lebih dulu; server utama tetap tidak diubah pada sesi ini. Integrasi akhir perlu memakai konfigurasi URL/key server dan verifikasi read-only/preflight sebelum migrasi apa pun.

### Penerapan migrasi dan APK ke server Perpus - 2 Oktober 2026

- Atas instruksi pengguna, preflight read-only memeriksa database PostgreSQL 17.6, RLS, bucket privat, dan jumlah data. Sebelum perubahan terdapat 2 profil, 100 siswa, 8 buku, 26 QR, 0 loan/request/evidence, serta 0 kelompok claim siswa ganda.
- Membuat backup database server `/opt/backups/perpus/perpus-pre-m3-20261002.dump`, tervalidasi dengan `pg_restore --list`, berukuran 481.019 byte dan berizin 600.
- Menerapkan berurutan `202609300003_inventory_lock_protocol.sql`, `202610010001_member_claim_recovery.sql`, lalu `202610020001_self_service_borrowing.sql`. Ketiganya selesai `COMMIT`.
- `verify_migration.sql` PASS dan `verify_staff_admin.sql` PASS. RPC `borrow_books(uuid,uuid[],text,text)` dapat dipanggil `authenticated` dan ditolak untuk `anon`. Data tetap 2 profil, 100 siswa, 8 buku, 26 QR, 0 loan/request/evidence.
- Endpoint Auth `https://sup.tunneladguard.xyz/auth/v1/health` merespons HTTP 200 dengan publishable key aplikasi. APK debug tanpa override lokal berhasil dibangun; paket Android terpasang diperbarui pada 2 Oktober.
- Belum melakukan login atau membuat pinjaman uji pada server agar tidak menulis data sintetis ke database aktif. Edge Function `account-recovery` belum ada di direktori runtime server dan belum dideploy; pemulihan akun masih memerlukan langkah deployment terpisah.

### Refresh status setelah pinjaman mandiri - 2 Oktober 2026

- Pengujian pinjaman server memakai QR khusus `BJ-BUE-01`. Setelah submit, verifikasi read-only menunjukkan satu pinjaman aktif, satu permintaan, dan satu bukti; status QR berubah menjadi `borrowed`.
- Ditemukan halaman hasil scan masih menyimpan status katalog sebelum pinjaman. RPC server tetap mencegah QR yang sama dipinjam dua kali, tetapi UI stale membuat tombol **Pinjam buku** masih tampak tersedia.
- Setelah RPC sukses, halaman hasil scan kini langsung menampilkan status **Dipinjam** dan mengambil ulang status terbaru dari server. Jika refresh gagal, status lokal tetap dikunci ke **Dipinjam** dan anggota diberi arahan untuk scan ulang.
- `flutter analyze` PASS tanpa temuan. APK debug berhasil dibangun dan dipasang pada perangkat Android yang terhubung. Belum dilakukan uji ulang interaksi UI setelah pemasangan.
- Tidak ada perubahan database atau kebijakan server pada perbaikan ini; foto bukti tidak disalin ke dokumentasi.

### Kategori katalog, cetak QR per kategori, dan riwayat aktivitas - 2 Oktober 2026

- Form katalog memisahkan bidang dengan jarak dan outline agar label/error tidak bertabrakan. Kelompok kategori Adaptif, Normatif, Produktif, dan Kustom tersedia; nama mapel/program dapat ditulis admin. Produktif menyediakan pilihan cepat TKJ, TKR, TPTL, dan AKT. Nilai disimpan pada kolom `books.category` yang sudah ada; tidak perlu migrasi.
- Inventaris dapat difilter menurut kategori. Admin dapat mencetak semua QR aktif dalam kategori terpilih pada layout A4 atau F4; cetak satuan tetap tersedia.
- Pemeriksaan read-only audit server menemukan event `loan_requests`, `loans`, `loan_items`, dan perubahan status `book_copies` pada waktu pinjaman uji. UI operasional sebelumnya hanya menampilkan antrean yang perlu ditangani, sehingga pinjaman yang sudah tercatat tidak tampak sebagai riwayat. Tab **Riwayat** ditambahkan untuk menampilkan pinjaman, pengembalian, kehilangan, dan sesi pembelajaran dengan judul/kode QR dan status.
- Server tidak diubah. Riwayat pengembalian, kehilangan, dan pembelajaran belum punya event runtime pada data yang diperiksa; tampilannya memanfaatkan record/tabel yang sudah ada dan tetap perlu uji per alur.
- `flutter analyze` PASS tanpa temuan. APK debug berhasil dibangun dan dipasang pada perangkat Android yang terhubung. Tampilan baru belum diuji manual setelah pemasangan; belum ada alur uji pengembalian, kehilangan, atau pembelajaran pada data server.

### E2E server aktif fixture sintetis - 15 Oktober 2026

- Login anggota/pengurus, scan QR, bukti selfie privat, pengajuan, persetujuan, pengembalian kondisi baik, dan refresh status diverifikasi pada fixture `TEST-E2E-20261015`.
- Jalur kehilangan diverifikasi penuh: `reported` → `resolved`, QR-01 berubah menjadi `lost`, dan catatan penyelesaian tersimpan.
- Jalur pembelajaran terhenti pada pemindaian QR-02 karena hanya satu perangkat ADB tersedia; dicatat BLOCKED dan belum ada sesi tersimpan.
- Fixture diarsipkan setelah pengujian; akun/profil dan student registry sintetis dinonaktifkan. Detail bukti ada di [laporan E2E server aktif](e2e-server-aktif-2026-10-15.md).

### Mode hybrid sesi pembelajaran - 15 Oktober 2026

- Mode sesi pembelajaran sekarang mendukung pemindaian QR satu per satu dan pemilihan judul plus jumlah. RPC baru mengalokasikan QR tersedia secara atomik agar stok tetap konsisten.
- Migrasi `202610150001_classroom_book_quantity.sql` sudah dimuat ke runner SQL dan fungsi terdeteksi pada server aktif. Tidak ada sesi/data buku yang dibuat saat validasi.
- `dart analyze apps/mobile` dan runner SQL lulus. Build APK serta instalasi ke HP belum dilakukan sesuai instruksi pengguna.
- Detail keputusan dan batas verifikasi ada di [dokumentasi mode hybrid](classroom-hybrid-mode-2026-10-15.md).
