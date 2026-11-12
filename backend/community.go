package main

import (
	"fmt"
	"net/http"
	"strings"
	"time"
)

// Community posts are the shared channel/group timeline for a club. A post is
// either a normal group message (`kind: chat` / `message`) or a channel event
// such as a join notice, challenge announcement, activity, milestone, journey
// or segment share.
func handleCommunityPosts(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		clubID := strings.TrimSpace(r.URL.Query().Get("clubId"))
		if clubID == "" {
			fail(w, 400, "clubId is required")
			return
		}
		posts, err := store.CommunityPosts(clubID)
		if err != nil {
			failInternal(w, err)
			return
		}
		// Channels are readable by everyone; group chat is for members only.
		viewer := currentViewer(tokenFrom(r))
		isMember := false
		if viewer.ID != "" {
			members, _ := store.ClubMembers(clubID)
			isMember = members[viewer.ID] != ""
		}
		if !isMember {
			visible := make([]CommunityPost, 0, len(posts))
			for _, post := range posts {
				if isChannelKind(post.Kind) {
					visible = append(visible, post)
				}
			}
			posts = visible
		}
		writeJSON(w, posts)
	case http.MethodPost:
		v := currentViewer(tokenFrom(r))
		if v.ID == "" {
			fail(w, 401, "sign in to post in a community")
			return
		}
		var post CommunityPost
		if err := decode(r, w, &post); err != nil {
			fail(w, 400, "invalid JSON: "+err.Error())
			return
		}
		post.ClubID = strings.TrimSpace(post.ClubID)
		if post.ClubID == "" {
			fail(w, 400, "clubId is required")
			return
		}
		club, found := clubByID(post.ClubID)
		if !found {
			fail(w, 404, "community not found")
			return
		}
		members, _ := store.ClubMembers(post.ClubID)
		if members[v.ID] == "" {
			fail(w, 403, "join this community before posting")
			return
		}

		post.Kind = strings.ToLower(strings.TrimSpace(post.Kind))
		if !validMemberPostKind(post.Kind) {
			post.Kind = "message"
		}
		if post.Kind == "chat" {
			post.Kind = "message"
		}
		post.Title = strings.TrimSpace(post.Title)
		post.Body = strings.TrimSpace(post.Body)
		if post.Title == "" && post.Body == "" {
			fail(w, 400, "write a message first")
			return
		}
		if len(post.Title) > 120 {
			post.Title = post.Title[:120]
		}
		if len(post.Body) > 2000 {
			post.Body = post.Body[:2000]
		}
		post.ID = fmt.Sprintf("cpost_%d", time.Now().UnixNano())
		post.CreatedAt = nowISO()
		post.AuthorID = v.ID
		post.AuthorName = v.Username
		post.ClubName = club.Name
		if err := store.AddCommunityPost(post); err != nil {
			failInternal(w, err)
			return
		}
		writeJSON(w, post)
	default:
		fail(w, 405, "GET or POST only")
	}
}

// handleCommunityFeed is the public channel stream: join notices, challenge
// announcements and shared training updates. Group chat stays inside its club
// and is never exposed here, because feed readers may not be club members.
func handleCommunityFeed(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		fail(w, 405, "GET only")
		return
	}
	posts, err := store.CommunityFeed(100)
	if err != nil {
		failInternal(w, err)
		return
	}
	out := make([]CommunityPost, 0, len(posts))
	for _, post := range posts {
		if isChannelKind(post.Kind) {
			out = append(out, post)
		}
	}
	writeJSON(w, out)
}

// isChannelKind reports whether a community post belongs in the shared
// channel stream rather than the members-only group conversation.
func isChannelKind(kind string) bool {
	switch kind {
	case "join", "challenge", "activity", "milestone", "journey", "segment", "system":
		return true
	default:
		return false
	}
}

func validCommunityKind(kind string) bool {
	switch kind {
	case "message", "chat", "activity", "milestone", "journey", "segment", "challenge", "join", "system":
		return true
	default:
		return false
	}
}

// Members may share training updates, but system events (join notices,
// challenge announcements) can only be created by the server itself.
func validMemberPostKind(kind string) bool {
	switch kind {
	case "message", "chat", "activity", "milestone", "journey", "segment":
		return true
	default:
		return false
	}
}

func clubByID(id string) (Club, bool) {
	clubs, err := store.Clubs()
	if err != nil {
		return Club{}, false
	}
	for _, club := range clubs {
		if club.ID == id {
			return club, true
		}
	}
	return Club{}, false
}

func publishCommunityPost(post CommunityPost) error {
	if post.ID == "" {
		post.ID = fmt.Sprintf("cpost_%d", time.Now().UnixNano())
	}
	if post.CreatedAt == "" {
		post.CreatedAt = nowISO()
	}
	if post.Kind == "" {
		post.Kind = "system"
	}
	return store.AddCommunityPost(post)
}

func publishJoinNotice(club Club, athleteID, athleteName string) {
	if athleteName == "" {
		athleteName = "A new athlete"
	}
	_ = publishCommunityPost(CommunityPost{
		ClubID:     club.ID,
		ClubName:   club.Name,
		AuthorID:   athleteID,
		AuthorName: athleteName,
		Kind:       "join",
		Title:      athleteName + " joined " + club.Name,
		Body:       "Welcome to the community! Say hello in the group and share your next run or ride.",
		City:       club.City,
	})
}

// announceChallenge publishes a challenge to every community the creator
// belongs to. Creators without a club still reach the global RUCHA feed.
func announceChallenge(c Challenge, v Viewer) {
	title := "New challenge: " + c.Title
	body := c.Description
	if body == "" {
		body = "Open the Challenges tab to join."
	}
	posted := false
	clubs, _ := store.Clubs()
	for _, club := range clubs {
		members, _ := store.ClubMembers(club.ID)
		if v.ID == "" || members[v.ID] == "" {
			continue
		}
		_ = publishCommunityPost(CommunityPost{
			ClubID:      club.ID,
			ClubName:    club.Name,
			AuthorID:    v.ID,
			AuthorName:  firstNonEmpty(v.Username, c.CreatedBy, "RUCHA"),
			Kind:        "challenge",
			Title:       title,
			Body:        body,
			ChallengeID: c.ID,
			City:        club.City,
		})
		posted = true
	}
	if !posted {
		_ = publishCommunityPost(CommunityPost{
			ClubID:      "rucha",
			ClubName:    "RUCHA Community",
			AuthorID:    v.ID,
			AuthorName:  firstNonEmpty(v.Username, c.CreatedBy, "RUCHA"),
			Kind:        "challenge",
			Title:       title,
			Body:        body,
			ChallengeID: c.ID,
		})
	}
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return ""
}
