package main

import (
	"fmt"
	"math"
	"sort"
	"sync"
	"time"
)

type Store interface {
	Kind() string
	Activities() ([]Activity, error)
	AddActivity(a Activity) error
	Gallery() ([]GalleryCard, error)
	AddGallery(g GalleryCard) error
	DeleteGallery(id string) error
	Challenges() ([]Challenge, error)
	ChallengeByID(id string) (Challenge, error)
	UpdateChallenge(c Challenge) error
	AddChallenge(c Challenge) error
	JoinChallenge(id, athlete, athleteName string) error
	ChallengeMembers(id string) (map[string]string, error)
	ProgressList(challengeID string) ([]ChallengeProgress, error)
	UpsertProgress(p ChallengeProgress) error
	PopularAreas() ([]PopularArea, error)
	Places() ([]Place, error)
	Segments() ([]Segment, error)
	HallOfFame() ([]HallEntry, error)
}

type MemStore struct {
	mu         sync.RWMutex
	activities []Activity
	gallery    []GalleryCard
	challenges []Challenge
	joined     map[string]bool
	members    map[string]map[string]string
	progress   map[string]map[string]ChallengeProgress
	places     []Place
	segments   []Segment
}

func NewMemStore() *MemStore {
	return &MemStore{
		activities: seedActivities(),
		gallery:    []GalleryCard{},
		challenges: seedChallenges(),
		joined:     map[string]bool{},
		members:    map[string]map[string]string{},
		progress:   map[string]map[string]ChallengeProgress{},
		places:     seedPlaces(),
		segments:   seedSegments(),
	}
}

func (s *MemStore) Kind() string { return "memory" }

func (s *MemStore) Activities() ([]Activity, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]Activity, len(s.activities))
	copy(out, s.activities)
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt > out[j].CreatedAt })
	return out, nil
}

func (s *MemStore) AddActivity(a Activity) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i := range s.activities {
		if s.activities[i].ID == a.ID {
			s.activities[i] = a
			return nil
		}
	}
	s.activities = append([]Activity{a}, s.activities...)
	return nil
}

func (s *MemStore) Gallery() ([]GalleryCard, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]GalleryCard, len(s.gallery))
	copy(out, s.gallery)
	return out, nil
}

func (s *MemStore) AddGallery(g GalleryCard) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.gallery = append([]GalleryCard{g}, s.gallery...)
	return nil
}

func (s *MemStore) DeleteGallery(id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := s.gallery[:0]
	for _, g := range s.gallery {
		if g.ID != id {
			out = append(out, g)
		}
	}
	s.gallery = out
	return nil
}

func (s *MemStore) Challenges() ([]Challenge, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]Challenge, len(s.challenges))
	copy(out, s.challenges)
	for i := range out {
		out[i].Joined = s.joined[out[i].ID+"|me"]
	}
	return out, nil
}

func (s *MemStore) ChallengeByID(id string) (Challenge, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	for _, c := range s.challenges {
		if c.ID == id {
			return c, nil
		}
	}
	return Challenge{}, errNoChallenge
}

func (s *MemStore) UpdateChallenge(c Challenge) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i := range s.challenges {
		if s.challenges[i].ID == c.ID {
			s.challenges[i] = c
			return nil
		}
	}
	return errNoChallenge
}

func (s *MemStore) AddChallenge(c Challenge) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.challenges = append([]Challenge{c}, s.challenges...)
	return nil
}

func (s *MemStore) JoinChallenge(id, athlete, athleteName string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if athlete == "" {
		athlete = "me"
	}
	if s.members[id] == nil {
		s.members[id] = map[string]string{}
	}
	if _, exists := s.members[id][athlete]; exists {
		return nil
	}
	s.members[id][athlete] = athleteName
	s.joined[id+"|me"] = true
	for i := range s.challenges {
		if s.challenges[i].ID == id {
			s.challenges[i].Members++
		}
	}
	return nil
}

func (s *MemStore) ChallengeMembers(id string) (map[string]string, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := map[string]string{}
	for k, v := range s.members[id] {
		out[k] = v
	}
	return out, nil
}

