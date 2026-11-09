

CREATE TABLE IF NOT EXISTS activities (
  id          TEXT PRIMARY KEY,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  owner_id    TEXT NOT NULL DEFAULT '',
  visibility  TEXT NOT NULL DEFAULT 'private',
  start_lat   DOUBLE PRECISION NOT NULL DEFAULT 0,
  start_lng   DOUBLE PRECISION NOT NULL DEFAULT 0,
  source      TEXT NOT NULL DEFAULT 'gps',
  payload     JSONB NOT NULL,
  payload_gz    BYTEA,
  payload_bytes INTEGER NOT NULL DEFAULT 0
);
ALTER TABLE activities ADD COLUMN IF NOT EXISTS payload_bytes INTEGER NOT NULL DEFAULT 0;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS owner_id TEXT NOT NULL DEFAULT '';
ALTER TABLE activities ADD COLUMN IF NOT EXISTS visibility TEXT NOT NULL DEFAULT 'private';
ALTER TABLE activities ADD COLUMN IF NOT EXISTS payload_gz BYTEA;
CREATE INDEX IF NOT EXISTS idx_activities_start ON activities (start_lat, start_lng);
CREATE INDEX IF NOT EXISTS idx_activities_created ON activities (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activities_owner ON activities (owner_id);

CREATE TABLE IF NOT EXISTS gallery_cards (
  id          TEXT PRIMARY KEY,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  owner_id    TEXT NOT NULL DEFAULT '',
  visibility  TEXT NOT NULL DEFAULT 'private',
  payload     JSONB NOT NULL,
  payload_gz    BYTEA,
  payload_bytes INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS challenges (
  id            TEXT PRIMARY KEY,
  kind          TEXT NOT NULL,
  owner_id      TEXT NOT NULL DEFAULT '',
  visibility    TEXT NOT NULL DEFAULT 'everyone',
  mode          TEXT NOT NULL DEFAULT 'open',
  opponent_id   TEXT NOT NULL DEFAULT '',
  invite_status TEXT NOT NULL DEFAULT '',
  start_lat     DOUBLE PRECISION,
  start_lng     DOUBLE PRECISION,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  payload       JSONB NOT NULL,
  payload_gz    BYTEA,
  payload_bytes INTEGER NOT NULL DEFAULT 0
);
ALTER TABLE challenges ADD COLUMN IF NOT EXISTS payload_bytes INTEGER NOT NULL DEFAULT 0;
CREATE INDEX IF NOT EXISTS idx_challenges_owner ON challenges (owner_id);

CREATE TABLE IF NOT EXISTS challenge_members (
  challenge_id TEXT NOT NULL,
  athlete_id   TEXT NOT NULL,
  athlete_name TEXT NOT NULL DEFAULT '',
  joined_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (challenge_id, athlete_id)
);

CREATE TABLE IF NOT EXISTS challenge_progress (
  challenge_id TEXT NOT NULL,
  athlete_id   TEXT NOT NULL,
  athlete_name TEXT NOT NULL DEFAULT '',
  distance_km  DOUBLE PRECISION NOT NULL DEFAULT 0,
  duration_sec INTEGER NOT NULL DEFAULT 0,
  elevation_m  INTEGER NOT NULL DEFAULT 0,
  completed    BOOLEAN NOT NULL DEFAULT false,
  best_seconds INTEGER NOT NULL DEFAULT 0,
  attempts     INTEGER NOT NULL DEFAULT 0,
  finished_at  TIMESTAMPTZ,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (challenge_id, athlete_id)
);
CREATE INDEX IF NOT EXISTS idx_progress_challenge ON challenge_progress (challenge_id);

CREATE TABLE IF NOT EXISTS places   (name TEXT PRIMARY KEY, payload JSONB NOT NULL);
CREATE TABLE IF NOT EXISTS segments (
  id          TEXT PRIMARY KEY,
  owner_id    TEXT NOT NULL DEFAULT '',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  payload     JSONB NOT NULL
);
ALTER TABLE segments ADD COLUMN IF NOT EXISTS owner_id TEXT NOT NULL DEFAULT '';
ALTER TABLE segments ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
CREATE INDEX IF NOT EXISTS idx_segments_owner ON segments (owner_id);

CREATE TABLE IF NOT EXISTS clubs (
  id          TEXT PRIMARY KEY,
  owner_id    TEXT NOT NULL DEFAULT '',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  payload     JSONB NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_clubs_owner ON clubs (owner_id);
CREATE TABLE IF NOT EXISTS club_members (
  club_id      TEXT NOT NULL,
  athlete_id   TEXT NOT NULL,
  athlete_name TEXT NOT NULL DEFAULT '',
  joined_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (club_id, athlete_id)
);

CREATE TABLE IF NOT EXISTS users (
  id          TEXT PRIMARY KEY,
  username    TEXT NOT NULL UNIQUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  payload     JSONB NOT NULL
);
CREATE TABLE IF NOT EXISTS sessions (
  token       TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at  TIMESTAMPTZ NOT NULL
);
CREATE TABLE IF NOT EXISTS friendships (
  id           TEXT PRIMARY KEY,
  requester_id TEXT NOT NULL,
  addressee_id TEXT NOT NULL,
  status       TEXT NOT NULL DEFAULT 'pending',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  payload      JSONB NOT NULL,
  UNIQUE (requester_id, addressee_id)
);
CREATE INDEX IF NOT EXISTS idx_friendships_addressee ON friendships (addressee_id);
CREATE TABLE IF NOT EXISTS shares (
  id             TEXT PRIMARY KEY,
  owner_id       TEXT NOT NULL,
  activity_id    TEXT NOT NULL,
  shared_with_id TEXT NOT NULL DEFAULT '',
  is_public      BOOLEAN NOT NULL DEFAULT false,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  payload        JSONB NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_shares_activity ON shares (activity_id);

CREATE OR REPLACE VIEW popular_areas AS
SELECT round(start_lat::numeric, 3)::float8 AS lat,
       round(start_lng::numeric, 3)::float8 AS lng,
       count(*)::int AS run_count
FROM activities
GROUP BY 1, 2
ORDER BY 3 DESC;
