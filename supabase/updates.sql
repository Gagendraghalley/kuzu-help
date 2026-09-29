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


-- Make the app's API see the new functions now, not in a few minutes.
notify pgrst, 'reload schema';
