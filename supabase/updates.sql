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
--   6. Admins read reports and mark them reviewed or closed in the app.
--   7. Only customers who got in touch with a worker can review them.
--   8. Workers reply to reviews.
--   9. Photos of workers' past work.
--  10. Customers save workers.
--  11. Job requests: customers send them, workers accept or decline.
--  12. Push notifications: each notification also goes to the user's phones.
--  13. Sports grounds: admins register venues with their managers; players book grounds.
--      One account can hold more than one role (customer and player), one per service.
--      Anyone can look at venues and their free times without logging in.
--      Each ground's timings are time slots (several a day); customers book a whole slot,
--      up to a week ahead. Managers add bookings taken by phone, and regular bookings
--      (the same time every week), and keep a record of who books.
--      Each venue can have its place on the map, for directions and how far away it is.
--      New accounts made with 'Continue with Google' take the role picked on Welcome (13d).
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
--    keeps its grants.) It runs with the owner's rights, on purpose
--    (schema.sql): never with the caller's (security_invoker).
-- ---------------------------------------------------------------------
create or replace view public.worker_directory with (security_invoker = false) as
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
-- No [recipient] (a venue without a manager, section 13): nobody is told.
create or replace function public.add_notification(recipient uuid, kind text, details jsonb default '{}', actor uuid default null)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.notifications (user_id, type, data, actor_id)
  select recipient, kind, coalesce(details, '{}'), actor
  where recipient is not null;
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

-- 5g. C3: a customer tapped Call or WhatsApp on a worker's page. It's
-- recorded in worker_contacts (a customer can only review workers they've
-- been in touch with, section 7), and the worker is told someone is getting
-- in touch: at most once a day for each customer and worker; only for
-- workers customers can see; never for yourself. [method] is 'call' or
-- 'whatsapp'. Sending a job request counts as getting in touch too (section 11).
create table if not exists public.worker_contacts (
  worker_id    uuid not null references public.worker_profiles (id) on delete cascade,
  customer_id  uuid not null references public.profiles (id) on delete cascade,
  first_at     timestamptz not null default now(),
  last_at      timestamptz not null default now(),
  constraint worker_contacts_pkey primary key (worker_id, customer_id)
);

alter table public.worker_contacts enable row level security;
revoke all on public.worker_contacts from anon, authenticated;
grant select on public.worker_contacts to authenticated;

drop policy if exists "worker_contacts: customers read their own" on public.worker_contacts;
create policy "worker_contacts: customers read their own"
  on public.worker_contacts for select to authenticated
  using (customer_id = (select auth.uid()));

-- Contacts from before this table: Call/WhatsApp taps already notified, and
-- reviews already written (so their authors can still edit them).
insert into public.worker_contacts (worker_id, customer_id, first_at, last_at)
select n.user_id, n.actor_id, min(n.created_at), max(n.created_at)
from public.notifications n
where n.type = 'contact' and n.actor_id is not null
  and exists (select 1 from public.worker_profiles w where w.id = n.user_id)
group by n.user_id, n.actor_id
on conflict on constraint worker_contacts_pkey do nothing;

insert into public.worker_contacts (worker_id, customer_id, first_at, last_at)
select worker_id, customer_id, created_at, created_at from public.reviews
on conflict on constraint worker_contacts_pkey do nothing;

