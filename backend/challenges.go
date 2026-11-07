package main

import (
	"errors"
	"fmt"
	"math"
	"net/http"
	"sort"
	"strings"
	"time"
)

var errNoChallenge = errors.New("challenge not found")

var challengeKinds = map[string]bool{
	"route": true, "distance_time": true, "elevation": true, "streak": true,
	"weekly": true, "segment_sprint": true, "relay": true, "fartlek": true,
	"vertical": true, "consistency": true, "explorer": true, "buddy": true,
}

func validVisibility(v string) bool {
	return v == "friends" || v == "public" || v == "everyone"
}

func canSeeChallenge(c Challenge, v Viewer) bool {
	if c.OwnerID == "" || c.Visibility == "" || c.Visibility == "everyone" {
		return true
	}
	if v.ID != "" && (c.OwnerID == v.ID || (c.OpponentID == v.ID && c.InviteStatus != "declined")) {
		return true
	}
	switch c.Visibility {
	case "friends":
		return v.ID != "" && v.Friends[c.OwnerID]
	case "public":
		return v.ID != ""
	}
	return false
}

func isTimeTrial(c Challenge) bool {
	if c.Mode == "head_to_head" {
		return true
	}
	switch c.Kind {
	case "distance_time", "segment_sprint", "route":
		return true
	}
	return false
}

func challengeMetric(c Challenge) (metric, unit string, target float64) {
	if c.TargetElevationM > 0 && c.TargetKm == 0 {
		return "elevation", "m", float64(c.TargetElevationM)
	}
	if c.TargetKm > 0 {
		return "distance", "km", c.TargetKm
	}
	if c.TargetSeconds > 0 {
		return "time", "min", float64(c.TargetSeconds) / 60
	}
	return "distance", "km", 0
}

func fmtDuration(sec int) string {
	if sec < 0 {
		sec = 0
	}
	h, m, s := sec/3600, (sec%3600)/60, sec%60
	if h > 0 {
		return fmt.Sprintf("%d:%02d:%02d", h, m, s)
	}
	return fmt.Sprintf("%d:%02d", m, s)
}

func fnv32(s string) uint32 {
	h := uint32(2166136261)
	for i := 0; i < len(s); i++ {
		h = (h ^ uint32(s[i])) * 16777619
	}
	return h
}

func unitValue(h uint32, i int) float64 {
	return float64(h+uint32(i+1)*2654435761) / 4294967296.0
}

var roster = []string{
	"Selam Tesfaye", "Dawit Bekele", "Marta Lemma", "Yonas Girma",
	"Hana Alemu", "Abel Tadesse", "Lidya Kebede", "Fasil Teshome",
	"Tigist Haile", "Robel Mengistu",
}

func sampleProgress(c Challenge) []ChallengeProgress {
	if c.OwnerID != "" || c.Mode == "head_to_head" {
		return nil
	}
	metric, _, target := challengeMetric(c)
	if target <= 0 {
		return nil
	}
	h := fnv32(c.ID)
	out := []ChallengeProgress{}
	for i, name := range roster {
		u := unitValue(h, i)
		p := ChallengeProgress{
			ChallengeID: c.ID, AthleteID: "sample_" + fmt.Sprint(i),
			AthleteName: name, Attempts: 1,
		}
		if isTimeTrial(c) {
			p.Completed = u > 0.34
			if p.Completed {
				p.DistanceKm = target
				p.DurationSec = int(float64(c.TargetSeconds)*0.82 + float64(c.TargetSeconds)*0.3*u)
				if p.DurationSec <= 0 {
					p.DurationSec = int(target*300*(0.78+0.42*u)) + 1
				}
				p.BestSeconds = p.DurationSec
				p.FinishedAt = time.Now().UTC().Add(-time.Duration(u*72) * time.Hour).Format(time.RFC3339)
			} else {
				p.DistanceKm = target * (0.12 + 0.72*u)
				p.DurationSec = int(p.DistanceKm * 300)
			}
		} else {
			p.Completed = u > 0.85
			if p.Completed {
				p.DistanceKm, p.ElevationM = target, int(target)
				p.FinishedAt = time.Now().UTC().Add(-time.Duration(u*72) * time.Hour).Format(time.RFC3339)
			} else {
				p.DistanceKm = target * (0.08 + 0.82*u)
				p.ElevationM = int(p.DistanceKm)
			}
			p.DurationSec = int(p.DistanceKm * 300)
		}
		if metric == "elevation" {
			p.DistanceKm = 0
		}
		out = append(out, p)
	}
	return out
}

func progressValue(c Challenge, p ChallengeProgress) float64 {
	metric, _, _ := challengeMetric(c)
	if metric == "elevation" {
		return float64(p.ElevationM)
	}
	return p.DistanceKm
}

