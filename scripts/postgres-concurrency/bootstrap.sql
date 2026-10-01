\set ON_ERROR_STOP on
create role anon nologin;
create role authenticated nologin;
create schema auth;
create schema storage;
create table auth.users (
  id uuid primary key,
  email text unique,
  raw_user_meta_data jsonb not null default '{}',
  email_confirmed_at timestamptz
);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
create table storage.buckets (
  id text primary key,
  name text not null,
  public boolean not null default false,
  file_size_limit bigint,
  allowed_mime_types text[]
);
create table storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text not null,
  name text not null,
  owner_id text not null,
  unique(bucket_id,name)
);
alter table storage.objects enable row level security;
create function storage.foldername(name text) returns text[] language sql immutable as $$
  select case when array_length(string_to_array(name,'/'),1)>1
    then (string_to_array(name,'/'))[1:array_length(string_to_array(name,'/'),1)-1]
    else array[]::text[] end
$$;
grant usage on schema auth,storage to authenticated;
grant execute on function auth.uid() to authenticated;
grant select,insert on storage.objects to authenticated;
grant execute on function storage.foldername(text) to authenticated;

