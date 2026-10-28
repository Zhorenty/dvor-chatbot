package telegram

import (
	"encoding/hex"
	"errors"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"testing"
	"time"
)

const testToken = "123456:TEST-token"

// sign builds init data the way Telegram does, for tests only.
func sign(t *testing.T, fields map[string]string) string {
	t.Helper()
	pairs := make([]string, 0, len(fields))
	for key, value := range fields {
		pairs = append(pairs, key+"="+value)
	}
	sort.Strings(pairs)
	secret := hmacSHA256([]byte("WebAppData"), []byte(testToken))
	hash := hex.EncodeToString(hmacSHA256(secret, []byte(strings.Join(pairs, "\n"))))

	values := url.Values{}
	for key, value := range fields {
		values.Set(key, value)
	}
	values.Set("hash", hash)
	return values.Encode()
}

func TestValidateInitData(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	fresh := strconv.FormatInt(now.Add(-time.Minute).Unix(), 10)
	user := `{"id":42,"first_name":"Аня","username":"anya"}`

	tests := []struct {
		name    string
		raw     func() string
		wantErr error
	}{
		{
			name: "valid",
			raw: func() string {
				return sign(t, map[string]string{"auth_date": fresh, "user": user, "start_param": "ev"})
			},
		},
		{
			name: "tampered user",
			raw: func() string {
				raw := sign(t, map[string]string{"auth_date": fresh, "user": user})
				return strings.Replace(raw, "anya", "mallory", 1)
			},
			wantErr: ErrBadHash,
		},
		{
			name:    "missing hash",
			raw:     func() string { return "auth_date=" + fresh },
			wantErr: ErrMissingHash,
		},
		{
			name: "expired",
			raw: func() string {
				old := strconv.FormatInt(now.Add(-48*time.Hour).Unix(), 10)
				return sign(t, map[string]string{"auth_date": old, "user": user})
			},
			wantErr: ErrExpired,
		},
		{
			name:    "no user",
			raw:     func() string { return sign(t, map[string]string{"auth_date": fresh}) },
			wantErr: ErrNoUser,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			data, err := ValidateInitData(tt.raw(), testToken, 24*time.Hour, now)
			if !errors.Is(err, tt.wantErr) {
				t.Fatalf("err = %v, want %v", err, tt.wantErr)
			}
			if tt.wantErr == nil {
				if data.User.ID != 42 || data.User.Username != "anya" || data.StartParam != "ev" {
					t.Fatalf("unexpected data: %+v", data)
				}
			}
		})
	}
}
