package main

type TrackPoint struct {
	Lat float64 `json:"lat"`
	Lng float64 `json:"lng"`
	Ele float64 `json:"ele"`
	D   float64 `json:"d"`
	T   int64   `json:"t,omitempty"`
	Acc float64 `json:"accuracy,omitempty"`
	HR  int     `json:"hr,omitempty"`
	Cad int     `json:"cad,omitempty"`
	Pw  int     `json:"pw,omitempty"`
}

type Activity struct {
	ID             string       `json:"id"`
	OwnerID        string       `json:"ownerId,omitempty"`
	OwnerName      string       `json:"ownerName,omitempty"`
	Visibility     string       `json:"visibility,omitempty"`
	Title          string       `json:"title"`
	Type           string       `json:"type"`
	AthleteID      string       `json:"athleteId"`
	AthleteName    string       `json:"athleteName"`
	City           string       `json:"city"`
	StartLat       float64      `json:"startLat"`
	StartLng       float64      `json:"startLng"`
	EndLat         float64      `json:"endLat"`
	EndLng         float64      `json:"endLng"`
	DistanceKm     float64      `json:"distanceKm"`
	DurationSec    int          `json:"durationSec"`
	PaceSecPerKm   float64      `json:"paceSecPerKm"`
	ElevationGainM int          `json:"elevationGainM"`
	Calories       int          `json:"calories"`
	AvgHR          *int         `json:"avgHr"`
	HRSource       string       `json:"hrSource"`
	MaxHR          *int         `json:"maxHr,omitempty"`
	AvgCadence     *int         `json:"avgCadence,omitempty"`
	AvgPowerW      *int         `json:"avgPowerW,omitempty"`
	GPSAccuracyM   float64      `json:"gpsAccuracyM"`
	Source         string       `json:"source"`
	Track          []TrackPoint `json:"track"`
	StartedAt      string       `json:"startedAt"`
	CreatedAt      string       `json:"createdAt"`
}

type GalleryCard struct {
	ID         string  `json:"id"`
	OwnerID    string  `json:"ownerId,omitempty"`
	Visibility string  `json:"visibility,omitempty"`
	Title      string  `json:"title"`
	ActivityID string  `json:"activityId"`
	ImageData  string  `json:"imageData"`
	DistanceKm float64 `json:"distanceKm"`
	Duration   string  `json:"duration"`
	City       string  `json:"city"`
	CreatedAt  string  `json:"createdAt"`
}

type Challenge struct {
	ID               string   `json:"id"`
	Kind             string   `json:"kind"`
	Title            string   `json:"title"`
	Description      string   `json:"description"`
	StartLat         *float64 `json:"startLat"`
	StartLng         *float64 `json:"startLng"`
	StartName        string   `json:"startName"`
	EndLat           *float64 `json:"endLat"`
	EndLng           *float64 `json:"endLng"`
	EndName          string   `json:"endName"`
	TargetKm         float64  `json:"targetKm"`
	TargetSeconds    int      `json:"targetSeconds"`
	TargetElevationM int      `json:"targetElevationM"`
	SegmentID        string   `json:"segmentId"`
	GeofenceM        int      `json:"geofenceM"`
	PrizeBr          int      `json:"prizeBr"`
	Members          int      `json:"members"`
	Joined           bool     `json:"joined"`
	CreatedBy        string   `json:"createdBy"`
	EndsAt           string   `json:"endsAt"`
	OwnerID          string   `json:"ownerId,omitempty"`
	OwnerName        string   `json:"ownerName,omitempty"`
	Visibility       string   `json:"visibility,omitempty"`
	Mode             string   `json:"mode,omitempty"`
	OpponentID       string   `json:"opponentId,omitempty"`
	OpponentName     string   `json:"opponentName,omitempty"`
	InviteStatus     string   `json:"inviteStatus,omitempty"`
	AutoStop         bool     `json:"autoStop,omitempty"`
	CreatedAt        string   `json:"createdAt,omitempty"`
}

type ChallengeProgress struct {
	ChallengeID string  `json:"challengeId"`
	AthleteID   string  `json:"athleteId"`
	AthleteName string  `json:"athleteName"`
	DistanceKm  float64 `json:"distanceKm"`
	DurationSec int     `json:"durationSec"`
	ElevationM  int     `json:"elevationM"`
	Completed   bool    `json:"completed"`
	BestSeconds int     `json:"bestSeconds"`
	Attempts    int     `json:"attempts"`
	FinishedAt  string  `json:"finishedAt"`
	UpdatedAt   string  `json:"updatedAt"`
}

