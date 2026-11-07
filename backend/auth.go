package main

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"net/http"
	"regexp"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"
)

var auth Auth

var usernameRE = regexp.MustCompile(`^[a-z0-9_]{3,20}$`)

var (
	errUserTaken    = errors.New("that username is already taken")
	errBadUsername  = errors.New("username must be 3-20 characters: letters, numbers and _ only")
	errBadPassword  = errors.New("password must be at least 6 characters")
	errBadCreds     = errors.New("wrong username or password")
	errNoUser       = errors.New("user not found")
	errNotAuthed    = errors.New("sign in required")
	errSelf         = errors.New("you cannot add yourself")
	errAlreadyAsked = errors.New("a friend request already exists")
	errNoRequest    = errors.New("friend request not found")
)

type User struct {
	ID          string `json:"id"`
	Username    string `json:"username"`
	DisplayName string `json:"displayName"`
	City        string `json:"city"`
	CreatedAt   string `json:"createdAt"`
}

type userRecord struct {
	User
	Hash       string `json:"hash"`
	Provider   string `json:"provider,omitempty"`
	ProviderID string `json:"providerId,omitempty"`
}

type FriendEdge struct {
	ID            string `json:"id"`
	RequesterID   string `json:"requesterId"`
	RequesterName string `json:"requesterName"`
	AddresseeID   string `json:"addresseeId"`
	AddresseeName string `json:"addresseeName"`
	Status        string `json:"status"`
	CreatedAt     string `json:"createdAt"`
}

type Share struct {
	ID             string `json:"id"`
	OwnerID        string `json:"ownerId"`
	OwnerName      string `json:"ownerName"`
	ActivityID     string `json:"activityId"`
	ActivityTitle  string `json:"activityTitle"`
	SharedWithID   string `json:"sharedWithId"`
	SharedWithName string `json:"sharedWithName"`
	Public         bool   `json:"public"`
	CreatedAt      string `json:"createdAt"`
}

type FriendState struct {
	Incoming []FriendEdge `json:"incoming"`
	Outgoing []FriendEdge `json:"outgoing"`
	Friends  []User       `json:"friends"`
}

type Auth interface {
	Kind() string
	Register(username, password, displayName string) (User, string, error)
	Login(username, password string) (User, string, error)
	SocialLogin(provider, providerID, displayName, usernameHint string) (User, string, error)
	Logout(token string) error
	Me(token string) (User, error)
	SearchUsers(q, excludeID string) ([]User, error)
	SendRequest(fromID, username string) (FriendEdge, error)
	Respond(userID, edgeID, action string) error
	RemoveFriend(userID, otherID string) error
	FriendState(userID string) (FriendState, error)
	FriendIDs(userID string) (map[string]bool, error)
	AddShare(ownerID, activityID, activityTitle, username string, public bool) (Share, error)
	RemoveShare(userID, shareID string) error
	Shares(userID string) ([]Share, error)
	SharedWith(userID string) (map[string]bool, error)
	PublicActivityIDs() (map[string]bool, error)
	PublicShareExists(activityID string) (bool, error)
}

func normUsername(s string) string { return strings.ToLower(strings.TrimSpace(s)) }

func newID(prefix string) string {
	b := make([]byte, 12)
	if _, err := rand.Read(b); err != nil {
		return fmt.Sprintf("%s_%d", prefix, time.Now().UnixNano())
	}
	return prefix + "_" + hex.EncodeToString(b)
}

func newToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

func hashPassword(pw string) (string, error) {
	b, err := bcrypt.GenerateFromPassword([]byte(pw), bcrypt.DefaultCost)
	return string(b), err
}

func checkPassword(hash, pw string) bool {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(pw)) == nil
}

type authCore struct{ d authData }

func (a *authCore) Kind() string { return a.d.Kind() }

