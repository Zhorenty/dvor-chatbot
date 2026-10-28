// Package telegram validates Mini App launch data and calls the Bot API.
package telegram

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"
)

// User is the Telegram user embedded in Mini App init data.
type User struct {
	ID           int64  `json:"id"`
	FirstName    string `json:"first_name"`
	LastName     string `json:"last_name,omitempty"`
	Username     string `json:"username,omitempty"`
	LanguageCode string `json:"language_code,omitempty"`
	PhotoURL     string `json:"photo_url,omitempty"`
}

// InitData is the verified subset of Telegram.WebApp.initData.
type InitData struct {
	User       User
	AuthDate   time.Time
	StartParam string
}

var (
	ErrMissingHash = errors.New("init data: missing hash")
	ErrBadHash     = errors.New("init data: hash mismatch")
	ErrExpired     = errors.New("init data: expired")
	ErrNoUser      = errors.New("init data: missing user")
)

// ValidateInitData checks the HMAC signature described in
// https://core.telegram.org/bots/webapps#validating-data-received-via-the-mini-app
// and rejects data older than maxAge.
func ValidateInitData(raw, botToken string, maxAge time.Duration, now time.Time) (InitData, error) {
	values, err := url.ParseQuery(raw)
	if err != nil {
		return InitData{}, err
	}
	hash := values.Get("hash")
	if hash == "" {
		return InitData{}, ErrMissingHash
	}

	pairs := make([]string, 0, len(values))
	for key := range values {
		if key == "hash" {
			continue
		}
		pairs = append(pairs, key+"="+values.Get(key))
	}
	sort.Strings(pairs)
	checkString := strings.Join(pairs, "\n")

	secret := hmacSHA256([]byte("WebAppData"), []byte(botToken))
	expected := hex.EncodeToString(hmacSHA256(secret, []byte(checkString)))
	if !hmac.Equal([]byte(expected), []byte(hash)) {
		return InitData{}, ErrBadHash
	}

	authUnix, err := strconv.ParseInt(values.Get("auth_date"), 10, 64)
	if err != nil {
		return InitData{}, ErrExpired
	}
	authDate := time.Unix(authUnix, 0)
	if maxAge > 0 && now.Sub(authDate) > maxAge {
		return InitData{}, ErrExpired
	}

	var user User
	if err := json.Unmarshal([]byte(values.Get("user")), &user); err != nil || user.ID == 0 {
		return InitData{}, ErrNoUser
	}

	return InitData{User: user, AuthDate: authDate, StartParam: values.Get("start_param")}, nil
}

func hmacSHA256(key, data []byte) []byte {
	mac := hmac.New(sha256.New, key)
	mac.Write(data)
	return mac.Sum(nil)
}
