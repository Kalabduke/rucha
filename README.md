# RUCHA

GPS run and ride tracking built for Ethiopia. Record activities, climb local
segments, join challenges, and train with friends.

RUCHA runs as a static frontend with optional sync to a Go + PostgreSQL
backend. Without the backend it stores everything locally in the browser, so
the app works offline.

## Features

- **Activity recording** — GPS runs and rides with live distance, pace, speed,
  elevation and heart-rate readouts.
- **Maps and segments** — route drawing, local segment leaderboards, and
  point-to-point, distance/time-trial and vertical challenges.
- **Training goals** — weekly distance goals, streaks, challenge progress and a
  hall of fame.
- **Community** — feed, kudos, comments, follows, clubs and notifications.
- **Sensors** — Web Bluetooth heart-rate straps and smartwatch broadcasts, plus
  device motion/temperature sensors where supported.
- **Accounts** — local username/password sign-in out of the box, with optional
  Telegram and Google sign-in through the backend.
- **Responsive UI** — light/dark themes and a mobile-friendly layout.

## Project layout

```
index.html          App shell
styles.css          Design system and layout
data.js             Demo data, routes, challenges, translations
app.js              UI, GPS recording, maps, social features
auth.js             Client-side auth (API mode and offline mode)
api.js              Backend API client
sensors.js          GPS, Bluetooth and device sensors
api/health          Static health probe used by the frontend

backend/
  main.go           HTTP server and routes
  auth.go           Password auth and sessions
  social_auth.go    Telegram and Google sign-in
  challenges.go     Challenges, segments, goals, social feed
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
| `TELEGRAM_BOT_TOKEN` | Telegram bot token from [@BotFather](https://t.me/BotFather) |
| `TELEGRAM_BOT_USERNAME` | Optional; detected from the token |
| `GOOGLE_CLIENT_ID` | Web OAuth client ID from Google Cloud console |
| `POSTGRES_PASSWORD` | Database password |
| `CORS_ORIGIN` | Allowed frontend origin |

Telegram sends the six-digit sign-in code in the bot chat. For Google, add the
site under **Authorized JavaScript origins**.

## Notes

- Geolocation and Bluetooth require HTTPS (or `localhost`).
- Heart-rate broadcast works with standard BLE straps and watches that expose
  the Heart Rate service (e.g. Garmin Broadcast Heart Rate). Apple Watch needs
  a third-party broadcast app.
- Web Bluetooth is supported in Chrome and Edge, not Safari on iPhone.
