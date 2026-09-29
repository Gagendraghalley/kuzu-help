-- =====================================================================
-- Kuzu Help - database schema (version 1)
-- Run ONCE in Supabase > SQL Editor on a fresh project.
-- Running it twice gives 'already exists' errors: use a fresh project instead.
-- =====================================================================
-- Creates:
--   Tables (all with RLS enabled):
--     profiles, service_categories, worker_profiles, worker_services,
--     worker_verifications, reviews, reports
--   View:      worker_directory (approved workers + avg rating + review count)
--   Buckets:   avatars (public), verification-docs (private)
--   Trigger:   create profiles row on sign-up using full_name + role metadata
--   Seed:      Plumber, Electrician, Carpenter, Appliance Repair, Painter, Mason
--   App calls: become_worker(), request_review()
--              (the admin, deactivation, role-switch and email-check
--               functions are in updates.sql: run it after this)
--
-- Security rules it guarantees:
--   * users cannot set role = 'admin' (only customer -> worker allowed)
--   * workers cannot change their own verification_status
--   * one review per customer per worker; no self-reviews
--   * verification-docs readable only by the owner and admins
--   * uploads only allowed inside the user's own <user-id>/ folder
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------

-- One row per user, created automatically on sign-up (section 3).
create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text not null default '',
  role        text not null default 'customer'
              check (role in ('customer', 'worker', 'admin')),
  email       text,
  phone       text,                       -- +975XXXXXXXX
  avatar_url  text,
  dzongkhag   text,
  town        text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.service_categories (
  id          uuid primary key default gen_random_uuid(),
  name        text not null unique,
  name_dz     text,                       -- Dzongkha name, filled in later
  icon        text,                       -- file name in assets/icons/categories/
  sort_order  int  not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

-- Worker details shown to customers. Only admins set verification_status
-- and admin_notes (in the dashboard); see the grants in section 5.
create table public.worker_profiles (
  id                   uuid primary key references public.profiles (id) on delete cascade,
  bio                  text check (char_length(bio) <= 500),
  years_experience     int  not null default 0 check (years_experience between 0 and 60),
  whatsapp_number      text check (whatsapp_number ~ '^\+[0-9]{8,15}$'),
  is_available         boolean not null default true,
  verification_status  text not null default 'pending'
                       check (verification_status in ('pending', 'approved', 'rejected')),
  admin_notes          text,              -- shown to the worker when rejected
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create table public.worker_services (
  worker_id    uuid not null references public.worker_profiles (id) on delete cascade,
  category_id  uuid not null references public.service_categories (id),
  price_note   text check (char_length(price_note) <= 100),   -- e.g. 'Nu 500 per visit'
  created_at   timestamptz not null default now(),
  primary key (worker_id, category_id)
);
create index worker_services_category_idx on public.worker_services (category_id);

-- CID photo (required) and training certificate (optional) in the private
-- verification-docs bucket. Files must be inside the worker's own folder.
create table public.worker_verifications (
  worker_id         uuid primary key references public.worker_profiles (id) on delete cascade,
  cid_path          text not null,
  certificate_path  text,
  consent_given     boolean not null,
  submitted_at      timestamptz not null default now(),
  check (consent_given),
  check (split_part(cid_path, '/', 1) = worker_id::text),
  check (split_part(certificate_path, '/', 1) = worker_id::text)
);

create table public.reviews (
  id           uuid primary key default gen_random_uuid(),
  worker_id    uuid not null references public.worker_profiles (id) on delete cascade,
  customer_id  uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  rating       smallint not null check (rating between 1 and 5),
  comment      text check (char_length(comment) <= 1000),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (worker_id, customer_id),        -- one review per customer per worker
  check (worker_id <> customer_id)        -- no self-reviews
);

create table public.reports (
  id           uuid primary key default gen_random_uuid(),
  worker_id    uuid not null references public.worker_profiles (id) on delete cascade,
  reporter_id  uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  reason       text not null check (reason in
               ('did_not_show_up', 'poor_work', 'overcharged', 'rude_or_unsafe', 'other')),
  details      text check (char_length(details) <= 1000),
  status       text not null default 'open' check (status in ('open', 'reviewed', 'closed')),
  created_at   timestamptz not null default now(),
  check (worker_id <> reporter_id)
);
create index reports_status_idx on public.reports (status);


-- ---------------------------------------------------------------------
-- 2. Helper functions
-- ---------------------------------------------------------------------

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger worker_profiles_updated_at before update on public.worker_profiles
  for each row execute function public.set_updated_at();
create trigger reviews_updated_at before update on public.reviews
  for each row execute function public.set_updated_at();

-- Used by the security rules. 'security definer' lets them read the caller's
-- role without running into the profiles table's own rules.
create function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'admin'
  );
$$;

create function public.is_worker()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'worker'
  );
