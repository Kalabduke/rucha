package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

var store Store

func main() {
	var s Store
	if url := os.Getenv("DATABASE_URL"); url != "" {
		ps, err := NewPgStore(url)
		if err != nil {
			log.Printf("Postgres unavailable (%v); falling back to in-memory store", err)
			s = NewMemStore()
		} else {
			log.Println("connected to Postgres")
			s = ps
		}
	} else {
		log.Println("DATABASE_URL not set; using in-memory store")
		s = NewMemStore()
	}
	store = s
	if ps, ok := s.(*PgStore); ok {
		a, err := NewPgAuth(ps.db)
		if err != nil {
			log.Printf("auth tables unavailable (%v); falling back to memory auth", err)
			auth = NewMemAuth()
		} else {
			auth = a
		}
	} else {
		auth = NewMemAuth()
	}

	startTelegramBot()

	staticDir := os.Getenv("STATIC_DIR")
	if staticDir == "" {
		if _, err := os.Stat("../index.html"); err == nil {
			staticDir = ".."
		} else {
			staticDir = "."
		}
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/api/health", handleHealth)
	mux.HandleFunc("/api/storage", handleStorage)
	mux.HandleFunc("/api/activities", handleActivities)
	mux.HandleFunc("/api/gallery", handleGallery)
	mux.HandleFunc("/api/challenges", handleChallenges)
	mux.HandleFunc("/api/challenges/join", handleJoin)
	mux.HandleFunc("/api/challenges/respond", handleChallengeRespond)
	mux.HandleFunc("/api/challenges/progress", handleChallengeProgress)
	mux.HandleFunc("/api/challenges/leaderboard", handleLeaderboard)
	mux.HandleFunc("/api/areas/popular", handlePopular)
	mux.HandleFunc("/api/places", handlePlaces)
	mux.HandleFunc("/api/segments", handleSegments)
	mux.HandleFunc("/api/halloffame", handleHall)
	mux.HandleFunc("/api/auth/config", handleAuthConfig)
	mux.HandleFunc("/api/auth/telegram/start", handleTelegramStart)
	mux.HandleFunc("/api/auth/telegram/verify", handleTelegramVerify)
	mux.HandleFunc("/api/auth/google", handleGoogleLogin)
	mux.HandleFunc("/api/auth/logout", handleLogout)
	mux.HandleFunc("/api/auth/me", handleMe)
	mux.HandleFunc("/api/users", handleUsers)
	mux.HandleFunc("/api/friends", handleFriends)
	mux.HandleFunc("/api/shares", handleShares)
	mux.HandleFunc("/api/activities/visibility", handleVisibility)

	fs := http.FileServer(http.Dir(staticDir))
	mux.Handle("/", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		p := filepath.Join(staticDir, filepath.Clean(r.URL.Path))
		if info, err := os.Stat(p); err == nil && !info.IsDir() {
			fs.ServeHTTP(w, r)
			return
		}
		http.ServeFile(w, r, filepath.Join(staticDir, "index.html"))
	}))

	port := os.Getenv("PORT")
	if port == "" {
		port = "8081"
	}
	log.Printf("RUCHA API on :%s (store=%s, static=%s)", port, s.Kind(), staticDir)
	srv := &http.Server{Addr: ":" + port, Handler: withCORS(mux), ReadHeaderTimeout: 10 * time.Second}
	log.Fatal(srv.ListenAndServe())
}

func withCORS(h http.Handler) http.Handler {
	raw := strings.TrimSpace(os.Getenv("CORS_ORIGIN"))
	allowed := []string{}
	if raw != "" && raw != "*" {
		for _, part := range strings.Split(raw, ",") {
			if v := strings.TrimSpace(part); v != "" {
				allowed = append(allowed, v)
			}
		}
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if len(allowed) == 0 {
			w.Header().Set("Access-Control-Allow-Origin", "*")
		} else {
			origin := r.Header.Get("Origin")
			for _, a := range allowed {
				if a == origin {
					w.Header().Set("Access-Control-Allow-Origin", origin)
					w.Header().Add("Vary", "Origin")
					break
				}
			}
		}
		w.Header().Set("Access-Control-Allow-Methods", "GET,POST,DELETE,OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "SAMEORIGIN")
		w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
		if strings.HasPrefix(r.URL.Path, "/api/") {
			w.Header().Set("Cache-Control", "no-store")
		}
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		h.ServeHTTP(w, r)
	})
}

func writeJSON(w http.ResponseWriter, v interface{}) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_ = json.NewEncoder(w).Encode(v)
}

func fail(w http.ResponseWriter, code int, msg string) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(map[string]string{"error": msg})
}

func decode(r *http.Request, v interface{}) error {
	defer r.Body.Close()
	r.Body = http.MaxBytesReader(nil, r.Body, 32<<20)
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	return dec.Decode(v)
}

func nowISO() string { return time.Now().UTC().Format(time.RFC3339) }

func handleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		fail(w, 405, "GET only")
		return
	}
	writeJSON(w, map[string]interface{}{"ok": true, "store": store.Kind(), "time": nowISO()})
}

func handleActivities(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		v := currentViewer(tokenFrom(r))
		list, err := store.Activities()
		if err != nil {
			fail(w, 500, err.Error())
			return
		}
		out := []Activity{}
		for _, a := range list {
			if canSeeActivity(a.OwnerID, a.Visibility, a.ID, v) {
				out = append(out, a)
			}
		}
		writeJSON(w, out)
	case http.MethodPost:
		v := currentViewer(tokenFrom(r))
		if v.ID == "" {
			fail(w, 401, errNotAuthed.Error())
			return
		}
		var a Activity
		if err := decode(r, &a); err != nil {
			fail(w, 400, "invalid JSON: "+err.Error())
			return
		}
		if a.ID == "" {
			a.ID = fmt.Sprintf("act_%d", time.Now().UnixNano())
		}
		if a.CreatedAt == "" {
			a.CreatedAt = nowISO()
		}
		if a.StartedAt == "" {
			a.StartedAt = a.CreatedAt
		}
		if a.Track == nil {
			a.Track = []TrackPoint{}
		}
		if a.HRSource == "" {
			a.HRSource = "none"
		}
		if a.Source == "" {
			a.Source = "demo"
		}

		a.OwnerID = v.ID
		a.OwnerName = v.Username
		if a.Visibility != "friends" && a.Visibility != "public" {
			a.Visibility = "private"
		}
		if err := store.AddActivity(a); err != nil {
			fail(w, 500, err.Error())
			return
		}
		writeJSON(w, a)
	default:
		fail(w, 405, "GET or POST only")
	}
}

func handleGallery(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		v := currentViewer(tokenFrom(r))
		list, err := store.Gallery()
		if err != nil {
			fail(w, 500, err.Error())
			return
		}
		out := []GalleryCard{}
		for _, g := range list {
			if canSeeGallery(g.OwnerID, g.Visibility, g.ID, v) {
				out = append(out, g)
			}
		}
		writeJSON(w, out)
	case http.MethodPost:
		v := currentViewer(tokenFrom(r))
		if v.ID == "" {
			fail(w, 401, errNotAuthed.Error())
			return
		}
		var g GalleryCard
		if err := decode(r, &g); err != nil {
			fail(w, 400, "invalid JSON: "+err.Error())
			return
		}
		if g.ID == "" {
			g.ID = fmt.Sprintf("card_%d", time.Now().UnixNano())
		}
		if g.CreatedAt == "" {
			g.CreatedAt = nowISO()
		}
		g.OwnerID = v.ID
		if g.Visibility != "public" {
			g.Visibility = "private"
		}
		if err := store.AddGallery(g); err != nil {
			fail(w, 500, err.Error())
			return
		}
		writeJSON(w, g)
	case http.MethodDelete:
		id := r.URL.Query().Get("id")
		if id == "" {
			fail(w, 400, "missing id")
			return
		}
		v := currentViewer(tokenFrom(r))
		list, _ := store.Gallery()
		for _, g := range list {
			if g.ID == id && g.OwnerID != "" && g.OwnerID != v.ID {
				fail(w, 403, "only the owner can delete this card")
				return
			}
		}
		if err := store.DeleteGallery(id); err != nil {
			fail(w, 500, err.Error())
			return
		}
		writeJSON(w, map[string]bool{"deleted": true})
	default:
		fail(w, 405, "GET, POST or DELETE only")
	}
}

func handlePopular(w http.ResponseWriter, r *http.Request) {
	list, err := store.PopularAreas()
	if err != nil {
		fail(w, 500, err.Error())
		return
	}
	writeJSON(w, list)
}

func handlePlaces(w http.ResponseWriter, r *http.Request) {
	list, err := store.Places()
	if err != nil {
		fail(w, 500, err.Error())
		return
	}
	writeJSON(w, list)
}

func handleSegments(w http.ResponseWriter, r *http.Request) {
	list, err := store.Segments()
	if err != nil {
		fail(w, 500, err.Error())
		return
	}
	writeJSON(w, list)
}

func handleHall(w http.ResponseWriter, r *http.Request) {
	list, err := store.HallOfFame()
	if err != nil {
		fail(w, 500, err.Error())
		return
	}
	writeJSON(w, list)
}

func handleStorage(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		fail(w, 405, "GET only")
		return
	}
	if ps, ok := store.(*PgStore); ok {
		st, err := ps.StorageStats()
		if err != nil {
			fail(w, 500, err.Error())
			return
		}
		writeJSON(w, st)
		return
	}
	writeJSON(w, map[string]interface{}{
		"store": "memory", "rows": 0, "rawBytes": 0,
		"storedBytes": 0, "savedPct": 0,
		"algorithm": "gzip (active in Postgres mode)",
	})
}
