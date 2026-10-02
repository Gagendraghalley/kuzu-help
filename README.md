# Kuzu Help (version 1)

Flutter + Supabase marketplace connecting customers with verified local workers.

## About

Kuzu Help is a mobile app for Android and iPhone that helps people in Bhutan find trusted
local workers, such as plumbers, electricians, carpenters, appliance repairers, painters
and masons, in their own dzongkhag. Customers choose a service and their dzongkhag, then
see a list of workers with their ratings, prices and years of experience, and can show
only the workers who are available now. On a worker's page they can read reviews, look at
photos of past work, call or WhatsApp the worker directly, send a job request that says
what needs doing, where and when, save the worker for later, and leave a review once they
have been in touch. Workers sign up, set up a profile with the services they offer and
their prices, and upload their CID and a certificate. An admin checks these documents and
approves or rejects the worker, and only approved workers are shown to customers. Once
approved, workers run everything from their dashboard: they switch their availability on
or off, accept or decline job requests, reply to reviews and add up to 12 photos of their
work. Admins also read the reports customers send about workers and can deactivate
accounts that break the rules. Every important step, such as a new job request, an
approval or a new review, sends an in-app notification and, once set up, a push
notification to the person's phone, so customers, workers and admins always know what has
changed.

## First-time setup

1. Unzip this folder and open a terminal inside `bhutan_services/`.
2. The Android and iOS platform folders are already generated with the organisation ID
   `bt.kuzuhelp`: the app ID is `bt.kuzuhelp.app` on Android (the package name registered
   in the Google Play Console) and `bt.gov.kuzuhelp` on iOS. These cannot be
   changed after publishing.

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
   - **Sports grounds** (section 13): Customer Home offers Home services (the workers
     above), and Sports grounds only to accounts that use them too (the player role) and
     to admins: someone who signed up to find workers sees home services only. A third,
     Party & dining, is hidden until it's ready
     (`showPartyDining` in `customer_home_screen.dart`). An admin
     registers each futsal or football ground together with its **ground manager**, the one
     person who runs it (Settings → Sports grounds → Register a ground: the ground's details,
     its type and price per hour, and the manager's name, email and phone, saved together;
     the database makes all of them or none). The manager's account is made from their name
     and email (the `create-venue-manager` Edge Function, below); to log in the first time
     they tap 'Log in', then 'Forgot password?', get a code by email and choose a password.
     From then on the app opens on their ground: once, they set its **timings** ('Set
     timings'): for each day, Monday to Sunday, as many times as they like, e.g. Sunday
     6–9 pm, 8–10 pm and 10 pm–12 am (a day with none is closed). Later they change them the
     same way, and the type and price under 'Edit ground'. They answer booking requests (or
     have them confirmed automatically); add a booking for someone who calls ('Add a
     booking' on Bookings: confirmed at once, and everyone sees the time as booked); hold a
     time every week for a team that always plays then ('Regular bookings', one day or more a
     week, e.g. Tuesday and Friday, or 'Mark as regular' on a confirmed booking: the same
     days and times every week until they edit or
     remove it; everyone sees it as a regular booking, nobody else can book it); keep 'Booking records' of everyone who
     has booked, with their phone, how often and when last; block time; mark bookings
     played, no-show or paid; and pause bookings. Admins can do all of that for any ground, and change or remove its
     manager; a ground without an active manager, or without timings, can't be booked.
     Workers' and admins' accounts can't be ground managers. Customers pick a day, then one
     of its times, and book the whole time, up to one week ahead (by phone too), in Bhutan time; the price is
     its hours at the day price, or at the night price for hours from the time it starts (most grounds have one price all day). The database works out the price and refuses
     a time that is taken, or runs into a taken one, even when two people book at once.
     Requests the manager doesn't answer within 12 hours are cancelled and the time is free
     again. Each step notifies the other person, and customers can review a ground once they
     have played there. Sports grounds are public: from Welcome ('Browse sports grounds')
     anyone can see grounds, prices, timings, reviews and which times are booked, on hold or
     free, without an account; 'Create a free account to book' or 'I have an account: log
     in' takes them there, then back to the ground. People who sign up from a ground are
     **players** (role `player`), apart from customers, who use the home services; a
     player's home is the grounds and their bookings. One email can use both services:
     signing up for the other one with the same email (or 'Use this account for sports
     grounds' on a ground's booking screen, after 'Log in to book') adds that role to the
     account (`profiles.roles`, `add_my_role`), and a customer who plays too keeps Customer
     Home, which then has sports grounds as well. Only accounts with the player role can book a
     ground. Cover photos go in the public `venue-photos` bucket.
     **Finding grounds**: 'Search grounds by name or place' finds them anywhere in Bhutan by
     name, town or dzongkhag. Under 'Location on the map' (Edit ground, or when registering
     one) the manager or an admin sets where the ground is: 'Use my current location' while
     standing there, or a pasted Google Maps link (Share, then Copy link; short
     `maps.app.goo.gl` links are followed). Customers then see how far away each ground is in
     a straight line, and 'Directions' (on its card and its page) opens Google Maps, which
     shows the road and the drive time. No Google API key or billing is needed.
     **Location**: the first time the app needs it, it asks once to use the phone's location;
     after that only when someone taps 'Nearest first' or 'How far is it from me?'. 'Your
     area' then starts as the dzongkhag the phone is in (the nearest main town in
     `dzongkhags.dart`), for workers and grounds alike; one picked by hand stays until the app
     is closed. Outside Bhutan no distances are shown. Every dzongkhag picker narrows as you
     type: a name, another spelling (Wangdi, Chukha) or a town (Phuentsholing, Gelephu). Optional: to tell
     customers about expired requests straight away, turn on pg_cron (Database → Extensions)
     and run the `cron.schedule` line at the end of section 13 once.
     Words: in the app, a venue (the place, e.g. Babesa Futsal Ground) is called a
     **ground**. In the database it is a `venues` row with one `grounds` row (its type and
     price) and that row's `ground_time_slots` (its timings).
     Don't run the older 'Migration 02' draft: section 13 replaces it.
   - **Ground subscriptions** (section 14): each ground pays Kuzu Help every month to be
     listed for players. A new ground gets its **first month free** when it's registered
     (grounds registered before this update get theirs when you run it, and their managers
     are told). After that an admin records each month's payment on the ground's
     **Subscription** page (Settings → Sports grounds → the ground → Subscription): the
     amount, how it was paid (mBoB, mPay, bank transfer, cash) and the journal number. A
     payment is always exactly **one month**, and can only be recorded in the last 7 days
     of the current period (or once it has ended), so no ground pays more than a month at
     a time. Admins can also **Give free time** of any length (a week to a year at once,
     as often as they like) and change each ground's monthly fee. **Billing settings** (the
     receipt icon on Sports grounds) holds the fee new grounds get and how managers pay
     Kuzu Help (e.g. an mBoB account), shown to every manager. Only admins can change any
     of it: the database refuses everyone else. Managers see their subscription on their
     home (at the top, in orange, in its last 7 days; in red once it has ended) and on its
     page, with the fee, how to pay and the billing history. When a subscription ends, the
     ground disappears from players' lists, search and its page, nobody can book it, and
     its manager can't add bookings by phone or regular bookings until the next payment
     is recorded; bookings already made stay. Notifications: the manager when the free
     month starts, free time is given or a payment is recorded (a receipt), 7, 3 and 1
     days before the end, and when it ends; admins when one ends. **The reminders need
     pg_cron**: Database → Extensions → turn on pg_cron, then run `updates.sql` again (it
     schedules them every hour). Deploy `send-push` again for their push wording.

   **Ground managers' accounts** (Register a venue, and Change manager on a venue): deploy `supabase/functions/create-venue-manager/` the same way as `delete-account`
   below, named `create-venue-manager`. Only admins can call it. It makes the account
   (already confirmed), or finds the one that uses the email, and the app then gives it
   the venue.

   **Deleting accounts** (Settings → Delete account; Apple and Google require it for apps
   with sign-up): deploy the Edge Function in `supabase/functions/delete-account/`. In
   Supabase go to Edge Functions → Deploy a new function → Via Editor, name it
   `delete-account`, paste in `index.ts` and press Deploy (or, with the Supabase CLI,
   `supabase functions deploy delete-account`); deploy it again whenever `index.ts`
   changes (so does `send-push`, for the booking notifications). It deletes the user's
   photos and documents in every bucket, then their account and everything linked to
   it; a ground manager's venues stay, without a manager. Admins and deactivated users can't
   delete their account (deactivated users could otherwise sign up again). Admins also
   delete other users' accounts with it, from Settings → Users (never another admin's); a
   version deployed before that only lets users delete themselves, so deploy it again.

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
   Android* with the package name `bt.kuzuhelp.app`. Download its
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
2. **Firebase**: *Add app → iOS* with the bundle ID `bt.gov.kuzuhelp`. From its
   `GoogleService-Info.plist` (again, only read it) copy `GOOGLE_APP_ID` into
   `FIREBASE_IOS_APP_ID` and `API_KEY` into `FIREBASE_IOS_API_KEY` in `config/dev.json`.
   Then Project settings → Cloud Messaging → Apple app configuration → *APNs Authentication
   Key*: upload the `.p8` with its Key ID and the Team ID.
