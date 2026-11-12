package main

import (
	"math"
	"sort"
	"sync"
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
	AddSegment(s Segment) error
	HallOfFame() ([]HallEntry, error)
	Clubs() ([]Club, error)
	AddClub(c Club) error
	JoinClub(id, athlete, athleteName string) error
	LeaveClub(id, athlete string) error
	ClubMembers(id string) (map[string]string, error)
	CommunityPosts(clubID string) ([]CommunityPost, error)
	CommunityFeed(limit int) ([]CommunityPost, error)
	AddCommunityPost(p CommunityPost) error
}

type MemStore struct {
	mu          sync.RWMutex
	activities  []Activity
	gallery     []GalleryCard
	challenges  []Challenge
	joined      map[string]bool
	members     map[string]map[string]string
	progress    map[string]map[string]ChallengeProgress
	places      []Place
	segments    []Segment
	clubs       []Club
	clubMembers map[string]map[string]string
	community   []CommunityPost
}

func NewMemStore() *MemStore {
	return &MemStore{
		activities:  []Activity{},
		gallery:     []GalleryCard{},
		challenges:  []Challenge{},
		joined:      map[string]bool{},
		members:     map[string]map[string]string{},
		progress:    map[string]map[string]ChallengeProgress{},
		places:      seedPlaces(),
		segments:    []Segment{},
		clubs:       []Club{},
		clubMembers: map[string]map[string]string{},
		community:   []CommunityPost{},
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
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt > out[j].CreatedAt })
	return out, nil
}

func (s *MemStore) AddSegment(seg Segment) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i := range s.segments {
		if s.segments[i].ID == seg.ID {
			s.segments[i] = seg
			return nil
		}
	}
	s.segments = append([]Segment{seg}, s.segments...)
	return nil
}

func (s *MemStore) PopularAreas() ([]PopularArea, error) {
	s.mu.RLock()
	activities := make([]Activity, len(s.activities))
	copy(activities, s.activities)
	places := make([]Place, len(s.places))
	copy(places, s.places)
	s.mu.RUnlock()
	return clusterPopularAreas(activities, places), nil
}

func (s *MemStore) HallOfFame() ([]HallEntry, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := []HallEntry{}
	for _, sg := range s.segments {
		if sg.BestSeconds <= 0 {
			continue
		}
		place, _ := nearestPlace(s.places, sg.StartLat, sg.StartLng)
		name := sg.BestAthleteName
		if name == "" {
			name = sg.OwnerName
		}
		if name == "" {
			name = "Athlete"
		}
		out = append(out, HallEntry{
			SegmentID: sg.ID, SegmentName: sg.Name,
			AthleteName: name, Seconds: sg.BestSeconds,
			StartLat: sg.StartLat, StartLng: sg.StartLng, PlaceName: place,
		})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Seconds < out[j].Seconds })
	return out, nil
}

func (s *MemStore) Clubs() ([]Club, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]Club, len(s.clubs))
	copy(out, s.clubs)
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt > out[j].CreatedAt })
	return out, nil
}

func (s *MemStore) AddClub(c Club) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i := range s.clubs {
		if s.clubs[i].ID == c.ID {
			s.clubs[i] = c
			return nil
		}
	}
	s.clubs = append([]Club{c}, s.clubs...)
	return nil
}

func (s *MemStore) JoinClub(id, athlete, athleteName string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if athlete == "" {
		athlete = "me"
	}
	if s.clubMembers[id] == nil {
		s.clubMembers[id] = map[string]string{}
	}
	if _, exists := s.clubMembers[id][athlete]; exists {
		return nil
	}
	s.clubMembers[id][athlete] = athleteName
	for i := range s.clubs {
		if s.clubs[i].ID == id {
			s.clubs[i].Members++
			return nil
		}
	}
	return nil
}

