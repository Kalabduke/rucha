package main

/*
 Sign in with Apple.

 The browser receives an identity token from Apple and posts it here. RUCHA
 verifies the token against Apple's public keys before creating or signing in an
 account. No private key is needed for this flow; the Apple Services ID is the
 only required setting.

 Environment variables:
   APPLE_CLIENT_ID   Services ID configured in the Apple Developer portal
*/

import (
	"crypto"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"math/big"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"
)

var appleClientID = strings.TrimSpace(os.Getenv("APPLE_CLIENT_ID"))

const appleKeysURL = "https://appleid.apple.com/auth/keys"

type appleJWK struct {
	Kty string `json:"kty"`
	Kid string `json:"kid"`
	Use string `json:"use"`
	Alg string `json:"alg"`
	N   string `json:"n"`
	E   string `json:"e"`
}

type appleKeyCache struct {
	mu      sync.Mutex
	keys    map[string]*rsa.PublicKey
	fetched time.Time
}

var appleKeys appleKeyCache

func b64url(s string) ([]byte, error) {
	return base64.RawURLEncoding.DecodeString(strings.TrimSpace(s))
}

func applePublicKey(kid string) (*rsa.PublicKey, error) {
	appleKeys.mu.Lock()
	defer appleKeys.mu.Unlock()
	if !appleKeys.fetched.IsZero() && time.Since(appleKeys.fetched) < time.Hour {
		if k := appleKeys.keys[kid]; k != nil {
			return k, nil
		}
	}
	resp, err := httpClient.Get(appleKeysURL)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, errors.New("could not load Apple sign-in keys")
	}
	var set struct {
		Keys []appleJWK `json:"keys"`
	}
	if err := json.NewDecoder(io.LimitReader(resp.Body, 1<<20)).Decode(&set); err != nil {
		return nil, err
	}
	keys := map[string]*rsa.PublicKey{}
	for _, k := range set.Keys {
		if k.Kty != "RSA" || k.Kid == "" {
			continue
		}
		nb, err := b64url(k.N)
		if err != nil {
			continue
		}
		eb, err := b64url(k.E)
		if err != nil || len(eb) == 0 {
			continue
		}
		e := 0
		for _, b := range eb {
			e = e<<8 | int(b)
		}
		if e == 0 {
			continue
		}
		keys[k.Kid] = &rsa.PublicKey{N: new(big.Int).SetBytes(nb), E: e}
	}
	if len(keys) == 0 {
		return nil, errors.New("Apple returned no usable signing keys")
	}
	appleKeys.keys, appleKeys.fetched = keys, time.Now()
	if k := keys[kid]; k != nil {
		return k, nil
	}
	return nil, errors.New("Apple signing key not found")
}

func verifyAppleToken(idToken string) (sub, email string, err error) {
	parts := strings.Split(idToken, ".")
	if len(parts) != 3 {
		return "", "", errors.New("malformed Apple identity token")
	}
	headerRaw, err := b64url(parts[0])
	if err != nil {
		return "", "", errors.New("malformed Apple identity token")
	}
	var header struct {
		Alg string `json:"alg"`
		Kid string `json:"kid"`
	}
	if err := json.Unmarshal(headerRaw, &header); err != nil || header.Alg != "RS256" || header.Kid == "" {
		return "", "", errors.New("unsupported Apple identity token")
	}
	key, err := applePublicKey(header.Kid)
	if err != nil {
		return "", "", err
	}
	sig, err := b64url(parts[2])
	if err != nil {
		return "", "", errors.New("malformed Apple identity token")
	}
	sum := sha256.Sum256([]byte(parts[0] + "." + parts[1]))
	if err := rsa.VerifyPKCS1v15(key, crypto.SHA256, sum[:], sig); err != nil {
		return "", "", errors.New("Apple identity token signature does not match")
	}
	claimsRaw, err := b64url(parts[1])
	if err != nil {
		return "", "", errors.New("malformed Apple identity token")
	}
	var claims struct {
		Iss   string          `json:"iss"`
		Aud   json.RawMessage `json:"aud"`
		Exp   int64           `json:"exp"`
		Sub   string          `json:"sub"`
		Email string          `json:"email"`
	}
	if err := json.Unmarshal(claimsRaw, &claims); err != nil {
		return "", "", errors.New("malformed Apple identity token")
	}
	if claims.Iss != "https://appleid.apple.com" || claims.Sub == "" {
		return "", "", errors.New("Apple identity token has the wrong issuer")
	}
	if claims.Exp < time.Now().Unix() {
		return "", "", errors.New("Apple identity token has expired")
	}
	audOK := false
	var aud string
	if err := json.Unmarshal(claims.Aud, &aud); err == nil {
		audOK = aud == appleClientID
	} else {
		var list []string
		if err := json.Unmarshal(claims.Aud, &list); err == nil {
			for _, a := range list {
				if a == appleClientID {
					audOK = true
					break
				}
			}
		}
	}
	if !audOK {
		return "", "", errors.New("Apple identity token was issued for another app")
	}
	return claims.Sub, claims.Email, nil
}

func handleAppleLogin(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		fail(w, 405, "POST only")
		return
	}
	if appleClientID == "" {
		fail(w, 503, "Apple sign-in is not set up on this server yet")
		return
	}
	if !allowed("apple:" + clientIP(r)) {
		fail(w, 429, "Too many attempts. Please wait a few minutes.")
		return
	}
	var b struct {
		IdentityToken string `json:"identityToken"`
		Name          string `json:"name"`
	}
	if err := decode(r, w, &b); err != nil || strings.TrimSpace(b.IdentityToken) == "" {
		fail(w, 400, "missing Apple identity token")
		return
	}
	sub, email, err := verifyAppleToken(b.IdentityToken)
	if err != nil {
		fail(w, 401, err.Error())
		return
	}
	name := strings.TrimSpace(b.Name)
	hint := ""
	if email != "" {
		hint = strings.SplitN(email, "@", 2)[0]
		if name == "" {
			name = hint
		}
	}
	u, tok, err := auth.SocialLogin("apple", sub, name, hint)
	if err != nil {
		failInternal(w, err)
		return
	}
	writeJSON(w, map[string]interface{}{"user": u, "token": tok})
}
