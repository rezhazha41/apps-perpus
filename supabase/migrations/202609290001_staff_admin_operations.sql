-- Separate staff identity from students and complete admin operations.
-- Apply after 202609280001_identity_inventory.sql. It is safe before or after
-- 202609280002_transactions.sql.
begin;

create table public.staff_registry (
  id uuid primary key default gen_random_uuid(),
  staff_no text unique,
  full_name text not null check (length(btrim(full_name)) > 0),
  position text not null default 'Pengurus Perpustakaan',
  active boolean not null default true,
  linked_user_id uuid unique references auth.users(id),
  created_at timestamptz not null default now()
);

alter table public.profiles add column staff_id uuid references public.staff_registry(id);

-- Preserve existing admin accounts while moving their identity to staff_registry.
insert into public.staff_registry(full_name, position, linked_user_id)
select coalesce(nullif(btrim(u.raw_user_meta_data->>'full_name'), ''), u.email, 'Pengurus Perpustakaan'),
       'Pengurus Perpustakaan', p.id
from public.profiles p
join auth.users u on u.id=p.id
where p.role='admin'
on conflict (linked_user_id) do nothing;

update public.student_registry s
set linked_user_id=null
from public.profiles p
where p.role='admin' and s.linked_user_id=p.id;

update public.profiles p
set staff_id=s.id, claimed_student_id=null
from public.staff_registry s
where s.linked_user_id=p.id and p.role='admin';

alter table public.profiles
  add constraint profiles_identity_role_check check (
    (role='member' and claimed_student_id is not null and staff_id is null)
    or (role='admin' and claimed_student_id is null and staff_id is not null)
  );

create or replace function private.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles p
    join public.staff_registry s on s.id=p.staff_id
    where p.id=auth.uid() and p.role='admin' and p.status='active'
      and s.active and s.linked_user_id=p.id
  );
$$;

create or replace function private.is_active() returns boolean
language sql stable security definer set search_path = '' as $$
  select private.is_admin() or exists (
    select 1 from public.profiles p
    join public.student_registry s on s.id=p.claimed_student_id
    where p.id=auth.uid() and p.role='member' and p.status='active'
      and s.active and s.linked_user_id=p.id
  );
$$;

alter table public.staff_registry enable row level security;
revoke all on public.staff_registry from anon, authenticated;
grant select on public.staff_registry to authenticated;
create policy staff_read on public.staff_registry for select to authenticated
  using (private.is_admin() or linked_user_id=auth.uid());
create trigger audit_staff after insert or update or delete on public.staff_registry
  for each row execute function private.audit_change();

-- Only admins can archive a copy, and only while it is available. Loan-state
-- changes remain exclusively owned by transaction RPCs.
create function public.archive_available_copy(p_copy_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare changed integer;
begin
  if not private.is_admin() then raise exception 'Akses admin diperlukan.'; end if;
  update public.book_copies set archived_at=now()
  where id=p_copy_id and archived_at is null and status='available';
  get diagnostics changed = row_count;
  if changed<>1 then raise exception 'Eksemplar tidak tersedia untuk diarsipkan.'; end if;
end;
$$;
revoke all on function public.archive_available_copy(uuid) from public, anon;
grant execute on function public.archive_available_copy(uuid) to authenticated;

commit;
