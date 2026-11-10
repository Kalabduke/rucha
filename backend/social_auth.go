package main

import (
	"bytes"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math/big"
	"net"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"
)

/*
 Sign-in with Telegram and Google.

 Telegram: the website never sends email. The person taps "Continue with Telegram", the bot receives
 /start <loginId> and sends a six digit code in the chat, and the person types that code on the site.

 Environment variables:
   TELEGRAM_BOT_TOKEN      token from @BotFather
   TELEGRAM_BOT_USERNAME   optional, found automatically from the token
   GOOGLE_CLIENT_ID        OAuth web client id from Google Cloud console
*/

var (
	tgToken    = strings.TrimSpace(os.Getenv("TELEGRAM_BOT_TOKEN"))
	tgUsername = strings.TrimPrefix(strings.TrimSpace(os.Getenv("TELEGRAM_BOT_USERNAME")), "@")
	tgMu       sync.RWMutex
	googleID   = strings.TrimSpace(os.Getenv("GOOGLE_CLIENT_ID"))
	httpClient = &http.Client{Timeout: 35 * time.Second}
)

const (
	tgLinkTTL    = 10 * time.Minute
	tgCodeTTL    = 5 * time.Minute
	tgMaxTries   = 5
	rateWindow   = 10 * time.Minute
	rateMaxCalls = 30
)

type tgPending struct {
	CodeHash string
	CodeSet  bool
	Expires  time.Time
	Attempts int
	TgID     int64
	First    string
	Username string
}

var (
	pendMu  sync.Mutex
	pending = map[string]*tgPending{}

	rateMu sync.Mutex
	rates  = map[string][]time.Time{}
)

func botName() string {
	tgMu.RLock()
	defer tgMu.RUnlock()
	return tgUsername
}

func clientIP(r *http.Request) string {
	if os.Getenv("TRUST_PROXY") == "true" {
		if xf := r.Header.Get("X-Forwarded-For"); xf != "" {
			return strings.TrimSpace(strings.Split(xf, ",")[0])
		}
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

func allowed(key string) bool {
	rateMu.Lock()
	defer rateMu.Unlock()
	now := time.Now()
	keep := rates[key][:0]
	for _, t := range rates[key] {
		if now.Sub(t) < rateWindow {
			keep = append(keep, t)
		}
	}
	if len(keep) >= rateMaxCalls {
		rates[key] = keep
		return false
	}
	rates[key] = append(keep, now)
	return true
}

func randHex(n int) string {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return fmt.Sprintf("%d", time.Now().UnixNano())
	}
	return hex.EncodeToString(b)
}

func hashCode(loginID, code string) string {
	sum := sha256.Sum256([]byte(loginID + ":" + code))
	return hex.EncodeToString(sum[:])
}

func newCode() string {
	n, err := rand.Int(rand.Reader, big.NewInt(1000000))
	if err != nil {
		return fmt.Sprintf("%06d", time.Now().UnixNano()%1000000)
	}
	return fmt.Sprintf("%06d", n.Int64())
}

func purgePending() {
	pendMu.Lock()
	defer pendMu.Unlock()
	now := time.Now()
	for id, p := range pending {
		if now.After(p.Expires) {
			delete(pending, id)
		}
	}
}

// ---------- config ----------

func handleAuthConfig(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]interface{}{
		"telegram":       tgToken != "" && botName() != "",
		"telegramBot":    botName(),
		"google":         googleID != "",
		"googleId":       googleID,
		"apple":          appleClientID != "",
		"appleClientId":  appleClientID,
		"privacyVersion": privacyVersion,
		"termsVersion":   termsVersion,
		"minPassword":    minPasswordLength,
		"privacyUpdated": "7 November 2026",
		"termsUpdated":   "7 November 2026",
	})
}

// ---------- telegram ----------

func handleTelegramStart(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		fail(w, 405, "POST only")
		return
	}
	if tgToken == "" || botName() == "" {
		fail(w, 503, "Telegram sign-in is not set up on this server yet")
		return
	}
	if !allowed("tg-start:" + clientIP(r)) {
		fail(w, 429, "Too many attempts. Please wait a few minutes.")
		return
	}
	purgePending()
	id := randHex(16)
	pendMu.Lock()
	pending[id] = &tgPending{Expires: time.Now().Add(tgLinkTTL)}
	pendMu.Unlock()
	writeJSON(w, map[string]interface{}{
		"loginId": id,
		"bot":     botName(),
		"link":    "https://t.me/" + botName() + "?start=" + id,
	})
}

