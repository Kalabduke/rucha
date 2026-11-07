package main

import (
	"database/sql"
	"encoding/json"
	"sort"
	"strings"
	"sync"
	"time"
)

type authData interface {
	Kind() string
	userByID(id string) (*userRecord, error)
	userByName(name string) (*userRecord, error)
	userByProvider(provider, id string) (*userRecord, error)
	insertUser(u *userRecord) error
	listUsers(q, excludeID string) ([]*userRecord, error)
	insertSession(tok, userID string, exp time.Time) error
	sessionUser(tok string) (*userRecord, error)
	deleteSession(tok string) error
	insertEdge(e *FriendEdge) error
	edgeByID(id string) (*FriendEdge, error)
	findEdge(a, b string) (*FriendEdge, error)
	updateEdge(e *FriendEdge) error
	deleteEdge(id string) error
	listEdges(userID string) ([]*FriendEdge, error)
	insertShare(s *Share) error
	shareByID(id string) (*Share, error)
	deleteShare(id string) error
	listShares() ([]*Share, error)
}

func NewMemAuth() Auth { return &authCore{d: newMemData()} }
func NewPgAuth(db *sql.DB) (Auth, error) {
	if _, err := db.Exec(authSchemaSQL); err != nil {
		return nil, err
	}
	return &authCore{d: &pgData{db: db}}, nil
}

type memData struct {
	mu       sync.RWMutex
	users    map[string]*userRecord
	byName   map[string]string
	sessions map[string]struct {
		userID string
		exp    time.Time
	}
	edges  map[string]*FriendEdge
	shares map[string]*Share
}

func newMemData() *memData {
	return &memData{
		users: map[string]*userRecord{}, byName: map[string]string{},
		sessions: map[string]struct {
			userID string
			exp    time.Time
		}{},
		edges: map[string]*FriendEdge{}, shares: map[string]*Share{},
	}
}

func (m *memData) Kind() string { return "memory" }

func (m *memData) userByID(id string) (*userRecord, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	u := m.users[id]
	if u == nil {
		return nil, errNoUser
	}
	c := *u
	return &c, nil
}

func (m *memData) userByName(name string) (*userRecord, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	id := m.byName[name]
	u := m.users[id]
	if u == nil {
		return nil, errNoUser
	}
	c := *u
	return &c, nil
}

func (m *memData) userByProvider(provider, id string) (*userRecord, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	for _, u := range m.users {
		if u.Provider == provider && u.ProviderID == id {
			c := *u
			return &c, nil
		}
	}
	return nil, errNoUser
}

func (m *memData) insertUser(u *userRecord) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, taken := m.byName[u.Username]; taken {
		return errUserTaken
	}
	m.users[u.ID] = u
	m.byName[u.Username] = u.ID
	return nil
}

func (m *memData) listUsers(q, excludeID string) ([]*userRecord, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	out := []*userRecord{}
	for id, u := range m.users {
		if id == excludeID {
			continue
		}
		if q == "" || strings.Contains(u.Username, q) {
			c := *u
			out = append(out, &c)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Username < out[j].Username })
	if len(out) > 20 {
		out = out[:20]
	}
	return out, nil
}

func (m *memData) insertSession(tok, userID string, exp time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.sessions[tok] = struct {
		userID string
		exp    time.Time
	}{userID, exp}
	return nil
}

func (m *memData) sessionUser(tok string) (*userRecord, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	s, ok := m.sessions[tok]
	if !ok || time.Now().UTC().After(s.exp) {
		return nil, errNotAuthed
	}
	u := m.users[s.userID]
	if u == nil {
		return nil, errNotAuthed
	}
	c := *u
	return &c, nil
}

func (m *memData) deleteSession(tok string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.sessions, tok)
	return nil
}

func (m *memData) insertEdge(e *FriendEdge) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	c := *e
	m.edges[e.ID] = &c
	return nil
}

func (m *memData) edgeByID(id string) (*FriendEdge, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	e := m.edges[id]
	if e == nil {
		return nil, errNoRequest
	}
	c := *e
	return &c, nil
}

func (m *memData) findEdge(a, b string) (*FriendEdge, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	for _, e := range m.edges {
		if (e.RequesterID == a && e.AddresseeID == b) || (e.RequesterID == b && e.AddresseeID == a) {
			c := *e
			return &c, nil
		}
	}
	return nil, errNoRequest
}

func (m *memData) updateEdge(e *FriendEdge) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	c := *e
	m.edges[e.ID] = &c
	return nil
}

