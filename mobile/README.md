# RUCHA Flutter app

The native RUCHA client. It mirrors the PWA's eight main views:

1. Dashboard
2. Explore
3. Record
4. Activities
5. Gallery
6. Segments
7. Community (feed, athletes, clubs, challenges)
8. Profile

Every club opens as a Telegram-style **Channel** for join notices, challenge
announcements and shared training updates, plus a **Group** for member chat.
Community posts and notifications are cached on the device for offline reading;
members can share activities, milestones, journeys and segments from the
channel screen. Joining a club creates an in-app notification.

## Challenge time trials

A challenge card opens its own time-trial runner; it never redirects to the
Record tab. Pick 1 km, 5 km, 10 km or a custom distance, and the real GPS clock
stops automatically at the target. Best times are stored per challenge and
distance, shown on the challenge card, and every attempt is also saved as a
normal activity. Leaving mid-trial always stops the GPS session.

Route maps fit the complete recorded track, so long runs and rides are never
cut off at a fixed distance. Fit-route and recenter controls remain available
after panning or zooming.

## Run

```sh
flutter pub get
flutter run
```

Quality checks:

```sh
flutter analyze
flutter test
```

## Accounts and storage

The app is usable without a backend:

- **Create account** saves a local account on the device. Passwords are stored
  as a random-salt SHA-256 hash, never in plain text.
- **Sign in** checks the local account first. If the configured backend is
  online, it also tries the server account.
- **Continue without an account** enables guest mode.
- Activities, gallery cards, segments and challenges are persisted with
  `SharedPreferences` and are never discarded because a network call failed.

Local account and activity data are device-global, not per-account. Signing out
does not delete recorded activities.

## Connect a backend

Open **Server settings** from the auth screen, Profile, or the navigation
drawer.

| Target | API URL |
| --- | --- |
| Android emulator | `http://10.0.2.2:8081/api` |
| Desktop / iOS simulator | `http://localhost:8081/api` |
| Production | your HTTPS Go backend URL ending in `/api` |

The default is `https://ruchaa.ethiodeploy.app/api`. If a host serves only the
static PWA, `/api/auth/config` returns an nginx 404 page. The app detects that,
shows a clear message, and keeps working locally.

Telegram sign-in requires:

1. A reachable RUCHA Go backend.
2. `TELEGRAM_BOT_TOKEN` configured on that backend.
3. The server's `/api/auth/config` response reporting Telegram as enabled.

When those conditions are not met, Telegram is hidden and local account/guest
mode remains available. There is no fake `123456` fallback.

Native Google and Apple sign-in are not implemented in this build. Adding them
requires the `google_sign_in` / `sign_in_with_apple` packages, platform
configuration, and client IDs.

## Bundled PWA

`assets/www/` contains a copy of the PWA used by the optional in-app web view.
It is not the primary UI. The native screens are under `lib/screens/`.
