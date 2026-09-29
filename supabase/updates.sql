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
--   5. Notifications: each user's own list, under the bell.
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


-- ---------------------------------------------------------------------
-- 5. Notifications
-- ---------------------------------------------------------------------
-- Each user's own list of what has happened that concerns them, under the
-- bell on their home screen. Only this section's functions add to it, never
-- the app, so a notification always means it really happened:
--   admins:    someone registered; a worker sent their documents or asks to
--              be checked again; a customer reported a worker
--   workers:   approved or rejected; a customer reviewed them, or tapped
--              Call or WhatsApp on their page
--   customers: the team has dealt with their report
--   everyone:  welcome; account deactivated or reactivated
-- The app words each one from [type] and [data] (app_strings.dart), so it
-- can be translated. Workers aren't told which customer reviewed or
-- contacted them, as the app doesn't show reviewers' names.
create table if not exists public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  type        text not null,
  data        jsonb not null default '{}',
  actor_id    uuid references public.profiles (id) on delete set null, -- who caused it, when a user did
  read_at     timestamptz,
  created_at  timestamptz not null default now()
);
create index if not exists notifications_user_idx on public.notifications (user_id, created_at desc);

alter table public.notifications enable row level security;
revoke all on public.notifications from anon, authenticated;

-- Users read their own and mark them read; nothing else.
grant select on public.notifications to authenticated;
grant update (read_at) on public.notifications to authenticated;

drop policy if exists "notifications: read own" on public.notifications;
create policy "notifications: read own"
  on public.notifications for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "notifications: mark own read" on public.notifications;
create policy "notifications: mark own read"
  on public.notifications for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- New ones reach the bell straight away (Supabase Realtime).
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications'
     ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end;
$$;

-- Adding notifications. The app can't call these; the triggers below do.
create or replace function public.add_notification(recipient uuid, kind text, details jsonb default '{}', actor uuid default null)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.notifications (user_id, type, data, actor_id)
  values (recipient, kind, coalesce(details, '{}'), actor);
$$;

-- Every admin except [actor], so an admin isn't told about what they did.
create or replace function public.add_admin_notification(kind text, details jsonb default '{}', actor uuid default null)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.notifications (user_id, type, data, actor_id)
  select id, kind, coalesce(details, '{}'), actor
  from public.profiles
  where role = 'admin' and id is distinct from actor;
$$;

revoke execute on function public.add_notification(uuid, text, jsonb, uuid),
  public.add_admin_notification(text, jsonb, uuid)
  from public, anon, authenticated;

-- 5a. Someone registered: they entered the code from their email (A4). Their
-- profiles row is made earlier, when the code is sent, so people who never
-- enter it aren't announced. The insert trigger is for projects that don't
-- ask for the code; its name sorts after on_auth_user_created (schema.sql),
-- so the profiles row is there first.
create or replace function public.handle_user_registered()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  p public.profiles;
begin
  select * into p from public.profiles where id = new.id;
  if not found then
    return new;
  end if;
  perform public.add_notification(p.id, 'welcome', jsonb_build_object('role', p.role));
  perform public.add_admin_notification('new_user',
    jsonb_build_object('user_id', p.id, 'name', p.full_name, 'email', p.email, 'role', p.role), p.id);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_confirmed on auth.users;
create trigger on_auth_user_created_confirmed
  after insert on auth.users
  for each row when (new.email_confirmed_at is not null)
  execute function public.handle_user_registered();

drop trigger if exists on_auth_user_confirmed on auth.users;
create trigger on_auth_user_confirmed
  after update of email_confirmed_at on auth.users
  for each row when (old.email_confirmed_at is null and new.email_confirmed_at is not null)
  execute function public.handle_user_registered();

-- 5b. A worker sent their documents for checking for the first time (B3).
create or replace function public.handle_worker_documents_sent()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.add_admin_notification('worker_submitted',
    jsonb_build_object(
      'worker_id', new.worker_id,
      'name', (select full_name from public.profiles where id = new.worker_id)),
    new.worker_id);
  return new;
end;
$$;

drop trigger if exists worker_verifications_notify on public.worker_verifications;
create trigger worker_verifications_notify
  after insert on public.worker_verifications
  for each row execute function public.handle_worker_documents_sent();