func (m *memData) deleteEdge(id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.edges, id)
	return nil
}

func (m *memData) listEdges(userID string) ([]*FriendEdge, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	out := []*FriendEdge{}
	for _, e := range m.edges {
		if e.RequesterID == userID || e.AddresseeID == userID {
			c := *e
			out = append(out, &c)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt > out[j].CreatedAt })
	return out, nil
}

func (m *memData) insertShare(s *Share) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	c := *s
	m.shares[s.ID] = &c
	return nil
}

func (m *memData) shareByID(id string) (*Share, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	s := m.shares[id]
	if s == nil {
		return nil, errNoUser
	}
	c := *s
	return &c, nil
}

func (m *memData) deleteShare(id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.shares, id)
	return nil
}

func (m *memData) listShares() ([]*Share, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	out := []*Share{}
	for _, s := range m.shares {
		c := *s
		out = append(out, &c)
	}
	return out, nil
}

const authSchemaSQL = `
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  username TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  payload JSONB NOT NULL
);
CREATE TABLE IF NOT EXISTS sessions (
  token TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL
);
CREATE TABLE IF NOT EXISTS friendships (
  id TEXT PRIMARY KEY,
  requester_id TEXT NOT NULL,
  addressee_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  payload JSONB NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_friendships_requester ON friendships (requester_id);
CREATE INDEX IF NOT EXISTS idx_friendships_addressee ON friendships (addressee_id);
CREATE TABLE IF NOT EXISTS shares (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  activity_id TEXT NOT NULL,
  shared_with_id TEXT NOT NULL DEFAULT '',
  is_public BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  payload JSONB NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_shares_activity ON shares (activity_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_provider ON users ((payload->>'provider'), (payload->>'providerId'))
  WHERE payload->>'provider' IS NOT NULL;
`

type pgData struct{ db *sql.DB }

func (p *pgData) Kind() string { return "postgres" }

func scanUser(raw []byte) (*userRecord, error) {
	var u userRecord
	if err := json.Unmarshal(raw, &u); err != nil {
		return nil, err
	}
	return &u, nil
}

func (p *pgData) userByID(id string) (*userRecord, error) {
	var raw []byte
	if err := p.db.QueryRow(`SELECT payload FROM users WHERE id=$1`, id).Scan(&raw); err != nil {
		return nil, errNoUser
	}
	return scanUser(raw)
}

func (p *pgData) userByName(name string) (*userRecord, error) {
	var raw []byte
	if err := p.db.QueryRow(`SELECT payload FROM users WHERE username=$1`, name).Scan(&raw); err != nil {
		return nil, errNoUser
	}
	return scanUser(raw)
}

func (p *pgData) userByProvider(provider, id string) (*userRecord, error) {
	var raw []byte
	if err := p.db.QueryRow(`SELECT payload FROM users WHERE payload->>'provider'=$1 AND payload->>'providerId'=$2`,
		provider, id).Scan(&raw); err != nil {
		return nil, errNoUser
	}
	return scanUser(raw)
}

func (p *pgData) insertUser(u *userRecord) error {
	raw, _ := json.Marshal(u)
	res, err := p.db.Exec(`INSERT INTO users (id,username,created_at,payload)
		VALUES ($1,$2,$3,$4::jsonb) ON CONFLICT (username) DO NOTHING`,
		u.ID, u.Username, parseTime(u.CreatedAt), string(raw))
	if err != nil {
		return err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return errUserTaken
	}
	return nil
}