func buildLeaderboard(c Challenge, v Viewer, members map[string]string, real []ChallengeProgress) Leaderboard {
	metric, unit, target := challengeMetric(c)
	ranking := "progress"
	if isTimeTrial(c) {
		ranking = "time"
	}
	rows := []ChallengeProgress{}
	rows = append(rows, sampleProgress(c)...)
	rows = append(rows, real...)
	if c.Mode == "head_to_head" && c.InviteStatus == "accepted" {
		for _, pair := range [][2]string{{c.OwnerID, c.OwnerName}, {c.OpponentID, c.OpponentName}} {
			if pair[0] == "" {
				continue
			}
			found := false
			for _, r := range rows {
				if r.AthleteID == pair[0] {
					found = true
					break
				}
			}
			if !found {
				rows = append(rows, ChallengeProgress{ChallengeID: c.ID, AthleteID: pair[0], AthleteName: pair[1]})
			}
		}
	}
	sort.SliceStable(rows, func(i, j int) bool {
		a, b := rows[i], rows[j]
		if a.Completed != b.Completed {
			return a.Completed
		}
		if a.Completed && ranking == "time" {
			ta, tb := a.BestSeconds, b.BestSeconds
			if ta == 0 {
				ta = math.MaxInt32
			}
			if tb == 0 {
				tb = math.MaxInt32
			}
			if ta != tb {
				return ta < tb
			}
		}
		return progressValue(c, a) > progressValue(c, b)
	})

	out := make([]LeaderRow, 0, len(rows))
	for i, p := range rows {
		name := p.AthleteName
		if name == "" {
			name = members[p.AthleteID]
		}
		if name == "" {
			name = "RUCHA athlete"
		}
		val := progressValue(c, p)
		label := fmt.Sprintf("%.2f %s", val, unit)
		if target > 0 {
			label = fmt.Sprintf("%.2f / %.2f %s", val, target, unit)
		}
		result := "In progress"
		if p.Completed {
			if ranking == "time" {
				result = fmtDuration(p.BestSeconds)
			} else {
				result = "Completed"
			}
		} else if ranking == "time" && p.BestSeconds > 0 {
			result = fmtDuration(p.BestSeconds)
		}
		out = append(out, LeaderRow{
			Rank: i + 1, AthleteID: p.AthleteID, AthleteName: name,
			Progress: val, ProgressLabel: label, Target: target, Unit: unit,
			Completed: p.Completed, Result: result, FinishedAt: p.FinishedAt,
			Me: v.ID != "" && p.AthleteID == v.ID,
		})
	}
	joined := v.ID != "" && (members[v.ID] != "" || c.OwnerID == v.ID ||
		(c.OpponentID == v.ID && c.InviteStatus == "accepted"))
	return Leaderboard{
		ChallengeID: c.ID, Ranking: ranking, Metric: metric, Unit: unit,
		Target: target, Rows: out, ViewerID: v.ID, Joined: joined,
	}
}

func resolveUsername(name string) (User, error) {
	list, err := auth.SearchUsers(strings.ToLower(strings.TrimSpace(name)), "")
	if err != nil {
		return User{}, err
	}
	for _, u := range list {
		if u.Username == strings.ToLower(strings.TrimSpace(name)) {
			return u, nil
		}
	}
	return User{}, errNoUser
}

func athleteFor(v Viewer, requestedID, requestedName string) (string, string) {
	if v.ID != "" {
		return v.ID, v.Username
	}
	id := strings.TrimSpace(requestedID)
	if id == "" || strings.HasPrefix(id, "usr_") {
		id = "anon_guest"
	}
	name := strings.TrimSpace(requestedName)
	if name == "" || len(name) > 48 {
		name = "Guest athlete"
	}
	return id, name
}

func handleChallenges(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		v := currentViewer(tokenFrom(r))
		list, err := store.Challenges()
		if err != nil {
			fail(w, 500, err.Error())
			return
		}
		out := []Challenge{}
		for _, c := range list {
			if !canSeeChallenge(c, v) {
				continue
			}
			if v.ID != "" {
				m, _ := store.ChallengeMembers(c.ID)
				c.Joined = m[v.ID] != "" || c.OwnerID == v.ID ||
					(c.OpponentID == v.ID && c.InviteStatus == "accepted")
			} else {
				c.Joined = false
			}
			out = append(out, c)
		}
		writeJSON(w, out)
	case http.MethodPost:
		createChallenge(w, r)
	default:
		fail(w, 405, "GET or POST only")
	}
}

