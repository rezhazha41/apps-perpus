-- M2 foundation. Apply to an empty Supabase development database, never plain Postgres.
begin;
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create table public.student_registry (
  id uuid primary key default gen_random_uuid(),
  nis text unique check (nis is null or nis ~ '^[0-9]+$'),
  nisn text unique check (nisn is null or nisn ~ '^[0-9]+$'),
  full_name text not null check (length(btrim(full_name)) > 0),
  class_name text not null check (length(btrim(class_name)) > 0),
  active boolean not null default true,
  linked_user_id uuid unique references auth.users(id),
  created_at timestamptz not null default now(),
  check (nis is not null or nisn is not null)
);
create table public.profiles (
  id uuid primary key references auth.users(id),
  claimed_student_id uuid references public.student_registry(id),
  role text not null default 'member' check (role in ('member','admin')),
  status text not null default 'pending' check (status in ('pending','active','rejected','inactive')),
  contact text,
  rejection_reason text,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  check (role = 'admin' or claimed_student_id is not null)
);
create table public.books (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(btrim(title)) > 0),
  author text not null check (length(btrim(author)) > 0),
  category text not null check (length(btrim(category)) > 0),
  isbn text,
  description text not null default '',
  archived_at timestamptz,
  created_at timestamptz not null default now()
);
create table public.book_copies (
  id uuid primary key default gen_random_uuid(),
  book_id uuid not null references public.books(id),
  code text not null unique check (length(btrim(code)) > 0),
  status text not null default 'available' check (status in ('available','borrowed','damaged','lost')),
  archived_at timestamptz,
  created_at timestamptz not null default now()
);
create index book_copies_book on public.book_copies(book_id);
create index profiles_claim on public.profiles(claimed_student_id);
create table public.library_settings (
  id boolean primary key default true check (id),
  loan_days integer not null default 7 check (loan_days between 1 and 365),
  max_books integer not null default 3 check (max_books between 1 and 50),
  school_timezone text not null default 'Asia/Jakarta',
  evidence_retention text check (evidence_retention in ('3_days','7_days','30_days','1_year')),
  policy_confirmed boolean not null default false
);
insert into public.library_settings(id) values (true);
create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid,
  action text not null,
  table_name text not null,
  record_id text not null,
  old_data jsonb,
  new_data jsonb,
  occurred_at timestamptz not null default now()
);

create function private.is_admin() returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles where id = auth.uid() and role = 'admin' and status = 'active');
$$;
create function private.is_active() returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles p where p.id = auth.uid() and p.status = 'active'
    and (p.role = 'admin' or exists(select 1 from public.student_registry s
      where s.id = p.claimed_student_id and s.active and s.linked_user_id = p.id)));
$$;
revoke all on function private.is_admin(), private.is_active() from public;
grant execute on function private.is_admin(), private.is_active() to authenticated;

-- Auth checks NIS/NISN without exposing a public registry lookup endpoint.
-- A pending claim does not link/lock the student identity. Only reviewed activation does.
create function private.create_member_profile() returns trigger language plpgsql security definer set search_path = '' as $$
declare
  student_id uuid;
  identity_kind text := new.raw_user_meta_data ->> 'identity_kind';
  identity_number text := btrim(new.raw_user_meta_data ->> 'identity_number');
begin
  if identity_kind not in ('nis','nisn') or identity_number is null or identity_number !~ '^[0-9]+$' then
    raise exception 'Pendaftaran tidak dapat diproses. Hubungi admin perpustakaan.';
  end if;
  select id into student_id from public.student_registry
    where active and linked_user_id is null and
      ((identity_kind = 'nis' and nis = identity_number) or (identity_kind = 'nisn' and nisn = identity_number));
  if student_id is null then
    raise exception 'Pendaftaran tidak dapat diproses. Hubungi admin perpustakaan.';
  end if;
  insert into public.profiles(id, claimed_student_id, role, status, contact)
    values (new.id, student_id, 'member', 'pending', left(new.raw_user_meta_data ->> 'contact', 200));
  return new;
end;
$$;
revoke all on function private.create_member_profile() from public;
create trigger perpus_new_auth_user after insert on auth.users for each row execute function private.create_member_profile();

