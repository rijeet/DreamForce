# Dream Force — Google Play, data, and the Android App Bundle

Last updated 21 November 2026. Package `com.dreamforce.dream_force`. This describes the Android app and API as they are in this repository. It is the product’s plain-language policy, not a lawyer’s draft. Dream Force does not publish a support email. Support is Profile after Google sign-in.

The same subjects are also on the landing site as static pages: `/terms`, `/privacy`, and `/account-deletion`. Play Console must use the published site, not `localhost`.

## Terms and conditions

These terms apply when someone installs Dream Force from Google Play or uses a Dream Force account.

- Sign-in is with Google. Dream Force does not collect or store the Google password. A standard account cannot have a password. Admin accounts are separate and are not created from the app.
- The person chooses the activity and the total time. The app splits that time into focus and rest, about five-sixths focus and one-sixth rest. A 30-minute block is 25 minutes of focus and 5 minutes of rest. A phase cannot be skipped or finished early.
- Skipping one planned occurrence does not delete the weekly plan. That activity can return on a later week. Weekdays are numbered with Monday as 1.
- Reminders and the sound at the end of a block depend on the device. Dream Force does not promise delivery at an exact second.
- Android screen time is shown only after the person allows usage access. It is a daily total from the device. Other apps’ screen time is not available on iPhone.
- Country is Bangladesh and the time zone is `Asia/Dhaka`. Both are fixed.
- Sign-out leaves the account in place. Deleting the account follows the account-deletion section below. Deleting Dream Force does not delete the Google account.
- Uninstalling the app removes the copy on that phone. It does not delete the account.

## Data policy

Dream Force is operated from Bangladesh. The policy covers the Android app and the account used with it.

Google sign-in gives Dream Force the name, email address, and Google account id that Google shares for sign-in. The Google password is not received and is not stored.

The account stores the plans, activities, session times, and skips the person creates, and the daily review they write. Review text stays on the account. It is not placed on a notification or the lock screen. A notification may include the activity name only when the device’s own notification privacy setting allows it.

Profile fields the person chooses to add — gender, date of birth, city, and profession — stay on the account. Gender and date of birth are optional.

If the person allows Android usage access and turns on screen-time sync, Dream Force stores that day’s per-app screen-time total for the account. It does not upload a timeline of what was on the screen. Turning sync off deletes those uploaded totals. The consent time is kept as a record that permission was given and later withdrawn. Clearing the app or uninstalling it removes only the phone’s copy.

This information is used to show the plan, run the focus and rest timer, schedule a reminder for a planned local start time, and show insights for day, week, month, and year. Dream Force does not sell it.

A short-lived cache may hold one day’s plan for about 30 seconds so the app can load it faster. Writing a plan, a skip, or a session drops that cache.

## How data is stored and used

The phone talks to `https://dream-force-backend.vercel.app` unless a build overrides `API_BASE_URL`.

| Place | What is kept | How it is used |
| --- | --- | --- |
| Neon PostgreSQL | The account and everything owned by it | The API reads and writes it for the signed-in user only |
| Phone, Android Keystore via secure storage | Access token and refresh token (`dream_force_access_token`, `dream_force_refresh_token`) | Keeps the person signed in. The database stores a hash of the refresh token, not the token itself |
| Phone, SharedPreferences | Whether the notification explanation was already shown (`session_notification_asked`) | Avoids asking again |
| Phone, SharedPreferences `dream_force_plan_reminders` | Reminder ids, activity titles, and planned times | Restores future alarms after reboot |
| Phone, Usage Access | Today’s per-app foreground time, read on the device | Shown in Insights. Uploaded only after screen-time sync is turned on |
| Upstash Redis | One cached plan day, about 30 seconds | Speeds the Today and Plan read. It is not the record of the account |
| Upstash QStash | A delayed job id for a pending deletion | Calls the API when the 30 days end |

Android backup of the app is off (`android:allowBackup="false"`).

Account rows live in PostgreSQL and are removed with the user because those tables use `ON DELETE CASCADE`:

