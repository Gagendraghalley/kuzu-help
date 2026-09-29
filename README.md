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

## Push notifications (optional; Android and iPhone)

Every notification in the bell can also reach the phone when the app is closed. Until
this is set up, the app works exactly as before (the bell only). Each piece checks its own
setup, so you can do the steps in any order; pushes start once all are done.

1. **Firebase** (free): create a project at console.firebase.google.com, then *Add app →
   Android* with the package name `bt.kuzuhelp.bhutan_services`. Download its
   `google-services.json` (you only read values from it; don't add it to the project or
   to git) and copy four values into `config/dev.json`:

   | config/dev.json | google-services.json |
   | --- | --- |
   | `FIREBASE_PROJECT_ID` | `project_info.project_id` |
   | `FIREBASE_MESSAGING_SENDER_ID` | `project_info.project_number` |
   | `FIREBASE_ANDROID_APP_ID` | `client[0].client_info.mobilesdk_app_id` |
   | `FIREBASE_ANDROID_API_KEY` | `client[0].api_key[0].current_key` |

2. **A key for sending**: Firebase → Project settings → Service accounts → *Generate new
   private key*. Keep the JSON file private: it lets anyone send pushes to your users.

3. **The send-push Edge Function**: Supabase → Edge Functions → Deploy a new function →
   Via Editor, name it `send-push`, paste in `supabase/functions/send-push/index.ts`,
   Deploy. Open its settings and turn **off** *Enforce JWT verification* (the database
   proves who it is with a secret instead). Then Edge Functions → Secrets, add:
   - `FIREBASE_SERVICE_ACCOUNT`: the whole JSON file from step 2;
   - `PUSH_SECRET`: a long random text you make up (e.g. from a password generator).

4. **Tell the database where to send**: in the SQL Editor, run once (your project URL, and
   the same random text as `PUSH_SECRET`):

   ```sql
   select vault.create_secret('https://YOUR-PROJECT-ID.supabase.co', 'kuzu_project_url');
   select vault.create_secret('THE-SAME-RANDOM-TEXT', 'kuzu_push_secret');
   ```

5. Run the latest `supabase/updates.sql` (section 12 adds the phones' tokens and the sender).

6. Run the app on an Android phone, or an emulator with Google Play, log in and allow
   notifications. From then on each new notification also arrives on the phone; tapping it
   opens the same screen as tapping it in the bell. Logging out stops that phone getting
   them.

Notes:
- The push text is worded in `send-push/index.ts`, a copy of `AppStrings.notificationTitle`
  and `notificationBody`: change both together.
- If pushes don't arrive, look at Edge Functions → send-push → Logs, and in the SQL Editor
  `select * from net._http_response order by created desc limit 10;` for the database's calls.

### iPhones

The iOS project already has push set up (`ios/Runner/Runner.entitlements`, and
*remote-notification* in `Info.plist`); the minimum iOS is 15 because of the Firebase SDK.
It needs a paid Apple Developer team (this project uses team `6E2JNTTC36`), and:

1. **An APNs key** (developer.apple.com → Certificates, Identifiers & Profiles → Keys, with
   *Apple Push Notifications service* ticked). A team can only have two, and one key serves
   every app on the team, so an existing one can be reused: you need its `.p8` file (it can
   only be downloaded once, by whoever created it) and its Key ID. A **Sandbox** key only
   works for builds run from Xcode / `flutter run`; TestFlight and App Store builds need
   one that includes **Production**. Keep the `.p8` private: it can send notifications to
   every app on the team. It goes only into Firebase, never into the app or git.
2. **Firebase**: *Add app → iOS* with the bundle ID `bt.kuzuhelp.bhutanServices`. From its
   `GoogleService-Info.plist` (again, only read it) copy `GOOGLE_APP_ID` into
   `FIREBASE_IOS_APP_ID` and `API_KEY` into `FIREBASE_IOS_API_KEY` in `config/dev.json`.
   Then Project settings → Cloud Messaging → Apple app configuration → *APNs Authentication
   Key*: upload the `.p8` with its Key ID and the Team ID.
3. Steps 2–5 above (the service account, send-push, Vault, `updates.sql`) are shared with
   Android: do them once.
4. Test on a real iPhone, run from Xcode or `flutter run` with the team selected under
   Runner → Signing & Capabilities. (Recent simulators on Apple silicon Macs can receive
   pushes too, but a real phone is the dependable test.)

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
| `supabase/` | `schema.sql` (run once), `updates.sql` (run after it; safe to re-run), and the Edge Functions: delete-account (Settings → Delete account) and send-push (push notifications) |

Each feature has `screens/` (display only), `providers/` (Riverpod state) and
`data/` (the only files that talk to Supabase).

## Rules for every screen
- Loading indicator while data loads; friendly error with a Retry button.
- All display text lives in `lib/core/strings/app_strings.dart` (Dzongkha later).
- Every upload goes to `<user-id>/filename` via `storage_paths.dart`.
