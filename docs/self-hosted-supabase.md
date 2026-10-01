# Supabase pada server LAN + Nginx Proxy Manager

Status: Supabase pengguna sudah berjalan di Docker Compose pada server LAN dan diakses lewat Nginx Proxy Manager. URL HTTPS Auth serta callback Android telah disetel. SMTP belum siap. Contoh berikut tetap menjadi referensi setup, bukan instruksi untuk menginstal ulang stack yang sudah berjalan.

## Topologi yang dipakai Perpus

```text
HP Android (Wi-Fi sekolah)
  -> DNS LAN: api.perpus.DOMAIN-SEKOLAH -> IP LAN server NPM
  -> HTTPS :443 / Nginx Proxy Manager
  -> HTTP perpus-api:8000 / gateway Supabase
  -> Auth, PostgREST, Storage -> PostgreSQL
```

Domain `school.example` dalam file contoh adalah placeholder, tidak bisa diterbitkan sertifikat publik. Gunakan subdomain domain yang dimiliki sekolah. Untuk LAN, arahkan DNS lokal/router ke IP server. HP dan PC harus memakai DNS tersebut; periksa Private DNS/DoH bila hasil resolusi berbeda. NPM sendiri tidak menyediakan DNS. `localhost` pada HP berarti HP, bukan server.

Saran implementasi: sertifikat publik melalui DNS challenge memungkinkan endpoint tetap privat di LAN tanpa membuka port router ke internet. Alternatif internal CA memerlukan distribusi trust dan konfigurasi Android khusus; belum disiapkan. Tidak ada bypass pemeriksaan sertifikat atau HTTP cleartext pada build ini. Jika HP memakai jaringan seluler, backend LAN tidak dapat diakses tanpa koneksi VPN/rute ke LAN. Notifikasi push memerlukan koneksi keluar ke FCM walaupun database berada di LAN.

## Menyiapkan stack resmi

