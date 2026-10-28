package store

import (
	"context"
	"database/sql"
	"path/filepath"
	"testing"
	"time"
)

func TestProfile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "bookings.sqlite")
	seed, err := sql.Open("sqlite", path)
	if err != nil {
		t.Fatal(err)
	}
	for _, stmt := range []string{
		`CREATE TABLE loyalty_accounts (user_id INTEGER PRIMARY KEY, remaining INTEGER NOT NULL, last_loyalty_activity_at TEXT)`,
		`CREATE TABLE loyalty_ledger (id INTEGER PRIMARY KEY, user_id INTEGER, amount INTEGER, reason TEXT, created_at TEXT)`,
		`CREATE TABLE bookings (id INTEGER PRIMARY KEY, user_id INTEGER, participant_user_id INTEGER, status TEXT, attendance TEXT)`,
		`CREATE TABLE referral_attributions (invitee_user_id INTEGER PRIMARY KEY, inviter_user_id INTEGER)`,
		`INSERT INTO loyalty_accounts VALUES (7, 340, '2026-10-01T10:00:00.000Z')`,
		`INSERT INTO loyalty_ledger VALUES (1, 7, 1000, 'start', '2026-09-01T10:00:00.000Z'), (2, 7, -660, 'spend', '2026-10-01T10:00:00.000Z'), (3, 9, 50, 'training', '2026-10-02T10:00:00.000Z')`,
		`INSERT INTO bookings VALUES (1, 7, 7, 'paid', 'attended'), (2, 7, 7, 'cancelled', NULL), (3, 9, 7, 'paid', 'attended'), (4, 7, 8, 'paid', 'attended')`,
		`INSERT INTO referral_attributions VALUES (100, 7), (101, 7)`,
	} {
		if _, err := seed.Exec(stmt); err != nil {
			t.Fatal(err)
		}
	}
	seed.Close()

	s, err := Open(path)
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	got, err := s.Profile(context.Background(), 7)
	if err != nil {
		t.Fatal(err)
	}
	if got.Peaks != 340 || got.Visits != 2 || got.Invited != 2 || got.Bookings != 2 {
		t.Fatalf("got %+v", got)
	}
	wantExpiry := time.Date(2026, 11, 15, 10, 0, 0, 0, time.UTC)
	if got.PeaksExpireAt == nil || !got.PeaksExpireAt.Equal(wantExpiry) {
		t.Fatalf("expiry = %v, want %v", got.PeaksExpireAt, wantExpiry)
	}
	if len(got.PeaksHistory) != 2 || got.PeaksHistory[0].Reason != "spend" || got.PeaksHistory[0].Amount != -660 {
		t.Fatalf("history = %+v", got.PeaksHistory)
	}
	if _, err := s.db.Exec(`DELETE FROM bookings`); err == nil {
		t.Fatal("store must be read-only")
	}
}

func TestProfileWithoutTables(t *testing.T) {
	s, err := Open(filepath.Join(t.TempDir(), "empty.sqlite"))
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	if _, err := s.Profile(context.Background(), 1); err != nil {
		t.Fatalf("missing tables should not fail: %v", err)
	}
}