3. Steps 2–5 above (the service account, send-push, Vault, `updates.sql`) are shared with
   Android: do them once.
4. Test on a real iPhone, run from Xcode or `flutter run` with the team selected under
   Runner → Signing & Capabilities. (Recent simulators on Apple silicon Macs can receive
   pushes too, but a real phone is the dependable test.)

## Sign in with Google (optional; Android and iPhone)

Adds **Continue with Google** to the log in and sign-up screen: no code to type and no
password to choose. Until it is set up the button is hidden and email sign-in works as
before. The app uses Google's own account picker and hands Supabase the ID token
(`AuthRepository.signInWithGoogle`); no web page or redirect is involved.

1. **Google Cloud** (console.cloud.google.com; the Firebase project is fine): *Google Auth
   Platform → Branding*: app name *Kuzu Help* and a support email (a logo is optional,
   and waits for Google's review). Under *Audience*, **Publish** the app, or only the test
   users listed there can sign in.
2. *Clients → Create client*, three times:
   - **Web application** (name it e.g. *Supabase*). Its Client ID goes into
     `GOOGLE_WEB_CLIENT_ID` in `config/dev.json`; it and its Client secret go into Supabase
     (step 3). Both phones ask Google for tokens meant for this client.
   - **Android**: package name `bt.kuzuhelp.app` and a SHA-1 fingerprint. Make one per key
     the app is signed with: the debug key (`keytool -list -v -keystore
     ~/.android/debug.keystore -alias androiddebugkey -storepass android`), the upload key in
     `android/key.properties`, and Play Console → *Test and release → App integrity → App
     signing key*. Nothing from these goes into the app.
   - **iOS**: bundle ID `bt.gov.kuzuhelp`. Its Client ID goes into
     `GOOGLE_IOS_CLIENT_ID`, and its *iOS URL scheme* (`com.googleusercontent.apps.…`)
     replaces `com.googleusercontent.apps.YOUR-IOS-CLIENT-ID` in `ios/Runner/Info.plist`.
     (The iOS app was `bt.kuzuhelp.bhutanServices` before; an iOS client made for that
     only needs its Bundle ID changed, and keeps its Client ID.)
3. **Supabase** → Authentication → Sign In / Providers → **Google**: turn it on. *Client
   IDs*: the Web client ID, a comma, then the iOS client ID. *Client Secret*: the Web
   client's secret. Leave *Skip nonce checks* off (the app sends a nonce). Save.
4. Run the latest `supabase/updates.sql` (13d adds `claim_signup_role`).
5. Run with the new `config/dev.json`, tap *Find a service → Continue with Google*, pick an
   account: you land on Customer Home with your Google name.

How it fits the rest of sign-up:
- Google (and Apple) only make an account when signing up, i.e. after picking on Welcome
  how they'll use Kuzu Help. Logging in with a Google or Apple account whose email no
  account uses says *No account uses this email yet*, as logging in with a password does,
  and makes nothing (the app checks `is_email_registered` before Supabase signs in).
- The database makes every new Google account a customer (Google can't carry the role the
  way the email code's metadata does). Right after, the splash calls `claim_signup_role`,
  which makes it a worker or player when that's what they picked on Welcome. It only works
  on an account made in the last 10 minutes, so it can't be used to change role later.
- Signing in with Google with an email that already has an account logs into that account
  (Supabase links the two); picking home services or sports grounds adds that service, as
  the email code does. Picking *Offer your services* doesn't turn an existing account into
  a worker: an admin adds the role in Settings → Users → *Edit roles* (Settings has no
  role switching for users, so nobody gets confused).
- Google accounts skip *Create a password*. They can add one in Settings → *Change
  password* (or with *Forgot password?*) to log in with email too.
- If the button shows an error, check the Web client ID in both `config/dev.json` and
  Supabase, and on Android the SHA-1 of the key the app was signed with.

## Sign in with Apple (iPhone)

App Review asks apps that offer Continue with Google to offer Sign in with Apple too
(guideline 4.8), so iPhones show **Continue with Apple** above the Google button; Android
doesn't. It works like Google: Apple's own sheet, then Supabase gets the ID token
(`AuthRepository.signInWithApple`).

1. **Apple Developer**: the App ID `bt.gov.kuzuhelp` needs the *Sign in with
   Apple* capability. `ios/Runner/Runner.entitlements` asks for it, so Xcode adds it when
   it signs the app (automatic signing).
2. **Supabase** → Authentication → Sign In / Providers → **Apple**: turn it on. *Client
   IDs*: `bt.gov.kuzuhelp`. Leave the secret key empty (only signing in on the
   web needs it). Save.
3. Test on a real iPhone that is signed in to an Apple ID.

Notes:
- New accounts get their role as Google ones do (`claim_signup_role`), and skip *Create a
  password*.
- Apple shares the person's name only the first time they use their Apple ID with the app,
  and not in the token; the splash saves it to their profile then. If they chose not to
  share it, the profile has no name until they add one in Settings → Edit profile. To try
  a first sign-in again, remove Kuzu Help under *Sign in with Apple* in the iPhone's Apple
  Account settings.
- With *Hide My Email*, the account's email is a `…@privaterelay.appleid.com` address.
  Supabase's emails (the *Forgot password?* code) only reach it once Supabase's sending
  domain is added under Apple Developer → Services → *Sign in with Apple for Email
  Communication*. Apple accounts don't need a password, so this only matters to someone
  who wants to add one.
- Deleting an account doesn't revoke its Apple sign-in (that needs the secret key and a
  call from a server); the person can remove it in their Apple Account settings as above.

## One-command release (both stores)

```
scripts/release.sh
```

raises the build number in `pubspec.yaml` (1.0.0+6 → 1.0.0+7), cleans, builds the Android
app bundle and uploads it to Google Play, then builds the iPhone app and uploads it to App
Store Connect. If one store fails, the other still goes ahead, and the summary says how to
retry. Before changing anything it checks everything below is in place.

- `scripts/release.sh android` or `scripts/release.sh ios`: one store only.
- Google Play gets a **draft** release on the production track, which you roll out in Play
  Console. `--rollout` sends it for review instead, to roll out once Google approves it;
  `--track internal` (or `alpha`, `beta`) uses a testing track.
- `--no-bump` keeps the build number, to retry a store whose upload failed.
- `--dry-run` checks everything and shows what it would do, without changing anything.
- Apple has no 'release' step here: once the build is processed, pick it on the version's
  page in App Store Connect → *Add for Review* → *Submit*, as below.
- Commit `pubspec.yaml` afterwards, so the next release counts on from the new number.

Once, for the Google Play upload (`scripts/play_upload.mjs`, which needs Node.js 18 or newer):

1. Google Cloud console (the Firebase project is fine) → *APIs & Services* → enable the
   **Google Play Android Developer API**.
2. *IAM & Admin → Service accounts → Create service account* (no roles needed), then on it
   *Keys → Add key → JSON*. Save the file as `~/.kuzu-help/play-service-account.json`,
   outside the project (or set `PLAY_SERVICE_ACCOUNT` to where it is). Keep it private:
   it can publish the app. Never put it in git.
3. Play Console → *Users and permissions → Invite new users*: the service account's email
   (`…@….iam.gserviceaccount.com`), with Kuzu Help's permissions to **release to
   production** and **release apps to testing tracks**. It can take a few minutes to work.

The iPhone upload uses Xcode's signed-in Apple ID, as in *iOS release build* below.

## Android release build (Google Play)

Release builds are signed with the upload key named in `android/key.properties`
(gitignored), which points to a keystore kept outside the project. **Back up both the
keystore and `key.properties`**: every Play Store update must be signed with this key.
Without `key.properties`, release builds fall back to the debug key, which Play rejects.

Raise `version:` in `pubspec.yaml` before each upload (the number after `+` must go up
every time), then:

```
flutter build appbundle --release --dart-define-from-file=config/dev.json
```

Upload `build/app/outputs/bundle/release/app-release.aab` in the Play Console. To install
on a phone directly instead, build an APK with `flutter build apk --release` and the same
`--dart-define-from-file`.

## iOS release build (App Store)

The App Store app is published by team `6E2JNTTC36`, *G2C Office, Royal Government of
Bhutan*, which the App Store shows as the seller; the Apple ID gagenghaley123@gmail.com is
a member. Making the app in App Store Connect needs the *Admin* or *App Manager* role in
the team, and signing for the App Store needs a distribution certificate (or access to
cloud-managed ones): the team's Account Holder can give these in App Store Connect →
Users and Access. Xcode signs automatically: sign in with that Apple ID in Xcode →
Settings → Accounts. The app is iPhone only (iPads run the iPhone version). iPad can be
added later, but not removed once released.

Once:

1. Open `ios/Runner.xcworkspace` in Xcode, select *Runner* → *Signing & Capabilities*, and
   check the team is *G2C Office, Royal Government of Bhutan* with no errors. Xcode adds
   Push Notifications and Sign in with Apple to the App ID `bt.gov.kuzuhelp`.
2. **App Store Connect** (appstoreconnect.apple.com): the app is *kuzu help* (Apple ID
   6818068893, SKU `kuzuhelp-ios-001`) with bundle ID `bt.gov.kuzuhelp`. The two must
   match, or Xcode can't find the app and tries to make a new one.
3. Fill in the listing, much as in the Play Console: description, keywords, support URL,
   **Privacy Policy URL** (the hosted `privacy.html`), category, age rating, price (free),
   and **App Privacy** (what's collected: name, email, phone, photos, location, reviews
   and other content, as declared in Play's Data safety). Screenshots: at least one of a
   6.9-inch iPhone (e.g. the iPhone 16 Pro Max simulator).
4. *App Review Information*: reviewers can't receive the email code, so give them an
   account that already has a password (email and password), and say in the notes what
   to try (finding a worker, a sports ground, and that sign-up is by email code).

Each release: raise `version:` in `pubspec.yaml` as for Google Play (the number after `+`
must go up for every upload to App Store Connect too), then:

```
flutter build ipa --release --dart-define-from-file=config/dev.json
```

`flutter build ipa` only builds; it doesn't upload. To upload from the terminal (it signs
in as the Apple ID in Xcode → Settings → Accounts; `ios/UploadOptions.plist` says where to):

```
xcodebuild -exportArchive -archivePath build/ios/archive/Runner.xcarchive -exportOptionsPlist ios/UploadOptions.plist -exportPath build/ios/upload -allowProvisioningUpdates
```

It ends with *Upload succeeded* and *EXPORT SUCCEEDED* (a warning about a missing dSYM for
`objective_c.framework` is harmless). Or upload `build/ios/ipa/*.ipa` with Apple's
*Transporter* app, or open `build/ios/archive/Runner.xcarchive` in Xcode → *Distribute App*
→ *App Store Connect*.
Once it has been processed (up to about 30 minutes), install it from **TestFlight** on your
own iPhone and check it, then on the version's page pick the build → *Add for Review* →
*Submit*. Review usually takes a day or two.

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
| `lib/features/grounds` | Sports grounds: venues, booking a ground, My bookings, venue reviews; the ground manager's home, grounds, bookings and blocked time; subscriptions and billing |
| `lib/features/profile` | D1: settings, edit profile, change password, logout, delete account |
| `lib/features/admin` | Workers awaiting approval, Sports venues, Users, Reports, and the 'Admin check' card (approve, reject, deactivate) |
| `lib/features/notifications` | The bell (unread count) and the Notifications screen |
| `lib/shared` | Models and reusable widgets |
| `supabase/` | `schema.sql` (run once), `updates.sql` (run after it; safe to re-run), and the Edge Functions: delete-account (Settings → Delete account), send-push (push notifications) and create-venue-manager (ground managers' accounts) |
| `scripts/` | `release.sh`: build and upload to both stores in one command; `play_upload.mjs`: its Google Play upload |

Each feature has `screens/` (display only), `providers/` (Riverpod state) and
`data/` (the only files that talk to Supabase).

## Rules for every screen
- Loading indicator while data loads; friendly error with a Retry button.
- All display text lives in `lib/core/strings/app_strings.dart` (Dzongkha later).
- Every upload goes to `<user-id>/filename` via `storage_paths.dart`.