type LeaderRow struct {
	Rank          int     `json:"rank"`
	AthleteID     string  `json:"athleteId"`
	AthleteName   string  `json:"athleteName"`
	Progress      float64 `json:"progress"`
	ProgressLabel string  `json:"progressLabel"`
	Target        float64 `json:"target"`
	Unit          string  `json:"unit"`
	Completed     bool    `json:"completed"`
	Result        string  `json:"result"`
	FinishedAt    string  `json:"finishedAt"`
	Me            bool    `json:"me"`
}

type Leaderboard struct {
	ChallengeID string      `json:"challengeId"`
	Ranking     string      `json:"ranking"`
	Metric      string      `json:"metric"`
	Unit        string      `json:"unit"`
	Target      float64     `json:"target"`
	Rows        []LeaderRow `json:"rows"`
	ViewerID    string      `json:"viewerId"`
	Joined      bool        `json:"joined"`
}

type Place struct {
	Name string  `json:"name"`
	Lat  float64 `json:"lat"`
	Lng  float64 `json:"lng"`
	Kind string  `json:"kind"`
	City string  `json:"city"`
}

type Segment struct {
	ID              string  `json:"id"`
	Name            string  `json:"name"`
	City            string  `json:"city"`
	StartLat        float64 `json:"startLat"`
	StartLng        float64 `json:"startLng"`
	EndLat          float64 `json:"endLat"`
	EndLng          float64 `json:"endLng"`
	Km              float64 `json:"km"`
	GainM           int     `json:"gainM"`
	Cat             string  `json:"cat"`
	Type            string  `json:"type"`
	BestSeconds     int     `json:"bestSeconds"`
	Attempts        int     `json:"attempts"`
	OwnerID         string  `json:"ownerId,omitempty"`
	OwnerName       string  `json:"ownerName,omitempty"`
	BestAthleteID   string  `json:"bestAthleteId,omitempty"`
	BestAthleteName string  `json:"bestAthleteName,omitempty"`
	ActivityID      string  `json:"activityId,omitempty"`
	CreatedAt       string  `json:"createdAt,omitempty"`
}

type Club struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	City        string `json:"city"`
	Type        string `json:"type"`
	Color       string `json:"color"`
	OwnerID     string `json:"ownerId,omitempty"`
	OwnerName   string `json:"ownerName,omitempty"`
	Members     int    `json:"members"`
	Joined      bool   `json:"joined"`
	CreatedAt   string `json:"createdAt,omitempty"`
}

// CommunityPost is one message or event in a community channel.
//
// A community works like a Telegram channel and group combined: joined members
// read the channel and post messages, while join events and challenge
// announcements are published automatically as system posts.
type CommunityPost struct {
	ID          string  `json:"id"`
	ClubID      string  `json:"clubId"`
	ClubName    string  `json:"clubName,omitempty"`
	AuthorID    string  `json:"authorId,omitempty"`
	AuthorName  string  `json:"authorName,omitempty"`
	Kind        string  `json:"kind"`
	Title       string  `json:"title"`
	Body        string  `json:"body,omitempty"`
	ActivityID  string  `json:"activityId,omitempty"`
	ChallengeID string  `json:"challengeId,omitempty"`
	SegmentID   string  `json:"segmentId,omitempty"`
	DistanceKm  float64 `json:"distanceKm,omitempty"`
	DurationSec int     `json:"durationSec,omitempty"`
	ElevationM  int     `json:"elevationM,omitempty"`
	City        string  `json:"city,omitempty"`
	CreatedAt   string  `json:"createdAt"`
}

type PopularArea struct {
	Lat      float64 `json:"lat"`
	Lng      float64 `json:"lng"`
	RunCount int     `json:"runCount"`
	Name     string  `json:"name"`
	City     string  `json:"city"`
}

type HallEntry struct {
	SegmentID   string  `json:"segmentId"`
	SegmentName string  `json:"segmentName"`
	AthleteName string  `json:"athleteName"`
	Seconds     int     `json:"seconds"`
	StartLat    float64 `json:"startLat"`
	StartLng    float64 `json:"startLng"`
	PlaceName   string  `json:"placeName"`
}