func (s *MemStore) ProgressList(challengeID string) ([]ChallengeProgress, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := []ChallengeProgress{}
	for _, p := range s.progress[challengeID] {
		out = append(out, p)
	}
	return out, nil
}

func (s *MemStore) UpsertProgress(p ChallengeProgress) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.progress[p.ChallengeID] == nil {
		s.progress[p.ChallengeID] = map[string]ChallengeProgress{}
	}
	old := s.progress[p.ChallengeID][p.AthleteID]
	p.Attempts = old.Attempts + 1
	if p.BestSeconds == 0 || (old.BestSeconds > 0 && old.BestSeconds < p.BestSeconds) {
		p.BestSeconds = old.BestSeconds
	}
	if p.DistanceKm < old.DistanceKm {
		p.DistanceKm = old.DistanceKm
	}
	if p.ElevationM < old.ElevationM {
		p.ElevationM = old.ElevationM
	}
	if !p.Completed && old.Completed {
		p.Completed, p.FinishedAt = true, old.FinishedAt
	}
	if p.FinishedAt == "" {
		p.FinishedAt = old.FinishedAt
	}
	s.progress[p.ChallengeID][p.AthleteID] = p
	return nil
}

func (s *MemStore) Places() ([]Place, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]Place, len(s.places))
	copy(out, s.places)
	return out, nil
}

func (s *MemStore) Segments() ([]Segment, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]Segment, len(s.segments))
	copy(out, s.segments)
	return out, nil
}

func (s *MemStore) PopularAreas() ([]PopularArea, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	type cell struct {
		lat, lng float64
		count    int
	}
	m := map[string]*cell{}
	for _, a := range s.activities {
		la := math.Round(a.StartLat*1000) / 1000
		ln := math.Round(a.StartLng*1000) / 1000
		k := fmt.Sprintf("%.3f,%.3f", la, ln)
		if m[k] == nil {
			m[k] = &cell{lat: la, lng: ln}
		}
		m[k].count++
	}
	out := []PopularArea{}
	for _, c := range m {
		name, city := nearestPlace(s.places, c.lat, c.lng)
		out = append(out, PopularArea{Lat: c.lat, Lng: c.lng, RunCount: c.count, Name: name, City: city})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].RunCount > out[j].RunCount })
	if len(out) > 12 {
		out = out[:12]
	}
	return out, nil
}

func (s *MemStore) HallOfFame() ([]HallEntry, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	names := []string{"Selam Tesfaye", "Dawit Bekele", "Marta Lemma", "Yonas Girma", "Hana Alemu", "Abel Tadesse"}
	out := []HallEntry{}
	for i, sg := range s.segments {
		place, _ := nearestPlace(s.places, sg.StartLat, sg.StartLng)
		out = append(out, HallEntry{
			SegmentID: sg.ID, SegmentName: sg.Name,
			AthleteName: names[i%len(names)], Seconds: sg.BestSeconds,
			StartLat: sg.StartLat, StartLng: sg.StartLng, PlaceName: place,
		})
	}
	return out, nil
}

func nearestPlace(places []Place, lat, lng float64) (string, string) {
	best := math.MaxFloat64
	name, city := "", ""
	for _, p := range places {
		d := haversineKm(lat, lng, p.Lat, p.Lng)
		if d < best {
			best, name, city = d, p.Name, p.City
		}
	}
	return name, city
}

func haversineKm(lat1, lng1, lat2, lng2 float64) float64 {
	const R = 6371.0088
	const d2r = math.Pi / 180
	dLat := (lat2 - lat1) * d2r
	dLng := (lng2 - lng1) * d2r
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*d2r)*math.Cos(lat2*d2r)*math.Sin(dLng/2)*math.Sin(dLng/2)
	return 2 * R * math.Asin(math.Min(1, math.Sqrt(a)))
}

