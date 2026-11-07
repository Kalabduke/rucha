#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
echo "RUCHA: starting Postgres + Go API on http://localhost:8081/"
echo "Offline mode: open index.html directly in a browser."
echo "Sign-in: copy backend/.env.example to backend/.env and set TELEGRAM_BOT_TOKEN and GOOGLE_CLIENT_ID."
docker compose -f backend/docker-compose.yml up --build
