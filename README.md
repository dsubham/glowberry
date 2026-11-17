# Glowberry Utopia — School app

Admin-first preschool app, built with React + TypeScript, Vite, Capacitor Android and Supabase. The separate preschool marketing website is not changed by this app.

## Included

- Responsive Admin login and dashboard, matching the school's cream, berry, green and yellow posters.
- School-issued username/password sign-in. No public sign-up UI.
- Announcements, daily activity text/photos, and downloadable documents.
- Create, edit, preview, delete, search, drafts and published status.
- School-wide or staff-only visibility. **Class labels are organisational; they do not restrict access by class.**
- Editable About Us, Contact Info and Admin profile; password change.
- Backend-only parent/teacher account provisioning and password reset.
- Private Supabase Storage with expiring signed file URLs, database RLS, and realtime refresh.
- Explicit browser-local demo, separate from authenticated school data. Do not use demo mode for real pupil information.
- Native Android project under `android/`. iOS can be added with Capacitor later.

Parent, Teacher and Guest screen flows are future phases. The backend already defines their roles: parents read published school-wide content, teachers read published school and staff content, guests read only public school details. Only Admin has a workspace in this release.

## Run locally

```sh
npm ci
cp .env.example .env.local
# Set the Supabase URL and public publishable/anon key.
npm run dev
```

The existing local `.env.local` is configured for project `ukcozqyszfektythecgg`. Environment files are excluded from source control. Never put a Supabase secret/service-role key in a `VITE_` variable.

Choose **Explore Admin demo** to review without a configured backend. Demo changes persist in this browser only. Production login requires the setup below.

## Activate Supabase

The configured Glowberry project is `ukcozqyszfektythecgg`. Its schema, private storage, account function and school-issued-only sign-in have been deployed. Initial Admin credentials are provided separately and are never committed. These instructions also document a fresh installation.

1. Open the SQL Editor for project `ukcozqyszfektythecgg`. Run all SQL files in `supabase/migrations/` **once, in filename order**, on a project without the app tables (or use the CLI command below). Review/resolve conflicts if you already have tables with these names. The migration creates roles, profiles, content, media, public school settings, private storage, RLS and realtime publication entries.
2. In Authentication settings, disable **Allow new users to sign up**. The school issues accounts; the Admin Edge Function uses the server-side Admin API. Supabase email/password auth must be enabled. Auth usernames are represented by internal email aliases, e.g. `admin@accounts.glowberryutopia.in`; parents enter just `parent.ananya` in the app. These aliases are not inboxes. Password resets are handled by school Admin rather than email recovery.
3. Bootstrap the first Admin: in Authentication → Users, add a confirmed email user with alias `admin@accounts.glowberryutopia.in` and a strong password you choose. Then use SQL Editor to create its profile (replace the UUID):

```sql
insert into public.profiles (id, username, full_name, role)
values ('REPLACE_WITH_AUTH_USER_UUID', 'admin', 'School Administrator', 'admin');
```

4. Deploy the function using the Supabase CLI (sign in to your own Supabase account when prompted):

```sh
npx supabase login
npx supabase db push --remote=ukcozqyszfektythecgg --yes
npx supabase functions deploy manage-users --remote=ukcozqyszfektythecgg --use-api --yes
npx supabase config diff --remote=ukcozqyszfektythecgg
npx supabase config push --remote=ukcozqyszfektythecgg --yes
```

`supabase/config.toml` disables the legacy gateway JWT check for this function because publishable keys are supported. The function independently validates the caller's JWT using `auth.getUser` and reads their Admin role from the database on every request. It never trusts client-supplied roles for authorisation. The platform supplies `SUPABASE_SERVICE_ROLE_KEY` to the function; never copy it into the frontend. If using another alias domain, set the same `AUTH_DOMAIN` Edge Function secret and `VITE_AUTH_DOMAIN` client setting.

5. Sign in as `admin`. Create parent/teacher accounts in **School accounts**, and share credentials privately. Supabase Auth stores password hashes; this app never writes passwords into school tables.
6. Before real school use, verify in the deployed project: unauthenticated access cannot read posts/files/profiles, parents cannot read drafts/staff posts, teachers cannot write content, and users cannot change roles. Run `npx supabase db query --remote=ukcozqyszfektythecgg --file tests/rls.sql --yes` for transaction-based role and file access tests. All test records roll back.