func seedPlaces() []Place {
	return []Place{
		{"Meskel Square", 9.0107, 38.7610, "square", "Addis Ababa"},
		{"Africa Hall / UNECA", 9.0140, 38.7520, "building", "Addis Ababa"},
		{"Unity Park", 9.0130, 38.7540, "park", "Addis Ababa"},
		{"Addis Ababa University", 9.0470, 38.7570, "building", "Addis Ababa"},
		{"National Museum", 9.0380, 38.7530, "building", "Addis Ababa"},
		{"Mercato", 9.0290, 38.7350, "market", "Addis Ababa"},
		{"Piassa", 9.0360, 38.7500, "square", "Addis Ababa"},
		{"Kazanchis", 9.0200, 38.7620, "district", "Addis Ababa"},
		{"Megenagna", 9.0300, 38.8100, "square", "Addis Ababa"},
		{"Bole Airport", 8.9779, 38.7993, "building", "Addis Ababa"},
		{"Friendship Park", 8.9960, 38.7570, "park", "Addis Ababa"},
		{"Saris", 8.9600, 38.7400, "district", "Addis Ababa"},
		{"Entoto Maryam", 9.1150, 38.7550, "peak", "Entoto Hills"},
		{"Entoto Natural Park", 9.1000, 38.7300, "park", "Entoto Hills"},
		{"Mount Entoto Summit", 9.1210, 38.7460, "peak", "Entoto Hills"},
		{"Sidist Kilo", 9.0470, 38.7570, "district", "Addis Ababa"},
		{"Lake Bishoftu", 8.7410, 38.9870, "water", "Bishoftu"},
		{"Lake Hawassa", 7.0621, 38.4765, "water", "Hawassa"},
		{"Lake Tana", 11.5742, 37.3614, "water", "Bahir Dar"},
		{"Fasil Ghebbi", 12.6000, 37.4667, "building", "Gondar"},
		{"Harar Jugol", 9.3139, 42.1181, "district", "Harar"},
		{"Mekelle Market", 13.4967, 39.4753, "market", "Mekelle"},
	}
}

func seedSegments() []Segment {
	return []Segment{
		{"s1", "Entoto Hill Climb", "Addis Ababa", 9.0470, 38.7570, 9.1150, 38.7550, 6.8, 612, "HC", "run", 1542, 4821},
		{"s2", "Meskel Square Straight", "Addis Ababa", 9.0107, 38.7610, 9.0140, 38.7520, 1.2, 4, "4", "run", 205, 9120},
		{"s3", "Bole Road Flyer", "Addis Ababa", 8.9779, 38.7993, 9.0107, 38.7610, 2.4, 12, "3", "ride", 248, 3310},
		{"s4", "Saris Rise", "Addis Ababa", 8.9600, 38.7400, 9.0107, 38.7610, 3.1, 96, "2", "run", 648, 2740},
		{"s5", "Bishoftu Lake Circuit", "Bishoftu", 8.7380, 38.9850, 8.7410, 38.9870, 12.6, 42, "3", "ride", 1420, 1890},
		{"s6", "Unity Park 400", "Addis Ababa", 9.0130, 38.7540, 9.0160, 38.7570, 0.4, 1, "5", "run", 66, 6402},
	}
}