-- 5c. An admin approved or rejected a worker (section 1): the worker. A
-- rejected worker asked to be checked again (B4): the admins.
create or replace function public.handle_verification_changed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.verification_status = 'approved' then
    perform public.add_notification(new.id, 'worker_approved', '{}', (select auth.uid()));
  elsif new.verification_status = 'rejected' then
    perform public.add_notification(new.id, 'worker_rejected',
      jsonb_build_object('note', new.admin_notes), (select auth.uid()));
  elsif old.verification_status = 'rejected' and new.id = (select auth.uid()) then
    perform public.add_admin_notification('worker_resubmitted',
      jsonb_build_object('worker_id', new.id, 'name', (select full_name from public.profiles where id = new.id)),
      new.id);
  end if;
  return new;
end;
$$;

drop trigger if exists worker_profiles_verification_notify on public.worker_profiles;
create trigger worker_profiles_verification_notify
  after update of verification_status on public.worker_profiles
  for each row when (old.verification_status is distinct from new.verification_status)
  execute function public.handle_verification_changed();

-- 5d. A customer reviewed a worker, or changed their review (C4): the worker.
-- Saving the same review again changes nothing, so tells no one.
create or replace function public.handle_review_saved()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.add_notification(new.worker_id,
    case when tg_op = 'INSERT' then 'review_new' else 'review_updated' end,
    jsonb_build_object('worker_id', new.worker_id, 'rating', new.rating),
    new.customer_id);
  return new;
end;
$$;

drop trigger if exists reviews_notify_new on public.reviews;
create trigger reviews_notify_new
  after insert on public.reviews
  for each row execute function public.handle_review_saved();

drop trigger if exists reviews_notify_changed on public.reviews;
create trigger reviews_notify_changed
  after update of rating, comment on public.reviews
  for each row when (old.rating is distinct from new.rating or old.comment is distinct from new.comment)
  execute function public.handle_review_saved();

-- 5e. A customer reported a worker (C5): the admins. The worker isn't told.
-- An admin changed the report's status (in the Supabase dashboard): the
-- customer who sent it.
create or replace function public.handle_report_sent()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.add_admin_notification('report_new',
    jsonb_build_object(
      'report_id', new.id,
      'worker_id', new.worker_id,
      'worker_name', (select full_name from public.profiles where id = new.worker_id),
      'reason', new.reason),
    new.reporter_id);
  return new;
end;
$$;

drop trigger if exists reports_notify_new on public.reports;
create trigger reports_notify_new
  after insert on public.reports
  for each row execute function public.handle_report_sent();

create or replace function public.handle_report_status_changed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.add_notification(new.reporter_id, 'report_updated',
    jsonb_build_object(
      'report_id', new.id,
      'worker_name', (select full_name from public.profiles where id = new.worker_id),
      'status', new.status),
    (select auth.uid()));
  return new;
end;
$$;

drop trigger if exists reports_notify_status on public.reports;
create trigger reports_notify_status
  after update of status on public.reports
  for each row when (old.status is distinct from new.status)
  execute function public.handle_report_status_changed();

-- 5f. An admin deactivated or reactivated a user (section 2): that user.
create or replace function public.handle_account_status_changed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.add_notification(new.id,
    case when new.is_active then 'account_reactivated' else 'account_deactivated' end,
    jsonb_build_object('reason', new.deactivated_reason),
    (select auth.uid()));
  return new;
end;
$$;

drop trigger if exists profiles_active_notify on public.profiles;
create trigger profiles_active_notify
  after update of is_active on public.profiles
  for each row when (old.is_active is distinct from new.is_active)
  execute function public.handle_account_status_changed();

-- 5g. C3: a customer tapped Call or WhatsApp on a worker's page, so the
-- worker knows someone is getting in touch. At most once a day for each
-- customer and worker; only for workers customers can see; never for
-- yourself. [method] is 'call' or 'whatsapp'.
create or replace function public.record_contact(worker_id uuid, method text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
begin
  if method not in ('call', 'whatsapp') then
    raise exception 'Unknown contact method: %', method using errcode = '22023';
  end if;
  if me is null or me = record_contact.worker_id or not public.is_active_profile(me) then
    return;
  end if;
  if not exists (select 1 from public.worker_directory d where d.id = record_contact.worker_id) then
    return;
  end if;
  if exists (
    select 1 from public.notifications n
    where n.user_id = record_contact.worker_id and n.actor_id = me and n.type = 'contact'
      and n.created_at > now() - interval '1 day'
  ) then
    return;
  end if;
  perform public.add_notification(record_contact.worker_id, 'contact',
    jsonb_build_object('method', method), me);
end;
$$;

revoke execute on function public.record_contact(uuid, text) from public, anon;
grant execute on function public.record_contact(uuid, text) to authenticated;


-- Make the app's API see the new functions now, not in a few minutes.
notify pgrst, 'reload schema';