func (p *pgData) listUsers(q, excludeID string) ([]*userRecord, error) {

	clean := strings.Map(func(r rune) rune {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '_' {
			return r
		}
		return -1
	}, q)
	pattern := "%" + clean + "%"
	rows, err := p.db.Query(`SELECT payload FROM users WHERE username LIKE $1 AND id <> $2
		ORDER BY username LIMIT 20`, pattern, excludeID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []*userRecord{}
	for rows.Next() {
		var raw []byte
		if err := rows.Scan(&raw); err != nil {
			continue
		}
		if u, err := scanUser(raw); err == nil {
			out = append(out, u)
		}
	}
	return out, nil
}

func (p *pgData) insertSession(tok, userID string, exp time.Time) error {
	_, err := p.db.Exec(`INSERT INTO sessions (token,user_id,expires_at) VALUES ($1,$2,$3)`, tok, userID, exp)
	return err
}

func (p *pgData) sessionUser(tok string) (*userRecord, error) {
	var uid string
	var exp time.Time
	if err := p.db.QueryRow(`SELECT user_id, expires_at FROM sessions WHERE token=$1`, tok).Scan(&uid, &exp); err != nil {
		return nil, errNotAuthed
	}
	if time.Now().UTC().After(exp) {
		_, _ = p.db.Exec(`DELETE FROM sessions WHERE token=$1`, tok)
		return nil, errNotAuthed
	}
	return p.userByID(uid)
}

func (p *pgData) deleteSession(tok string) error {
	_, err := p.db.Exec(`DELETE FROM sessions WHERE token=$1`, tok)
	return err
}

func (p *pgData) insertEdge(e *FriendEdge) error {
	raw, _ := json.Marshal(e)
	_, err := p.db.Exec(`INSERT INTO friendships (id,requester_id,addressee_id,status,created_at,payload)
		VALUES ($1,$2,$3,$4,$5,$6::jsonb)`, e.ID, e.RequesterID, e.AddresseeID, e.Status,
		parseTime(e.CreatedAt), string(raw))
	return err
}

func (p *pgData) edgeByID(id string) (*FriendEdge, error) {
	var raw []byte
	if err := p.db.QueryRow(`SELECT payload FROM friendships WHERE id=$1`, id).Scan(&raw); err != nil {
		return nil, errNoRequest
	}
	var e FriendEdge
	if err := json.Unmarshal(raw, &e); err != nil {
		return nil, err
	}
	return &e, nil
}

func (p *pgData) findEdge(a, b string) (*FriendEdge, error) {
	var raw []byte
	err := p.db.QueryRow(`SELECT payload FROM friendships
		WHERE (requester_id=$1 AND addressee_id=$2) OR (requester_id=$2 AND addressee_id=$1)
		LIMIT 1`, a, b).Scan(&raw)
	if err != nil {
		return nil, errNoRequest
	}
	var e FriendEdge
	if err := json.Unmarshal(raw, &e); err != nil {
		return nil, err
	}
	return &e, nil
}

func (p *pgData) updateEdge(e *FriendEdge) error {
	raw, _ := json.Marshal(e)
	_, err := p.db.Exec(`UPDATE friendships SET status=$1, payload=$2::jsonb WHERE id=$3`,
		e.Status, string(raw), e.ID)
	return err
}

func (p *pgData) deleteEdge(id string) error {
	_, err := p.db.Exec(`DELETE FROM friendships WHERE id=$1`, id)
	return err
}

func (p *pgData) listEdges(userID string) ([]*FriendEdge, error) {
	rows, err := p.db.Query(`SELECT payload FROM friendships
		WHERE requester_id=$1 OR addressee_id=$1 ORDER BY created_at DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []*FriendEdge{}
	for rows.Next() {
		var raw []byte
		if err := rows.Scan(&raw); err != nil {
			continue
		}
		var e FriendEdge
		if err := json.Unmarshal(raw, &e); err == nil {
			out = append(out, &e)
		}
	}
	return out, nil
}

func (p *pgData) insertShare(s *Share) error {
	raw, _ := json.Marshal(s)
	_, err := p.db.Exec(`INSERT INTO shares (id,owner_id,activity_id,shared_with_id,is_public,created_at,payload)
		VALUES ($1,$2,$3,$4,$5,$6,$7::jsonb)`, s.ID, s.OwnerID, s.ActivityID, s.SharedWithID,
		s.Public, parseTime(s.CreatedAt), string(raw))
	return err
}

func (p *pgData) shareByID(id string) (*Share, error) {
	var raw []byte
	if err := p.db.QueryRow(`SELECT payload FROM shares WHERE id=$1`, id).Scan(&raw); err != nil {
		return nil, errNoUser
	}
	var s Share
	if err := json.Unmarshal(raw, &s); err != nil {
		return nil, err
	}
	return &s, nil
}

func (p *pgData) deleteShare(id string) error {
	_, err := p.db.Exec(`DELETE FROM shares WHERE id=$1`, id)
	return err
}

func (p *pgData) listShares() ([]*Share, error) {
	rows, err := p.db.Query(`SELECT payload FROM shares`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []*Share{}
	for rows.Next() {
		var raw []byte
		if err := rows.Scan(&raw); err != nil {
			continue
		}
		var s Share
		if err := json.Unmarshal(raw, &s); err == nil {
			out = append(out, &s)
		}
	}
	return out, nil
}
