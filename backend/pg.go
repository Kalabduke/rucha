package main

import (
	"bytes"
	"compress/gzip"
	"database/sql"
	"encoding/json"
	"io"
	"log"
	"sort"
	"time"

	_ "github.com/lib/pq"
)

const schemaSQL = `
CREATE TABLE IF NOT EXISTS activities (
  id          TEXT PRIMARY KEY,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  owner_id    TEXT NOT NULL DEFAULT '',
  visibility  TEXT NOT NULL DEFAULT 'private',
  start_lat   DOUBLE PRECISION NOT NULL DEFAULT 0,
  start_lng   DOUBLE PRECISION NOT NULL DEFAULT 0,
  source      TEXT NOT NULL DEFAULT 'demo',
  payload       JSONB NOT NULL,
  payload_gz    BYTEA,
  payload_bytes INTEGER NOT NULL DEFAULT 0
);
ALTER TABLE activities ADD COLUMN IF NOT EXISTS payload_bytes INTEGER NOT NULL DEFAULT 0;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS owner_id TEXT NOT NULL DEFAULT '';
ALTER TABLE activities ADD COLUMN IF NOT EXISTS visibility TEXT NOT NULL DEFAULT 'private';
ALTER TABLE activities ADD COLUMN IF NOT EXISTS payload_gz BYTEA;
CREATE INDEX IF NOT EXISTS idx_activities_start ON activities (start_lat, start_lng);
CREATE INDEX IF NOT EXISTS idx_activities_owner ON activities (owner_id);

CREATE TABLE IF NOT EXISTS gallery_cards (
  id          TEXT PRIMARY KEY,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  owner_id    TEXT NOT NULL DEFAULT '',
  visibility  TEXT NOT NULL DEFAULT 'private',
  payload       JSONB NOT NULL,
  payload_gz    BYTEA,
  payload_bytes INTEGER NOT NULL DEFAULT 0
);
ALTER TABLE gallery_cards ADD COLUMN IF NOT EXISTS payload_bytes INTEGER NOT NULL DEFAULT 0;
ALTER TABLE gallery_cards ADD COLUMN IF NOT EXISTS owner_id TEXT NOT NULL DEFAULT '';
ALTER TABLE gallery_cards ADD COLUMN IF NOT EXISTS visibility TEXT NOT NULL DEFAULT 'private';
ALTER TABLE gallery_cards ADD COLUMN IF NOT EXISTS payload_gz BYTEA;

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
ALTER TABLE challenges ADD COLUMN IF NOT EXISTS owner_id TEXT NOT NULL DEFAULT '';
ALTER TABLE challenges ADD COLUMN IF NOT EXISTS visibility TEXT NOT NULL DEFAULT 'everyone';
ALTER TABLE challenges ADD COLUMN IF NOT EXISTS mode TEXT NOT NULL DEFAULT 'open';
ALTER TABLE challenges ADD COLUMN IF NOT EXISTS opponent_id TEXT NOT NULL DEFAULT '';
ALTER TABLE challenges ADD COLUMN IF NOT EXISTS invite_status TEXT NOT NULL DEFAULT '';
ALTER TABLE challenges ADD COLUMN IF NOT EXISTS payload_gz BYTEA;
CREATE INDEX IF NOT EXISTS idx_challenges_owner ON challenges (owner_id);

CREATE TABLE IF NOT EXISTS challenge_members (
  challenge_id TEXT NOT NULL,
  athlete_id   TEXT NOT NULL,
  athlete_name TEXT NOT NULL DEFAULT '',
  joined_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (challenge_id, athlete_id)
);
ALTER TABLE challenge_members ADD COLUMN IF NOT EXISTS athlete_name TEXT NOT NULL DEFAULT '';

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
CREATE TABLE IF NOT EXISTS segments (id   TEXT PRIMARY KEY, payload JSONB NOT NULL);
`

type PgStore struct{ db *sql.DB }

func NewPgStore(url string) (*PgStore, error) {
	db, err := sql.Open("postgres", url)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(8)
	db.SetMaxIdleConns(4)
	if err = db.Ping(); err != nil {
		db.Close()
		return nil, err
	}
	if _, err = db.Exec(schemaSQL); err != nil {
		db.Close()
		return nil, err
	}
	p := &PgStore{db: db}
	if err = p.seedIfEmpty(); err != nil {
		db.Close()
		return nil, err
	}
	if err = p.backfillSizes(); err != nil {
		log.Printf("payload size backfill skipped: %v", err)
	}
	return p, nil
}