func (a *authCore) Register(username, password, displayName string) (User, string, error) {
	username = normUsername(username)
	if !usernameRE.MatchString(username) {
		return User{}, "", errBadUsername
	}
	if len(password) < 6 {
		return User{}, "", errBadPassword
	}
	if _, err := a.d.userByName(username); err == nil {
		return User{}, "", errUserTaken
	}
	hash, err := hashPassword(password)
	if err != nil {
		return User{}, "", err
	}
	name := strings.TrimSpace(displayName)
	if name == "" {
		name = username
	}
	if len(name) > 48 {
		name = name[:48]
	}
	u := &userRecord{
		User: User{ID: newID("usr"), Username: username, DisplayName: name,
			City: "Addis Ababa", CreatedAt: nowISO()},
		Hash: hash,
	}
	if err := a.d.insertUser(u); err != nil {
		return User{}, "", err
	}
	tok, err := a.issue(u.User)
	if err != nil {
		return User{}, "", err
	}
	return u.User, tok, nil
}

func (a *authCore) issue(u User) (string, error) {
	tok, err := newToken()
	if err != nil {
		return "", err
	}
	if err := a.d.insertSession(tok, u.ID, time.Now().UTC().AddDate(0, 0, 30)); err != nil {
		return "", err
	}
	return tok, nil
}

func (a *authCore) Login(username, password string) (User, string, error) {
	u, err := a.d.userByName(normUsername(username))
	if err != nil || u == nil {
		return User{}, "", errBadCreds
	}
	if !checkPassword(u.Hash, password) {
		return User{}, "", errBadCreds
	}
	tok, err := a.issue(u.User)
	if err != nil {
		return User{}, "", err
	}
	return u.User, tok, nil
}

func (a *authCore) Logout(token string) error { return a.d.deleteSession(token) }

func (a *authCore) Me(token string) (User, error) {
	u, err := a.d.sessionUser(token)
	if err != nil || u == nil {
		return User{}, errNotAuthed
	}
	return u.User, nil
}

func (a *authCore) SearchUsers(q, excludeID string) ([]User, error) {
	rows, err := a.d.listUsers(normUsername(q), excludeID)
	if err != nil {
		return nil, err
	}
	out := make([]User, 0, len(rows))
	for _, u := range rows {
		out = append(out, u.User)
	}
	return out, nil
}

func (a *authCore) SendRequest(fromID, username string) (FriendEdge, error) {
	from, err := a.d.userByID(fromID)
	if err != nil || from == nil {
		return FriendEdge{}, errNotAuthed
	}
	to, err := a.d.userByName(normUsername(username))
	if err != nil || to == nil {
		return FriendEdge{}, errNoUser
	}
	if to.ID == fromID {
		return FriendEdge{}, errSelf
	}
	if e, _ := a.d.findEdge(fromID, to.ID); e != nil {
		if e.Status == "accepted" {
			return FriendEdge{}, errors.New("you are already friends")
		}
		return FriendEdge{}, errAlreadyAsked
	}
	e := &FriendEdge{ID: newID("fr"), RequesterID: from.ID, RequesterName: from.Username,
		AddresseeID: to.ID, AddresseeName: to.Username, Status: "pending", CreatedAt: nowISO()}
	if err := a.d.insertEdge(e); err != nil {
		return FriendEdge{}, err
	}
	return *e, nil
}

func (a *authCore) Respond(userID, edgeID, action string) error {
	e, err := a.d.edgeByID(edgeID)
	if err != nil || e == nil {
		return errNoRequest
	}
	if e.AddresseeID != userID || e.Status != "pending" {
		return errNoRequest
	}
	if action == "accept" {
		e.Status = "accepted"
		return a.d.updateEdge(e)
	}
	if action == "decline" {
		return a.d.deleteEdge(edgeID)
	}
	return errors.New("action must be accept or decline")
}

func (a *authCore) RemoveFriend(userID, otherID string) error {
	e, err := a.d.findEdge(userID, otherID)
	if err != nil || e == nil {
		return errNoRequest
	}
	return a.d.deleteEdge(e.ID)
}

func (a *authCore) FriendState(userID string) (FriendState, error) {
	st := FriendState{Incoming: []FriendEdge{}, Outgoing: []FriendEdge{}, Friends: []User{}}
	edges, err := a.d.listEdges(userID)
	if err != nil {
		return st, err
	}
	for _, e := range edges {
		if e.Status == "pending" && e.AddresseeID == userID {
			st.Incoming = append(st.Incoming, *e)
		} else if e.Status == "pending" && e.RequesterID == userID {
			st.Outgoing = append(st.Outgoing, *e)
		} else if e.Status == "accepted" {
			otherID := e.RequesterID
			if otherID == userID {
				otherID = e.AddresseeID
			}
			if u, err := a.d.userByID(otherID); err == nil && u != nil {
				st.Friends = append(st.Friends, u.User)
			}
		}
	}
	return st, nil
}

