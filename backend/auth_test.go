package main

import (
	"errors"
	"strings"
	"testing"
)

func testConsent() Consent {
	return Consent{
		AcceptPrivacy:  true,
		AcceptTerms:    true,
		PrivacyVersion: privacyVersion,
		TermsVersion:   termsVersion,
	}
}

func TestRegisterRequiresCurrentConsent(t *testing.T) {
	a := NewMemAuth()

	if _, _, err := a.Register("selam_runs", "longenough1", "Selam", "+251911234567", Consent{}); !errors.Is(err, errConsent) {
		t.Fatalf("missing consent: got %v, want %v", err, errConsent)
	}
	stale := testConsent()
	stale.PrivacyVersion = "2020-01-01"
	if _, _, err := a.Register("selam_runs", "longenough1", "Selam", "+251911234567", stale); !errors.Is(err, errConsentStale) {
		t.Fatalf("stale consent: got %v, want %v", err, errConsentStale)
	}

	u, tok, err := a.Register("Selam_Runs", "longenough1", "Selam", "+251911234567", testConsent())
	if err != nil {
		t.Fatalf("register: %v", err)
	}
	if tok == "" {
		t.Fatal("register returned an empty token")
	}
	if u.Username != "selam_runs" {
		t.Fatalf("username = %q, want normalized %q", u.Username, "selam_runs")
	}
	if u.Phone != "+251911234567" {
		t.Fatalf("phone = %q, want %q", u.Phone, "+251911234567")
	}
	if !u.ProfileComplete || !u.HasPassword {
		t.Fatalf("new account is not complete: %+v", u)
	}
	if u.PrivacyVersion != privacyVersion || u.TermsVersion != termsVersion {
		t.Fatalf("consent versions not stored: %+v", u)
	}
	if u.PrivacyAt == "" || u.TermsAt == "" {
		t.Fatalf("consent timestamps not stored: %+v", u)
	}

	me, err := a.Me(tok)
	if err != nil {
		t.Fatalf("me: %v", err)
	}
	if me.PrivacyVersion != privacyVersion || me.TermsVersion != termsVersion {
		t.Fatalf("me lost consent versions: %+v", me)
	}
}

func TestUsernameUniquenessIsCaseInsensitive(t *testing.T) {
	a := NewMemAuth()
	if _, _, err := a.Register("selam_runs", "longenough1", "Selam", "", testConsent()); err != nil {
		t.Fatalf("first register: %v", err)
	}

	for _, name := range []string{"selam_runs", "Selam_Runs", "SELAM_RUNS"} {
		if _, _, err := a.Register(name, "longenough2", "Other", "", testConsent()); !errors.Is(err, errUserTaken) {
			t.Fatalf("register %q: got %v, want %v", name, err, errUserTaken)
		}
	}

	available, reason := a.UsernameAvailable("SELAM_RUNS")
	if available {
		t.Fatalf("UsernameAvailable reported a taken name as free (reason %q)", reason)
	}
	available, reason = a.UsernameAvailable("another_name")
	if !available {
		t.Fatalf("UsernameAvailable rejected a free name: %q", reason)
	}

	if _, _, err := a.Login("SELAM_RUNS", "longenough1"); err != nil {
		t.Fatalf("case-insensitive login failed: %v", err)
	}
}

