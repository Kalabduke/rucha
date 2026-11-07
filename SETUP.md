# RUCHA setup

## Run
    ./start.sh          # Postgres + Go API on http://localhost:8081

GPS and Bluetooth only work on https (or localhost). Put the site behind https before using a phone.

## Sign-in
Copy backend/.env.example to backend/.env.

Telegram: create a bot with @BotFather, set TELEGRAM_BOT_TOKEN. The bot sends the 6 digit code in the chat.
Google: create a Web OAuth client, set GOOGLE_CLIENT_ID, add your site under Authorized JavaScript origins.

## Smartwatches
Web Bluetooth reads standard heart-rate broadcast. Garmin: Broadcast Heart Rate. Apple Watch needs a
broadcast app. Works in Chrome/Edge on Android and desktop, not Safari on iPhone.