func (p *PgStore) Kind() string { return "postgres" }

func parseTime(s string) time.Time {
	if t, err := time.Parse(time.RFC3339, s); err == nil {
		return t
	}
	return time.Now().UTC()
}

func nullableTime(s string) interface{} {
	if s == "" {
		return nil
	}
	return parseTime(s)
}

func (p *PgStore) seedIfEmpty() error {
	var n int
	if err := p.db.QueryRow(`SELECT count(*) FROM places`).Scan(&n); err != nil {
		return err
	}
	if n == 0 {
		for _, pl := range seedPlaces() {
			raw, err := json.Marshal(pl)
			if err != nil {
				return err
			}
			if _, err := p.db.Exec(`INSERT INTO places (name,payload) VALUES ($1,$2::jsonb) ON CONFLICT DO NOTHING`, pl.Name, string(raw)); err != nil {
				return err
			}
		}
	}
	if err := p.db.QueryRow(`SELECT count(*) FROM segments`).Scan(&n); err != nil {
		return err
	}
	if n == 0 {
		for _, sg := range seedSegments() {
			raw, err := json.Marshal(sg)
			if err != nil {
				return err
			}
			if _, err := p.db.Exec(`INSERT INTO segments (id,payload) VALUES ($1,$2::jsonb) ON CONFLICT DO NOTHING`, sg.ID, string(raw)); err != nil {
				return err
			}
		}
	}
	if err := p.db.QueryRow(`SELECT count(*) FROM activities`).Scan(&n); err != nil {
		return err
	}
	if n == 0 {
		for _, a := range seedActivities() {
			if err := p.AddActivity(a); err != nil {
				return err
			}
		}
	}
	if err := p.db.QueryRow(`SELECT count(*) FROM challenges`).Scan(&n); err != nil {
		return err
	}
	if n == 0 {
		for _, c := range seedChallenges() {
			if err := p.AddChallenge(c); err != nil {
				return err
			}
		}
	}
	return nil
}

func scanRows(rows *sql.Rows, dest func(raw, gz []byte) error) error {
	defer rows.Close()
	for rows.Next() {
		var raw, gz []byte
		if err := rows.Scan(&raw, &gz); err != nil {
			return err
		}
		if err := dest(raw, gz); err != nil {
			return err
		}
	}
	return rows.Err()
}

func (p *PgStore) Activities() ([]Activity, error) {
	rows, err := p.db.Query(`SELECT payload, payload_gz FROM activities ORDER BY created_at DESC LIMIT 300`)
	if err != nil {
		return nil, err
	}
	out := []Activity{}
	err = scanRows(rows, func(raw, gz []byte) error {
		var a Activity
		if err := unpackPayload(raw, gz, &a); err != nil {
			return err
		}
		out = append(out, a)
		return nil
	})
	return out, err
}

func (p *PgStore) AddActivity(a Activity) error {
	index, gz, n, err := packPayload(a)
	if err != nil {
		return err
	}
	_, err = p.db.Exec(`
INSERT INTO activities (id,created_at,owner_id,visibility,start_lat,start_lng,source,payload,payload_gz,payload_bytes)
VALUES ($1,$2,$3,$4,$5,$6,$7,$8::jsonb,$9,$10)
ON CONFLICT (id) DO UPDATE SET
  created_at=EXCLUDED.created_at, owner_id=EXCLUDED.owner_id,
  visibility=EXCLUDED.visibility, start_lat=EXCLUDED.start_lat,
  start_lng=EXCLUDED.start_lng, source=EXCLUDED.source,
  payload=EXCLUDED.payload, payload_gz=EXCLUDED.payload_gz,
  payload_bytes=EXCLUDED.payload_bytes`,
		a.ID, parseTime(a.CreatedAt), a.OwnerID, a.Visibility, a.StartLat, a.StartLng,
		a.Source, string(index), gz, n)
	return err
}

func (p *PgStore) Gallery() ([]GalleryCard, error) {
	rows, err := p.db.Query(`SELECT payload, payload_gz FROM gallery_cards ORDER BY created_at DESC LIMIT 200`)
	if err != nil {
		return nil, err
	}
	out := []GalleryCard{}
	err = scanRows(rows, func(raw, gz []byte) error {
		var g GalleryCard
		if err := unpackPayload(raw, gz, &g); err != nil {
			return err
		}
		out = append(out, g)
		return nil
	})
	return out, err
}