Gunakan paket Docker resmi, dipatok pada `self-hosted/v0.8.2` yang diperiksa 28 September 2026. Kebutuhan minimum dokumentasi: 2 core, RAM 4 GB, SSD 40 GB; rekomendasi RAM 8 GB. Simpan folder runtime di server, terpisah dari repository aplikasi. Contoh berikut hanya membuat instalasi baru. [Panduan Docker Supabase](https://supabase.com/docs/guides/self-hosting/docker).

```bash
git clone --depth 1 --branch self-hosted/v0.8.2 https://github.com/supabase/supabase.git supabase-upstream
mkdir perpus-supabase
cp -a supabase-upstream/docker/. perpus-supabase/
cd perpus-supabase
cp .env.example .env
sh utils/generate-keys.sh
sh utils/add-new-auth-keys.sh
```

Periksa perubahan yang diminta skrip kunci pada Compose. Ganti kredensial contoh sebelum start; jangan kirim `.env`, secret key/service_role, atau password database ke aplikasi. Gabungkan pengaturan dari `infra/supabase/urls.env.example` ke `.env`, lalu isi SMTP sungguhan sebelum membuka signup. Kunci yang dibagikan ke client hanya publishable key atau legacy anon key sesuai gateway. [Konfigurasi resmi](https://supabase.com/docs/guides/self-hosting/docker).

`API_EXTERNAL_URL` pada versi ini mencakup `/auth/v1`; `SUPABASE_PUBLIC_URL` tidak. Ini berubah dari beberapa tutorial lama. `SITE_URL` adalah tujuan setelah konfirmasi/pemulihan, bukan otomatis endpoint API. Halaman landing dan callback Android masih pekerjaan M2. [Perubahan URL Auth](https://supabase.com/changelog/47093-self-hosted-supabase-api-external-url-to-include-auth-v1).

## Menghubungkan NPM yang sudah ada

Overlay `infra/supabase/compose.lan.yaml` adalah konfigurasi proyek ini untuk upstream tersebut: gateway bernama `api-gw`, alias jaringan `perpus-api`; port gateway dan Supavisor tidak dipublikasikan ke host. Terapkan bersama Compose utama. Membutuhkan Compose 2.24.4+ untuk `!reset`. [Compose upstream yang diperiksa](https://github.com/supabase/supabase/blob/self-hosted/v0.8.2/docker/docker-compose.yml).

```bash
docker network create perpus_proxy
# Salin compose.lan.yaml dari repository Perpus ke folder perpus-supabase.
docker compose -f docker-compose.yml -f compose.lan.yaml config --quiet
docker compose -f docker-compose.yml -f compose.lan.yaml up -d --wait
docker compose -f docker-compose.yml -f compose.lan.yaml ps
```

Jika jaringan sudah ada, jangan membuat ulang. Tambahkan network eksternal `perpus_proxy` pada service NPM di Compose NPM yang ada **tanpa menghapus network lamanya**, kemudian recreate service NPM. Dengan network bersama, NPM dapat mengakses alias Docker tanpa port host. [Jaringan Docker NPM](https://nginxproxymanager.com/advanced-config/).

```yaml
# Fragmen untuk digabungkan dengan Compose NPM yang ada, bukan file lengkap.
services:
  app: # sesuaikan nama service NPM
    networks:
      - default
      - perpus_proxy
networks:
  perpus_proxy:
    external: true
    name: perpus_proxy
```

Pada Proxy Hosts NPM, buat host:

| Field | Nilai |
| --- | --- |
| Domain Names | domain API sekolah yang sebenarnya |
| Scheme | http |
| Forward Hostname | perpus-api |
| Forward Port | 8000 |
| Websockets Support | aktif |
| Cache Assets | nonaktif untuk endpoint API |
| SSL | sertifikat valid untuk domain tersebut; Force SSL |

Tambahkan `client_max_body_size 10m;` di Advanced bila diperlukan untuk batas upload rencana. Batas file aplikasi/Storage tetap perlu ditetapkan tersendiri. Jangan menambahkan Basic Auth NPM pada seluruh API karena akan mengganggu header Bearer Supabase. Studio memiliki autentikasi tersendiri pada gateway; batasi pengelolaan Studio dan port admin NPM ke jaringan admin/VPN. [HTTPS Supabase](https://supabase.com/docs/guides/self-hosting/self-hosted-proxy-https), [setup NPM](https://nginxproxymanager.com/setup/).

Jika NPM dan Supabase berada pada host berbeda, overlay jaringan bersama ini tidak berlaku. Pakai IP privat upstream dengan firewall yang hanya mengizinkan server NPM; sesuaikan Compose setelah alamat kedua host tersedia. Jangan mengarahkan NPM ke `127.0.0.1` untuk container lain.

## Memasang skema Perpus

Setelah stack sehat, salin folder `supabase/migrations` repository Perpus ke direktori kerja server. Gunakan database khusus pengembangan dan terapkan setiap migrasi hanya sekali, berurutan. Contoh untuk migrasi pertama:

```bash
docker compose -f docker-compose.yml -f compose.lan.yaml exec -T db \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  < /path/Perpus/supabase/migrations/202609280001_identity_inventory.sql
```

Gunakan pola yang sama untuk `supabase/seed.sql` jika membutuhkan data fiktif, lalu `supabase/tests/identity_inventory.sql` untuk pengujian rollback. Skema belum mencakup transaksi produksi. Lihat [database.md](database.md) untuk bootstrap admin. Jangan membuka signup sampai trigger, kebijakan RLS, SMTP, dan batas percobaan Auth telah diuji.

Migrasi aditif staf/admin `202609290001_staff_admin_operations.sql` dan undangan staf `202609290002_staff_invites.sql` dijalankan setelah migrasi identitas. Keduanya mempertahankan registry siswa, memisahkan staf, membuat undangan satu kali, mengikat hak admin ke akun staf aktif, dan menambahkan RPC arsip eksemplar tersedia. Uji dahulu pada salinan database sebelum menjalankannya pada server berisi data resmi.

## Memeriksa akses dari HP

1. Pastikan domain API di HP mengarah ke IP LAN NPM dan sertifikat valid.
2. Tes `/auth/v1/health` dengan kunci publik yang sesuai gateway, lalu login akun uji.
3. Tes anggota hanya dapat membaca profilnya; admin dapat membaca registry.
4. Simpan URL HTTPS dan kunci publik untuk integrasi Flutter berikutnya. Aplikasi demo saat ini belum memakai variabel koneksi server.

Backup harus meliputi database, file Storage, konfigurasi runtime dan secrets yang disimpan terenkripsi. Uji restore ke instalasi terpisah sebelum data sungguhan digunakan. Penghapusan foto di storage aktif tidak menghapus salinan backup; kebijakan backup sekolah perlu ditetapkan.