func createChallenge(w http.ResponseWriter, r *http.Request) {
	v := currentViewer(tokenFrom(r))
	var c Challenge
	if err := decode(r, &c); err != nil {
		fail(w, 400, "invalid JSON: "+err.Error())
		return
	}
	c.Title = strings.TrimSpace(c.Title)
	if c.Title == "" || len(c.Title) > 80 {
		fail(w, 400, "title must be 1-80 characters")
		return
	}
	if c.Description == "" {
		c.Description = "A RUCHA community challenge."
	}
	if len(c.Description) > 400 {
		c.Description = c.Description[:400]
	}
	if !challengeKinds[c.Kind] {
		c.Kind = "weekly"
	}
	if !validVisibility(c.Visibility) {
		c.Visibility = "everyone"
	}
	if c.Visibility == "friends" && v.ID == "" {
		fail(w, 401, "sign in to create a friends-only challenge")
		return
	}
	if c.TargetKm < 0 || c.TargetKm > 2000 || c.TargetElevationM < 0 || c.TargetElevationM > 100000 || c.TargetSeconds < 0 {
		fail(w, 400, "target values are out of range")
		return
	}
	if c.StartLat != nil && (math.IsNaN(*c.StartLat) || math.Abs(*c.StartLat) > 90) {
		fail(w, 400, "invalid start latitude")
		return
	}
	if c.StartLng != nil && (math.IsNaN(*c.StartLng) || math.Abs(*c.StartLng) > 180) {
		fail(w, 400, "invalid start longitude")
		return
	}
	if c.EndLat != nil && (math.IsNaN(*c.EndLat) || math.Abs(*c.EndLat) > 90) {
		fail(w, 400, "invalid end latitude")
		return
	}
	if c.EndLng != nil && (math.IsNaN(*c.EndLng) || math.Abs(*c.EndLng) > 180) {
		fail(w, 400, "invalid end longitude")
		return
	}
	if c.ID == "" {
		c.ID = fmt.Sprintf("ch_%d", time.Now().UnixNano())
	}
	if c.CreatedAt == "" {
		c.CreatedAt = nowISO()
	}
	if c.EndsAt == "" {
		c.EndsAt = time.Now().UTC().AddDate(0, 0, 14).Format(time.RFC3339)
	}
	if c.GeofenceM == 0 && (c.Kind == "route" || c.Kind == "segment_sprint") && c.StartLat != nil {
		c.GeofenceM = 50
	}
	if c.PrizeBr < 0 {
		c.PrizeBr = 0
	}
	c.Members = 0
	c.Joined = false
	c.OwnerID, c.OwnerName = v.ID, v.Username
	c.CreatedBy = v.Username
	if c.CreatedBy == "" {
		c.CreatedBy = "Guest"
	}
	c.Mode = strings.TrimSpace(c.Mode)
	if c.Mode != "head_to_head" && c.Mode != "goal" {
		c.Mode = "open"
	}
	if c.Mode == "head_to_head" {
		oppName := strings.ToLower(strings.TrimSpace(c.OpponentName))
		if oppName == "" {
			fail(w, 400, "choose an opponent by username")
			return
		}
		opp, err := resolveUsername(oppName)
		if err != nil {
			fail(w, 400, "no account with that username")
			return
		}
		if opp.ID == v.ID {
			fail(w, 400, "you cannot challenge yourself")
			return
		}
		c.OpponentID, c.OpponentName = opp.ID, opp.Username
		c.InviteStatus = "pending"
		c.Visibility = "friends"
		if c.TargetKm <= 0 {
			c.TargetKm = 5
		}
		c.AutoStop = true
	} else {
		c.OpponentID, c.OpponentName, c.InviteStatus = "", "", ""
	}
	if err := store.AddChallenge(c); err != nil {
		fail(w, 500, err.Error())
		return
	}
	athleteID, athleteName := athleteFor(v, "", "")
	_ = store.JoinChallenge(c.ID, athleteID, athleteName)
	writeJSON(w, c)
}

func handleJoin(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		fail(w, 405, "POST only")
		return
	}
	var body struct {
		ChallengeID string `json:"challengeId"`
		AthleteID   string `json:"athleteId"`
		AthleteName string `json:"athleteName"`
	}
	if err := decode(r, &body); err != nil || body.ChallengeID == "" {
		fail(w, 400, "challengeId is required")
		return
	}
	c, err := store.ChallengeByID(body.ChallengeID)
	if err != nil {
		fail(w, 404, errNoChallenge.Error())
		return
	}
	v := currentViewer(tokenFrom(r))
	if !canSeeChallenge(c, v) {
		fail(w, 403, "this challenge is not available to you")
		return
	}
	id, name := athleteFor(v, body.AthleteID, body.AthleteName)
	if err := store.JoinChallenge(c.ID, id, name); err != nil {
		fail(w, 500, err.Error())
		return
	}
	writeJSON(w, map[string]interface{}{"joined": true, "athleteId": id})
}