func (a *authCore) FriendIDs(userID string) (map[string]bool, error) {
	st, err := a.FriendState(userID)
	if err != nil {
		return nil, err
	}
	m := map[string]bool{}
	for _, f := range st.Friends {
		m[f.ID] = true
	}
	return m, nil
}

func (a *authCore) AddShare(ownerID, activityID, activityTitle, username string, public bool) (Share, error) {
	owner, err := a.d.userByID(ownerID)
	if err != nil || owner == nil {
		return Share{}, errNotAuthed
	}
	s := Share{ID: newID("sh"), OwnerID: owner.ID, OwnerName: owner.Username,
		ActivityID: activityID, ActivityTitle: activityTitle, Public: public, CreatedAt: nowISO()}
	if !public {
		if username == "" {
			return Share{}, errors.New("choose a friend or make the link public")
		}
		to, err := a.d.userByName(normUsername(username))
		if err != nil || to == nil {
			return Share{}, errNoUser
		}
		if to.ID == ownerID {
			return Share{}, errSelf
		}
		s.SharedWithID, s.SharedWithName = to.ID, to.Username
	}
	shares, _ := a.d.listShares()
	for _, old := range shares {
		if old.ActivityID == activityID && old.SharedWithID == s.SharedWithID && old.Public == s.Public {
			return *old, nil
		}
	}
	if err := a.d.insertShare(&s); err != nil {
		return Share{}, err
	}
	return s, nil
}

func (a *authCore) RemoveShare(userID, shareID string) error {
	s, err := a.d.shareByID(shareID)
	if err != nil || s == nil {
		return errors.New("share not found")
	}
	if s.OwnerID != userID {
		return errors.New("only the owner can remove a share")
	}
	return a.d.deleteShare(shareID)
}

func (a *authCore) Shares(userID string) ([]Share, error) {
	all, err := a.d.listShares()
	if err != nil {
		return nil, err
	}
	out := []Share{}
	for _, s := range all {
		if s.OwnerID == userID {
			out = append(out, *s)
		}
	}
	return out, nil
}

func (a *authCore) SharedWith(userID string) (map[string]bool, error) {
	all, err := a.d.listShares()
	if err != nil {
		return nil, err
	}
	m := map[string]bool{}
	for _, s := range all {
		if s.SharedWithID == userID {
			m[s.ActivityID] = true
		}
	}
	return m, nil
}

func (a *authCore) PublicActivityIDs() (map[string]bool, error) {
	all, err := a.d.listShares()
	if err != nil {
		return nil, err
	}
	m := map[string]bool{}
	for _, s := range all {
		if s.Public {
			m[s.ActivityID] = true
		}
	}
	return m, nil
}

func (a *authCore) PublicShareExists(activityID string) (bool, error) {
	m, err := a.PublicActivityIDs()
	if err != nil {
		return false, err
	}
	return m[activityID], nil
}

type Viewer struct {
	ID       string
	Username string
	Friends  map[string]bool
	Shared   map[string]bool
}

func currentViewer(token string) Viewer {
	v := Viewer{ID: "", Friends: map[string]bool{}, Shared: map[string]bool{}}
	if token != "" {
		if u, err := auth.Me(token); err == nil {
			v.ID, v.Username = u.ID, u.Username
			if f, err := auth.FriendIDs(u.ID); err == nil {
				v.Friends = f
			}
			if s, err := auth.SharedWith(u.ID); err == nil {
				v.Shared = s
			}
		}
	}

	if p, err := auth.PublicActivityIDs(); err == nil {
		for id := range p {
			v.Shared[id] = true
		}
	}
	return v
}

func canSeeActivity(ownerID, visibility, activityID string, v Viewer) bool {
	if ownerID == "" || visibility == "public" {
		return true
	}
	if v.Shared[activityID] {
		return true
	}
	if v.ID == "" {
		return false
	}
	if ownerID == v.ID {
		return true
	}
	return visibility == "friends" && v.Friends[ownerID]
}