create or replace function public.record_contact(worker_id uuid, method text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  previous timestamptz;
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

  select c.last_at into previous from public.worker_contacts c
  where c.worker_id = record_contact.worker_id and c.customer_id = me;

  insert into public.worker_contacts as c (worker_id, customer_id)
  values (record_contact.worker_id, me)
  on conflict on constraint worker_contacts_pkey do update set last_at = now();

  if previous is null or previous < now() - interval '1 day' then
    perform public.add_notification(record_contact.worker_id, 'contact',
      jsonb_build_object('method', method), me);
  end if;
end;
$$;

revoke execute on function public.record_contact(uuid, text) from public, anon;
grant execute on function public.record_contact(uuid, text) to authenticated;


-- ---------------------------------------------------------------------
-- 6. Reports, for admins in the app
-- ---------------------------------------------------------------------
-- Settings -> Reports: each report with the names of the worker and of the
-- customer who sent it. The view runs with the caller's rights
-- (security_invoker), so the tables' rules still apply: admins see every
-- report; anyone else only their own, without other people's names.
create or replace view public.report_list with (security_invoker = true) as
select
  r.id,
  r.worker_id,
  w.full_name  as worker_name,
  w.avatar_url as worker_avatar_url,
  r.reporter_id,
  c.full_name  as reporter_name,
  c.email      as reporter_email,
  r.reason,
  r.details,
  r.status,
  r.created_at
from public.reports r
left join public.profiles w on w.id = r.worker_id
left join public.profiles c on c.id = r.reporter_id;

revoke all on public.report_list from anon, authenticated;
grant select on public.report_list to authenticated;

-- Admins: mark a report 'reviewed' or 'closed', or 'open' again. The
-- customer who sent it is told (section 5e).
create or replace function public.set_report_status(report_id uuid, new_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can update reports' using errcode = '42501';
  end if;
  if new_status not in ('open', 'reviewed', 'closed') then
    raise exception 'Unknown status: %', new_status using errcode = '22023';
  end if;

  update public.reports set status = new_status where id = report_id;

  if not found then
    raise exception 'No report with this ID' using errcode = 'P0002';
  end if;
end;
$$;

revoke execute on function public.set_report_status(uuid, text) from public, anon;
grant execute on function public.set_report_status(uuid, text) to authenticated;


-- ---------------------------------------------------------------------
-- 7. Reviews only from customers who got in touch
-- ---------------------------------------------------------------------
-- C4: a customer can only review a worker they have called, messaged or sent
-- a job request (worker_contacts, section 5g), which makes fake reviews
-- harder. These replace section 2's review rules, adding that check.
create or replace function public.has_contacted(worker uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.worker_contacts
    where worker_id = worker and customer_id = (select auth.uid())
  );
$$;

revoke execute on function public.has_contacted(uuid) from public, anon;
grant execute on function public.has_contacted(uuid) to authenticated;

alter policy "reviews: write your own" on public.reviews
  with check (
    customer_id = (select auth.uid())
    and (select public.is_active_profile((select auth.uid())))
    and public.has_contacted(worker_id)
  );

alter policy "reviews: edit your own" on public.reviews
  using (customer_id = (select auth.uid()))
  with check (
    customer_id = (select auth.uid())
    and (select public.is_active_profile((select auth.uid())))
    and public.has_contacted(worker_id)
  );

-- Customers change only their own words; the worker's reply (section 8) is
-- the worker's. worker_id and customer_id are here because saving a review
-- again (upsert) sets them to the same values.
revoke update on public.reviews from authenticated;
grant update (worker_id, customer_id, rating, comment) on public.reviews to authenticated;


-- ---------------------------------------------------------------------
-- 8. Workers reply to reviews
-- ---------------------------------------------------------------------
-- One public reply per review, shown under it. Only the worker who was
-- reviewed can write it; an empty reply removes it. The customer is told.
alter table public.reviews
  add column if not exists reply text check (char_length(reply) <= 500),
  add column if not exists replied_at timestamptz;

create or replace function public.reply_to_review(review_id uuid, reply_text text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  cleaned text := nullif(trim(reply_text), '');
begin
  if char_length(cleaned) > 500 then
    raise exception 'Replies can be up to 500 characters' using errcode = '22001';
  end if;

  update public.reviews r
  set reply = cleaned,
      replied_at = case when cleaned is null then null else now() end
  where r.id = review_id
    and r.worker_id = (select auth.uid())
    and public.is_active_profile((select auth.uid()));

  if not found then
    raise exception 'Only the worker who was reviewed can reply' using errcode = '42501';
  end if;
end;
$$;

revoke execute on function public.reply_to_review(uuid, text) from public, anon;
grant execute on function public.reply_to_review(uuid, text) to authenticated;

create or replace function public.handle_review_reply()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.add_notification(new.customer_id, 'review_reply',
    jsonb_build_object(
      'worker_id', new.worker_id,
      'worker_name', (select full_name from public.profiles where id = new.worker_id)),
    new.worker_id);
  return new;
end;
$$;

drop trigger if exists reviews_notify_reply on public.reviews;
create trigger reviews_notify_reply
  after update of reply on public.reviews
  for each row when (new.reply is not null and new.reply is distinct from old.reply)
  execute function public.handle_review_reply();


-- ---------------------------------------------------------------------
-- 9. Photos of past work
-- ---------------------------------------------------------------------
-- Up to 12 per worker, on their page. Public like avatars (anyone with the
-- link can see them), in work-photos/<worker-id>/.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('work-photos', 'work-photos', true, 2097152, array['image/jpeg', 'image/png', 'image/webp']),
  ('job-photos', 'job-photos', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create table if not exists public.work_photos (
  id          uuid primary key default gen_random_uuid(),
  worker_id   uuid not null default auth.uid() references public.worker_profiles (id) on delete cascade,
  path        text not null,
  created_at  timestamptz not null default now(),
  check (split_part(path, '/', 1) = worker_id::text)
);
create index if not exists work_photos_worker_idx on public.work_photos (worker_id, created_at desc);

alter table public.work_photos enable row level security;
revoke all on public.work_photos from anon, authenticated;
grant select, delete on public.work_photos to authenticated;
grant insert (worker_id, path) on public.work_photos to authenticated;

drop policy if exists "work_photos: everyone reads" on public.work_photos;
create policy "work_photos: everyone reads"
  on public.work_photos for select to authenticated
  using (true);

drop policy if exists "work_photos: workers add their own" on public.work_photos;
create policy "work_photos: workers add their own"
  on public.work_photos for insert to authenticated
  with check (
    worker_id = (select auth.uid())
    and (select public.is_worker())
    and (select public.is_active_profile((select auth.uid())))
    and (select count(*) from public.work_photos p where p.worker_id = (select auth.uid())) < 12
  );

drop policy if exists "work_photos: workers remove their own" on public.work_photos;
create policy "work_photos: workers remove their own"
  on public.work_photos for delete to authenticated
  using (worker_id = (select auth.uid()));


-- ---------------------------------------------------------------------
-- 10. Saved workers
-- ---------------------------------------------------------------------
-- The heart on a worker's page: customers keep workers to call again.
-- Private to each customer.
create table if not exists public.saved_workers (
  customer_id  uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  worker_id    uuid not null references public.worker_profiles (id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (customer_id, worker_id)
);

alter table public.saved_workers enable row level security;
revoke all on public.saved_workers from anon, authenticated;
grant select, delete on public.saved_workers to authenticated;
grant insert (customer_id, worker_id) on public.saved_workers to authenticated;

drop policy if exists "saved_workers: read own" on public.saved_workers;
create policy "saved_workers: read own"
  on public.saved_workers for select to authenticated
  using (customer_id = (select auth.uid()));

drop policy if exists "saved_workers: add own" on public.saved_workers;
create policy "saved_workers: add own"
  on public.saved_workers for insert to authenticated
  with check (customer_id = (select auth.uid()) and (select public.is_active_profile((select auth.uid()))));

drop policy if exists "saved_workers: remove own" on public.saved_workers;
create policy "saved_workers: remove own"
  on public.saved_workers for delete to authenticated
  using (customer_id = (select auth.uid()));


-- ---------------------------------------------------------------------
-- 11. Job requests
-- ---------------------------------------------------------------------
-- A customer describes a job to a worker who is taking work: what, where,
-- when, a phone number to reach them and an optional photo. The worker
-- accepts or declines (with an optional note); either can mark an accepted
-- job done; the customer can cancel until then. Each step notifies the
-- other person. One open (pending or accepted) request per customer and
-- worker. Names are copied in when it's sent, so each side sees the other's
-- name without reading their profile. Sending one counts as getting in touch
-- (section 7).
create table if not exists public.job_requests (
  id             uuid primary key default gen_random_uuid(),
  customer_id    uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  worker_id      uuid not null references public.worker_profiles (id) on delete cascade,
  category_id    uuid references public.service_categories (id) on delete set null,
  description    text not null check (char_length(trim(description)) between 1 and 1000),
  when_needed    text check (char_length(when_needed) <= 100),
  address        text not null check (char_length(trim(address)) between 1 and 200),
  contact_phone  text not null check (contact_phone ~ '^\+[0-9]{8,15}$'),
  photo_path     text,
  status         text not null default 'pending'
                 check (status in ('pending', 'accepted', 'declined', 'cancelled', 'completed')),
  worker_note    text check (char_length(worker_note) <= 500),
  customer_name  text not null default '',
  worker_name    text not null default '',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  check (customer_id <> worker_id),
  check (split_part(photo_path, '/', 1) = customer_id::text)
);
create index if not exists job_requests_worker_idx on public.job_requests (worker_id, created_at desc);
create index if not exists job_requests_customer_idx on public.job_requests (customer_id, created_at desc);
create unique index if not exists job_requests_one_open_idx
  on public.job_requests (customer_id, worker_id) where status in ('pending', 'accepted');

drop trigger if exists job_requests_updated_at on public.job_requests;
create trigger job_requests_updated_at before update on public.job_requests
  for each row execute function public.set_updated_at();

-- Copies in both names, and makes sure a new request starts as pending.
create or replace function public.prepare_job_request()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.customer_name := coalesce((select full_name from public.profiles where id = new.customer_id), '');
  new.worker_name := coalesce((select full_name from public.profiles where id = new.worker_id), '');
  new.status := 'pending';
  new.worker_note := null;
  return new;
end;
$$;

drop trigger if exists job_requests_prepare on public.job_requests;
create trigger job_requests_prepare before insert on public.job_requests
  for each row execute function public.prepare_job_request();

alter table public.job_requests enable row level security;
revoke all on public.job_requests from anon, authenticated;
grant select on public.job_requests to authenticated;
grant insert (customer_id, worker_id, category_id, description, when_needed, address, contact_phone, photo_path)
  on public.job_requests to authenticated;

drop policy if exists "job_requests: the customer, the worker and admins read" on public.job_requests;
create policy "job_requests: the customer, the worker and admins read"
  on public.job_requests for select to authenticated
  using (
    customer_id = (select auth.uid())
    or worker_id = (select auth.uid())
    or (select public.is_admin())
  );

-- Only to workers customers can see who are taking work (B5 'Available').
drop policy if exists "job_requests: customers send their own" on public.job_requests;
create policy "job_requests: customers send their own"
  on public.job_requests for insert to authenticated
  with check (
    customer_id = (select auth.uid())
    and (select public.is_active_profile((select auth.uid())))
    and exists (select 1 from public.worker_directory d where d.id = worker_id and d.is_available)
  );

-- The only way to change a request's status:
--   the worker:   pending -> accepted or declined ([note] is shown to the customer)
--   the customer: pending or accepted -> cancelled
--   either:       accepted -> completed
create or replace function public.set_job_status(request_id uuid, new_status text, note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  j public.job_requests;
begin
  select * into j from public.job_requests where id = request_id for update;
  if not found or me is null or me not in (j.customer_id, j.worker_id) then
    raise exception 'No job request with this ID' using errcode = 'P0002';
  end if;
  if not public.is_active_profile(me) then
    raise exception 'This account is deactivated' using errcode = '42501';
  end if;
  if not (
    (me = j.worker_id and j.status = 'pending' and new_status in ('accepted', 'declined'))
    or (me = j.customer_id and j.status in ('pending', 'accepted') and new_status = 'cancelled')
    or (j.status = 'accepted' and new_status = 'completed')
  ) then
    raise exception 'A % job request cannot become %', j.status, new_status using errcode = '22023';
  end if;

  update public.job_requests
  set status = new_status,
      worker_note = case
        when new_status in ('accepted', 'declined') then left(nullif(trim(note), ''), 500)
        else worker_note
      end
  where id = request_id;
end;
$$;

revoke execute on function public.set_job_status(uuid, text, text) from public, anon;
grant execute on function public.set_job_status(uuid, text, text) to authenticated;

-- A new request: the worker is told, and the customer has now been in touch.
create or replace function public.handle_job_request_sent()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.worker_contacts (worker_id, customer_id)
  values (new.worker_id, new.customer_id)
  on conflict on constraint worker_contacts_pkey do update set last_at = now();

  perform public.add_notification(new.worker_id, 'job_new',
    jsonb_build_object(
      'job_id', new.id,
      'customer_name', new.customer_name,
      'category', (select name from public.service_categories where id = new.category_id)),
    new.customer_id);
  return new;
end;
$$;

drop trigger if exists job_requests_notify_new on public.job_requests;
create trigger job_requests_notify_new
  after insert on public.job_requests
  for each row execute function public.handle_job_request_sent();

-- Accepted or declined: the customer. Cancelled: the worker. Done: whoever
-- didn't mark it.
create or replace function public.handle_job_status_changed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  details jsonb := jsonb_build_object(
    'job_id', new.id,
    'worker_id', new.worker_id,
    'worker_name', new.worker_name,
    'customer_name', new.customer_name,
    'note', new.worker_note,
    'by', case when (select auth.uid()) = new.worker_id then 'worker' else 'customer' end);
begin
  if new.status in ('accepted', 'declined') then
    perform public.add_notification(new.customer_id, 'job_' || new.status, details, new.worker_id);
  elsif new.status = 'cancelled' then
    perform public.add_notification(new.worker_id, 'job_cancelled', details, new.customer_id);
  elsif new.status = 'completed' then
    if (select auth.uid()) = new.worker_id then
      perform public.add_notification(new.customer_id, 'job_completed', details, new.worker_id);
    else
      perform public.add_notification(new.worker_id, 'job_completed', details, new.customer_id);
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists job_requests_notify_status on public.job_requests;
create trigger job_requests_notify_status
  after update of status on public.job_requests
  for each row when (old.status is distinct from new.status)
  execute function public.handle_job_status_changed();

-- Storage for sections 9 and 11. Uploads only into your own <user-id>/
-- folder, as for the other buckets (schema.sql, section 6). work-photos is
-- public; a job photo can be read by the customer who sent it, the worker it
-- was sent to, and admins.
drop policy if exists "storage: photos upload into own folder" on storage.objects;
create policy "storage: photos upload into own folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id in ('work-photos', 'job-photos')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage: photos delete own" on storage.objects;
create policy "storage: photos delete own"
  on storage.objects for delete to authenticated
  using (
    bucket_id in ('work-photos', 'job-photos')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage: photos read own, job photos by the job's worker" on storage.objects;
create policy "storage: photos read own, job photos by the job's worker"
  on storage.objects for select to authenticated
  using (
    bucket_id in ('work-photos', 'job-photos')
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or (bucket_id = 'job-photos' and (select public.is_admin()))
      or (bucket_id = 'job-photos' and exists (
        select 1 from public.job_requests j
        where j.photo_path = objects.name and j.worker_id = (select auth.uid())
      ))
    )
  );


-- ---------------------------------------------------------------------
-- 12. Push notifications
-- ---------------------------------------------------------------------
-- Every notification (section 5) is also sent to the user's phones through
-- Firebase Cloud Messaging, so they see it with the app closed. Nothing is
-- sent until push is set up (README, 'Push notifications'): Firebase, the
-- send-push Edge Function, and two Vault secrets. Until then, and if sending
-- ever fails, notifications still reach the bell as before.
--
-- push_tokens: which phones get which user's notifications. A phone's token
-- moves to whoever logs in on it last; logging out removes it.
create table if not exists public.push_tokens (
  token       text primary key,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  platform    text not null check (platform in ('android', 'ios')),
  updated_at  timestamptz not null default now()
);
create index if not exists push_tokens_user_idx on public.push_tokens (user_id);

-- Only through the two functions below; nobody reads other people's tokens.
alter table public.push_tokens enable row level security;
revoke all on public.push_tokens from anon, authenticated;

create or replace function public.register_push_token(push_token text, device_platform text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Log in first' using errcode = '42501';
  end if;
  if device_platform not in ('android', 'ios') then
    raise exception 'Unknown platform: %', device_platform using errcode = '22023';
  end if;
  if char_length(push_token) not between 1 and 4096 then
    raise exception 'Not a push token' using errcode = '22023';
  end if;

  insert into public.push_tokens as t (token, user_id, platform)
  values (push_token, (select auth.uid()), device_platform)
  on conflict (token) do update
    set user_id = excluded.user_id, platform = excluded.platform, updated_at = now();
end;
$$;

create or replace function public.unregister_push_token(push_token text)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.push_tokens where token = push_token and user_id = (select auth.uid());
$$;

revoke execute on function public.register_push_token(text, text), public.unregister_push_token(text)
  from public, anon;
grant execute on function public.register_push_token(text, text), public.unregister_push_token(text)
  to authenticated;

-- pg_net lets the database call the Edge Function. Supabase has it; if a
-- database doesn't, push just stays off.
do $$
begin
  create extension if not exists pg_net with schema extensions;
exception when others then
  raise notice 'pg_net is not available, so push notifications are off: %', sqlerrm;
end;
$$;

-- A new notification for someone with a registered phone: ask the send-push
-- Edge Function to deliver it. The function's address and a shared secret
-- come from Supabase Vault (README); without them nothing is sent. The call
-- happens after the notification is saved, and any problem here is only
-- logged, so push can never stop a notification.
create or replace function public.send_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  project_url text;
  push_secret text;
begin
  if not exists (select 1 from public.push_tokens where user_id = new.user_id) then
    return new;
  end if;
  select decrypted_secret into project_url from vault.decrypted_secrets where name = 'kuzu_project_url';
  select decrypted_secret into push_secret from vault.decrypted_secrets where name = 'kuzu_push_secret';
  if project_url is null or push_secret is null then
    return new;
  end if;

  perform net.http_post(
    url := rtrim(project_url, '/') || '/functions/v1/send-push',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', push_secret),
    body := jsonb_build_object('notification_id', new.id)
  );
  return new;
exception when others then
  raise warning 'Push notification not sent: %', sqlerrm;
  return new;
end;
$$;

revoke execute on function public.send_push() from public, anon, authenticated;

drop trigger if exists notifications_send_push on public.notifications;
create trigger notifications_send_push
  after insert on public.notifications
  for each row execute function public.send_push();


-- ---------------------------------------------------------------------
-- 13. Sports grounds: futsal and football booking
-- ---------------------------------------------------------------------
-- An admin registers each venue (a futsal arena, a football ground)
-- together with the one person who runs it, its ground manager
-- (profiles.role 'ground_manager'): add_venue (13d) saves both at once. The
-- manager runs everything about their venue: its grounds (courts, pitches)
-- with their prices and opening hours, its details, and its bookings. Admins
-- can do all of that for every venue, and change or remove its manager. In the app a venue
-- is a 'ground' with one playing area (its grounds row); its timings are time slots,
-- several a day if the manager likes (ground_time_slots), and customers book a whole
-- slot up to a week ahead, at venues with an active manager; the manager also books
-- slots for people who call (book_by_phone). The manager
-- confirms or rejects each request (or the venue confirms them straight
-- away), blocks time for maintenance or tournaments, and marks bookings
-- done, no-show or paid. Two bookings of one ground can never overlap: the
-- database refuses the second, even when two people book the same hour at
-- the same moment. Times are Bhutan time (Asia/Thimphu, UTC+6 all year).
-- venue_type also allows 'restaurant' and 'bar', for party bookings later.
-- Each step notifies the other person.
--
-- A manager's account is made first by the create-venue-manager Edge
-- Function (README), which needs the service_role key; add_venue or
-- set_venue_manager (13d) then gives them the venue.

-- An early draft of this section ('Migration 02') made public.venues with
-- other columns. Stop with a clear message instead of failing further down.
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'venues' and column_name = 'cover_image_url') then
    raise exception 'public.venues was made by an older script. Drop the venues, grounds, ground_opening_hours, '
      'ground_bookings, venue_verifications and venue_reviews tables (they hold no real data yet), then run this again.';
  end if;
end;
$$;

-- Ground managers are a fourth kind of user; only set_venue_manager makes one.
-- They were called venue managers ('venue_manager') at first: renamed here.
-- Players, a fifth, book sports grounds: kept apart from customers, who use
-- the home services. They sign up from a ground (the app sends role
-- 'player', handle_new_user below).
alter table public.profiles drop constraint if exists profiles_role_check;
update public.profiles set role = 'ground_manager' where role = 'venue_manager';
alter table public.profiles add constraint profiles_role_check
  check (role in ('customer', 'worker', 'admin', 'ground_manager', 'player'));

-- schema.sql's, now letting people sign up as players too. Never as an
-- admin or ground manager: those are only given by admins.
create or replace function public.handle_new_user()
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
    case when new.raw_user_meta_data ->> 'role' in ('worker', 'player') then new.raw_user_meta_data ->> 'role'
         else 'customer' end,
    new.email,
    case when coalesce(new.phone, '') <> '' then '+' || new.phone end
  );
  return new;
end;
$$;

-- The caller's profiles row, made now if their account has none (one made
-- before schema.sql's trigger, or whose row went missing), just as
-- handle_new_user makes it. The app calls it when it finds no row after
-- logging in (A1). Does nothing when the row is there.
create or replace function public.ensure_my_profile()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, role, email, phone)
  select u.id,
         coalesce(trim(u.raw_user_meta_data ->> 'full_name'), ''),
         case when u.raw_user_meta_data ->> 'role' in ('worker', 'player') then u.raw_user_meta_data ->> 'role'
              else 'customer' end,
         u.email,
         case when coalesce(u.phone, '') <> '' then '+' || u.phone end
  from auth.users u
  where u.id = (select auth.uid())
  on conflict (id) do nothing;
end;
$$;

revoke execute on function public.ensure_my_profile() from public, anon;
grant execute on function public.ensure_my_profile() to authenticated;

-- The first version of this section let anyone list a venue, as its owner,
-- for an admin to approve from its trade licence. Venues now have a manager
-- chosen by an admin instead, and no approval or licence: bring a database
-- that ran the first version up to date. (Its venue-docs bucket, for
-- licences, isn't used any more; delete it in Storage if you like.)
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'venues' and column_name = 'owner_id') then
    drop view if exists public.venue_directory;
    drop view if exists public.ground_booking_list;
    drop trigger if exists venues_notify_new on public.venues;
    drop trigger if exists venues_verification_notify on public.venues;
    drop function if exists public.handle_venue_added();
    drop function if exists public.handle_venue_verification_changed();
    drop function if exists public.set_venue_verification(uuid, text, text);
    drop function if exists public.request_venue_review(uuid);
    drop policy if exists "venues: owners and admins read" on public.venues;
    drop policy if exists "venues: add your own" on public.venues;
    drop policy if exists "venues: edit your own" on public.venues;
    drop policy if exists "grounds: listed ones, owners and admins read" on public.grounds;
    drop policy if exists "grounds: owners add" on public.grounds;
    drop policy if exists "grounds: owners edit" on public.grounds;
    drop policy if exists "ground_opening_hours: owners add" on public.ground_opening_hours;
    drop policy if exists "ground_opening_hours: owners edit" on public.ground_opening_hours;
    drop policy if exists "ground_opening_hours: owners remove" on public.ground_opening_hours;
    drop policy if exists "ground_bookings: the customer, the owner and admins read" on public.ground_bookings;
    drop function if exists public.owns_venue(uuid);
    drop function if exists public.owns_ground(uuid);
    alter table public.venues drop constraint if exists venues_check;
    alter table public.venues drop constraint if exists venues_owner_id_fkey;
    alter table public.venues rename column owner_id to manager_id;
    alter table public.venues alter column manager_id drop not null;
    alter table public.venues alter column manager_id drop default;
    alter table public.venues add constraint venues_manager_id_fkey
      foreign key (manager_id) references public.profiles (id) on delete set null;
    alter table public.venues
      drop column if exists trade_license_path,
      drop column if exists verification_status,
      drop column if exists admin_notes;
    drop index if exists public.venues_owner_idx;
    -- Customers who listed a venue now manage it.
    update public.profiles p set role = 'ground_manager'
    where p.role = 'customer' and exists (select 1 from public.venues v where v.manager_id = p.id);
  end if;
end;
$$;

-- Lets the database compare a ground's ID and time together (no overlaps).
create extension if not exists btree_gist with schema extensions;

create table if not exists public.venues (
  id                   uuid primary key default gen_random_uuid(),
  -- The one account that runs the venue (set_venue_manager, 13d). Null: none
  -- yet, so customers can't book it. Deleting that account leaves the venue.
  manager_id           uuid references public.profiles (id) on delete set null,
  venue_type           text not null default 'sports_ground'
                       check (venue_type in ('sports_ground', 'restaurant', 'bar')),
  name                 text not null check (char_length(trim(name)) between 2 and 80),
  description          text check (char_length(description) <= 1000),
  dzongkhag            text not null check (char_length(dzongkhag) <= 40),
  town                 text check (char_length(town) <= 80),
  address              text check (char_length(address) <= 200),
  phone                text not null check (phone ~ '^\+[0-9]{8,15}$'),
  whatsapp_number      text check (whatsapp_number ~ '^\+[0-9]{8,15}$'),
  cover_url            text,                           -- public venue-photos bucket
  auto_confirm         boolean not null default false, -- true: bookings are confirmed at once
  free_cancel_hours    int not null default 24 check (free_cancel_hours between 0 and 168),
  cancellation_policy  text check (char_length(cancellation_policy) <= 500),
  payment_info         text check (char_length(payment_info) <= 300), -- e.g. the mBoB account for advances
  is_active            boolean not null default true,  -- false: bookings are paused
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);
-- Where the venue is on the map, set by its manager or an admin (from their
-- phone's location, or a Google Maps link): the app shows customers how far
-- away it is and opens Google Maps for directions. Null until it's set.
-- Added after the table, so they're added here where it's older.
alter table public.venues
  add column if not exists latitude double precision check (latitude between -90 and 90),
  add column if not exists longitude double precision check (longitude between -180 and 180);
alter table public.venues drop constraint if exists venues_location_check;
alter table public.venues add constraint venues_location_check
  check ((latitude is null) = (longitude is null));

create index if not exists venues_manager_idx on public.venues (manager_id);
create index if not exists venues_dzongkhag_idx on public.venues (dzongkhag);

drop trigger if exists venues_updated_at on public.venues;
create trigger venues_updated_at before update on public.venues
  for each row execute function public.set_updated_at();

-- A pitch or court inside a venue: 'Court A', 'Main ground'. Prices are in
-- whole Ngultrum; from evening_from_hour the evening price is used, if set.
create table if not exists public.grounds (
  id                 uuid primary key default gen_random_uuid(),
  venue_id           uuid not null references public.venues (id) on delete cascade,
  name               text not null check (char_length(trim(name)) between 1 and 60),
  sport              text not null default 'futsal'
                     check (sport in ('futsal', 'football', 'basketball', 'badminton', 'other')),
  format             text check (char_length(format) <= 40),  -- e.g. 5-a-side
  surface            text check (char_length(surface) <= 40), -- e.g. Artificial turf
  is_indoor          boolean not null default false,
  has_floodlights    boolean not null default true,
  price_per_hour_nu  int not null check (price_per_hour_nu between 1 and 100000),
  evening_price_nu   int check (evening_price_nu between 1 and 100000),
  evening_from_hour  smallint not null default 17 check (evening_from_hour between 0 and 23),
  is_active          boolean not null default true,           -- false: not taking bookings
  created_at         timestamptz not null default now()
);
create index if not exists grounds_venue_idx on public.grounds (venue_id);

-- No longer used: ground_time_slots (below) replaced it, and its rows move
-- there. It was one row for each day a ground is open (0 = Sunday ... 6 =
-- Saturday); close_hour 24 is midnight.
create table if not exists public.ground_opening_hours (
  ground_id   uuid not null references public.grounds (id) on delete cascade,
  weekday     smallint not null check (weekday between 0 and 6),
  open_hour   smallint not null check (open_hour between 0 and 23),
  close_hour  smallint not null check (close_hour between 1 and 24),
  primary key (ground_id, weekday),
  check (close_hour > open_hour)
);

-- The times a ground can be booked, for each day of the week (0 = Sunday ...
-- 6 = Saturday): as many a day as the manager sets, e.g. Sunday 6-9 pm,
-- 8-10 pm and 10 pm-midnight. Customers book a whole slot; slots may overlap,
-- and ground_bookings_no_overlap stops two bookings of the same time. No slot
-- on a day: closed that day. end_hour 24 is midnight. Only
-- set_ground_time_slots (13d) changes them. (They replace
-- ground_opening_hours, one window a day, which is no longer used.)
create table if not exists public.ground_time_slots (
  id          uuid primary key default gen_random_uuid(),
  ground_id   uuid not null references public.grounds (id) on delete cascade,
  weekday     smallint not null check (weekday between 0 and 6),
  start_hour  smallint not null check (start_hour between 0 and 23),
  end_hour    smallint not null check (end_hour between 1 and 24),
  check (end_hour > start_hour),
  unique (ground_id, weekday, start_hour, end_hour)
);

-- Grounds set up before time slots: each day's opening hours become one slot
-- (moved, so running this again changes nothing).
with moved as (delete from public.ground_opening_hours returning *)
insert into public.ground_time_slots (ground_id, weekday, start_hour, end_hour)
select ground_id, weekday, open_hour, close_hour from moved
on conflict (ground_id, weekday, start_hour, end_hour) do nothing;

-- Customers' bookings, bookings the manager took by phone (kind 'phone'),
-- and time the manager blocked (kind 'owner_block'). Only the functions
-- below add or change them. Pending and confirmed ones
-- hold their time: ground_bookings_no_overlap refuses any other that
-- overlaps it (Postgres error 23P01). contact_name is copied in, so the
-- manager sees who booked without reading their profile.
create table if not exists public.ground_bookings (
  id                 uuid primary key default gen_random_uuid(),
  ground_id          uuid not null references public.grounds (id) on delete cascade,
  booked_by          uuid not null references public.profiles (id) on delete cascade,
  kind               text not null default 'customer' check (kind in ('customer', 'owner_block', 'phone')),
  starts_at          timestamptz not null,
  ends_at            timestamptz not null,
  status             text not null default 'pending'
                     check (status in ('pending', 'confirmed', 'rejected', 'cancelled', 'completed', 'no_show')),
  price_nu           int not null default 0,
  team_name          text check (char_length(team_name) <= 60),
  players_count      int check (players_count between 1 and 30),
  contact_name       text not null default '',
  contact_phone      text check (contact_phone ~ '^\+[0-9]{8,15}$'),
  payment_method     text not null default 'pay_at_venue'
                     check (payment_method in ('pay_at_venue', 'mbob_transfer', 'mpay_transfer')),
  payment_reference  text check (char_length(payment_reference) <= 60), -- the mBoB / mPay journal number
  payment_status     text not null default 'unpaid'
                     check (payment_status in ('unpaid', 'deposit_claimed', 'paid')),
  customer_note      text check (char_length(customer_note) <= 500),
  owner_note         text check (char_length(owner_note) <= 500),     -- the venue's message, or why time is blocked
  cancelled_by       uuid references public.profiles (id) on delete set null, -- null: expired unanswered
  cancelled_at       timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  check (ends_at > starts_at),
  constraint ground_bookings_no_overlap exclude using gist (
    ground_id with =,
    tstzrange(starts_at, ends_at, '[)') with &&
  ) where (status in ('pending', 'confirmed'))
);
create index if not exists ground_bookings_booked_by_idx on public.ground_bookings (booked_by, starts_at desc);
create index if not exists ground_bookings_ground_idx on public.ground_bookings (ground_id, starts_at);

drop trigger if exists ground_bookings_updated_at on public.ground_bookings;
create trigger ground_bookings_updated_at before update on public.ground_bookings
  for each row execute function public.set_updated_at();

-- Regular bookings: the same time every week, for someone who always plays
-- then (e.g. a team, every Tuesday 6-8 pm), with no end: it holds until the
-- manager changes or removes it. Everyone sees that time as a regular
-- booking and nobody else can book it; only the ground's manager (and
-- admins) see who it is. Two can't overlap on the same day. Only
-- add_regular_booking(s), update_regular_booking, make_booking_regular and
-- remove_regular_booking (13d) change them.
create table if not exists public.ground_regular_bookings (
  id          uuid primary key default gen_random_uuid(),
  ground_id   uuid not null references public.grounds (id) on delete cascade,
  weekday     smallint not null check (weekday between 0 and 6),
  start_hour  smallint not null check (start_hour between 0 and 23),
  end_hour    smallint not null check (end_hour between 1 and 24),
  name        text not null check (char_length(trim(name)) between 1 and 100),
  phone       text check (phone ~ '^\+[0-9]{8,15}$'),
  team_name   text check (char_length(team_name) <= 60),
  created_by  uuid references public.profiles (id) on delete set null,
  created_at  timestamptz not null default now(),
  check (end_hour > start_hour),
  constraint ground_regular_bookings_no_overlap exclude using gist (
    ground_id with =,
    weekday with =,
    int4range(start_hour, end_hour) with &&
  )
);
create index if not exists ground_regular_bookings_ground_idx on public.ground_regular_bookings (ground_id);

-- Bookings taken by phone came after the table: allow them where it's older.
alter table public.ground_bookings drop constraint if exists ground_bookings_kind_check;
alter table public.ground_bookings add constraint ground_bookings_kind_check
  check (kind in ('customer', 'owner_block', 'phone'));

-- One review per customer per venue, once they have played there.
create table if not exists public.venue_reviews (
  id           uuid primary key default gen_random_uuid(),
  venue_id     uuid not null references public.venues (id) on delete cascade,
  customer_id  uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  rating       smallint not null check (rating between 1 and 5),
  comment      text check (char_length(comment) <= 1000),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (venue_id, customer_id)
);
create index if not exists venue_reviews_venue_idx on public.venue_reviews (venue_id, created_at desc);

drop trigger if exists venue_reviews_updated_at on public.venue_reviews;
create trigger venue_reviews_updated_at before update on public.venue_reviews
  for each row execute function public.set_updated_at();

-- One account, more than one service: profiles.role is the main role (the
-- home the app opens), and roles every role the account has. Someone who
-- signs up for another service with the same email gets that role too
-- (add_my_role, 13d): a customer who books grounds as well is a customer and
-- a player. Only customer and player are added this way. The trigger keeps
-- roles in step: it always holds role, plus customer and player once added,
-- whatever role becomes later. Users can't change either column themselves.
alter table public.profiles add column if not exists roles text[] not null default '{}';

create or replace function public.keep_profile_roles()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.roles := array(
    select distinct r from unnest(array[new.role] || coalesce(new.roles, '{}')) r
    where r = new.role or r in ('customer', 'player')
    order by r);
  return new;
end;
$$;

drop trigger if exists profiles_keep_roles on public.profiles;
create trigger profiles_keep_roles before insert or update of role, roles on public.profiles
  for each row execute function public.keep_profile_roles();

-- Accounts from before roles: their role. Those who have booked a ground are
-- players too, so they go on booking.
update public.profiles set roles = roles where not (role = any(roles));
update public.profiles p set roles = p.roles || array['player']
where not ('player' = any(p.roles))
  and exists (select 1 from public.ground_bookings b where b.booked_by = p.id and b.kind = 'customer');

-- 13a. Helpers for the rules below.
-- The caller's account has [check_role] (profiles.roles), or is an admin's.
create or replace function public.has_role(check_role text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and (check_role = any(roles) or role = 'admin')
  );
$$;

revoke execute on function public.has_role(text) from public, anon;
grant execute on function public.has_role(text) to authenticated;

create or replace function public.is_venue_manager()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'ground_manager'
  );
$$;

-- The venue's manager, or an admin.
create or replace function public.can_manage_venue(venue uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_admin()
      or exists (select 1 from public.venues where id = venue and manager_id = (select auth.uid()));
$$;

create or replace function public.can_manage_ground(ground uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_admin()
      or exists (
        select 1 from public.grounds g join public.venues v on v.id = g.venue_id
        where g.id = ground and v.manager_id = (select auth.uid())
      );
$$;

-- Customers can see and book it: it has a manager who isn't deactivated,
-- and bookings aren't paused.
create or replace function public.is_listed_venue(venue uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.venues v join public.profiles p on p.id = v.manager_id
    where v.id = venue and v.is_active and p.is_active
  );
$$;

-- The caller has played at the venue (a booking that has ended), so may review it.
create or replace function public.has_played_at(venue uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.ground_bookings b join public.grounds g on g.id = b.ground_id
    where g.venue_id = venue
      and b.booked_by = (select auth.uid())
      and b.kind = 'customer'
      and b.status in ('confirmed', 'completed')
      and b.ends_at <= now()
  );
$$;

revoke execute on function public.is_venue_manager(), public.can_manage_venue(uuid),
  public.can_manage_ground(uuid), public.is_listed_venue(uuid), public.has_played_at(uuid)
  from public, anon;
grant execute on function public.is_venue_manager(), public.can_manage_venue(uuid),
  public.can_manage_ground(uuid), public.is_listed_venue(uuid), public.has_played_at(uuid)
  to authenticated;
-- Visitors who haven't logged in (the anon role) browse venues too (13c):
-- the rules they read by call these two.
grant execute on function public.is_listed_venue(uuid), public.is_active_profile(uuid) to anon;

-- 13b. What customers see. Like worker_directory, these views run with the
-- owner's rights and choose their rows themselves. Supabase's Security
-- Advisor reports them as 'security definer views'; that is on purpose. Don't
-- turn security_invoker on for them: visitors and customers would then get
-- 'permission denied for table venues', or no venues at all. Running this
-- file again turns it back off.
-- venue_directory: listed venues with at least one ground taking bookings (with timings),
-- their lowest hourly price, sports, rating (from active customers) and place on
-- the map. (A replaced view can only gain columns at the end.)
create or replace view public.venue_directory with (security_invoker = false) as
select
  v.id,
  v.manager_id,
  v.venue_type,
  v.name,
  v.description,
  v.dzongkhag,
  v.town,
  v.address,
  v.phone,
  v.whatsapp_number,
  v.cover_url,
  v.auto_confirm,
  v.free_cancel_hours,
  v.cancellation_policy,
  v.payment_info,
  g.from_price_nu,
  g.ground_count,
  g.sports,
  coalesce(r.avg_rating, 0)::float8 as avg_rating,
  coalesce(r.review_count, 0)::int  as review_count,
  v.latitude,
  v.longitude
from public.venues v
join public.profiles m on m.id = v.manager_id
join lateral (
  select min(gr.price_per_hour_nu)                   as from_price_nu,
         count(*)::int                               as ground_count,
         array_agg(distinct gr.sport order by gr.sport) as sports
  from public.grounds gr
  where gr.venue_id = v.id and gr.is_active
    and exists (select 1 from public.ground_time_slots s where s.ground_id = gr.id)
) g on g.ground_count > 0
left join lateral (
  select avg(vr.rating) as avg_rating, count(*) as review_count
  from public.venue_reviews vr
  join public.profiles c on c.id = vr.customer_id
  where vr.venue_id = v.id and c.is_active
) r on true
where v.is_active and m.is_active;

-- ground_booking_list: 'My bookings' for customers and the bookings screen
-- for managers, with the ground and venue. Each user gets the bookings they
-- made and the ones at the venues they manage (admins: all).
create or replace view public.ground_booking_list with (security_invoker = false) as
select
  b.id,
  b.ground_id,
  b.booked_by,
  b.kind,
  b.starts_at,
  b.ends_at,
  b.status,
  b.price_nu,
  b.team_name,
  b.players_count,
  b.contact_name,
  b.contact_phone,
  b.payment_method,
  b.payment_reference,
  b.payment_status,
  b.customer_note,
  b.owner_note,
  b.cancelled_by,
  b.cancelled_at,
  b.created_at,
  g.name              as ground_name,
  g.sport,
  v.id                as venue_id,
  v.manager_id,
  v.name              as venue_name,
  v.town              as venue_town,
  v.dzongkhag         as venue_dzongkhag,
  v.phone             as venue_phone,
  v.whatsapp_number   as venue_whatsapp,
  v.free_cancel_hours,
  v.payment_info
from public.ground_bookings b
join public.grounds g on g.id = b.ground_id
join public.venues v on v.id = g.venue_id
where b.booked_by = (select auth.uid())
   or v.manager_id = (select auth.uid())
   or (select public.is_admin());

-- 13c. Who can do what.
alter table public.venues               enable row level security;
alter table public.grounds              enable row level security;
alter table public.ground_opening_hours enable row level security;
alter table public.ground_bookings      enable row level security;
alter table public.ground_time_slots    enable row level security;
alter table public.ground_regular_bookings enable row level security;
alter table public.venue_reviews        enable row level security;

revoke all on public.venues, public.grounds, public.ground_opening_hours, public.ground_bookings,
  public.venue_reviews, public.venue_directory, public.ground_booking_list, public.ground_time_slots,
  public.ground_regular_bookings
  from anon, authenticated;

grant select on public.venue_directory, public.ground_booking_list to authenticated;

-- Sports grounds are public: visitors who haven't logged in (anon) read
-- listed venues, their grounds, opening hours, reviews and taken times
-- (get_ground_availability, 13d), so they can choose before signing up.
-- Booking, My bookings and everything else still need an account.
grant select on public.venue_directory, public.grounds, public.ground_opening_hours,
  public.venue_reviews, public.ground_time_slots to anon;

-- venues: their manager and admins read and edit them. Customers read
-- venue_directory instead. Only add_venue (admins) adds one, always with its
-- manager, and only set_venue_manager (admins) changes the manager.
grant select on public.venues to authenticated;
grant update (name, description, dzongkhag, town, address, phone, whatsapp_number, cover_url,
  auto_confirm, free_cancel_hours, cancellation_policy, payment_info, is_active, latitude, longitude)
  on public.venues to authenticated;

drop policy if exists "venues: managers and admins read" on public.venues;
create policy "venues: managers and admins read"
  on public.venues for select to authenticated
  using (manager_id = (select auth.uid()) or (select public.is_admin()));

drop policy if exists "venues: admins add" on public.venues;

drop policy if exists "venues: managers and admins edit" on public.venues;
create policy "venues: managers and admins edit"
  on public.venues for update to authenticated
  using (manager_id = (select auth.uid()) or (select public.is_admin()))
  with check (
    (manager_id = (select auth.uid()) and (select public.is_active_profile((select auth.uid()))))
    or (select public.is_admin())
  );

-- grounds and their opening hours: everyone reads those of listed venues;
-- the manager and admins manage them. Grounds are paused (is_active), never
-- deleted, so past bookings keep them.
grant select on public.grounds to authenticated;
grant insert (venue_id, name, sport, format, surface, is_indoor, has_floodlights, price_per_hour_nu,
  evening_price_nu, evening_from_hour, is_active) on public.grounds to authenticated;
grant update (name, sport, format, surface, is_indoor, has_floodlights, price_per_hour_nu,
  evening_price_nu, evening_from_hour, is_active) on public.grounds to authenticated;

drop policy if exists "grounds: listed ones, managers and admins read" on public.grounds;
create policy "grounds: listed ones, managers and admins read"
  on public.grounds for select to authenticated
  using (public.is_listed_venue(venue_id) or public.can_manage_venue(venue_id));

drop policy if exists "grounds: visitors read listed ones" on public.grounds;
create policy "grounds: visitors read listed ones"
  on public.grounds for select to anon
  using (public.is_listed_venue(venue_id));

drop policy if exists "grounds: managers and admins add" on public.grounds;
create policy "grounds: managers and admins add"
  on public.grounds for insert to authenticated
  with check (public.can_manage_venue(venue_id) and (select public.is_active_profile((select auth.uid()))));

drop policy if exists "grounds: managers and admins edit" on public.grounds;
create policy "grounds: managers and admins edit"
  on public.grounds for update to authenticated
  using (public.can_manage_venue(venue_id))
  with check (public.can_manage_venue(venue_id) and (select public.is_active_profile((select auth.uid()))));

grant select, insert, update, delete on public.ground_opening_hours to authenticated;

drop policy if exists "ground_opening_hours: whoever sees the ground reads" on public.ground_opening_hours;
create policy "ground_opening_hours: whoever sees the ground reads"
  on public.ground_opening_hours for select to anon, authenticated
  using (exists (select 1 from public.grounds g where g.id = ground_id));

drop policy if exists "ground_opening_hours: managers and admins add" on public.ground_opening_hours;
create policy "ground_opening_hours: managers and admins add"
  on public.ground_opening_hours for insert to authenticated
  with check (public.can_manage_ground(ground_id) and (select public.is_active_profile((select auth.uid()))));

drop policy if exists "ground_opening_hours: managers and admins edit" on public.ground_opening_hours;
create policy "ground_opening_hours: managers and admins edit"
  on public.ground_opening_hours for update to authenticated
  using (public.can_manage_ground(ground_id))
  with check (public.can_manage_ground(ground_id) and (select public.is_active_profile((select auth.uid()))));

drop policy if exists "ground_opening_hours: managers and admins remove" on public.ground_opening_hours;
create policy "ground_opening_hours: managers and admins remove"
  on public.ground_opening_hours for delete to authenticated
  using (public.can_manage_ground(ground_id) and (select public.is_active_profile((select auth.uid()))));

-- ground_time_slots: whoever sees the ground reads them, logged in or not;
-- only set_ground_time_slots (13d) changes them.
grant select on public.ground_time_slots to authenticated;

drop policy if exists "ground_time_slots: whoever sees the ground reads" on public.ground_time_slots;
create policy "ground_time_slots: whoever sees the ground reads"
  on public.ground_time_slots for select to anon, authenticated
  using (exists (select 1 from public.grounds g where g.id = ground_id));

-- ground_regular_bookings: only the ground's manager and admins read them
-- (everyone else sees their times through get_ground_availability).
grant select on public.ground_regular_bookings to authenticated;

drop policy if exists "ground_regular_bookings: the manager and admins read" on public.ground_regular_bookings;
create policy "ground_regular_bookings: the manager and admins read"
  on public.ground_regular_bookings for select to authenticated
  using (public.can_manage_ground(ground_id));

-- ground_bookings: the customer, the venue's manager and admins read.
-- Changes only through the functions in 13d.
grant select on public.ground_bookings to authenticated;

drop policy if exists "ground_bookings: the customer, the manager and admins read" on public.ground_bookings;
create policy "ground_bookings: the customer, the manager and admins read"
  on public.ground_bookings for select to authenticated
  using (booked_by = (select auth.uid()) or public.can_manage_ground(ground_id));

-- venue_reviews: everyone reads those by active customers; customers write
-- and edit their own once they have played there.
grant select, insert on public.venue_reviews to authenticated;
grant update (venue_id, customer_id, rating, comment) on public.venue_reviews to authenticated;

drop policy if exists "venue_reviews: everyone reads" on public.venue_reviews;
create policy "venue_reviews: everyone reads"
  on public.venue_reviews for select to anon, authenticated
  using (public.is_active_profile(customer_id));

drop policy if exists "venue_reviews: write your own" on public.venue_reviews;
create policy "venue_reviews: write your own"
  on public.venue_reviews for insert to authenticated
  with check (
    customer_id = (select auth.uid())
    and (select public.is_active_profile((select auth.uid())))
    and public.has_played_at(venue_id)
  );

drop policy if exists "venue_reviews: edit your own" on public.venue_reviews;
create policy "venue_reviews: edit your own"
  on public.venue_reviews for update to authenticated
  using (customer_id = (select auth.uid()))
  with check (
    customer_id = (select auth.uid())
    and (select public.is_active_profile((select auth.uid())))
    and public.has_played_at(venue_id)
  );

-- 13d. Functions the app calls.

-- The caller uses another service with the same account: 'player' (sports
-- grounds) or 'customer' (home services) is added to their roles, keeping
-- the ones they have. Called when someone signs up for it with an email
-- that already has an account (once they've entered the code), or adds it
-- in the app. A player who adds home services opens Customer Home from then
-- on, which has sports grounds too.
create or replace function public.add_my_role(new_role text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
begin
  if new_role is null or new_role not in ('customer', 'player') then
    raise exception 'Only home services or sports grounds can be added' using errcode = '22023';
  end if;
  if me is null or not public.is_active_profile(me) then
    raise exception 'This account can''t add services' using errcode = '42501';
  end if;
  update public.profiles
  set roles = roles || array[new_role],
      role = case when new_role = 'customer' and role = 'player' then 'customer' else role end
  where id = me;
end;
$$;

revoke execute on function public.add_my_role(text) from public, anon;
grant execute on function public.add_my_role(text) to authenticated;

-- A3 'Continue with Google': a Google sign-in can't send the role picked on
-- Welcome as an email sign-up's metadata does, so handle_new_user makes
-- every new Google account a customer. Straight after, the app calls this
-- to make it a 'worker' or 'player' instead. Only for an account made in
-- the last 10 minutes that is still just a customer, so it can't be used
-- to change role later (Settings has 'Become a worker' for that).
create or replace function public.claim_signup_role(new_role text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
begin
  if new_role is null or new_role not in ('worker', 'player') then
    raise exception 'Only worker or player can be picked when signing up' using errcode = '22023';
  end if;
  update public.profiles p
  set role = new_role, roles = '{}' -- keep_profile_roles puts the new role in
  where p.id = me
    and p.role = 'customer' and p.roles <@ array['customer'] and p.is_active
    and exists (select 1 from auth.users u where u.id = me and u.created_at > now() - interval '10 minutes');
  if found then
    -- Their welcome and the admins' 'new user' notice (5a) were made with
    -- the account, as a customer's: they now say the role picked.
    update public.notifications n
    set data = n.data || jsonb_build_object('role', new_role)
    where (n.user_id = me and n.type = 'welcome') or (n.actor_id = me and n.type = 'new_user');
  end if;
end;
$$;

revoke execute on function public.claim_signup_role(text) from public, anon;
grant execute on function public.claim_signup_role(text) to authenticated;

-- Admins give a venue its manager: an account made by the
-- create-venue-manager Edge Function, or one that already exists. [manager]
-- null removes the manager, and customers can't book the venue until it
-- has another. The manager becomes a 'ground_manager'; a previous one who
-- runs no other venue becomes a customer again. Workers' and admins'
-- accounts can't be managers (they would stop being what they are), nor
-- deactivated ones. The new manager is told.
create or replace function public.set_venue_manager(venue uuid, manager uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  previous uuid;
  venue_name text;
  target public.profiles;
begin
  if not public.is_admin() then
    raise exception 'Only admins can choose a venue''s manager' using errcode = '42501';
  end if;
  select v.manager_id, v.name into previous, venue_name from public.venues v where v.id = venue for update;
  if not found then
    raise exception 'No venue with this ID' using errcode = 'P0002';
  end if;

  if manager is not null then
    select * into target from public.profiles where id = manager;
    if not found then
      raise exception 'No user with this ID' using errcode = 'P0002';
    end if;
    if target.role in ('admin', 'worker') or not target.is_active then
      raise exception 'This account can''t manage a venue: it is an admin''s or a worker''s, or deactivated'
        using errcode = '22023';
    end if;
    update public.profiles set role = 'ground_manager' where id = manager;
  end if;

  update public.venues set manager_id = manager where id = venue;

  if previous is not null and previous is distinct from manager
     and not exists (select 1 from public.venues where manager_id = previous) then
    update public.profiles set role = 'customer' where id = previous and role = 'ground_manager';
  end if;
  if manager is not null and manager is distinct from previous then
    perform public.add_notification(manager, 'venue_assigned',
      jsonb_build_object('venue_id', venue, 'venue_name', venue_name), (select auth.uid()));
  end if;
end;
$$;

-- Admins register a venue together with its manager, in one go: if the
-- manager can't run it (set_venue_manager), no venue is made. [details]
-- holds the venues columns an admin fills in (name, dzongkhag, phone and
-- so on), and under 'ground' its type and price (grounds columns: sport,
-- price_per_hour_nu and so on); its manager adds the timings. [manager] is
-- the account from create-venue-manager. Returns the new venue's ID.
create or replace function public.add_venue(details jsonb, manager uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  venue uuid;
begin
  if not public.is_admin() then
    raise exception 'Only admins can register venues' using errcode = '42501';
  end if;
  if manager is null then
    raise exception 'A venue is registered with its manager' using errcode = '22023';
  end if;

  insert into public.venues (
    venue_type, name, description, dzongkhag, town, address, phone, whatsapp_number, cover_url,
    auto_confirm, free_cancel_hours, cancellation_policy, payment_info, latitude, longitude
  )
  select coalesce(d.venue_type, 'sports_ground'), d.name, d.description, d.dzongkhag, d.town, d.address,
         d.phone, d.whatsapp_number, d.cover_url, coalesce(d.auto_confirm, false),
         coalesce(d.free_cancel_hours, 24), d.cancellation_policy, d.payment_info, d.latitude, d.longitude
  from jsonb_populate_record(null::public.venues, details) d
  returning id into venue;

  insert into public.grounds (
    venue_id, name, sport, format, surface, is_indoor, has_floodlights,
    price_per_hour_nu, evening_price_nu, evening_from_hour
  )
  select venue, left(trim(details ->> 'name'), 60), coalesce(g.sport, 'futsal'), g.format, g.surface,
         coalesce(g.is_indoor, false), coalesce(g.has_floodlights, true),
         g.price_per_hour_nu, g.evening_price_nu, coalesce(g.evening_from_hour, 17)
  from jsonb_populate_record(null::public.grounds, details -> 'ground') g
  where jsonb_typeof(details -> 'ground') = 'object';

  perform public.set_venue_manager(venue, manager);
  return venue;
end;
$$;

-- Pending requests the manager hasn't answered in 12 hours, or whose time
-- has come, stop holding their time (the customer is told, 13e). Run before
-- each booking, and every 15 minutes if pg_cron is set up (end of 13).
create or replace function public.expire_stale_ground_bookings(only_ground uuid default null)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  expired int;
begin
  update public.ground_bookings
  set status = 'cancelled', cancelled_by = null, cancelled_at = now()
  where status = 'pending'
    and (only_ground is null or ground_id = only_ground)
    and (created_at < now() - interval '12 hours' or starts_at <= now());
  get diagnostics expired = row_count;
  return expired;
end;
$$;

revoke execute on function public.expire_stale_ground_bookings(uuid) from public, anon, authenticated;

-- The price of one of [ground]'s time slots: the one that starts at
-- [start_time] (on the hour, from now to a week ahead) and lasts [hours]
-- hours. Each hour costs the day price, or the night price from the hour
-- it starts. Postgres error 22023 when there's no such slot, or it's too
-- soon or too far ahead; 23P01 when a regular booking has that time every
-- week. For book_ground and book_by_phone, so both keep the same rules.
create or replace function public.ground_slot_price(ground uuid, start_time timestamptz, hours int)
returns int
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  g record;
  local_start timestamp := start_time at time zone 'Asia/Thimphu';
  first_hour int := extract(hour from local_start)::int;
  total int := 0;
begin
  if hours is null or hours not between 1 and 24 then
    raise exception 'Bookings are 1 to 24 hours long' using errcode = '22023';
  end if;
  if date_trunc('hour', local_start) <> local_start then
    raise exception 'Bookings start on the hour' using errcode = '22023';
  end if;
  if start_time <= now() or start_time > now() + interval '7 days' then
    raise exception 'Bookings are for a time in the next 7 days' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.ground_time_slots s
    where s.ground_id = ground
      and s.weekday = extract(dow from local_start)::int
      and s.start_hour = first_hour
      and s.end_hour = first_hour + hours
  ) then
    raise exception 'This is not one of the ground''s time slots' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.ground_regular_bookings r
    where r.ground_id = ground
      and r.weekday = extract(dow from local_start)::int
      and int4range(r.start_hour, r.end_hour) && int4range(first_hour, first_hour + hours)
  ) then
    raise exception 'This time is a regular booking, every week' using errcode = '23P01';
  end if;

  select gr.price_per_hour_nu, gr.evening_price_nu, gr.evening_from_hour into g
  from public.grounds gr where gr.id = ground;
  for i in 0 .. hours - 1 loop
    total := total + case
      when g.evening_price_nu is not null and first_hour + i >= g.evening_from_hour then g.evening_price_nu
      else g.price_per_hour_nu
    end;
  end loop;
  return total;
end;
$$;

revoke execute on function public.ground_slot_price(uuid, timestamptz, int) from public, anon, authenticated;

-- A customer books one of a listed ground's time slots: the one that starts
-- at [start_time] and lasts [hours] hours, up to a week ahead. The price
-- (ground_slot_price) comes from the ground, not the app. Confirmed at once
-- if the venue confirms automatically; otherwise pending, and a customer can
-- have 3 pending at most. [payment] is a payment_method value; [payment_ref]
-- the mBoB / mPay journal number, if they've paid an advance. Returns the
-- booking's ID. Postgres error 23P01: someone else has that time.
create or replace function public.book_ground(
  ground uuid,
  start_time timestamptz,
  hours int,
  phone text,
  team text default null,
  players int default null,
  payment text default 'pay_at_venue',
  payment_ref text default null,
  note text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  g record;
  total int;
  ref text := nullif(trim(payment_ref), '');
  booking uuid;
begin
  if me is null or not public.is_active_profile(me) then
    raise exception 'This account can''t make bookings' using errcode = '42501';
  end if;
  if not public.has_role('player') then
    raise exception 'Add sports grounds to this account first (add_my_role)' using errcode = '42501';
  end if;

  select gr.price_per_hour_nu, gr.evening_price_nu, gr.evening_from_hour, gr.is_active,
         v.id as venue_id, v.manager_id, v.auto_confirm
  into g
  from public.grounds gr join public.venues v on v.id = gr.venue_id
  where gr.id = ground;
  if not found or not g.is_active or not public.is_listed_venue(g.venue_id) then
    raise exception 'This ground is not taking bookings' using errcode = '42501';
  end if;
  if g.manager_id = me then
    raise exception 'You manage this ground: block the time instead' using errcode = '42501';
  end if;

  total := public.ground_slot_price(ground, start_time, hours);

  perform public.expire_stale_ground_bookings(ground);
  if not g.auto_confirm and (
    select count(*) from public.ground_bookings b
    where b.booked_by = me and b.status = 'pending' and b.starts_at > now()
  ) >= 3 then
    raise exception 'You have 3 bookings waiting for an answer' using errcode = '54000';
  end if;

  insert into public.ground_bookings (
    ground_id, booked_by, kind, starts_at, ends_at, status, price_nu, team_name, players_count,
    contact_name, contact_phone, payment_method, payment_reference, payment_status, customer_note
  )
  values (
    ground, me, 'customer', start_time, start_time + make_interval(hours => hours),
    case when g.auto_confirm then 'confirmed' else 'pending' end,
    total,
    nullif(trim(team), ''),
    players,
    coalesce((select full_name from public.profiles where id = me), ''),
    phone,
    payment,
    ref,
    case when ref is not null and payment <> 'pay_at_venue' then 'deposit_claimed' else 'unpaid' end,
    nullif(trim(note), '')
  )
  returning id into booking;
  return booking;
exception when exclusion_violation then
  raise exception 'Someone else has just booked this time' using errcode = '23P01';
end;
$$;

-- The manager (or an admin) books one of the ground's time slots for
-- someone who called: [name] and [phone] are theirs. Confirmed at once, so
-- everyone sees the time as booked; nobody is notified. Same slots, prices
-- and week ahead as book_ground. Returns the booking's ID. Postgres error
-- 23P01: that time is taken.
create or replace function public.book_by_phone(
  ground uuid,
  start_time timestamptz,
  hours int,
  name text,
  phone text default null,
  team text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  total int;
  booking uuid;
begin
  if not public.can_manage_ground(ground) or not public.is_active_profile(me) then
    raise exception 'Only the ground''s manager can add bookings' using errcode = '42501';
  end if;
  if nullif(trim(name), '') is null then
    raise exception 'The name of the person who called is needed' using errcode = '22023';
  end if;
  total := public.ground_slot_price(ground, start_time, hours);

  perform public.expire_stale_ground_bookings(ground);
  insert into public.ground_bookings (
    ground_id, booked_by, kind, starts_at, ends_at, status, price_nu, team_name, contact_name, contact_phone
  )
  values (
    ground, me, 'phone', start_time, start_time + make_interval(hours => hours), 'confirmed', total,
    nullif(trim(team), ''), left(trim(name), 100), nullif(trim(phone), '')
  )
  returning id into booking;
  return booking;
exception when exclusion_violation then
  raise exception 'This time is already booked' using errcode = '23P01';
end;
$$;

-- The manager (or an admin) blocks time on a ground (maintenance, a
-- tournament): on the hour, up to 14 days at once. Returns the block's ID.
-- Postgres error 23P01: a booking has that time; reject or cancel it first.
create or replace function public.block_ground_time(
  ground uuid,
  start_time timestamptz,
  end_time timestamptz,
  reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  local_start timestamp := start_time at time zone 'Asia/Thimphu';
  local_end timestamp := end_time at time zone 'Asia/Thimphu';
  block uuid;
begin
  if not public.can_manage_ground(ground) then
    raise exception 'Only the venue''s manager can block its time' using errcode = '42501';
  end if;
  if not public.is_active_profile(me) then
    raise exception 'This account is deactivated' using errcode = '42501';
  end if;
  if date_trunc('hour', local_start) <> local_start or date_trunc('hour', local_end) <> local_end then
    raise exception 'Blocks start and end on the hour' using errcode = '22023';
  end if;
  if end_time <= start_time or end_time <= now() or end_time - start_time > interval '14 days' then
    raise exception 'Blocks are up to 14 days, and not in the past' using errcode = '22023';
  end if;

  insert into public.ground_bookings (ground_id, booked_by, kind, starts_at, ends_at, status, contact_name, owner_note)
  values (ground, me, 'owner_block', start_time, end_time, 'confirmed',
          coalesce((select full_name from public.profiles where id = me), ''),
          left(nullif(trim(reason), ''), 500))
  returning id into block;
  return block;
exception when exclusion_violation then
  raise exception 'A booking already has some of this time' using errcode = '23P01';
end;
$$;

-- The only way to change a booking's status:
--   the manager (or an admin): pending -> confirmed or rejected (before it starts);
--                              confirmed -> cancelled (also removes a block, or
--                              a booking taken by phone);
--                              confirmed -> completed or no_show (once it has started)
--   the customer:              pending or confirmed -> cancelled, before it starts
-- The manager's [note] is shown to the customer.
create or replace function public.set_booking_status(booking uuid, new_status text, note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  b public.ground_bookings;
  is_manager boolean;
  is_customer boolean;
begin
  select * into b from public.ground_bookings where id = booking for update;
  if not found or me is null then
    raise exception 'No booking with this ID' using errcode = 'P0002';
  end if;
  is_manager := public.can_manage_ground(b.ground_id);
  is_customer := b.kind = 'customer' and b.booked_by = me;
  if not is_manager and not is_customer then
    raise exception 'No booking with this ID' using errcode = 'P0002';
  end if;
  if not public.is_active_profile(me) then
    raise exception 'This account is deactivated' using errcode = '42501';
  end if;
  if not (
    (is_manager and b.status = 'pending' and new_status in ('confirmed', 'rejected') and b.starts_at > now())
    or (is_manager and b.status = 'confirmed' and new_status = 'cancelled')
    or (is_manager and b.kind in ('customer', 'phone') and b.status = 'confirmed'
        and new_status in ('completed', 'no_show') and b.starts_at <= now())
    or (is_customer and b.status in ('pending', 'confirmed') and new_status = 'cancelled' and b.starts_at > now())
  ) then
    raise exception 'A % booking cannot become %', b.status, new_status using errcode = '22023';
  end if;

  -- Each answer replaces the venue's last message (blank: none), so a
  -- cancellation never shows the note that came with the confirmation.
  update public.ground_bookings
  set status = new_status,
      owner_note = case
        when is_manager and not is_customer and b.kind = 'customer'
             and new_status in ('confirmed', 'rejected', 'cancelled')
          then left(nullif(trim(note), ''), 500)
        else owner_note
      end,
      cancelled_by = case when new_status = 'cancelled' then me else cancelled_by end,
      cancelled_at = case when new_status = 'cancelled' then now() else cancelled_at end
  where id = booking;
end;
$$;

-- The customer adds the journal number of an advance they paid by mBoB or mPay.
create or replace function public.set_booking_payment_ref(booking uuid, payment_ref text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  ref text := left(nullif(trim(payment_ref), ''), 60);
begin
  update public.ground_bookings
  set payment_reference = ref,
      payment_status = case
        when payment_status = 'paid' then 'paid'
        when ref is null then 'unpaid'
        else 'deposit_claimed'
      end
  where id = booking
    and booked_by = (select auth.uid())
    and kind = 'customer'
    and status in ('pending', 'confirmed')
    and public.is_active_profile((select auth.uid()));
  if not found then
    raise exception 'Only the customer can add a payment to an open booking' using errcode = '42501';
  end if;
end;
$$;

-- The manager (or an admin) marks a booking paid, or not paid after all.
create or replace function public.set_booking_paid(booking uuid, paid boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.ground_bookings
  set payment_status = case
    when paid then 'paid'
    when payment_reference is not null then 'deposit_claimed'
    else 'unpaid'
  end
  where id = booking
    and kind in ('customer', 'phone')
    and public.can_manage_ground(ground_id)
    and public.is_active_profile((select auth.uid()));
  if not found then
    raise exception 'Only the venue''s manager can mark a booking paid' using errcode = '42501';
  end if;
end;
$$;

-- Behind add_regular_booking, update_regular_booking and make_booking_regular
-- (only they call it): the checks, then a new regular booking when [regular]
-- is null, else that one changed. A new or moved time must be one of the
-- ground's slots (Postgres error 22023). 23P01: another regular booking has
-- some of that time, or someone else's booking already has it in the week
-- ahead (cancel it first); bookings with the same phone number, and
-- [except_booking], are theirs. Returns its ID; null when [regular] isn't
-- one of the ground's.
create or replace function public.save_regular_booking(
  regular uuid,
  ground uuid,
  weekday int,
  start_hour int,
  end_hour int,
  name text,
  phone text,
  team text,
  except_booking uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  who text := left(nullif(trim(save_regular_booking.name), ''), 100);
  mobile text := nullif(trim(save_regular_booking.phone), '');
  -- Only a name or number changed: the time stays as it is.
  moved boolean := not exists (
    select 1 from public.ground_regular_bookings r
    where r.id = regular and r.weekday = save_regular_booking.weekday
      and r.start_hour = save_regular_booking.start_hour and r.end_hour = save_regular_booking.end_hour
  );
  saved uuid;
begin
  if not public.can_manage_ground(ground) or not public.is_active_profile(me) then
    raise exception 'Only the ground''s manager can change regular bookings' using errcode = '42501';
  end if;
  if who is null then
    raise exception 'The name of who books it is needed' using errcode = '22023';
  end if;
  if moved and not exists (
    select 1 from public.ground_time_slots s
    where s.ground_id = ground and s.weekday = save_regular_booking.weekday
      and s.start_hour = save_regular_booking.start_hour and s.end_hour = save_regular_booking.end_hour
  ) then
    raise exception 'This is not one of the ground''s time slots' using errcode = '22023';
  end if;
  if moved and exists (
    select 1 from public.ground_bookings b
    where b.ground_id = ground
      and b.status in ('pending', 'confirmed')
      and b.ends_at > now()
      and b.id is distinct from except_booking
      and (mobile is null or b.contact_phone is distinct from mobile)
      and extract(dow from b.starts_at at time zone 'Asia/Thimphu')::int = save_regular_booking.weekday
      and int4range(extract(hour from b.starts_at at time zone 'Asia/Thimphu')::int,
                    extract(hour from b.starts_at at time zone 'Asia/Thimphu')::int
                      + ceil(extract(epoch from b.ends_at - b.starts_at) / 3600)::int)
          && int4range(save_regular_booking.start_hour, save_regular_booking.end_hour)
  ) then
    raise exception 'A booking already has this time; cancel it first' using errcode = '23P01';
  end if;

  begin
    if regular is null then
      insert into public.ground_regular_bookings (ground_id, weekday, start_hour, end_hour, name, phone, team_name, created_by)
      values (ground, save_regular_booking.weekday, save_regular_booking.start_hour, save_regular_booking.end_hour,
              who, mobile, left(nullif(trim(team), ''), 60), me)
      returning id into saved;
    else
      update public.ground_regular_bookings r
      set weekday = save_regular_booking.weekday,
          start_hour = save_regular_booking.start_hour,
          end_hour = save_regular_booking.end_hour,
          name = who,
          phone = mobile,
          team_name = left(nullif(trim(team), ''), 60)
      where r.id = regular and r.ground_id = ground
      returning r.id into saved;
    end if;
  exception when exclusion_violation then
    raise exception 'Another regular booking has this time' using errcode = '23P01';
  end;
  return saved;
end;
$$;
revoke execute on function public.save_regular_booking(uuid, uuid, int, int, int, text, text, text, uuid)
  from public, anon, authenticated;

-- The manager (or an admin) holds one of the ground's time slots every week,
-- until they change or remove it, for someone who always plays then:
-- [weekday] (0 = Sunday), the slot's hours, and [name] and [phone] for the
-- record. Postgres error 22023: not one of the ground's slots; 23P01:
-- another regular booking has some of that time, or someone else's booking
-- already has it in the week ahead (cancel it first). Returns its ID.
create or replace function public.add_regular_booking(
  ground uuid,
  weekday int,
  start_hour int,
  end_hour int,
  name text,
  phone text default null,
  team text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  return public.save_regular_booking(null, ground, weekday, start_hour, end_hour, name, phone, team);
end;
$$;

-- The same, for someone who plays more than once a week (e.g. a team, every
-- Tuesday 6-8 pm and Friday 8-10 pm): [slots] is a list of {weekday,
-- start_hour, end_hour}, all held for them. All or none: errors as
-- add_regular_booking, and 22023 when [slots] is empty. Returns their IDs.
create or replace function public.add_regular_bookings(
  ground uuid,
  slots jsonb,
  name text,
  phone text default null,
  team text default null
)
returns uuid[]
language plpgsql
security definer
set search_path = ''
as $$
declare
  s jsonb;
  ids uuid[] := '{}';
begin
  if coalesce(jsonb_typeof(slots), '') <> 'array' or jsonb_array_length(slots) = 0 then
    raise exception 'Choose at least one time' using errcode = '22023';
  end if;
  for s in select value from jsonb_array_elements(slots) loop
    ids := ids || public.save_regular_booking(null, ground, (s ->> 'weekday')::int, (s ->> 'start_hour')::int,
                                              (s ->> 'end_hour')::int, name, phone, team);
  end loop;
  return ids;
end;
$$;

-- The manager (or an admin) changes a regular booking: its day and time,
-- or who has it. Errors as add_regular_booking.
create or replace function public.update_regular_booking(
  regular uuid,
  weekday int,
  start_hour int,
  end_hour int,
  name text,
  phone text default null,
  team text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  ground uuid := (select r.ground_id from public.ground_regular_bookings r where r.id = regular);
begin
  if ground is null
     or public.save_regular_booking(regular, ground, weekday, start_hour, end_hour, name, phone, team) is null then
    raise exception 'Only the ground''s manager can change a regular booking' using errcode = '42501';
  end if;
end;
$$;

-- The manager (or an admin) makes a confirmed booking regular: its day of
-- the week and time are held every week from now on, for the same person,
-- until the manager changes or removes it. Errors as add_regular_booking;
-- also 22023 when the booking isn't confirmed (or played). Returns its ID.
create or replace function public.make_booking_regular(booking uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  b public.ground_bookings;
  starts timestamp;
begin
  select * into b from public.ground_bookings where id = booking;
  if not found or not public.can_manage_ground(b.ground_id) then
    raise exception 'Only the ground''s manager can make a booking regular' using errcode = '42501';
  end if;
  if b.kind not in ('customer', 'phone') or b.status not in ('confirmed', 'completed') then
    raise exception 'Only a confirmed booking can be made regular' using errcode = '22023';
  end if;
  starts := b.starts_at at time zone 'Asia/Thimphu';
  return public.save_regular_booking(
    null,
    b.ground_id,
    extract(dow from starts)::int,
    extract(hour from starts)::int,
    extract(hour from starts)::int + ceil(extract(epoch from b.ends_at - b.starts_at) / 3600)::int,
    coalesce(nullif(trim(b.contact_name), ''), (select p.full_name from public.profiles p where p.id = b.booked_by)),
    b.contact_phone,
    b.team_name,
    b.id
  );
end;
$$;

-- The manager (or an admin) stops a regular booking: the time is free again.
create or replace function public.remove_regular_booking(regular uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.ground_regular_bookings r
  where r.id = regular
    and public.can_manage_ground(r.ground_id)
    and public.is_active_profile((select auth.uid()));
  if not found then
    raise exception 'Only the ground''s manager can stop a regular booking' using errcode = '42501';
  end if;
end;
$$;

-- The manager (or an admin) sets a ground's timings for the whole week at
-- once: [slots] is a list of {weekday, start_hour, end_hour}, replacing the
-- ones it had. Repeats are kept once.
create or replace function public.set_ground_time_slots(ground uuid, slots jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can_manage_ground(ground) or not public.is_active_profile((select auth.uid())) then
    raise exception 'Only the ground''s manager can set its timings' using errcode = '42501';
  end if;
  delete from public.ground_time_slots where ground_id = ground;
  insert into public.ground_time_slots (ground_id, weekday, start_hour, end_hour)
  select distinct ground, (s ->> 'weekday')::smallint, (s ->> 'start_hour')::smallint, (s ->> 'end_hour')::smallint
  from jsonb_array_elements(coalesce(slots, '[]'::jsonb)) s;
end;
$$;

-- The times on [day] (Bhutan time) that a ground is taken: booked
-- (confirmed), waiting for the manager's answer, blocked, or a regular
-- booking (every week). No names or numbers, only times. Anyone may call
-- it, logged in or not (13c). Dropped first: 'confirmed' and 'regular' were
-- added, and a function's columns can't change.
drop function if exists public.get_ground_availability(uuid, date);
create or replace function public.get_ground_availability(ground uuid, day date)
returns table (start_time timestamptz, end_time timestamptz, blocked boolean, confirmed boolean, regular boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select (day + make_interval(hours => r.start_hour))::timestamp at time zone 'Asia/Thimphu',
         (day + make_interval(hours => r.end_hour))::timestamp at time zone 'Asia/Thimphu',
         false, true, true
  from public.ground_regular_bookings r
  join public.grounds g on g.id = r.ground_id
  where r.ground_id = ground
    and r.weekday = extract(dow from day)::int
    and (public.is_listed_venue(g.venue_id) or public.can_manage_venue(g.venue_id))
  union all
  select b.starts_at, b.ends_at, b.kind = 'owner_block', b.status = 'confirmed', false
  from public.ground_bookings b
  join public.grounds g on g.id = b.ground_id
  where b.ground_id = ground
    and (public.is_listed_venue(g.venue_id) or public.can_manage_venue(g.venue_id))
    and b.status in ('pending', 'confirmed')
    and not (b.status = 'pending' and (b.created_at < now() - interval '12 hours' or b.starts_at <= now()))
    and tstzrange(b.starts_at, b.ends_at, '[)') && tstzrange(
      day::timestamp at time zone 'Asia/Thimphu',
      (day + 1)::timestamp at time zone 'Asia/Thimphu',
      '[)')
  order by 1;
$$;

revoke execute on function
  public.set_venue_manager(uuid, uuid),
  public.add_venue(jsonb, uuid),
  public.book_ground(uuid, timestamptz, int, text, text, int, text, text, text),
  public.book_by_phone(uuid, timestamptz, int, text, text, text),
  public.block_ground_time(uuid, timestamptz, timestamptz, text),
  public.set_booking_status(uuid, text, text),
  public.set_booking_payment_ref(uuid, text),
  public.set_booking_paid(uuid, boolean),
  public.set_ground_time_slots(uuid, jsonb),
  public.add_regular_booking(uuid, int, int, int, text, text, text),
  public.add_regular_bookings(uuid, jsonb, text, text, text),
  public.update_regular_booking(uuid, int, int, int, text, text, text),
  public.make_booking_regular(uuid),
  public.remove_regular_booking(uuid),
  public.get_ground_availability(uuid, date)
  from public, anon;
grant execute on function
  public.set_venue_manager(uuid, uuid),
  public.add_venue(jsonb, uuid),
  public.book_ground(uuid, timestamptz, int, text, text, int, text, text, text),
  public.book_by_phone(uuid, timestamptz, int, text, text, text),
  public.block_ground_time(uuid, timestamptz, timestamptz, text),
  public.set_booking_status(uuid, text, text),
  public.set_booking_payment_ref(uuid, text),
  public.set_booking_paid(uuid, boolean),
  public.set_ground_time_slots(uuid, jsonb),
  public.add_regular_booking(uuid, int, int, int, text, text, text),
  public.add_regular_bookings(uuid, jsonb, text, text, text),
  public.update_regular_booking(uuid, int, int, int, text, text, text),
  public.make_booking_regular(uuid),
  public.remove_regular_booking(uuid),
  public.get_ground_availability(uuid, date)
  to authenticated;
grant execute on function public.get_ground_availability(uuid, date) to anon;

-- 13e. Notifications (section 5).
--   managers:  they were given a venue (set_venue_manager, 13d); a new
--              booking; a customer cancelled; a customer reviewed the venue
--   customers: their booking was confirmed, rejected, cancelled by the
--              venue, expired unanswered, or is done (so they can review)
-- What a booking's notifications say: where, when and who.
create or replace function public.booking_notification_data(b public.ground_bookings)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'booking_id', b.id,
    'venue_id', v.id,
    'venue_name', v.name,
    'ground_name', g.name,
    'customer_name', b.contact_name,
    'starts_at', b.starts_at,
    'hours', (extract(epoch from b.ends_at - b.starts_at) / 3600)::int,
    'status', b.status,
    'note', b.owner_note)
  from public.grounds g join public.venues v on v.id = g.venue_id
  where g.id = b.ground_id;
$$;

revoke execute on function public.booking_notification_data(public.ground_bookings) from public, anon, authenticated;

-- A new booking: the manager (a request to answer, or already confirmed).
create or replace function public.handle_ground_booking_added()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.add_notification(
    (select v.manager_id from public.grounds g join public.venues v on v.id = g.venue_id where g.id = new.ground_id),
    'booking_new', public.booking_notification_data(new), new.booked_by);
  return new;
end;
$$;

drop trigger if exists ground_bookings_notify_new on public.ground_bookings;
create trigger ground_bookings_notify_new
  after insert on public.ground_bookings
  for each row when (new.kind = 'customer')
  execute function public.handle_ground_booking_added();

-- Confirmed, rejected, done: the customer. Cancelled: whoever didn't cancel
-- it (by the customer: the manager). Expired (cancelled by no one): the customer.
create or replace function public.handle_ground_booking_status_changed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  manager uuid := (select v.manager_id from public.grounds g join public.venues v on v.id = g.venue_id
                   where g.id = new.ground_id);
  details jsonb := public.booking_notification_data(new);
begin
  if new.status in ('confirmed', 'rejected', 'completed') then
    perform public.add_notification(new.booked_by, 'booking_' || new.status, details, manager);
  elsif new.status = 'cancelled' and new.cancelled_by is null then
    perform public.add_notification(new.booked_by, 'booking_expired', details);
  elsif new.status = 'cancelled' and new.cancelled_by = new.booked_by then
    perform public.add_notification(manager, 'booking_cancelled', details || '{"by": "customer"}', new.booked_by);
  elsif new.status = 'cancelled' then
    perform public.add_notification(new.booked_by, 'booking_cancelled', details || '{"by": "owner"}',
      new.cancelled_by);
  end if;
  return new;
end;
$$;

drop trigger if exists ground_bookings_notify_status on public.ground_bookings;
create trigger ground_bookings_notify_status
  after update of status on public.ground_bookings
  for each row when (old.status is distinct from new.status and new.kind = 'customer')
  execute function public.handle_ground_booking_status_changed();

-- A customer reviewed the venue, or changed their review: the manager.
create or replace function public.handle_venue_review_saved()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.add_notification(
    (select manager_id from public.venues where id = new.venue_id),
    case when tg_op = 'INSERT' then 'venue_review_new' else 'venue_review_updated' end,
    jsonb_build_object('venue_id', new.venue_id, 'rating', new.rating),
    new.customer_id);
  return new;
end;
$$;

drop trigger if exists venue_reviews_notify_new on public.venue_reviews;
create trigger venue_reviews_notify_new
  after insert on public.venue_reviews
  for each row execute function public.handle_venue_review_saved();

drop trigger if exists venue_reviews_notify_changed on public.venue_reviews;
create trigger venue_reviews_notify_changed
  after update of rating, comment on public.venue_reviews
  for each row when (old.rating is distinct from new.rating or old.comment is distinct from new.comment)
  execute function public.handle_venue_review_saved();

-- 13f. Storage: venue-photos (public, like avatars) for venues' cover
-- photos. Only managers and admins upload, into their own <user-id>/
-- folder as for the other buckets. The photos belong to the venue, so
-- deleting the account that uploaded one keeps it (delete-account).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('venue-photos', 'venue-photos', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

-- The first version's rules, which also covered trade licences.
drop policy if exists "storage: venue files upload into own folder" on storage.objects;
drop policy if exists "storage: venue files delete own" on storage.objects;
drop policy if exists "storage: venue files read own, admins read licences" on storage.objects;

drop policy if exists "storage: venue photos upload by managers and admins" on storage.objects;
create policy "storage: venue photos upload by managers and admins"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'venue-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and ((select public.is_admin()) or (select public.is_venue_manager()))
  );

-- Optional: expire unanswered requests every 15 minutes, so customers hear
-- in good time (without it, they expire when someone next books that
-- ground). Database -> Extensions -> turn on pg_cron, then run this line on
-- its own:
-- select cron.schedule('expire-ground-bookings', '*/15 * * * *', $$select public.expire_stale_ground_bookings()$$);


-- Make the app's API see the new functions now, not in a few minutes.
notify pgrst, 'reload schema';
