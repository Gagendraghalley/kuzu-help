-- =====================================================================
-- Kuzu Help - database updates after schema.sql
-- Run in Supabase > SQL Editor, after schema.sql: open this file, copy
-- ALL of it, paste it into a new query and press Run.
-- Safe to run again: it replaces what it made last time. Run the latest
-- version whenever the app says 'The database needs an update'.
-- =====================================================================
--   1. Admins approve or reject workers from the app.
--   2. Admins deactivate (blacklist) users.
--   3. Workers can switch to customer; sign-up and log-in check emails.
--   4. What customers see in worker_directory, with all of the above.
-- The last line makes the app see the changes straight away.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Approving workers
-- ---------------------------------------------------------------------
-- schema.sql lets no one change worker_profiles.verification_status through
-- the app, so a worker can never approve themself. This function is the one
-- way in, and it refuses anyone who isn't an admin.
--   approved: the worker appears to customers (worker_directory)
--   rejected: [note] is shown to the worker on their pending screen (B4)
--   pending:  back to waiting
create or replace function public.set_worker_verification(worker_id uuid, new_status text, note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can approve or reject workers' using errcode = '42501';
  end if;
  if new_status not in ('pending', 'approved', 'rejected') then
    raise exception 'Unknown status: %', new_status using errcode = '22023';
  end if;

  update public.worker_profiles
  set verification_status = new_status,
      admin_notes = case when new_status = 'rejected' then note end
  where id = worker_id;

  if not found then
    raise exception 'No worker with this ID' using errcode = 'P0002';
  end if;
end;
$$;

revoke execute on function public.set_worker_verification(uuid, text, text) from public, anon;
grant execute on function public.set_worker_verification(uuid, text, text) to authenticated;


-- ---------------------------------------------------------------------
-- 2. Deactivating (blacklisting) users
-- ---------------------------------------------------------------------
-- A deactivated user:
--   * sees 'Your account is deactivated' (with the admin's reason) when they
--     open the app, and nothing else;
--   * if a worker, is hidden from customers (worker_directory, section 4);
--   * can't write anything through the API: the rules below refuse it;
--   * has their reviews hidden, and left out of workers' ratings.
-- Admins can't be deactivated, so there is always a way back in.
alter table public.profiles
  add column if not exists is_active boolean not null default true,
  add column if not exists deactivated_reason text check (char_length(deactivated_reason) <= 500);

-- False once an admin has deactivated the user (or if there's no such user).
-- 'security definer' so the rules below can check other users' rows.
create or replace function public.is_active_profile(user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select is_active from public.profiles where id = user_id), false);
$$;

revoke execute on function public.is_active_profile(uuid) from public, anon;
grant execute on function public.is_active_profile(uuid) to authenticated;

-- Admins: deactivate or reactivate a user. [reason] is shown to them.
create or replace function public.set_user_active(user_id uuid, active boolean, reason text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can deactivate users' using errcode = '42501';
  end if;
  if exists (select 1 from public.profiles where id = user_id and role = 'admin') then
    raise exception 'Admins cannot be deactivated' using errcode = '42501';
  end if;

  update public.profiles
  set is_active = active,
      deactivated_reason = case when active then null else reason end
  where id = user_id;

  if not found then
    raise exception 'No user with this ID' using errcode = 'P0002';
  end if;
end;
$$;

revoke execute on function public.set_user_active(uuid, boolean, text) from public, anon;
grant execute on function public.set_user_active(uuid, boolean, text) to authenticated;

-- Deactivated users can't write. Same rules as schema.sql section 5, plus
-- the is_active_profile() check.
alter policy "profiles: update own" on public.profiles
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()) and (select public.is_active_profile((select auth.uid()))));

alter policy "worker_profiles: workers create their own" on public.worker_profiles
  with check (
    id = (select auth.uid())
    and (select public.is_worker())
    and (select public.is_active_profile((select auth.uid())))
  );

alter policy "worker_profiles: update own" on public.worker_profiles
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()) and (select public.is_active_profile((select auth.uid()))));

alter policy "worker_services: workers add their own" on public.worker_services
  with check (worker_id = (select auth.uid()) and (select public.is_active_profile((select auth.uid()))));

alter policy "worker_services: workers edit their own" on public.worker_services
  using (worker_id = (select auth.uid()))
  with check (worker_id = (select auth.uid()) and (select public.is_active_profile((select auth.uid()))));

alter policy "worker_services: workers remove their own" on public.worker_services
  using (worker_id = (select auth.uid()) and (select public.is_active_profile((select auth.uid()))));

alter policy "worker_verifications: workers add their own" on public.worker_verifications
  with check (worker_id = (select auth.uid()) and (select public.is_active_profile((select auth.uid()))));

alter policy "worker_verifications: workers update their own" on public.worker_verifications
  using (worker_id = (select auth.uid()))
  with check (worker_id = (select auth.uid()) and (select public.is_active_profile((select auth.uid()))));

alter policy "reviews: write your own" on public.reviews
  with check (customer_id = (select auth.uid()) and (select public.is_active_profile((select auth.uid()))));

alter policy "reviews: edit your own" on public.reviews
  using (customer_id = (select auth.uid()))
  with check (customer_id = (select auth.uid()) and (select public.is_active_profile((select auth.uid()))));

alter policy "reports: report as yourself" on public.reports
  with check (reporter_id = (select auth.uid()) and (select public.is_active_profile((select auth.uid()))));

-- Reviews by deactivated customers are hidden.
alter policy "reviews: everyone reads" on public.reviews
  using (public.is_active_profile(customer_id));


-- ---------------------------------------------------------------------
-- 3. Switching roles, and checking emails
-- ---------------------------------------------------------------------
-- D1 / B1 'Stop offering services', the reverse of become_worker(). Each
-- only changes that one role, so admins can never switch to customer or
-- worker. The worker profile is kept (hidden by section 4) in case they
-- offer services again.
create or replace function public.become_customer()
returns void
language sql
security definer
set search_path = ''
as $$
  update public.profiles
  set role = 'customer'
  where id = (select auth.uid()) and role = 'worker';
$$;

revoke execute on function public.become_customer() from public, anon;
grant execute on function public.become_customer() to authenticated;

-- A3: is there a confirmed account with this email? Callable before logging
-- in, so sign-up can say 'already registered' (instead of quietly logging the
-- person in) and log-in can say 'no account'. This does tell anyone whether
-- an email is registered; that is what those messages need. Sign-ups whose
-- code was never entered don't count, so those people can sign up again.
create or replace function public.is_email_registered(check_email text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from auth.users
    where lower(email) = lower(trim(check_email)) and email_confirmed_at is not null
  );
$$;

revoke execute on function public.is_email_registered(text) from public;
grant execute on function public.is_email_registered(text) to anon, authenticated;


-- ---------------------------------------------------------------------
-- 4. What customers see: approved, active, current workers, rated by
--    active customers. (Same columns as in schema.sql; replacing the view
--    keeps its grants.)
-- ---------------------------------------------------------------------
create or replace view public.worker_directory as
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
left join public.reviews r
  on r.worker_id = w.id
  and exists (select 1 from public.profiles c where c.id = r.customer_id and c.is_active)
where w.verification_status = 'approved' and p.is_active and p.role = 'worker'
group by w.id, p.id;


-- Make the app's API see the new functions now, not in a few minutes.
notify pgrst, 'reload schema';