func canSeeGallery(ownerID, visibility, id string, v Viewer) bool {
	return canSeeActivity(ownerID, visibility, id, v)
}

func tokenFrom(r *http.Request) string {
	h := r.Header.Get("Authorization")
	if strings.HasPrefix(strings.ToLower(h), "bearer ") {
		return strings.TrimSpace(h[7:])
	}
	return r.URL.Query().Get("token")
}

func handleRegister(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		fail(w, 405, "POST only")
		return
	}
	var b struct {
		Username    string `json:"username"`
		Password    string `json:"password"`
		DisplayName string `json:"displayName"`
	}
	if err := decode(r, &b); err != nil {
		fail(w, 400, "invalid JSON")
		return
	}
	u, tok, err := auth.Register(b.Username, b.Password, b.DisplayName)
	if err != nil {
		fail(w, 400, err.Error())
		return
	}
	writeJSON(w, map[string]interface{}{"user": u, "token": tok})
}

func handleLogin(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		fail(w, 405, "POST only")
		return
	}
	var b struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if err := decode(r, &b); err != nil {
		fail(w, 400, "invalid JSON")
		return
	}
	u, tok, err := auth.Login(b.Username, b.Password)
	if err != nil {
		fail(w, 401, err.Error())
		return
	}
	writeJSON(w, map[string]interface{}{"user": u, "token": tok})
}

func handleLogout(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		fail(w, 405, "POST only")
		return
	}
	_ = auth.Logout(tokenFrom(r))
	writeJSON(w, map[string]bool{"ok": true})
}

func handleMe(w http.ResponseWriter, r *http.Request) {
	u, err := auth.Me(tokenFrom(r))
	if err != nil {
		writeJSON(w, map[string]interface{}{"user": nil})
		return
	}
	writeJSON(w, map[string]interface{}{"user": u})
}

func handleUsers(w http.ResponseWriter, r *http.Request) {
	v := currentViewer(tokenFrom(r))
	list, err := auth.SearchUsers(r.URL.Query().Get("q"), v.ID)
	if err != nil {
		fail(w, 500, err.Error())
		return
	}
	writeJSON(w, list)
}

func handleFriends(w http.ResponseWriter, r *http.Request) {
	v := currentViewer(tokenFrom(r))
	if v.ID == "" {
		fail(w, 401, errNotAuthed.Error())
		return
	}
	switch r.Method {
	case "GET":
		st, err := auth.FriendState(v.ID)
		if err != nil {
			fail(w, 500, err.Error())
			return
		}
		writeJSON(w, st)
	case "POST":
		var b struct {
			Username string `json:"username"`
			OtherID  string `json:"otherId"`
			Action   string `json:"action"`
			EdgeID   string `json:"edgeId"`
			Decision string `json:"decision"`
		}
		if err := decode(r, &b); err != nil {
			fail(w, 400, "invalid JSON")
			return
		}
		switch b.Action {
		case "respond":
			if err := auth.Respond(v.ID, b.EdgeID, b.Decision); err != nil {
				fail(w, 400, err.Error())
				return
			}
		case "remove":
			if err := auth.RemoveFriend(v.ID, b.Username); err != nil {
				fail(w, 400, err.Error())
				return
			}
		default:
			e, err := auth.SendRequest(v.ID, b.Username)
			if err != nil {
				fail(w, 400, err.Error())
				return
			}
			writeJSON(w, e)
			return
		}
		writeJSON(w, map[string]bool{"ok": true})
	default:
		fail(w, 405, "GET or POST only")
	}
}

