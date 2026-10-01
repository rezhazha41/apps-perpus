# Account recovery Edge Function

Fungsi ini harus dijalankan dengan verifikasi JWT gateway dimatikan karena aksi `redeem` dipakai sebelum siswa dapat login. Aksi `issue` tetap memverifikasi JWT pengurus di dalam fungsi, lalu RPC database memeriksa bahwa penerbit adalah pengurus aktif.

Environment runtime:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

Jangan menaruh service-role key pada Flutter, Git, request body, atau log. Deploy fungsi hanya setelah migrasi `202610010001_member_claim_recovery.sql` lulus pada stack disposable.

Kode pemulihan memiliki 12 karakter acak, berlaku 15 menit, maksimal lima percobaan, dan hanya dapat dipakai sekali. Database hanya menyimpan hash SHA-256 kode. Pengurus menyerahkan ID dan kode langsung setelah memverifikasi kartu pelajar/NIS/NISN siswa.
