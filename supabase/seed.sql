-- Development only. Fictitious students; no auth users or passwords.
begin;
insert into public.student_registry(nis, nisn, full_name, class_name) values
  ('001024', '0099000024', 'Alya Putri (Contoh)', 'XI IPA 1'),
  ('001025', '0099000025', 'Raka Pratama (Contoh)', 'XI IPA 2') on conflict (nis) do nothing;
insert into public.books(id,title,author,category) values
  ('00000000-0000-4000-8000-000000000001','Algoritma Dasar','Tim Edukasi Perpus','Teknologi') on conflict (id) do nothing;
insert into public.book_copies(book_id,code) values
  ('00000000-0000-4000-8000-000000000001','BK-001'),
  ('00000000-0000-4000-8000-000000000001','BK-002') on conflict (code) do nothing;
commit;