$$;


-- ---------------------------------------------------------------------
-- 3. Create a profile on sign-up
-- ---------------------------------------------------------------------
-- The app sends full_name and role ('customer' or 'worker') as sign-up
-- metadata. Anything else, including 'admin', becomes 'customer':
-- nobody can sign up as an admin.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, role, email, phone)
  values (
    new.id,
    coalesce(trim(new.raw_user_meta_data ->> 'full_name'), ''),
    case when new.raw_user_meta_data ->> 'role' = 'worker' then 'worker' else 'customer' end,
    new.email,
    case when coalesce(new.phone, '') <> '' then '+' || new.phone end
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ---------------------------------------------------------------------
-- 4. Functions the app calls
-- ---------------------------------------------------------------------

-- D1 'Become a worker': the only role change users can make themselves.
create function public.become_worker()
returns void
language sql
security definer
set search_path = ''
as $$
  update public.profiles
  set role = 'worker'
  where id = (select auth.uid()) and role = 'customer';
$$;

-- B4: a rejected worker who has fixed their details asks to be checked again.
create function public.request_review()
returns void
language sql
security definer
set search_path = ''
as $$
  update public.worker_profiles
  set verification_status = 'pending'
  where id = (select auth.uid()) and verification_status = 'rejected';
$$;


-- ---------------------------------------------------------------------
-- 5. Who can do what (Row Level Security)
-- ---------------------------------------------------------------------
-- Supabase grants everything to 'anon' (not logged in) and 'authenticated'
-- by default. Start from nothing and give back only what the app needs.
-- The app always logs in first, so anon gets no access at all.

-- worker_directory: approved workers only, with their rating. Customers search
-- this instead of the tables, so they only ever see approved workers' public
-- details. It runs with the owner's rights (Supabase's linter reports it as a
-- 'security definer view'); that is on purpose: the tables' rules hide other
-- users' rows, and this view shows just these safe columns.
create view public.worker_directory as
select
  w.id,
  p.full_name,
  p.avatar_url,
  p.dzongkhag,
  p.town,
  w.bio,
  w.years_experience,
  w.whatsapp_number,
  w.is_available,
  coalesce(avg(r.rating), 0)::float8 as avg_rating,
  count(r.id)::int                   as review_count
from public.worker_profiles w
join public.profiles p on p.id = w.id
left join public.reviews r on r.worker_id = w.id
where w.verification_status = 'approved'
group by w.id, p.id;

alter table public.profiles             enable row level security;
alter table public.service_categories   enable row level security;
alter table public.worker_profiles      enable row level security;
alter table public.worker_services      enable row level security;
alter table public.worker_verifications enable row level security;
alter table public.reviews              enable row level security;
alter table public.reports              enable row level security;

revoke all on public.profiles, public.service_categories, public.worker_profiles,
  public.worker_services, public.worker_verifications, public.reviews,
  public.reports, public.worker_directory
  from anon, authenticated;

revoke execute on function public.is_admin(), public.is_worker(),
  public.become_worker(), public.request_review()
  from public, anon;
grant execute on function public.is_admin(), public.is_worker(),
  public.become_worker(), public.request_review()
  to authenticated;

grant select on public.worker_directory to authenticated;

-- profiles: read and edit your own row (admins read all). Only name, photo
-- and location are editable; role changes go through become_worker().
grant select on public.profiles to authenticated;
grant update (full_name, avatar_url, dzongkhag, town) on public.profiles to authenticated;

create policy "profiles: read own, admins read all"
  on public.profiles for select to authenticated
  using (id = (select auth.uid()) or (select public.is_admin()));

create policy "profiles: update own"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- service_categories: everyone logged in can read. Admins edit them in the dashboard.
grant select on public.service_categories to authenticated;

create policy "service_categories: everyone reads"
  on public.service_categories for select to authenticated
  using (true);

-- worker_profiles: workers create and edit their own row, but never
-- verification_status or admin_notes (id is included so the app can upsert).
grant select on public.worker_profiles to authenticated;
grant insert (id, bio, years_experience, whatsapp_number, is_available)
  on public.worker_profiles to authenticated;
grant update (id, bio, years_experience, whatsapp_number, is_available)
  on public.worker_profiles to authenticated;

