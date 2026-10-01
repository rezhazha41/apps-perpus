-- Operator-only: create a 48-hour, one-time invitation for the first admin.
-- Replace all values, run in Supabase Studio, then deliver the returned token
-- invite row keeps its token private; activate_first_admin.sql binds it only
-- after the matching email is confirmed in Supabase Auth.
begin;
insert into public.staff_registry(
  email,full_name,position,staff_no,invite_token,invite_expires_at
)
values (
  lower('GANTI_EMAIL_PENGURUS'),
  'GANTI_NAMA_PENGURUS',
  'Pengurus Perpustakaan',
  null,
  gen_random_uuid(),
  now()+interval '48 hours'
)
returning id,email,invite_expires_at;
commit;
