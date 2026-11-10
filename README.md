# RUCHA

GPS run and ride tracking built for Ethiopia. Record activities, climb local
segments, join challenges, and train with friends.

RUCHA runs as a static frontend with optional sync to a Go + PostgreSQL
backend. Without the backend it stores everything locally in the browser, so
the app works offline.

## Features

- **Activity recording** — GPS runs and rides with live distance, pace, speed,
  elevation and heart-rate readouts.
- **Maps and segments** — route drawing, user-created segments and local
  segment leaderboards, plus point-to-point, distance/time-trial and vertical
  challenges.
- **Training goals** — weekly distance goals, streaks, challenge progress and a
  hall of fame built from real segment records.
- **Community** — feed, kudos, comments, follows, user-created clubs and
  notifications.
- **Sensors** — Web Bluetooth heart-rate straps and smartwatch broadcasts, plus
  device motion/temperature sensors where supported.
- **Accounts** — Telegram (featured), Google and Apple sign-in through the
  backend, plus a local username/password mode. Every account chooses a unique,
  case-insensitive username and a password once.
- **Consent and legal** — an in-app privacy notice, versioned privacy/terms
  acceptance, and Help, Privacy and Terms pages.
- **First-run guide** — a dismissible Quick Start on the dashboard and a full
  guide covering recording, segments, challenges, run cards, accounts and
  offline use.
- **Responsive UI** — light/dark themes and a mobile-friendly layout.

## Project layout

```
index.html          App shell
styles.css          Design system and layout
legal.css           Shared styling for Help, Privacy and Terms pages
help.html           How RUCHA works
privacy.html        Privacy Policy
terms.html          Terms of Use
data.js             Reference data, map helpers and translations
app.js              UI, GPS recording, maps, social features
auth.js             Client-side auth (API mode and offline mode)
api.js              Backend API client
sensors.js          GPS, Bluetooth and device sensors
api/health          Static health probe used by the frontend

backend/
  main.go           HTTP server and routes
  auth.go           Accounts, consent, password auth and sessions
  social_auth.go    Telegram and Google sign-in
  apple_auth.go     Apple ID token verification
  challenges.go     Challenges, goals and social feed
  store.go          Data access layer
  pg.go             PostgreSQL helpers
  migrations/       Database schema
  docker-compose.yml
  Dockerfile
  .env.example      Configuration template
```

## Run the frontend

Open `index.html` directly in a browser for offline mode, or serve the folder:

```sh
python3 -m http.server 8080
```

## Run the backend

```sh
./start.sh
```

This starts PostgreSQL and the Go API with Docker Compose. The app is then
served at <http://localhost:8081>.

For local development without Docker:

```sh
cd backend
cp .env.example .env     # fill in the values you need
go run .
```

## Configuration

Copy `backend/.env.example` to `backend/.env` and set:

| Variable | Purpose |
| --- | --- |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token from [@BotFather](https://t.me/BotFather). Telegram is the featured sign-in method. |
| `TELEGRAM_BOT_USERNAME` | Optional; detected from the token |
| `GOOGLE_CLIENT_ID` | Web OAuth client ID from Google Cloud console |
| `APPLE_CLIENT_ID` | Apple Services ID for web sign-in. Apple also needs an HTTPS domain, domain verification and a Services ID configured in the Apple Developer portal. |
| `POSTGRES_PASSWORD` | Database password |
| `CORS_ORIGIN` | Allowed frontend origin |

Telegram sends the six-digit sign-in code in the bot chat. For Google, add the
site under **Authorized JavaScript origins**. For Apple, configure the Services
ID for the web, verify the domain, and serve RUCHA over HTTPS.

## Accounts and consent

RUCHA uses one account per person:

- **Username** — 3–20 characters, lowercase letters, numbers and underscores.
  It is unique and case-insensitive, so `Selam_Runs` and `selam_runs` are the
  same name.
- **Password** — at least 8 characters. Stored as a bcrypt hash.
- **Social sign-in** — Telegram, Google and Apple verify the person first. A new
  social account is created as *incomplete* and cannot use data endpoints until
  the person chooses a RUCHA username and password. Existing accounts return to
  the same RUCHA account on later sign-ins.
- **Consent** — registration, profile completion and consent renewal require
  accepting the current Privacy Policy and Terms of Use. The version and
  timestamp are stored with the account. The current versions live in
  `backend/auth.go` (`privacyVersion`, `termsVersion`) and are returned by
  `/api/auth/config`.
- **Anonymous use** — “Use without an account” stores activities and gallery
  cards in the browser. Creating an account afterwards offers to claim that
  local data.
- **Legal pages** — `help.html`, `privacy.html` and `terms.html` are static and
  work without the backend.

## Checks

```sh
cd backend
go test ./...
go vet ./...
go build ./...

cd ..
node --check app.js && node --check auth.js && node --check api.js
```

## Notes

- Geolocation and Bluetooth require HTTPS (or `localhost`).
- Apple web sign-in only works on an HTTPS site with a verified domain. The
  Apple button is hidden until `APPLE_CLIENT_ID` is configured, and disabled on
  plain HTTP pages.
- Heart-rate broadcast works with standard BLE straps and watches that expose
  the Heart Rate service (e.g. Garmin Broadcast Heart Rate). Apple Watch needs
  a third-party broadcast app.
- Web Bluetooth is supported in Chrome and Edge, not Safari on iPhone.
- The map falls back to an offline drawing when OpenStreetMap tiles cannot
  load. GPS recording continues without a network connection.