func handleTelegramVerify(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		fail(w, 405, "POST only")
		return
	}
	if !allowed("tg-verify:" + clientIP(r)) {
		fail(w, 429, "Too many attempts. Please wait a few minutes.")
		return
	}
	var b struct {
		LoginID string `json:"loginId"`
		Code    string `json:"code"`
	}
	if err := decode(r, &b); err != nil {
		fail(w, 400, "invalid JSON")
		return
	}
	code := strings.TrimSpace(b.Code)
	if len(code) != 6 {
		fail(w, 400, "Enter the 6 digit code from Telegram")
		return
	}

	pendMu.Lock()
	p := pending[b.LoginID]
	if p == nil || time.Now().After(p.Expires) {
		delete(pending, b.LoginID)
		pendMu.Unlock()
		fail(w, 400, "This sign-in expired. Start again.")
		return
	}
	if !p.CodeSet {
		pendMu.Unlock()
		fail(w, 400, "Open Telegram and press Start first. Your code is sent there.")
		return
	}
	p.Attempts++
	if p.Attempts > tgMaxTries {
		delete(pending, b.LoginID)
		pendMu.Unlock()
		fail(w, 429, "Too many wrong codes. Start again.")
		return
	}
	ok := subtle.ConstantTimeCompare([]byte(p.CodeHash), []byte(hashCode(b.LoginID, code))) == 1
	if !ok {
		left := tgMaxTries - p.Attempts
		pendMu.Unlock()
		fail(w, 400, fmt.Sprintf("That code is not right. %d tries left.", left))
		return
	}
	tgID, first, uname := p.TgID, p.First, p.Username
	delete(pending, b.LoginID)
	pendMu.Unlock()

	u, tok, err := auth.SocialLogin("telegram", strconv.FormatInt(tgID, 10), first, uname)
	if err != nil {
		fail(w, 500, err.Error())
		return
	}
	writeJSON(w, map[string]interface{}{"user": u, "token": tok})
}

type tgUpdate struct {
	UpdateID int64 `json:"update_id"`
	Message  *struct {
		Text string `json:"text"`
		Chat struct {
			ID   int64  `json:"id"`
			Type string `json:"type"`
		} `json:"chat"`
		From *struct {
			ID        int64  `json:"id"`
			FirstName string `json:"first_name"`
			Username  string `json:"username"`
			IsBot     bool   `json:"is_bot"`
		} `json:"from"`
	} `json:"message"`
}

func tgCall(method string, params url.Values, out interface{}) error {
	endpoint := "https://api.telegram.org/bot" + tgToken + "/" + method
	resp, err := httpClient.PostForm(endpoint, params)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	var env struct {
		OK          bool            `json:"ok"`
		Description string          `json:"description"`
		Result      json.RawMessage `json:"result"`
	}
	if err := json.NewDecoder(bytes.NewReader(body)).Decode(&env); err != nil {
		return err
	}
	if !env.OK {
		return fmt.Errorf("telegram %s: %s", method, env.Description)
	}
	if out != nil {
		return json.Unmarshal(env.Result, out)
	}
	return nil
}

func tgSend(chatID int64, text string) {
	err := tgCall("sendMessage", url.Values{
		"chat_id": {strconv.FormatInt(chatID, 10)},
		"text":    {text},
	}, nil)
	if err != nil {
		log.Printf("telegram send failed: %v", err)
	}
}

func handleTelegramMessage(m *tgUpdate) {
	msg := m.Message
	if msg == nil || msg.From == nil || msg.From.IsBot || msg.Chat.Type != "private" {
		return
	}
	text := strings.TrimSpace(msg.Text)
	if !strings.HasPrefix(text, "/start") {
		tgSend(msg.Chat.ID, "To sign in, open RUCHA, choose Continue with Telegram, and press the button there.")
		return
	}
	parts := strings.Fields(text)
	if len(parts) < 2 {
		tgSend(msg.Chat.ID, "Welcome to RUCHA. To sign in, open the RUCHA app or website and choose Continue with Telegram.")
		return
	}
	loginID := parts[1]
	pendMu.Lock()
	p := pending[loginID]
	if p == nil || time.Now().After(p.Expires) {
		delete(pending, loginID)
		pendMu.Unlock()
		tgSend(msg.Chat.ID, "That sign-in link has expired. Go back to RUCHA and start again.")
		return
	}
	code := newCode()
	p.CodeHash = hashCode(loginID, code)
	p.CodeSet = true
	p.Attempts = 0
	p.Expires = time.Now().Add(tgCodeTTL)
	p.TgID = msg.From.ID
	p.First = msg.From.FirstName
	p.Username = msg.From.Username
	pendMu.Unlock()
	tgSend(msg.Chat.ID, "Your RUCHA sign-in code: "+code+"\n\nIt works for 5 minutes. If you did not ask for it, ignore this message.")
}

