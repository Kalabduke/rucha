#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

echo "──────────────────────────────────────────────"
echo "  RUCHA backend"
echo "  API + Postgres on http://localhost:8081"
echo "──────────────────────────────────────────────"
echo ""
echo "Sign-in methods: username/password (always on)"
echo "                 Telegram (set TELEGRAM_BOT_TOKEN in backend/.env)"
echo ""
echo "Setup:"
echo "  cp backend/.env.example backend/.env"
echo "  # then fill in TELEGRAM_BOT_TOKEN and POSTGRES_PASSWORD"
echo ""

if [ ! -f backend/.env ]; then
  echo "WARNING: backend/.env not found."
  echo "         Copying .env.example → .env  (Telegram will be off until you add a token)"
  cp backend/.env.example backend/.env
fi

docker compose -f backend/docker-compose.yml up --build
