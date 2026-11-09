package main

import (
	"encoding/json"
	"fmt"
	"log"
	"math"
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
	mux.HandleFunc("/api/clubs", handleClubs)
	mux.HandleFunc("/api/clubs/join", handleClubJoin)
	mux.HandleFunc("/api/halloffame", handleHall)
	mux.HandleFunc("/api/auth/config", handleAuthConfig)
	mux.HandleFunc("/api/auth/username", handleUsernameCheck)
	mux.HandleFunc("/api/auth/register", handleRegister)
	mux.HandleFunc("/api/auth/login", handleLogin)
	mux.HandleFunc("/api/auth/complete", handleCompleteProfile)
	mux.HandleFunc("/api/auth/consent", handleConsent)
	mux.HandleFunc("/api/auth/telegram/start", handleTelegramStart)
	mux.HandleFunc("/api/auth/telegram/verify", handleTelegramVerify)
	mux.HandleFunc("/api/auth/google", handleGoogleLogin)
	mux.HandleFunc("/api/auth/apple", handleAppleLogin)
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
	if msg != "" {
		msg = strings.ToUpper(msg[:1]) + msg[1:]
	}
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
			a.Source = "gps"
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
	switch r.Method {
	case http.MethodGet:
		list, err := store.Segments()
		if err != nil {
			fail(w, 500, err.Error())
			return
		}
		writeJSON(w, list)
	case http.MethodPost:
		v := currentViewer(tokenFrom(r))
		if v.ID == "" {
			fail(w, 401, errNotAuthed.Error())
			return
		}
		var sg Segment
		if err := decode(r, &sg); err != nil {
			fail(w, 400, "invalid JSON: "+err.Error())
			return
		}
		sg.Name = strings.TrimSpace(sg.Name)
		if sg.Name == "" || len(sg.Name) > 80 {
			fail(w, 400, "segment name must be 1-80 characters")
			return
		}
		if math.IsNaN(sg.Km) || math.IsInf(sg.Km, 0) || sg.Km <= 0 || sg.Km > 2000 {
			fail(w, 400, "segment distance is out of range")
			return
		}
		if sg.GainM < 0 || sg.GainM > 100000 || sg.BestSeconds < 0 || sg.BestSeconds > 864000 {
			fail(w, 400, "segment gain or time is out of range")
			return
		}
		for _, pair := range [][3]float64{{sg.StartLat, -90, 90}, {sg.EndLat, -90, 90}, {sg.StartLng, -180, 180}, {sg.EndLng, -180, 180}} {
			if math.IsNaN(pair[0]) || math.IsInf(pair[0], 0) || pair[0] < pair[1] || pair[0] > pair[2] {
				fail(w, 400, "segment coordinates are out of range")
				return
			}
		}
		if sg.Type != "ride" {
			sg.Type = "run"
		}
		if sg.Cat == "" {
			sg.Cat = categoryFor(sg.GainM, sg.Km)
		}
		if sg.Attempts < 0 {
			sg.Attempts = 0
		}
		if sg.Attempts > 1000000 {
			fail(w, 400, "segment attempts are out of range")
			return
		}
		if sg.ID == "" {
			sg.ID = fmt.Sprintf("seg_%d", time.Now().UnixNano())
		}
		if sg.CreatedAt == "" {
			sg.CreatedAt = nowISO()
		}
		existing, found := Segment{}, false
		if list, err := store.Segments(); err == nil {
			for _, x := range list {
				if x.ID == sg.ID {
					existing, found = x, true
					break
				}
			}
		}
		if found {
			// Course records can be improved by any signed-in athlete, but the
			// route definition and ownership stay with the creator.
			sg.Name = existing.Name
			sg.City = existing.City
			sg.StartLat, sg.StartLng = existing.StartLat, existing.StartLng
			sg.EndLat, sg.EndLng = existing.EndLat, existing.EndLng
			sg.Km, sg.GainM, sg.Cat, sg.Type = existing.Km, existing.GainM, existing.Cat, existing.Type
			sg.OwnerID, sg.OwnerName = existing.OwnerID, existing.OwnerName
			sg.ActivityID, sg.CreatedAt = existing.ActivityID, existing.CreatedAt
			if sg.Attempts < existing.Attempts {
				sg.Attempts = existing.Attempts
			}
			if existing.BestSeconds > 0 && (sg.BestSeconds <= 0 || existing.BestSeconds < sg.BestSeconds) {
				sg.BestSeconds = existing.BestSeconds
				sg.BestAthleteID, sg.BestAthleteName = existing.BestAthleteID, existing.BestAthleteName
			}
		} else {
			sg.OwnerID, sg.OwnerName = v.ID, v.Username
			if sg.BestSeconds > 0 {
				sg.BestAthleteID, sg.BestAthleteName = v.ID, v.Username
			}
		}
		if err := store.AddSegment(sg); err != nil {
			fail(w, 500, err.Error())
			return
		}
		writeJSON(w, sg)
	default:
		fail(w, 405, "GET or POST only")
	}
}