func handleChallengeRespond(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		fail(w, 405, "POST only")
		return
	}
	v := currentViewer(tokenFrom(r))
	if v.ID == "" {
		fail(w, 401, errNotAuthed.Error())
		return
	}
	var body struct {
		ID       string `json:"id"`
		Decision string `json:"decision"`
	}
	if err := decode(r, &body); err != nil {
		fail(w, 400, "invalid JSON")
		return
	}
	c, err := store.ChallengeByID(body.ID)
	if err != nil {
		fail(w, 404, errNoChallenge.Error())
		return
	}
	if c.OpponentID != v.ID || c.InviteStatus != "pending" {
		fail(w, 403, "no pending invitation for your account")
		return
	}
	if body.Decision != "accept" && body.Decision != "decline" {
		fail(w, 400, "decision must be accept or decline")
		return
	}
	if body.Decision == "accept" {
		c.InviteStatus = "accepted"
	} else {
		c.InviteStatus = "declined"
	}
	if body.Decision == "accept" {
		_ = store.JoinChallenge(c.ID, c.OwnerID, c.OwnerName)
		_ = store.JoinChallenge(c.ID, c.OpponentID, c.OpponentName)
	}
	if err := store.UpdateChallenge(c); err != nil {
		fail(w, 500, err.Error())
		return
	}
	writeJSON(w, c)
}

func handleChallengeProgress(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		fail(w, 405, "POST only")
		return
	}
	v := currentViewer(tokenFrom(r))
	var body struct {
		ChallengeID string  `json:"challengeId"`
		AthleteID   string  `json:"athleteId"`
		AthleteName string  `json:"athleteName"`
		DistanceKm  float64 `json:"distanceKm"`
		DurationSec int     `json:"durationSec"`
		ElevationM  int     `json:"elevationM"`
		FinishedAt  string  `json:"finishedAt"`
	}
	if err := decode(r, &body); err != nil {
		fail(w, 400, "invalid JSON")
		return
	}
	c, err := store.ChallengeByID(body.ChallengeID)
	if err != nil {
		fail(w, 404, errNoChallenge.Error())
		return
	}
	id, name := athleteFor(v, body.AthleteID, body.AthleteName)
	members, _ := store.ChallengeMembers(c.ID)
	allowed := members[id] != "" || c.OwnerID == id ||
		(c.OpponentID == id && c.InviteStatus == "accepted")
	if !allowed {
		fail(w, 403, "join the challenge before posting progress")
		return
	}
	if math.IsNaN(body.DistanceKm) || math.IsInf(body.DistanceKm, 0) || body.DistanceKm < 0 || body.DistanceKm > 2000 {
		fail(w, 400, "distanceKm is out of range")
		return
	}
	if body.DurationSec < 0 || body.DurationSec > 864000 || body.ElevationM < 0 || body.ElevationM > 100000 {
		fail(w, 400, "duration or elevation is out of range")
		return
	}
	metric, _, target := challengeMetric(c)
	completed := false
	if target > 0 {
		if metric == "elevation" {
			completed = float64(body.ElevationM) >= target
		} else {
			completed = body.DistanceKm >= target*0.999
		}
	}
	best := 0
	if completed && body.DurationSec > 0 {
		best = body.DurationSec
	}
	finished := ""
	if completed {
		finished = nowISO()
	}
	row := ChallengeProgress{
		ChallengeID: c.ID, AthleteID: id, AthleteName: name,
		DistanceKm: body.DistanceKm, DurationSec: body.DurationSec,
		ElevationM: body.ElevationM, Completed: completed,
		BestSeconds: best, FinishedAt: finished, UpdatedAt: nowISO(),
	}
	if err := store.UpsertProgress(row); err != nil {
		fail(w, 500, err.Error())
		return
	}
	writeJSON(w, row)
}

func handleLeaderboard(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		fail(w, 405, "GET only")
		return
	}
	id := r.URL.Query().Get("id")
	if id == "" {
		fail(w, 400, "id is required")
		return
	}
	c, err := store.ChallengeByID(id)
	if err != nil {
		fail(w, 404, errNoChallenge.Error())
		return
	}
	v := currentViewer(tokenFrom(r))
	if !canSeeChallenge(c, v) {
		fail(w, 403, "this challenge is not available to you")
		return
	}
	members, _ := store.ChallengeMembers(id)
	real, _ := store.ProgressList(id)
	writeJSON(w, buildLeaderboard(c, v, members, real))
}