## Web deployment

```sh
npm run build
```

Deploy `dist/` to a static host (for example Cloudflare Pages, Netlify, Vercel, or GitHub Pages). For Git-based hosts: build command `npm ci && npm run build`, output `dist`, Node 22+. Configure `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_AUTH_DOMAIN` in the host before building. These Vite values are embedded at build time.

The `.openai/hosting.json` manifest belongs to the private Sites review deployment. This is separate from your school production domain. School content edits are fetched from Supabase and do not require rebuilding the website or reinstalling the Android app. Code changes, new native features, and changes to the embedded Supabase connection still require a release. Realtime updates work while the app is open; this version does not send push notifications.

For GitHub Pages under `/glowberry/`, set Vite `base` to `/glowberry/` and adjust root-relative `/brand/` asset URLs first. A root-domain host works without that change.

## Android

```sh
npm run android:sync
npm run android:open
```

The native project is already generated. Install Android Studio, its SDK, and a compatible JDK (Capacitor 7 uses JDK 21). Sync Gradle, test on a device, then create a signed Android App Bundle in Android Studio for Play Console. The application ID is `in.glowberryutopia.school`; confirm it before the first store upload. Use your own release signing key and keep it outside the repository. Build output, keystores and machine-specific SDK paths must not be committed.

The web build and Capacitor sync can be checked without an Android SDK; compiling/signing an APK or AAB requires the Android toolchain. The generated launcher/splash assets must also be replaced with final approved school artwork before release. No store release is included in this scaffold.

For iPhone later: install `@capacitor/ios` matching Capacitor's major version, run `npx cap add ios`, and complete Xcode signing/testing on macOS. Reuse the same app and Supabase backend.

## Checks

```sh
npm test
npm run build
```

Unit tests cover username alias validation, file type/size boundaries and attachment count. `tests/rls.sql` tests real database policies for all four roles and private file access, then rolls back. `scripts/bootstrap-admin.mjs` creates the first Admin (only if absent), saves a generated password to an owner-readable file outside the repository, and smoke-tests sign-in, account creation/reset and authorisation; it removes its temporary test account. Run it locally with an authenticated Supabase CLI:

```sh
node scripts/bootstrap-admin.mjs ukcozqyszfektythecgg /private/tmp/glowberry-admin-credentials.txt
```

The server key is obtained through the local CLI and stays in process memory. Validate native device behavior before release.

## Suggested next phases

1. Parent home with child/class assignments and a class-scoped feed (including stricter database policies).
2. Teacher activity authoring with Admin approval.
3. Guest school information and admission enquiry.
4. Attendance, push notifications and school calendar events.
5. Photo consent controls, audit history, account suspension and forced initial password changes.

File uploads support JPG/PNG/WebP/PDF, 10 MB per file and 8 per post. Files can be added while editing; individual file removal/replacement is a future improvement. Deleting a post removes its stored files first. Upload errors preserve the saved post; reopen it to retry missing files. Uploaded files stay private; signed URLs can remain valid for up to one hour after issue. This single-school foundation does not implement multi-school tenancy or offline pupil-data caching.

## Students and attendance (1.1.0)

The Admin **Students** screen adds and edits student name, private photo, parent/guardian name and phone, grade, admission number, date of birth, admission date and notes. Students can be archived without losing attendance history. Parent names are contact details; parent login accounts are not yet linked to students.

Attendance is saved per student and school date (Asia/Kolkata) as Present, Absent, Late or Excused. Unmarked is separate from Absent. Admins can correct earlier dates and view each student's last 90 recorded days. Future dates and days before admission are rejected. The page offers grade, record-status and search filters. School holidays and bulk marking are future work.

`supabase/migrations/202611170001_students.sql` creates Admin-only tables and a private student-photo bucket. Photos accept JPG, PNG or WebP up to 5 MB. Run `npm test` and `npx supabase db query --remote=ukcozqyszfektythecgg --file tests/students-rls.sql --yes` to check validation, attendance correction and role access. Demo student data stays in the local browser.