func (p *PgStore) AddGallery(g GalleryCard) error {
	index, gz, n, err := packPayload(g)
	if err != nil {
		return err
	}
	_, err = p.db.Exec(`
INSERT INTO gallery_cards (id,created_at,owner_id,visibility,payload,payload_gz,payload_bytes)
VALUES ($1,$2,$3,$4,$5::jsonb,$6,$7)
ON CONFLICT (id) DO UPDATE SET owner_id=EXCLUDED.owner_id,
  visibility=EXCLUDED.visibility, payload=EXCLUDED.payload,
  payload_gz=EXCLUDED.payload_gz, payload_bytes=EXCLUDED.payload_bytes`,
		g.ID, parseTime(g.CreatedAt), g.OwnerID, g.Visibility, string(index), gz, n)
	return err
}

func (p *PgStore) DeleteGallery(id string) error {
	_, err := p.db.Exec(`DELETE FROM gallery_cards WHERE id=$1`, id)
	return err
}

func (p *PgStore) Challenges() ([]Challenge, error) {
	rows, err := p.db.Query(`SELECT payload, payload_gz FROM challenges ORDER BY created_at DESC LIMIT 200`)
	if err != nil {
		return nil, err
	}
	out := []Challenge{}
	err = scanRows(rows, func(raw, gz []byte) error {
		var c Challenge
		if err := unpackPayload(raw, gz, &c); err != nil {
			return err
		}
		out = append(out, c)
		return nil
	})
	return out, err
}

func (p *PgStore) ChallengeByID(id string) (Challenge, error) {
	var raw, gz []byte
	if err := p.db.QueryRow(`SELECT payload, payload_gz FROM challenges WHERE id=$1`, id).Scan(&raw, &gz); err != nil {
		if err == sql.ErrNoRows {
			return Challenge{}, errNoChallenge
		}
		return Challenge{}, err
	}
	var c Challenge
	if err := unpackPayload(raw, gz, &c); err != nil {
		return Challenge{}, err
	}
	return c, nil
}

func (p *PgStore) AddChallenge(c Challenge) error {
	return p.writeChallenge(c, true)
}

func (p *PgStore) UpdateChallenge(c Challenge) error {
	return p.writeChallenge(c, false)
}

func (p *PgStore) writeChallenge(c Challenge, insert bool) error {
	index, gz, n, err := packPayload(c)
	if err != nil {
		return err
	}
	var la, ln interface{}
	if c.StartLat != nil {
		la = *c.StartLat
	}
	if c.StartLng != nil {
		ln = *c.StartLng
	}
	if !insert {
		_, err = p.db.Exec(`
UPDATE challenges SET kind=$2, owner_id=$3, visibility=$4, mode=$5,
  opponent_id=$6, invite_status=$7, start_lat=$8, start_lng=$9,
  payload=$10::jsonb, payload_gz=$11, payload_bytes=$12 WHERE id=$1`,
			c.ID, c.Kind, c.OwnerID, c.Visibility, c.Mode, c.OpponentID,
			c.InviteStatus, la, ln, string(index), gz, n)
		return err
	}
	_, err = p.db.Exec(`
INSERT INTO challenges (id,kind,owner_id,visibility,mode,opponent_id,invite_status,start_lat,start_lng,created_at,payload,payload_gz,payload_bytes)
VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11::jsonb,$12,$13)
ON CONFLICT (id) DO UPDATE SET kind=EXCLUDED.kind,
  owner_id=EXCLUDED.owner_id, visibility=EXCLUDED.visibility,
  mode=EXCLUDED.mode, opponent_id=EXCLUDED.opponent_id,
  invite_status=EXCLUDED.invite_status, payload=EXCLUDED.payload,
  payload_gz=EXCLUDED.payload_gz, payload_bytes=EXCLUDED.payload_bytes`,
		c.ID, c.Kind, c.OwnerID, c.Visibility, c.Mode,
		c.OpponentID, c.InviteStatus, la, ln, parseTime(c.CreatedAt), string(index), gz, n)
	return err
}

func (p *PgStore) JoinChallenge(id, athlete, athleteName string) error {
	if athlete == "" {
		athlete = "me"
	}
	if athleteName == "" {
		athleteName = "You"
	}
	res, err := p.db.Exec(`INSERT INTO challenge_members (challenge_id,athlete_id,athlete_name) VALUES ($1,$2,$3) ON CONFLICT DO NOTHING`, id, athlete, athleteName)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return nil
	}
	c, err := p.ChallengeByID(id)
	if err != nil {
		return nil
	}
	c.Members++
	return p.UpdateChallenge(c)
}