- `users` — email, Google subject, display name, avatar URL, locale, status, and `deletion_due_at` while a deletion is waiting
- `user_profiles` — optional gender, date of birth, city, profession; country Bangladesh; time zone `Asia/Dhaka`
- `user_settings` — theme, notification, sound, and haptics preferences; week start; terms version and time; screen-time consent
- `auth_sessions` — refresh-token hashes
- `activity_templates` — the person’s activities. Built-in activities have no owner and are not deleted with one account
- `weekly_plans`, `weekly_plan_entries`, `plan_occurrences` — the weekly plan, including skips
- `focus_sessions`, `session_phases`, `session_events` — timer state and completed or cancelled time
- `daily_reviews` — mood, reason tags, and the private written review (up to 5,000 characters)
- `user_app_usage_daily` — one row per app per local day: package name, app label, and seconds, never a screen timeline
- `idempotency_records` — a short record of a repeated write so the same request is not applied twice

`users.password_hash` is only for an admin account. A Google user cannot have one.

## Account deletion

Signing out does not delete the account. Uninstalling the app does not delete the account. Deleting Dream Force does not delete the Google account.

In the app:

1. Open Dream Force and sign in with the Google account to remove.
2. Open Profile.
3. Choose **Delete account**.
4. Read the confirmation and choose **Start 30-day timer**.
5. Profile shows a countdown, such as `30d 00:00:00`. **Keep account** stops it and returns the account to active.
6. When the countdown reaches zero, the API deletes the `users` row. The owned rows above go with it. The next sign-in with the same Google account creates a new Dream Force account.

The same thing happens if the app is closed. The deadline is `deletion_due_at` on `users`, set to 30 days from the confirmation (`DELETE /v1/me`, response 202). QStash is asked to call `POST /v1/jobs/account-deletions` at that time. If that schedule does not run, the next sign-in, token refresh, or profile load after the deadline still deletes the row.

Before the deadline, `POST /v1/me/deletion/cancel` clears the schedule.

What is removed: the Google-shared name, email, and account id; plans, activities, sessions, and skips; daily reviews; optional profile fields; Android screen-time totals stored for the account; session tokens.

What is kept: the Google account at Google; built-in activity templates; a copy that can remain in a database backup until that backup expires. There is no separate published number of days for that backup copy. Dream Force does not store the Google password.

If the app is not on the phone, install it again, sign in with the same Google account, and use Profile.

The phone calls the deployed API. The database column is already applied. The delete button on a phone still needs the API deployment that contains `DELETE /v1/me`.

## How to create the `.aab` file

Google Play wants an Android App Bundle (`.aab`), not an APK. Create an upload key once, then build.

### 1. Create the upload key

Run this from PowerShell. Replace the alias if you want a different name. Keep the file and the passwords. Losing them blocks later updates unless Play App Signing can reset the upload key.

```powershell
keytool -genkey -v -keystore "$env:USERPROFILE\dream-force-upload.jks" -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Do not commit the `.jks` file or the passwords. `apps/mobile/android/.gitignore` already ignores `key.properties` and `*.keystore`. A `.jks` file outside the repo is safer.

### 2. Point Gradle at the key

Create `apps/mobile/android/key.properties` (this file stays untracked):

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=C:\\Users\\YOUR_USER\\dream-force-upload.jks
```

In `apps/mobile/android/app/build.gradle.kts`, load that file and use it for the release signing config. The Flutter Android signing setup is the one documented at `https://docs.flutter.dev/deployment/android`. `signingReport` for the release variant should show the upload certificate.

Register the upload certificate SHA-1, and later the Play App Signing SHA-1, on the Android OAuth client. The package name stays `com.dreamforce.dream_force`. The command is in `Plan/Google OAuth and Vercel Setup.md`.

### 3. Set the version

`apps/mobile/pubspec.yaml` currently says `version: 1.0.0+1`. That is version name `1.0.0` and version code `1`. Play requires a higher version code for every upload. Before the next bundle, raise the number after `+`.

### 4. Build the bundle

From PowerShell:

```powershell
Set-Location "D:\Mobile Apps\Dream Force\apps\mobile"
flutter build appbundle --release
```

The file is written to:

```text
apps/mobile/build/app/outputs/bundle/release/app-release.aab
```

Upload that file in Play Console under the production or testing track. Play App Signing then re-signs it for devices. The first upload enrolls Play App Signing; keep the upload key for every later release.