func TestSocialAccountMustCompleteProfile(t *testing.T) {
	a := NewMemAuth()

	pending, tok, err := a.SocialLogin("telegram", "tg-100", "Selam Tesfaye", "selam")
	if err != nil {
		t.Fatalf("social login: %v", err)
	}
	if pending.ProfileComplete {
		t.Fatal("new social account should be incomplete")
	}
	if !strings.HasPrefix(pending.Username, "pending_") {
		t.Fatalf("placeholder username = %q, want pending_ prefix", pending.Username)
	}
	if pending.HasPassword {
		t.Fatal("new social account should not have a password yet")
	}
	if len(pending.Providers) != 1 || pending.Providers[0] != "telegram" {
		t.Fatalf("providers = %v, want [telegram]", pending.Providers)
	}
	if me, err := a.Me(tok); err != nil || me.ProfileComplete {
		t.Fatalf("Me for pending account = %+v, %v", me, err)
	}

	complete, sameTok, err := a.CompleteProfile(tok, "selam_runs", "longenough1", "Selam Tesfaye", "+251911234567", testConsent())
	if err != nil {
		t.Fatalf("complete profile: %v", err)
	}
	if sameTok != tok {
		t.Fatal("complete profile should keep the same session token")
	}
	if !complete.ProfileComplete || !complete.HasPassword {
		t.Fatalf("completed account is not usable: %+v", complete)
	}
	if complete.Phone != "+251911234567" {
		t.Fatalf("phone = %q, want %q", complete.Phone, "+251911234567")
	}
	if complete.Username != "selam_runs" {
		t.Fatalf("completed username = %q", complete.Username)
	}
	if complete.PrivacyVersion != privacyVersion || complete.TermsVersion != termsVersion {
		t.Fatalf("completed account did not store consent: %+v", complete)
	}
	if _, _, err := a.CompleteProfile(tok, "another_name", "longenough1", "Selam", "", testConsent()); !errors.Is(err, errProfileDone) {
		t.Fatalf("second completion: got %v, want %v", err, errProfileDone)
	}

	again, _, err := a.SocialLogin("telegram", "tg-100", "", "")
	if err != nil {
		t.Fatalf("repeat social login: %v", err)
	}
	if again.ID != complete.ID {
		t.Fatalf("repeat social login returned %q, want %q", again.ID, complete.ID)
	}
	if !again.ProfileComplete {
		t.Fatal("repeat social login should return the completed account")
	}
}

func TestCompleteProfileRejectsTakenUsername(t *testing.T) {
	a := NewMemAuth()
	if _, _, err := a.Register("taken_name", "longenough1", "First", "", testConsent()); err != nil {
		t.Fatalf("register: %v", err)
	}
	_, tok, err := a.SocialLogin("google", "google-1", "Second", "second")
	if err != nil {
		t.Fatalf("social login: %v", err)
	}
	if _, _, err := a.CompleteProfile(tok, "TAKEN_NAME", "longenough2", "Second", "", testConsent()); !errors.Is(err, errUserTaken) {
		t.Fatalf("complete with taken name: got %v, want %v", err, errUserTaken)
	}
	if _, _, err := a.CompleteProfile(tok, "not valid", "longenough2", "Second", "", testConsent()); !errors.Is(err, errBadUsername) {
		t.Fatalf("complete with invalid name: got %v, want %v", err, errBadUsername)
	}
	if _, _, err := a.CompleteProfile(tok, "second_name", "four", "Second", "", testConsent()); !errors.Is(err, errBadPassword) {
		t.Fatalf("complete with short password: got %v, want %v", err, errBadPassword)
	}
}

func TestAcceptConsentUpdatesVersion(t *testing.T) {
	a := NewMemAuth()
	_, tok, err := a.Register("consent_user", "longenough1", "Consent", "", testConsent())
	if err != nil {
		t.Fatalf("register: %v", err)
	}

	stale := testConsent()
	stale.TermsVersion = "2020-01-01"
	if _, err := a.AcceptConsent(tok, stale); !errors.Is(err, errConsentStale) {
		t.Fatalf("stale consent: got %v, want %v", err, errConsentStale)
	}

	u, err := a.AcceptConsent(tok, testConsent())
	if err != nil {
		t.Fatalf("accept consent: %v", err)
	}
	if u.PrivacyVersion != privacyVersion || u.TermsVersion != termsVersion || u.PrivacyAt == "" {
		t.Fatalf("consent not recorded: %+v", u)
	}
	if _, err := a.AcceptConsent("not-a-session", testConsent()); !errors.Is(err, errNotAuthed) {
		t.Fatalf("accept without session: got %v, want %v", err, errNotAuthed)
	}
}