create policy "worker_profiles: read own, admins read all"
  on public.worker_profiles for select to authenticated
  using (id = (select auth.uid()) or (select public.is_admin()));

create policy "worker_profiles: workers create their own"
  on public.worker_profiles for insert to authenticated
  with check (id = (select auth.uid()) and (select public.is_worker()));

create policy "worker_profiles: update own"
  on public.worker_profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- worker_services: everyone can read (search needs it); workers manage their own.
grant select, insert, update, delete on public.worker_services to authenticated;

create policy "worker_services: everyone reads"
  on public.worker_services for select to authenticated
  using (true);

create policy "worker_services: workers add their own"
  on public.worker_services for insert to authenticated
  with check (worker_id = (select auth.uid()));

create policy "worker_services: workers edit their own"
  on public.worker_services for update to authenticated
  using (worker_id = (select auth.uid()))
  with check (worker_id = (select auth.uid()));

create policy "worker_services: workers remove their own"
  on public.worker_services for delete to authenticated
  using (worker_id = (select auth.uid()));

-- worker_verifications: only the worker and admins can read.
grant select, insert, update on public.worker_verifications to authenticated;

create policy "worker_verifications: read own, admins read all"
  on public.worker_verifications for select to authenticated
  using (worker_id = (select auth.uid()) or (select public.is_admin()));

create policy "worker_verifications: workers add their own"
  on public.worker_verifications for insert to authenticated
  with check (worker_id = (select auth.uid()));

create policy "worker_verifications: workers update their own"
  on public.worker_verifications for update to authenticated
  using (worker_id = (select auth.uid()))
  with check (worker_id = (select auth.uid()));

-- reviews: everyone can read; customers write and edit their own.
grant select, insert, update on public.reviews to authenticated;

create policy "reviews: everyone reads"
  on public.reviews for select to authenticated
  using (true);

create policy "reviews: write your own"
  on public.reviews for insert to authenticated
  with check (customer_id = (select auth.uid()));

create policy "reviews: edit your own"
  on public.reviews for update to authenticated
  using (customer_id = (select auth.uid()))
  with check (customer_id = (select auth.uid()));

-- reports: anyone can report a worker; only the reporter and admins can read
-- it. status always starts as 'open' and only admins change it.
grant select on public.reports to authenticated;
grant insert (worker_id, reporter_id, reason, details) on public.reports to authenticated;

create policy "reports: read own, admins read all"
  on public.reports for select to authenticated
  using (reporter_id = (select auth.uid()) or (select public.is_admin()));

create policy "reports: report as yourself"
  on public.reports for insert to authenticated
  with check (reporter_id = (select auth.uid()));


-- ---------------------------------------------------------------------
-- 6. Storage buckets and rules
-- ---------------------------------------------------------------------
-- Upload images with contentType 'image/jpeg' (or png/webp), or the bucket
-- rejects them.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 2097152,
   array['image/jpeg', 'image/png', 'image/webp']),
  ('verification-docs', 'verification-docs', false, 5242880,
   array['image/jpeg', 'image/png', 'application/pdf']);

-- Uploads only inside your own <user-id>/ folder (see storage_paths.dart).
create policy "storage: upload into own folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id in ('avatars', 'verification-docs')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "storage: replace own files"
  on storage.objects for update to authenticated
  using (
    bucket_id in ('avatars', 'verification-docs')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id in ('avatars', 'verification-docs')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "storage: delete own files"
  on storage.objects for delete to authenticated
  using (
    bucket_id in ('avatars', 'verification-docs')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- Avatars are public, so anyone can view them through their public URL. Through
-- the API you can read your own files, and admins can read CID documents.
create policy "storage: read own files, admins read verification docs"
  on storage.objects for select to authenticated
  using (
    bucket_id in ('avatars', 'verification-docs')
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or (bucket_id = 'verification-docs' and (select public.is_admin()))
    )
  );


-- ---------------------------------------------------------------------
-- 7. Starting data
-- ---------------------------------------------------------------------
insert into public.service_categories (name, icon, sort_order) values
  ('Plumber',          'plumber',          1),
  ('Electrician',      'electrician',      2),
  ('Carpenter',        'carpenter',        3),
  ('Appliance Repair', 'appliance_repair', 4),
  ('Painter',          'painter',          5),
  ('Mason',            'mason',            6);


-- ---------------------------------------------------------------------
-- Make yourself an admin (Phase 5): sign up in the app first, then run this
-- line on its own with your email.
-- update public.profiles set role = 'admin' where email = 'you@example.com';