func seedActivities() []Activity {
	now := time.Now().UTC()
	type def struct {
		title, typ, city   string
		lat, lng, km, pace float64
		gain               int
	}
	defs := []def{
		{"Meskel Square Loop", "run", "Addis Ababa", 9.0107, 38.7610, 8.6, 298, 42},
		{"Meskel Square Tempo", "run", "Addis Ababa", 9.0107, 38.7610, 6.2, 276, 28},
		{"Meskel Square Sunrise", "run", "Addis Ababa", 9.0107, 38.7610, 5.1, 312, 22},
		{"Meskel Square Recovery", "run", "Addis Ababa", 9.0107, 38.7610, 4.3, 352, 18},
		{"Unity Park Easy Shakeout", "run", "Addis Ababa", 9.0130, 38.7540, 5.2, 352, 12},
		{"Unity Park 400 Repeats", "run", "Addis Ababa", 9.0130, 38.7540, 7.4, 288, 16},
		{"Unity Park Club Run", "run", "Addis Ababa", 9.0130, 38.7540, 10.1, 318, 24},
		{"Entoto Natural Park Trail", "run", "Entoto Hills", 9.1000, 38.7300, 11.8, 388, 410},
		{"Entoto Maryam Ascent", "run", "Entoto Hills", 9.1150, 38.7550, 9.4, 402, 520},
		{"Bole Road Tempo", "run", "Addis Ababa", 8.9779, 38.7993, 10.1, 276, 34},
		{"Kazanchis to Saris Long Run", "run", "Addis Ababa", 9.0200, 38.7620, 21.3, 336, 188},
		{"Bishoftu Lake Circuit", "ride", "Bishoftu", 8.7380, 38.9850, 32.6, 118, 42},
	}
	out := []Activity{}
	for i, d := range defs {
		ts := now.AddDate(0, 0, -i).Format(time.RFC3339)
		cal := int(d.km * 62)
		if d.typ == "ride" {
			cal = int(d.km * 31)
		}
		out = append(out, Activity{
			ID: fmt.Sprintf("seed_%02d", i+1), Title: d.title, Type: d.typ,
			AthleteID: "u0", AthleteName: "RUCHA Community", City: d.city,
			StartLat: d.lat, StartLng: d.lng, EndLat: d.lat, EndLng: d.lng,
			DistanceKm: d.km, DurationSec: int(d.km * d.pace), PaceSecPerKm: d.pace,
			ElevationGainM: d.gain, Calories: cal, HRSource: "none", Source: "demo",
			Track: []TrackPoint{}, StartedAt: ts, CreatedAt: ts,
		})
	}
	return out
}

func seedChallenges() []Challenge {
	f := func(v float64) *float64 { return &v }
	end := time.Now().UTC().AddDate(0, 0, 14).Format(time.RFC3339)
	def := func(id, kind, title, desc string, sl, slng, el, elng *float64,
		sn, en string, km float64, sec, elev int, seg string, geo, prize int,
		members int) Challenge {
		return Challenge{
			ID: id, Kind: kind, Title: title, Description: desc,
			StartLat: sl, StartLng: slng, StartName: sn,
			EndLat: el, EndLng: elng, EndName: en,
			TargetKm: km, TargetSeconds: sec, TargetElevationM: elev,
			SegmentID: seg, GeofenceM: geo, PrizeBr: prize, Members: members,
			CreatedBy: "RUCHA", EndsAt: end, Visibility: "everyone",
			Mode: "open", CreatedAt: nowISO(),
		}
	}
	return []Challenge{
		def("ch1", "route", "Meskel Square to Entoto Maryam", "Climb from the city centre to the Entoto ridge. Start at the square, finish at the church.", f(9.0107), f(38.7610), f(9.1150), f(38.7550), "Meskel Square", "Entoto Maryam", 12.4, 0, 0, "", 50, 2000, 8421),
		def("ch2", "distance_time", "Golden Hour 10K", "Log your fastest 10 km before 07:00. Run it anywhere.", nil, nil, nil, nil, "", "", 10, 3600, 0, "", 0, 750, 5602),
		def("ch3", "elevation", "Entoto Ascent 3000", "Climb 3,000 vertical metres. Every hill counts.", nil, nil, nil, nil, "", "", 0, 0, 3000, "", 0, 1500, 3180),
		def("ch4", "streak", "7-Day Sunrise Streak", "Run at least 3 km before sunrise, seven days in a row.", nil, nil, nil, nil, "", "", 3, 0, 0, "", 0, 1000, 4210),
		def("ch5", "weekly", "Meskerem 100", "Cover 100 km during the Ethiopian New Year month.", nil, nil, nil, nil, "", "", 100, 0, 0, "", 0, 2000, 8421),
		def("ch6", "segment_sprint", "Unity Park 400 Crown", "Take the crown on the Unity Park 400 segment.", f(9.0130), f(38.7540), f(9.0160), f(38.7570), "Unity Park", "Unity Park Straight", 0.4, 0, 0, "s6", 50, 500, 6402),
		def("ch7", "relay", "Addis to Lalibela Relay", "A community relay across 780 km of highland road.", nil, nil, nil, nil, "", "", 780, 0, 0, "", 0, 5000, 12640),
	}
}