func categoryFor(gainM int, km float64) string {
	if km <= 0 {
		return "5"
	}
	g := float64(gainM) / km
	switch {
	case g >= 80:
		return "HC"
	case g >= 45:
		return "1"
	case g >= 25:
		return "2"
	case g >= 12:
		return "3"
	case g >= 4:
		return "4"
	default:
		return "5"
	}
}

func handleClubs(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		v := currentViewer(tokenFrom(r))
		list, err := store.Clubs()
		if err != nil {
			fail(w, 500, err.Error())
			return
		}
		out := []Club{}
		for _, c := range list {
			c.Joined = false
			if v.ID != "" {
				m, _ := store.ClubMembers(c.ID)
				c.Joined = m[v.ID] != ""
			}
			out = append(out, c)
		}
		writeJSON(w, out)
	case http.MethodPost:
		v := currentViewer(tokenFrom(r))
		if v.ID == "" {
			fail(w, 401, "sign in to create a club")
			return
		}
		var c Club
		if err := decode(r, &c); err != nil {
			fail(w, 400, "invalid JSON: "+err.Error())
			return
		}
		c.Name = strings.TrimSpace(c.Name)
		if c.Name == "" || len(c.Name) > 60 {
			fail(w, 400, "club name must be 1-60 characters")
			return
		}
		c.Description = strings.TrimSpace(c.Description)
		if len(c.Description) > 300 {
			c.Description = c.Description[:300]
		}
		if c.Type != "ride" {
			c.Type = "run"
		}
		if c.Color == "" || len(c.Color) > 20 {
			c.Color = "#0B6E56"
		}
		if c.ID == "" {
			c.ID = fmt.Sprintf("club_%d", time.Now().UnixNano())
		}
		if c.CreatedAt == "" {
			c.CreatedAt = nowISO()
		}
		c.OwnerID, c.OwnerName = v.ID, v.Username
		c.Members = 0
		c.Joined = true
		if err := store.AddClub(c); err != nil {
			fail(w, 500, err.Error())
			return
		}
		if err := store.JoinClub(c.ID, v.ID, v.Username); err != nil {
			fail(w, 500, err.Error())
			return
		}
		c.Members = 1
		writeJSON(w, c)
	default:
		fail(w, 405, "GET or POST only")
	}
}

func handleClubJoin(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		fail(w, 405, "POST only")
		return
	}
	var body struct {
		ClubID      string `json:"clubId"`
		AthleteID   string `json:"athleteId"`
		AthleteName string `json:"athleteName"`
		Leave       bool   `json:"leave"`
	}
	if err := decode(r, &body); err != nil || body.ClubID == "" {
		fail(w, 400, "clubId is required")
		return
	}
	found := false
	list, _ := store.Clubs()
	for _, c := range list {
		if c.ID == body.ClubID {
			found = true
			break
		}
	}
	if !found {
		fail(w, 404, "club not found")
		return
	}
	v := currentViewer(tokenFrom(r))
	id, name := athleteFor(v, body.AthleteID, body.AthleteName)
	if body.Leave {
		if err := store.LeaveClub(body.ClubID, id); err != nil {
			fail(w, 500, err.Error())
			return
		}
		writeJSON(w, map[string]interface{}{"joined": false, "athleteId": id})
		return
	}
	if err := store.JoinClub(body.ClubID, id, name); err != nil {
		fail(w, 500, err.Error())
		return
	}
	writeJSON(w, map[string]interface{}{"joined": true, "athleteId": id})
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
