package store

import (
	"context"
	"database/sql"
	"path/filepath"
	"testing"
)

func TestProfile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "bookings.sqlite")
	seed, err := sql.Open("sqlite", path)
	if err != nil {
		t.Fatal(err)
	}
	for _, stmt := range []string{
		`CREATE TABLE loyalty_accounts (user_id INTEGER PRIMARY KEY, remaining INTEGER NOT NULL)`,
		`CREATE TABLE bookings (id INTEGER PRIMARY KEY, user_id INTEGER, participant_user_id INTEGER, status TEXT, attendance TEXT)`,
		`CREATE TABLE referral_attributions (invitee_user_id INTEGER PRIMARY KEY, inviter_user_id INTEGER)`,
		`INSERT INTO loyalty_accounts VALUES (7, 340)`,
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
	want := Profile{Peaks: 340, Visits: 2, Invited: 2, Bookings: 2}
	if got != want {
		t.Fatalf("got %+v, want %+v", got, want)
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