func handleShares(w http.ResponseWriter, r *http.Request) {
	v := currentViewer(tokenFrom(r))
	if v.ID == "" {
		fail(w, 401, errNotAuthed.Error())
		return
	}
	switch r.Method {
	case "GET":
		list, err := auth.Shares(v.ID)
		if err != nil {
			fail(w, 500, err.Error())
			return
		}
		writeJSON(w, list)
	case "POST":
		var b struct {
			ActivityID    string `json:"activityId"`
			ActivityTitle string `json:"activityTitle"`
			Username      string `json:"username"`
			Public        bool   `json:"public"`
		}
		if err := decode(r, &b); err != nil {
			fail(w, 400, "invalid JSON")
			return
		}
		if b.ActivityID == "" {
			fail(w, 400, "activityId is required")
			return
		}
		s, err := auth.AddShare(v.ID, b.ActivityID, b.ActivityTitle, b.Username, b.Public)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, s)
	case "DELETE":
		if err := auth.RemoveShare(v.ID, r.URL.Query().Get("id")); err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, map[string]bool{"deleted": true})
	default:
		fail(w, 405, "GET, POST or DELETE only")
	}
}

func handleVisibility(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		fail(w, 405, "POST only")
		return
	}
	v := currentViewer(tokenFrom(r))
	if v.ID == "" {
		fail(w, 401, errNotAuthed.Error())
		return
	}
	var b struct {
		ID         string `json:"id"`
		Visibility string `json:"visibility"`
	}
	if err := decode(r, &b); err != nil {
		fail(w, 400, "invalid JSON")
		return
	}
	if b.Visibility != "private" && b.Visibility != "friends" && b.Visibility != "public" {
		fail(w, 400, "visibility must be private, friends or public")
		return
	}
	all, err := store.Activities()
	if err != nil {
		fail(w, 500, err.Error())
		return
	}
	for _, a := range all {
		if a.ID == b.ID {
			if a.OwnerID != "" && a.OwnerID != v.ID {
				fail(w, 403, "only the owner can change visibility")
				return
			}
			a.Visibility = b.Visibility
			if err := store.AddActivity(a); err != nil {
				fail(w, 500, err.Error())
				return
			}
			writeJSON(w, a)
			return
		}
	}
	fail(w, 404, "activity not found")
}

var nonUsernameChars = regexp.MustCompile(`[^a-z0-9_]+`)

// cleanUsername turns any display text into something that satisfies usernameRE (3-14 chars, leaving room for a suffix).
func cleanUsername(raw string) string {
	s := strings.ToLower(strings.TrimSpace(raw))
	s = strings.ReplaceAll(s, " ", "_")
	s = nonUsernameChars.ReplaceAllString(s, "")
	s = strings.Trim(s, "_")
	if len(s) > 14 {
		s = s[:14]
	}
	if len(s) < 3 {
		s = "runner"
	}
	return s
}

// SocialLogin signs in an account verified by Google or Telegram, creating it the first time.
func (a *authCore) SocialLogin(provider, providerID, displayName, usernameHint string) (User, string, error) {
	if provider == "" || providerID == "" {
		return User{}, "", errBadCreds
	}
	if u, err := a.d.userByProvider(provider, providerID); err == nil && u != nil {
		tok, err := a.issue(u.User)
		if err != nil {
			return User{}, "", err
		}
		return u.User, tok, nil
	}
	name := strings.TrimSpace(displayName)
	if name == "" {
		name = usernameHint
	}
	if len(name) > 48 {
		name = name[:48]
	}
	base := cleanUsername(usernameHint)
	if usernameHint == "" {
		base = cleanUsername(displayName)
	}
	var created *userRecord
	for i := 0; i < 10; i++ {
		cand := base
		if i > 0 {
			b := make([]byte, 2)
			_, _ = rand.Read(b)
			cand = base + "_" + hex.EncodeToString(b)
		}
		if _, err := a.d.userByName(cand); err == nil {
			continue
		}
		if name == "" {
			name = cand
		}
		u := &userRecord{
			User: User{ID: newID("usr"), Username: cand, DisplayName: name,
				City: "Addis Ababa", CreatedAt: nowISO()},
			Provider: provider, ProviderID: providerID,
		}
		if err := a.d.insertUser(u); err != nil {
			if err == errUserTaken {
				continue
			}
			// another request may have just created this same account
			if again, e2 := a.d.userByProvider(provider, providerID); e2 == nil && again != nil {
				created = again
				break
			}
			return User{}, "", err
		}
		created = u
		break
	}
	if created == nil {
		return User{}, "", errors.New("could not create your account, please try again")
	}
	tok, err := a.issue(created.User)
	if err != nil {
		return User{}, "", err
	}
	return created.User, tok, nil
}
