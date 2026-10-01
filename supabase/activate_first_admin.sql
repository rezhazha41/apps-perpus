-- Run in Supabase Studio after creating the first Auth user in
-- Authentication > Users and confirming its email. Replace the email
-- placeholder with the same address used by bootstrap_first_admin.sql.
-- This binds the verified Auth user to the reserved staff row and activates
-- the first admin. The invitation must still be active and unclaimed; its
-- secret stays inside the database and never needs to be copied into Studio.
-- It deliberately raises a clear error instead of silently
-- returning "Success. No rows returned" when a prerequisite is missing.
begin;
do $$
declare
  v_email text := lower('GANTI_EMAIL_PENGURUS');
  v_user_id uuid;
  v_staff_id uuid;
  v_linked_user_id uuid;
begin
  select u.id into v_user_id
  from auth.users u
  where lower(u.email)=v_email and u.email_confirmed_at is not null;
  if v_user_id is null then
    raise exception 'Akun Auth belum dibuat atau email belum dikonfirmasi untuk %.',v_email;
  end if;

  select s.id,s.linked_user_id into v_staff_id,v_linked_user_id
  from public.staff_registry s
  where lower(s.email)=v_email and s.active
    and (s.linked_user_id=v_user_id or
      (s.linked_user_id is null and s.invite_token is not null and s.invite_expires_at>now()))
  for update;
  if v_staff_id is null then
    raise exception 'Undangan tidak ditemukan, sudah dipakai, atau kedaluwarsa.';
  end if;

  if v_linked_user_id is null then
    update public.staff_registry
      set linked_user_id=v_user_id,invite_token=null,invite_expires_at=null
      where id=v_staff_id;
    insert into public.profiles(id,staff_id,role,status,reviewed_at)
      values(v_user_id,v_staff_id,'admin','active',now());
  else
    update public.profiles
      set status='active',reviewed_at=coalesce(reviewed_at,now())
      where id=v_user_id and staff_id=v_staff_id and role='admin';
    if not found then
      raise exception 'Profil admin sudah tertaut tetapi tidak cocok; hubungi operator database.';
    end if;
  end if;
end;
$$;
commit;

-- Verify the result with:
-- select p.id,p.role,p.status,s.full_name,s.email
-- from public.profiles p join public.staff_registry s on s.id=p.staff_id
-- where lower(s.email)=lower('EMAIL_ADMIN_KAMU');