// startTelegramBot polls Telegram for messages. Long polling means no public webhook URL is needed.
func startTelegramBot() {
	if tgToken == "" {
		log.Println("TELEGRAM_BOT_TOKEN not set: Telegram sign-in is off")
		return
	}
	go func() {
		var me struct {
			Username string `json:"username"`
		}
		for {
			if err := tgCall("getMe", url.Values{}, &me); err != nil {
				log.Printf("telegram getMe failed, retrying: %v", err)
				time.Sleep(10 * time.Second)
				continue
			}
			break
		}
		tgMu.Lock()
		if tgUsername == "" {
			tgUsername = me.Username
		}
		tgMu.Unlock()
		// polling does not work while a webhook is registered
		_ = tgCall("deleteWebhook", url.Values{}, nil)
		log.Printf("Telegram sign-in ready via @%s", botName())

		var offset int64
		for {
			var updates []tgUpdate
			err := tgCall("getUpdates", url.Values{
				"offset":          {strconv.FormatInt(offset, 10)},
				"timeout":         {"25"},
				"allowed_updates": {`["message"]`},
			}, &updates)
			if err != nil {
				log.Printf("telegram polling error: %v", err)
				time.Sleep(5 * time.Second)
				continue
			}
			for i := range updates {
				if updates[i].UpdateID >= offset {
					offset = updates[i].UpdateID + 1
				}
				handleTelegramMessage(&updates[i])
			}
			purgePending()
		}
	}()
}

// ---------- google ----------

func handleGoogleLogin(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		fail(w, 405, "POST only")
		return
	}
	if googleID == "" {
		fail(w, 503, "Google sign-in is not set up on this server yet")
		return
	}
	if !allowed("google:" + clientIP(r)) {
		fail(w, 429, "Too many attempts. Please wait a few minutes.")
		return
	}
	var b struct {
		Credential string `json:"credential"`
	}
	if err := decode(r, &b); err != nil || b.Credential == "" {
		fail(w, 400, "missing Google credential")
		return
	}
	resp, err := httpClient.Get("https://oauth2.googleapis.com/tokeninfo?id_token=" + url.QueryEscape(b.Credential))
	if err != nil {
		fail(w, 502, "Could not reach Google. Try again.")
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		fail(w, 401, "Google did not accept this sign-in")
		return
	}
	var t struct {
		Aud           string `json:"aud"`
		Iss           string `json:"iss"`
		Sub           string `json:"sub"`
		Exp           string `json:"exp"`
		Name          string `json:"name"`
		GivenName     string `json:"given_name"`
		Email         string `json:"email"`
		EmailVerified string `json:"email_verified"`
	}
	if err := json.NewDecoder(io.LimitReader(resp.Body, 1<<20)).Decode(&t); err != nil {
		fail(w, 502, "Unexpected answer from Google")
		return
	}
	exp, _ := strconv.ParseInt(t.Exp, 10, 64)
	if t.Aud != googleID || t.Sub == "" || exp < time.Now().Unix() ||
		(t.Iss != "accounts.google.com" && t.Iss != "https://accounts.google.com") {
		fail(w, 401, "Google sign-in could not be verified")
		return
	}
	name := t.Name
	if name == "" {
		name = t.GivenName
	}
	hint := ""
	if t.Email != "" {
		hint = strings.SplitN(t.Email, "@", 2)[0]
	}
	u, tok, err := auth.SocialLogin("google", t.Sub, name, hint)
	if err != nil {
		fail(w, 500, err.Error())
		return
	}
	writeJSON(w, map[string]interface{}{"user": u, "token": tok})
}