func (s *MemStore) LeaveClub(id, athlete string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.clubMembers[id] == nil {
		return nil
	}
	if _, exists := s.clubMembers[id][athlete]; !exists {
		return nil
	}
	delete(s.clubMembers[id], athlete)
	for i := range s.clubs {
		if s.clubs[i].ID == id {
			if s.clubs[i].Members > 0 {
				s.clubs[i].Members--
			}
			return nil
		}
	}
	return nil
}

func (s *MemStore) ClubMembers(id string) (map[string]string, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := map[string]string{}
	for k, v := range s.clubMembers[id] {
		out[k] = v
	}
	return out, nil
}

func (s *MemStore) CommunityPosts(clubID string) ([]CommunityPost, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := []CommunityPost{}
	for _, p := range s.community {
		if p.ClubID == clubID {
			out = append(out, p)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt > out[j].CreatedAt })
	return out, nil
}

func (s *MemStore) AddCommunityPost(p CommunityPost) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i := range s.community {
		if s.community[i].ID == p.ID {
			s.community[i] = p
			return nil
		}
	}
	s.community = append([]CommunityPost{p}, s.community...)
	return nil
}

func (s *MemStore) CommunityFeed(limit int) ([]CommunityPost, error) {
	if limit <= 0 || limit > 200 {
		limit = 100
	}
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]CommunityPost, len(s.community))
	copy(out, s.community)
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt > out[j].CreatedAt })
	if len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}

// clusterPopularAreas groups activity start points that are within 500 metres
// of each other. The cluster centre is the average of its starts, and the name
// comes from the nearest well-known place seeded on the server. This is the
// same rule the app describes to athletes: train in the same area and the app
// automatically surfaces that area, without anyone posting it manually.
func clusterPopularAreas(activities []Activity, places []Place) []PopularArea {
	type start struct {
		lat, lng float64
	}
	starts := make([]start, 0, len(activities))
	for _, a := range activities {
		lat, lng := a.StartLat, a.StartLng
		if (lat == 0 && lng == 0) && len(a.Track) > 0 {
			lat, lng = a.Track[0].Lat, a.Track[0].Lng
		}
		if lat == 0 && lng == 0 {
			continue
		}
		starts = append(starts, start{lat: lat, lng: lng})
	}

	const radiusKm = 0.5
	used := make([]bool, len(starts))
	out := []PopularArea{}
	for i := range starts {
		if used[i] {
			continue
		}
		used[i] = true
		cluster := []start{starts[i]}
		for j := i + 1; j < len(starts); j++ {
			if used[j] {
				continue
			}
			if haversineKm(starts[i].lat, starts[i].lng, starts[j].lat, starts[j].lng) <= radiusKm {
				used[j] = true
				cluster = append(cluster, starts[j])
			}
		}

		var latSum, lngSum float64
		for _, p := range cluster {
			latSum += p.lat
			lngSum += p.lng
		}
		lat := latSum / float64(len(cluster))
		lng := lngSum / float64(len(cluster))
		name, city := popularAreaName(places, lat, lng)
		out = append(out, PopularArea{
			Lat:      math.Round(lat*100000) / 100000,
			Lng:      math.Round(lng*100000) / 100000,
			RunCount: len(cluster),
			Name:     name,
			City:     city,
		})
	}

	sort.Slice(out, func(i, j int) bool {
		if out[i].RunCount == out[j].RunCount {
			return out[i].Name < out[j].Name
		}
		return out[i].RunCount > out[j].RunCount
	})
	if len(out) > 12 {
		out = out[:12]
	}
	return out
}

// popularAreaName prefers a well-known landmark within 2.5 km. Farther out it
// falls back to the nearest town/city so every automatically discovered area
// still has a human-readable label.
func popularAreaName(places []Place, lat, lng float64) (string, string) {
	best := math.MaxFloat64
	name, city := "", ""
	for _, p := range places {
		d := haversineKm(lat, lng, p.Lat, p.Lng)
		if d < best {
			best, name, city = d, p.Name, p.City
		}
	}
	if best <= 2.5 && name != "" {
		return name, city
	}
	if city != "" && best <= 40 {
		return city + " training area", city
	}
	return "Open country", ""
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