func (p *PgStore) ChallengeMembers(id string) (map[string]string, error) {
	rows, err := p.db.Query(`SELECT athlete_id, athlete_name FROM challenge_members WHERE challenge_id=$1`, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string]string{}
	for rows.Next() {
		var id, name string
		if err := rows.Scan(&id, &name); err != nil {
			return nil, err
		}
		out[id] = name
	}
	return out, rows.Err()
}

func (p *PgStore) ProgressList(challengeID string) ([]ChallengeProgress, error) {
	rows, err := p.db.Query(`SELECT challenge_id,athlete_id,athlete_name,distance_km,duration_sec,elevation_m,completed,best_seconds,attempts,COALESCE(finished_at,now()),updated_at FROM challenge_progress WHERE challenge_id=$1`, challengeID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []ChallengeProgress{}
	for rows.Next() {
		var p ChallengeProgress
		var finished, updated time.Time
		if err := rows.Scan(&p.ChallengeID, &p.AthleteID, &p.AthleteName, &p.DistanceKm,
			&p.DurationSec, &p.ElevationM, &p.Completed, &p.BestSeconds, &p.Attempts,
			&finished, &updated); err != nil {
			return nil, err
		}
		p.FinishedAt = finished.Format(time.RFC3339)
		p.UpdatedAt = updated.Format(time.RFC3339)
		out = append(out, p)
	}
	return out, rows.Err()
}

func (p *PgStore) UpsertProgress(row ChallengeProgress) error {
	_, err := p.db.Exec(`
INSERT INTO challenge_progress
 (challenge_id,athlete_id,athlete_name,distance_km,duration_sec,elevation_m,completed,best_seconds,attempts,finished_at,updated_at)
VALUES ($1,$2,$3,$4,$5,$6,$7,$8,1,$9,now())
ON CONFLICT (challenge_id,athlete_id) DO UPDATE SET
  athlete_name=EXCLUDED.athlete_name,
  distance_km=GREATEST(challenge_progress.distance_km, EXCLUDED.distance_km),
  duration_sec=GREATEST(challenge_progress.duration_sec, EXCLUDED.duration_sec),
  elevation_m=GREATEST(challenge_progress.elevation_m, EXCLUDED.elevation_m),
  completed=challenge_progress.completed OR EXCLUDED.completed,
  best_seconds=CASE WHEN EXCLUDED.best_seconds > 0 AND
    (challenge_progress.best_seconds = 0 OR EXCLUDED.best_seconds < challenge_progress.best_seconds)
    THEN EXCLUDED.best_seconds ELSE challenge_progress.best_seconds END,
  attempts=challenge_progress.attempts + 1,
  finished_at=COALESCE(challenge_progress.finished_at, EXCLUDED.finished_at),
  updated_at=now()`,
		row.ChallengeID, row.AthleteID, row.AthleteName, row.DistanceKm, row.DurationSec,
		row.ElevationM, row.Completed, row.BestSeconds, nullableTime(row.FinishedAt))
	return err
}

func (p *PgStore) Places() ([]Place, error) {
	rows, err := p.db.Query(`SELECT payload FROM places`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Place{}
	for rows.Next() {
		var raw []byte
		if err := rows.Scan(&raw); err != nil {
			return nil, err
		}
		var pl Place
		if err := json.Unmarshal(raw, &pl); err == nil {
			out = append(out, pl)
		}
	}
	return out, rows.Err()
}

func (p *PgStore) Segments() ([]Segment, error) {
	rows, err := p.db.Query(`SELECT payload FROM segments`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Segment{}
	for rows.Next() {
		var raw []byte
		if err := rows.Scan(&raw); err != nil {
			return nil, err
		}
		var sg Segment
		if err := json.Unmarshal(raw, &sg); err == nil {
			out = append(out, sg)
		}
	}
	return out, rows.Err()
}

func (p *PgStore) PopularAreas() ([]PopularArea, error) {
	rows, err := p.db.Query(`
SELECT round(start_lat::numeric,3)::float8, round(start_lng::numeric,3)::float8, count(*)::int
FROM activities GROUP BY 1,2 ORDER BY 3 DESC LIMIT 12`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	places, _ := p.Places()
	out := []PopularArea{}
	for rows.Next() {
		var a PopularArea
		if err := rows.Scan(&a.Lat, &a.Lng, &a.RunCount); err != nil {
			return nil, err
		}
		a.Name, a.City = nearestPlace(places, a.Lat, a.Lng)
		out = append(out, a)
	}
	return out, rows.Err()
}

func (p *PgStore) HallOfFame() ([]HallEntry, error) {
	segments, err := p.Segments()
	if err != nil {
		return nil, err
	}
	places, _ := p.Places()
	names := []string{"Selam Tesfaye", "Dawit Bekele", "Marta Lemma", "Yonas Girma", "Hana Alemu", "Abel Tadesse"}
	out := []HallEntry{}
	for i, sg := range segments {
		place, _ := nearestPlace(places, sg.StartLat, sg.StartLng)
		out = append(out, HallEntry{
			SegmentID: sg.ID, SegmentName: sg.Name,
			AthleteName: names[i%len(names)], Seconds: sg.BestSeconds,
			StartLat: sg.StartLat, StartLng: sg.StartLng, PlaceName: place,
		})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Seconds < out[j].Seconds })
	return out, nil
}

type StorageStats struct {
	Store       string  `json:"store"`
	Rows        int     `json:"rows"`
	RawBytes    int64   `json:"rawBytes"`
	StoredBytes int64   `json:"storedBytes"`
	SavedPct    float64 `json:"savedPct"`
	Algorithm   string  `json:"algorithm"`
}

func (p *PgStore) StorageStats() (StorageStats, error) {
	var raw, stored sql.NullInt64
	if err := p.db.QueryRow(`
SELECT COALESCE(sum(payload_bytes),0), COALESCE(sum(octet_length(payload_gz)),0)
FROM (
  SELECT payload_bytes, payload_gz FROM activities
  UNION ALL SELECT payload_bytes, payload_gz FROM gallery_cards
  UNION ALL SELECT payload_bytes, payload_gz FROM challenges
) t WHERE payload_gz IS NOT NULL`).Scan(&raw, &stored); err != nil {
		return StorageStats{}, err
	}
	var rows int
	if err := p.db.QueryRow(`
SELECT count(*) FROM (
  SELECT payload_gz FROM activities UNION ALL
  SELECT payload_gz FROM gallery_cards UNION ALL
  SELECT payload_gz FROM challenges
) t WHERE payload_gz IS NOT NULL`).Scan(&rows); err != nil {
		return StorageStats{}, err
	}
	out := StorageStats{Store: "postgres", Rows: rows, RawBytes: raw.Int64,
		StoredBytes: stored.Int64, Algorithm: "gzip (JSON documents)"}
	if raw.Int64 > 0 {
		out.SavedPct = float64(raw.Int64-stored.Int64) / float64(raw.Int64) * 100
	}
	return out, nil
}

func (p *PgStore) backfillSizes() error {
	rows, err := p.db.Query(`
SELECT 'activities' AS tbl, id, payload_gz FROM activities WHERE payload_gz IS NOT NULL AND payload_bytes = 0
UNION ALL SELECT 'gallery_cards', id, payload_gz FROM gallery_cards WHERE payload_gz IS NOT NULL AND payload_bytes = 0
UNION ALL SELECT 'challenges', id, payload_gz FROM challenges WHERE payload_gz IS NOT NULL AND payload_bytes = 0`)
	if err != nil {
		return err
	}
	type job struct {
		tbl, id string
		gz      []byte
	}
	jobs := []job{}
	for rows.Next() {
		var j job
		if err := rows.Scan(&j.tbl, &j.id, &j.gz); err != nil {
			rows.Close()
			return err
		}
		jobs = append(jobs, j)
	}
	if err := rows.Close(); err != nil {
		return err
	}
	for _, j := range jobs {
		r, err := gzip.NewReader(bytes.NewReader(j.gz))
		if err != nil {
			continue
		}
		plain, err := io.ReadAll(io.LimitReader(r, 32<<20))
		r.Close()
		if err != nil {
			continue
		}
		var q string
		switch j.tbl {
		case "activities":
			q = `UPDATE activities SET payload_bytes=$1 WHERE id=$2`
		case "gallery_cards":
			q = `UPDATE gallery_cards SET payload_bytes=$1 WHERE id=$2`
		case "challenges":
			q = `UPDATE challenges SET payload_bytes=$1 WHERE id=$2`
		default:
			continue
		}
		if _, err := p.db.Exec(q, len(plain), j.id); err != nil {
			return err
		}
	}
	return nil
}