create function public.review_member(p_user_id uuid, p_approve boolean, p_reason text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare p public.profiles; s public.student_registry;
begin
  if not private.is_admin() then raise exception 'Akses admin diperlukan.'; end if;
  select * into p from public.profiles where id = p_user_id for update;
  if p.id is null or p.role <> 'member' or p.status not in ('pending','rejected') then
    raise exception 'Akun tidak dapat diproses.';
  end if;
  if p_approve is null then raise exception 'Keputusan wajib diisi.'; end if;
  if p_approve then
    if not exists(select 1 from auth.users where id = p_user_id and email_confirmed_at is not null) then
      raise exception 'Email akun belum dikonfirmasi.';
    end if;
    select * into s from public.student_registry where id = p.claimed_student_id for update;
    if not s.active or s.linked_user_id is not null then raise exception 'Identitas tidak dapat diaktifkan.'; end if;
    update public.student_registry set linked_user_id = p_user_id where id = s.id;
    update public.profiles set status = 'active', reviewed_by = auth.uid(), reviewed_at = now(), rejection_reason = null where id = p_user_id;
  else
    if p_reason is null or length(btrim(p_reason)) = 0 then raise exception 'Alasan wajib diisi.'; end if;
    update public.profiles set status = 'rejected', rejection_reason = p_reason,
      reviewed_by = auth.uid(), reviewed_at = now() where id = p_user_id;
  end if;
end;
$$;
revoke all on function public.review_member(uuid,boolean,text) from public, anon;
grant execute on function public.review_member(uuid,boolean,text) to authenticated;

create function private.audit_change() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.audit_logs(actor_id, action, table_name, record_id, old_data, new_data)
    values (auth.uid(), tg_op, tg_table_name, coalesce(to_jsonb(new)->>'id',to_jsonb(old)->>'id'),
      case when tg_op = 'INSERT' then null else to_jsonb(old) end,
      case when tg_op = 'DELETE' then null else to_jsonb(new) end);
  return coalesce(new, old);
end;
$$;
revoke all on function private.audit_change() from public;
create trigger audit_students after insert or update or delete on public.student_registry for each row execute function private.audit_change();
create trigger audit_profiles after insert or update or delete on public.profiles for each row execute function private.audit_change();
create trigger audit_books after insert or update or delete on public.books for each row execute function private.audit_change();
create trigger audit_copies after insert or update or delete on public.book_copies for each row execute function private.audit_change();
create trigger audit_settings after update on public.library_settings for each row execute function private.audit_change();

alter table public.student_registry enable row level security;
alter table public.profiles enable row level security;
alter table public.books enable row level security;
alter table public.book_copies enable row level security;
alter table public.library_settings enable row level security;
alter table public.audit_logs enable row level security;
revoke all on public.student_registry, public.profiles, public.books, public.book_copies, public.library_settings, public.audit_logs from anon, authenticated;
grant select on public.student_registry, public.profiles, public.books, public.book_copies, public.library_settings, public.audit_logs to authenticated;
grant insert (nis,nisn,full_name,class_name,active) on public.student_registry to authenticated;
grant update (nis,nisn,full_name,class_name,active) on public.student_registry to authenticated;
grant insert (title,author,category,isbn,description) on public.books to authenticated;
grant update (title,author,category,isbn,description,archived_at) on public.books to authenticated;
-- Stock transitions are reserved for future transactional RPCs, even for admins.
grant insert (book_id,code) on public.book_copies to authenticated;
grant update (loan_days,max_books,school_timezone,evidence_retention,policy_confirmed) on public.library_settings to authenticated;
create policy students_read on public.student_registry for select to authenticated using (private.is_admin() or linked_user_id = auth.uid());
create policy students_insert on public.student_registry for insert to authenticated with check (private.is_admin());
create policy students_update on public.student_registry for update to authenticated using (private.is_admin()) with check (private.is_admin());
create policy profiles_read on public.profiles for select to authenticated using (id = auth.uid() or private.is_admin());
create policy books_read on public.books for select to authenticated using (private.is_admin() or (private.is_active() and archived_at is null));
create policy books_insert on public.books for insert to authenticated with check (private.is_admin());
create policy books_update on public.books for update to authenticated using (private.is_admin()) with check (private.is_admin());
create policy copies_read on public.book_copies for select to authenticated using (private.is_admin() or (private.is_active() and archived_at is null));
create policy copies_insert on public.book_copies for insert to authenticated with check (private.is_admin());
create policy settings_read on public.library_settings for select to authenticated using (private.is_active());
create policy settings_update on public.library_settings for update to authenticated using (private.is_admin()) with check (private.is_admin());
create policy audit_read on public.audit_logs for select to authenticated using (private.is_admin());
commit;
