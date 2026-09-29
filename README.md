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

   Users can't delete their own account in the app; admins deactivate accounts instead.

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
| `lib/features/worker` | B1–B5: profile setup, services, verification, pending, dashboard |
| `lib/features/customer` | C1–C5: home, worker list, details, review, report |
| `lib/features/profile` | D1: settings, edit profile, change password, logout |
| `lib/features/admin` | Workers awaiting approval, Users, and the 'Admin check' card (approve, reject, deactivate) |
| `lib/shared` | Models and reusable widgets |
| `supabase/` | `schema.sql` (run once), `updates.sql` (run after it; safe to re-run), and the delete-account Edge Function (no longer called by the app) |

Each feature has `screens/` (display only), `providers/` (Riverpod state) and
`data/` (the only files that talk to Supabase).

## Rules for every screen
- Loading indicator while data loads; friendly error with a Retry button.
- All display text lives in `lib/core/strings/app_strings.dart` (Dzongkha later).
- Every upload goes to `<user-id>/filename` via `storage_paths.dart`.
