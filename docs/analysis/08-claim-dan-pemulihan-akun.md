# Analisis claim siswa dan pemulihan akun

Tanggal pembuktian: 1 Oktober 2026.

## Keputusan produk

- Satu siswa hanya dapat mempunyai satu claim anggota yang masih `pending` atau `active`.
- Pendaftaran kedua untuk siswa yang sedang diclaim ditolak oleh backend.
- Ketika pengurus menolak pendaftaran, claim dilepas otomatis.
- Siswa memperbaiki dan mengajukan ulang memakai akun Auth yang sama. Pembuatan akun baru bukan alur utama.
- Jika siswa lupa kata sandi dan tidak dapat mengakses email, pengurus memverifikasi identitas secara langsung sebelum menerbitkan kode pemulihan.
- Kode berlaku satu kali selama 15 menit, maksimal 5 percobaan, dan kode mentah tidak disimpan di database.

## Implementasi

| Bagian | Lokasi | Perilaku |
| --- | --- | --- |
| Claim eksklusif | `202610010001_member_claim_recovery.sql` | Indeks unik parsial dan lock registry menjaga satu claim terbuka. |
| Penolakan/pengajuan ulang | `review_member`, `resubmit_member_application` | Penolakan melepas claim; akun yang sama dapat kembali ke `pending`. |
| Challenge pemulihan | `account_recovery_challenges` | Menyimpan hash, masa berlaku, hitungan percobaan, dan waktu pemakaian. |
| Otorisasi server | RPC service-role dan Edge Function | Penerbitan memerlukan JWT pengurus aktif; penukaran mengubah kredensial dan mencabut sesi lama. |
| UI anggota | `auth_pages.dart` | Login menyediakan jalur saat email tidak dapat diakses; akun ditolak dapat diajukan ulang. |
| UI pengurus | `server_shell.dart` | Pengurus wajib mencentang konfirmasi pemeriksaan identitas sebelum menerbitkan kode. |

## Hasil pembuktian

| Pemeriksaan | Status | Bukti |
| --- | --- | --- |
| Flutter analyze | PASS | Tidak ada temuan. |
| Widget auth/recovery | PASS | 9/9 test mobile, termasuk validasi dan submit kode sekali pakai. |
| Domain/data-access | PASS | 10/10 test. |
| SQL claim/recovery | PASS | Claim kedua ditolak, penolakan melepas claim, akun sama dapat mengajukan ulang, RLS challenge privat, kode salah/benar/reuse diuji. |
| Race dua signup satu siswa | PASS | PostgreSQL dua koneksi menghasilkan tepat satu profil `pending`; tidak ada deadlock tak tertangani. |
| Helper Edge Function | PASS | 4/4 test normalisasi, pembuatan, hash, dan batas input. |
| Guard integrasi | PASS | 7/7 test; hostname server aktif selalu ditolak. |
| Preflight server aktif | PASS read-only | Tidak ditemukan kelompok claim `pending`/`active` ganda. |
| Migrasi/Edge Function pada server aktif | NOT RUN | Server aktif tidak diubah pada tahap ini. |
| GoTrue dan Edge Function pada Supabase disposable | BLOCKED | URL, anon key, dan service-role key stack disposable belum tersedia. |

Log preflight server: [server-claim-preflight-2026-10-01.log](server-claim-preflight-2026-10-01.log).
Log verifier gabungan: [verification-claim-recovery-2026-10-01.log](verification-claim-recovery-2026-10-01.log).

## Risiko tersisa

- Perubahan kata sandi, perubahan email opsional, dan pencabutan sesi belum dibuktikan terhadap GoTrue nyata.
- Konfigurasi gateway fungsi `account-recovery` harus mengizinkan request penukaran tanpa JWT; fungsi tetap memverifikasi JWT pengurus sendiri pada operasi penerbitan.
- Pengurus dapat salah memverifikasi orang. SOP sekolah untuk pemeriksaan kartu siswa/identitas tetap diperlukan.
- Migrasi sengaja berhenti jika menemukan claim ganda. Preflight saat ini bersih, tetapi harus diulang sesaat sebelum deployment.

## Gate deployment

1. Siapkan Supabase disposable dan terapkan seluruh migrasi sesuai urutan.
2. Deploy Edge Function dengan service-role key hanya di secret environment server.
3. Jalankan runner integrasi sampai alur issue/redeem, login sandi lama, login sandi baru, RLS, RPC, dan Storage PASS.
4. Review backup dan rencana rollback server aktif.
5. Ulangi preflight claim read-only, lalu jadwalkan migrasi server sebagai perubahan terpisah.
