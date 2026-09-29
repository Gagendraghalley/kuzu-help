# Kuzu Help (version 1)

Flutter + Supabase marketplace connecting customers with verified local workers.

## First-time setup

1. Unzip this folder and open a terminal inside `bhutan_services/`.
2. The Android and iOS platform folders are already generated with the organisation ID
   `bt.kuzuhelp`: the app ID is `bt.kuzuhelp.bhutan_services` on Android and
   `bt.kuzuhelp.bhutanServices` on iOS. These cannot be changed after publishing.

3. Install packages:

   ```
   flutter pub get
   ```

4. Set up Supabase (build guide, Phases 1–2): in the SQL Editor run `supabase/schema.sql`
   once. In Authentication → Email Templates, show the code `{{ .Token }}` instead of the
   link in **both** the Magic Link and the Confirm signup templates (brand-new users get
   the Confirm signup email; 'Forgot password?' codes use Magic Link).
   In the Email provider settings, set **Minimum password length** to 8 to match the app,
   and leave **Secure password change** off (otherwise a user who confirmed their code
   more than a day ago can't set their first password).

   How login works: new users confirm their email with a 6-digit code, then must choose
   a password (A5) before anything else. After that they log in with email and password.
   'Forgot password?' sends a code and ends on A5 again. Whether a user has set a
   password is kept as `has_password` in their Supabase user metadata.
   Admins (made with the SQL line at the end of `schema.sql`) are never made to set a
   password: they can log in with just the code from 'Forgot password?', or set a
   password in Settings.

   Then run `supabase/updates.sql` in the SQL Editor (copy all of it, paste, Run). It is
   safe to run again, so run the latest version whenever the app says "The database
   needs an update". It adds:
   - **Approving workers**: admins approve or reject workers in the app (Settings →
     Workers awaiting approval, or the 'Admin check' card on any worker's page, which
     shows their CID and certificate). Customers only see approved workers.
   - **Deactivating users**: admins blacklist users from Settings → Users or the 'Admin
     check' card. A deactivated user only sees why and can log out; the database refuses
     their changes, hides them from customers and hides their reviews. Admins can't be
     deactivated.
   - **Switching roles and checking emails**: workers can stop offering services (become
     customers); sign-up says when an email is already registered and log-in says when
     it isn't. Admins can't switch to customer or worker.
   - **Notifications**: a bell on every home screen with each user's own list, updated
     live (it adds the `notifications` table to Supabase Realtime). The database adds
     them itself, so they can't be faked from the app:
     - admins: someone registered (after entering their email code), a worker sent their
       documents or asks to be checked again, a customer reported a worker;
     - workers: approved or rejected (with the admin's note), a customer reviewed them,
       or tapped Call or WhatsApp on their page (at most once a day per customer);
     - customers: an admin changed the status of their report (in the dashboard);
     - everyone: welcome, and account deactivated or reactivated.

     Workers aren't told which customer reviewed or contacted them, as reviews don't
     show names. Tapping a notification opens what it's about (the worker's page, Users,
     Reports, or the worker's dashboard).
   - **Reports**: admins read customers' reports in the app (Settings → Reports), open the
     worker's page, and mark each report reviewed or closed. The customer who sent it is
     notified.
   - **Reviews only after getting in touch**: a customer can review a worker once they've
     tapped Call or WhatsApp on their page, or sent them a job request (the database
     checks this, so fake reviews are harder). Earlier reviewers keep their reviews.
   - **Replies to reviews**: workers answer a review from their dashboard or their own
     page; the reply shows under it and the customer is notified.
   - **Photos of work**: workers add up to 12 photos of finished jobs (Dashboard or
     Settings → Photos of your work), shown on their page. Stored in the public
     `work-photos` bucket.
   - **Search and saved workers**: search workers by name from Customer Home, an
     "Available now" filter on the worker list, and a heart to save workers (Customer Home →
     Saved workers).
   - **Job requests**: customers describe a job (what, where, when, their phone number and
     an optional photo in the private `job-photos` bucket) from a worker's page. Workers
     accept or decline with an optional note, either side marks it done, and customers can
     cancel until then. Each step notifies the other person. One open request per customer
     and worker; only workers set to "Available" can get them.
   - **Dzongkha category names**: fill in `service_categories.name_dz` in the Table Editor
     and Customer Home shows it under the English name. The rest of the app is English
     until its text (all in `app_strings.dart`) is translated.

   **Deleting accounts** (Settings → Delete account; Apple and Google require it for apps
   with sign-up): deploy the Edge Function in `supabase/functions/delete-account/`. In
   Supabase go to Edge Functions → Deploy a new function → Via Editor, name it
   `delete-account`, paste in `index.ts` and press Deploy (or, with the Supabase CLI,
   `supabase functions deploy delete-account`); deploy it again whenever `index.ts`
   changes. It deletes the user's photos and documents in every bucket, then their account
   and everything linked to it. Admins and deactivated users can't
   delete their account (deactivated users could otherwise sign up again).

5. Copy `config/dev.example.json` to `config/dev.json` and fill in your Supabase
   Project URL and anon (publishable) key. `dev.json` is gitignored.
   NEVER put the service_role / secret key here.

6. Run on your phone:

   ```
   flutter run --dart-define-from-file=config/dev.json
   ```

## Platform settings to add after step 2

**android/app/src/main/AndroidManifest.xml**
- `<uses-permission android:name="android.permission.INTERNET"/>`
- A `<queries>` block declaring the `tel` and `https` intents (see the url_launcher README),
  otherwise Call and WhatsApp buttons can silently fail on Android 11+.
- Camera / photo permissions as listed in the image_picker README.

**ios/Runner/Info.plist**
- `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` (see image_picker README).
- `LSApplicationQueriesSchemes` with `tel` and `https`.

## Folder guide

| Folder | Contains |
| --- | --- |
| `lib/core` | Supabase client, theme, routes, constants, all display strings, utilities |
| `lib/features/auth` | A1–A5: splash, welcome/role, login, verify code, set password; 'account deactivated' |
| `lib/features/worker` | B1–B5: profile setup, services, verification, pending, dashboard; photos of work |
| `lib/features/customer` | C1–C5: home, worker list, details, review, report; search by name, saved workers |
| `lib/features/jobs` | Job requests: the request form, and the list both sides answer from |
| `lib/features/profile` | D1: settings, edit profile, change password, logout, delete account |
| `lib/features/admin` | Workers awaiting approval, Users, Reports, and the 'Admin check' card (approve, reject, deactivate) |
| `lib/features/notifications` | The bell (unread count) and the Notifications screen |
| `lib/shared` | Models and reusable widgets |
| `supabase/` | `schema.sql` (run once), `updates.sql` (run after it; safe to re-run), and the delete-account Edge Function (Settings → Delete account) |

Each feature has `screens/` (display only), `providers/` (Riverpod state) and
`data/` (the only files that talk to Supabase).

## Rules for every screen
- Loading indicator while data loads; friendly error with a Retry button.
- All display text lives in `lib/core/strings/app_strings.dart` (Dzongkha later).
- Every upload goes to `<user-id>/filename` via `storage_paths.dart`.
