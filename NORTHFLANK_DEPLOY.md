# Deploying RUCHA Backend to Northflank

Northflank requires browser-based OAuth login or an API token that only you can generate.
This guide walks through the full setup. It takes about 5 minutes.

---

## Step 1 — Create a Northflank account

Sign up at https://northflank.com (free tier available).

---

## Step 2 — Get your API token

1. Go to https://app.northflank.com/account/api
2. Click **Create API token**
3. Give it a name (e.g. `rucha-deploy`)
4. Copy the token — you'll need it in Step 4

---

## Step 3 — Install the Northflank CLI

```bash
npm install -g @northflank/cli
# or
npx @northflank/cli --help
```

---

## Step 4 — Login

```bash
# Browser-based (interactive)
northflank login

# OR token-based (non-interactive, for CI)
northflank login -t YOUR_API_TOKEN
```

---

## Step 5 — Create a project

```bash
northflank create project --name rucha
```

---

## Step 6 — Add a PostgreSQL addon

```bash
northflank create addon \
  --name rucha-db \
  --type postgres \
  --version "16" \
  --plan nf-compute-10
```

After creation, get the connection string:
```bash
northflank get addon credentials --addon rucha-db
```

---

## Step 7 — Deploy the backend

The backend has a `Dockerfile` at `backend/Dockerfile`.

### Option A: Deploy from GitHub (recommended)

1. Push this repo to GitHub
2. In Northflank dashboard: **New Service → Deployment → Connect Git**
3. Select your repo, set **Build context** to `backend/`
4. Northflank auto-detects the Dockerfile

### Option B: Deploy via CLI from Dockerfile

```bash
cd backend

northflank create service deployment \
  --name rucha-api \
  --dockerfile ./Dockerfile \
  --port 8081 \
  --env DATABASE_URL="<paste-connection-string-from-step-6>" \
  --env PORT=8081 \
  --env CORS_ORIGIN="*" \
  --env TELEGRAM_BOT_TOKEN="9001526833:AAH2XCQ8mcuAgz_BZFzYsIPmMQZrKe8atXw" \
  --env TELEGRAM_BOT_USERNAME="ruchaabot"
```

---

## Step 8 — Get the public URL

```bash
northflank get service --name rucha-api
```

The URL will look like: `https://rucha-api-<hash>.northflank.app`

---

## Step 9 — Run database migrations

The Go backend runs migrations automatically on startup via `connectPostgres()`.
No manual step needed — just make sure `DATABASE_URL` is set correctly.

Verify:
```bash
curl https://rucha-api-<hash>.northflank.app/api/health
# → {"ok":true,"store":"postgres","time":"..."}
```

---

## Step 10 — Update the mobile app

Change the API URL in `mobile/lib/core/constants.dart`:

```dart
static const String defaultApiUrl = 'https://rucha-api-<hash>.northflank.app/api';
```

Then rebuild:
```bash
cd mobile
flutter build apk --split-per-abi --target-platform android-arm64
```

---

## Keeping the service always-on

Northflank free tier keeps services running (no sleep like Fly.io free tier).
To ensure the database never suspends:

```bash
northflank update addon \
  --name rucha-db \
  --suspended false
```

---

## Environment variables summary

| Variable | Value |
|---|---|
| `DATABASE_URL` | From Northflank addon credentials |
| `PORT` | `8081` |
| `CORS_ORIGIN` | `*` |
| `TELEGRAM_BOT_TOKEN` | Your bot token |
| `TELEGRAM_BOT_USERNAME` | `ruchaabot` |
| `TRUST_PROXY` | `true` |

---

## Current status

Fly.io backend is currently running at:
```
https://rucha-fitness.fly.dev/api/health
→ {"ok":true,"store":"postgres"}
```

Once Northflank is set up, update `defaultApiUrl` in constants.dart and rebuild.

---

## Automated deploy script

```bash
#!/bin/bash
# Run this after: northflank login -t YOUR_TOKEN

set -e

NF_PROJECT="rucha"
NF_SERVICE="rucha-api"
NF_ADDON="rucha-db"

echo "Creating project..."
northflank create project --name "$NF_PROJECT" || true

echo "Creating Postgres addon..."
northflank create addon --name "$NF_ADDON" --type postgres --version 16 || true

echo "Waiting for addon..."
sleep 15

echo "Getting DB credentials..."
DB_URL=$(northflank get addon credentials --addon "$NF_ADDON" --format json | jq -r '.connectionString')

echo "Deploying backend..."
cd backend
northflank create service deployment \
  --name "$NF_SERVICE" \
  --dockerfile ./Dockerfile \
  --port 8081 \
  --env DATABASE_URL="$DB_URL" \
  --env PORT=8081 \
  --env CORS_ORIGIN="*" \
  --env TRUST_PROXY=true

echo "Done! Check:"
northflank get service --name "$NF_SERVICE"
```

Save as `scripts/deploy_northflank.sh` and run:
```bash
chmod +x scripts/deploy_northflank.sh
northflank login -t YOUR_TOKEN
./scripts/deploy_northflank.sh
```
