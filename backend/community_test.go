package main

import "testing"

func TestPublishJoinNoticeCreatesCommunityPost(t *testing.T) {
	previous := store
	defer func() { store = previous }()
	store = NewMemStore()

	club := Club{ID: "club_test", Name: "Test Club", City: "Addis Ababa"}
	publishJoinNotice(club, "athlete_1", "Abebe Bikila")

	posts, err := store.CommunityPosts(club.ID)
	if err != nil {
		t.Fatalf("reading community posts: %v", err)
	}
	if len(posts) != 1 {
		t.Fatalf("expected one join notice, got %d", len(posts))
	}
	if posts[0].Kind != "join" {
		t.Fatalf("expected join kind, got %q", posts[0].Kind)
	}
	if posts[0].AuthorName != "Abebe Bikila" {
		t.Fatalf("expected author name, got %q", posts[0].AuthorName)
	}
}

func TestAnnounceChallengeFallsBackToGlobalFeed(t *testing.T) {
	previous := store
	defer func() { store = previous }()
	store = NewMemStore()

	announceChallenge(
		Challenge{ID: "ch_1", Title: "Highland 10K", Description: "Run ten kilometres"},
		Viewer{ID: "athlete_1", Username: "Abebe"},
	)

	posts, err := store.CommunityFeed(10)
	if err != nil {
		t.Fatalf("reading community feed: %v", err)
	}
	if len(posts) != 1 {
		t.Fatalf("expected one challenge post, got %d", len(posts))
	}
	if posts[0].Kind != "challenge" || posts[0].ChallengeID != "ch_1" {
		t.Fatalf("unexpected challenge post: %+v", posts[0])
	}
	if posts[0].ClubID != "rucha" {
		t.Fatalf("expected global feed fallback, got club %q", posts[0].ClubID)
	}
}

func TestAnnounceChallengePostsToMemberClubs(t *testing.T) {
	previous := store
	defer func() { store = previous }()
	store = NewMemStore()
	club := Club{ID: "club_1", Name: "Bole Runners", City: "Addis Ababa"}
	_ = store.AddClub(club)
	_ = store.JoinClub(club.ID, "athlete_1", "Abebe")

	announceChallenge(
		Challenge{ID: "ch_2", Title: "Entoto Hill Repeats"},
		Viewer{ID: "athlete_1", Username: "Abebe"},
	)

	posts, err := store.CommunityPosts(club.ID)
	if err != nil {
		t.Fatalf("reading club posts: %v", err)
	}
	if len(posts) != 1 || posts[0].Kind != "challenge" {
		t.Fatalf("expected the challenge in the club channel, got %+v", posts)
	}
	if posts[0].AuthorName != "Abebe" {
		t.Fatalf("expected creator name, got %q", posts[0].AuthorName)
	}
}

func TestCommunityKindValidation(t *testing.T) {
	valid := []string{
		"message", "chat", "activity", "milestone", "journey",
		"segment", "challenge", "join", "system",
	}
	for _, kind := range valid {
		if !validCommunityKind(kind) {
			t.Fatalf("expected %q to be valid", kind)
		}
	}
	if validCommunityKind("prize") {
		t.Fatal("unexpected valid community kind")
	}
	if validMemberPostKind("join") || validMemberPostKind("challenge") {
		t.Fatal("members must not be able to publish system events")
	}
	if !validMemberPostKind("milestone") || !validMemberPostKind("activity") {
		t.Fatal("members must be able to share training updates")
	}
}

func TestChannelFeedExcludesGroupChat(t *testing.T) {
	for _, kind := range []string{"message", "chat"} {
		if isChannelKind(kind) {
			t.Fatalf("%q must stay inside the group", kind)
		}
	}
	for _, kind := range []string{"join", "challenge", "activity", "milestone", "journey", "segment", "system"} {
		if !isChannelKind(kind) {
			t.Fatalf("%q must appear in the shared channel feed", kind)
		}
	}
}
