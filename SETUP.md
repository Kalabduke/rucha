# RUCHA setup

## Run
    ./start.sh          # Postgres + Go API on http://localhost:8081

GPS and Bluetooth only work on https (or localhost). Put the site behind https before using a phone.

## Flutter app
    cd mobile
    flutter pub get
    flutter run

The Flutter app is local-first: create a device account or continue as a guest, and every
activity is saved locally before sync. Open Server settings in the app to choose the API URL.
Use `http://10.0.2.2:8081/api` from the Android emulator and
`http://localhost:8081/api` on desktop. If `/api/auth/config` returns 404, the URL points at
the static site rather than the Go backend. Telegram only appears when the backend is online
and TELEGRAM_BOT_TOKEN is configured. Native Google/Apple sign-in is not included yet.

## Sign-in
Copy backend/.env.example to backend/.env.

Telegram: create a bot with @BotFather, set TELEGRAM_BOT_TOKEN. The bot sends the 6 digit code in the chat.
Use a bot created specifically for RUCHA; never reuse credentials from another project (such as the rental-ethiopia bot).
Google: create a Web OAuth client, set GOOGLE_CLIENT_ID, add your site under Authorized JavaScript origins.

## Smartwatches
Web Bluetooth reads standard heart-rate broadcast. Garmin: Broadcast Heart Rate. Apple Watch needs a
broadcast app. Works in Chrome/Edge on Android and desktop, not Safari on iPhone.
