// Package store reads profile aggregates from the bot's SQLite database.
// It never writes: the bot owns the schema and all mutations.
package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"

	_ "modernc.org/sqlite" // database/sql driver "sqlite"
)

type Store struct {
	db *sql.DB
}

// Open opens the shared database for queries only.
func Open(path string) (*Store, error) {
	dsn := fmt.Sprintf("file:%s?_pragma=busy_timeout(5000)&_pragma=query_only(1)", path)
	db, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(4)
	if err := db.Ping(); err != nil {
		db.Close()
		return nil, err
	}
	return &Store{db: db}, nil
}

func (s *Store) Close() error { return s.db.Close() }

// Profile is what the profile screen shows besides bookings.
type Profile struct {
	Peaks    int `json:"peaks"`
	Visits   int `json:"visits"`
	Invited  int `json:"invited"`
	Bookings int `json:"bookings"`
}

func (s *Store) Profile(ctx context.Context, userID int64) (Profile, error) {
	var p Profile
	err := s.db.QueryRowContext(ctx,
		`SELECT remaining FROM loyalty_accounts WHERE user_id = ?`, userID).Scan(&p.Peaks)
	if err != nil && !errors.Is(err, sql.ErrNoRows) && !isMissingTable(err) {
		return p, fmt.Errorf("loyalty: %w", err)
	}
	err = s.db.QueryRowContext(ctx, `
		SELECT
		  COUNT(*) FILTER (WHERE attendance = 'attended'),
		  COUNT(*) FILTER (WHERE status NOT IN ('cancelled', 'payment_rejected'))
		FROM bookings
		WHERE COALESCE(participant_user_id, user_id) = ?`, userID).Scan(&p.Visits, &p.Bookings)
	if err != nil && !isMissingTable(err) {
		return p, fmt.Errorf("bookings: %w", err)
	}
	err = s.db.QueryRowContext(ctx,
		`SELECT COUNT(*) FROM referral_attributions WHERE inviter_user_id = ?`, userID).Scan(&p.Invited)
	if err != nil && !isMissingTable(err) {
		return p, fmt.Errorf("referrals: %w", err)
	}
	return p, nil
}

func isMissingTable(err error) bool {
	return err != nil && strings.Contains(err.Error(), "no such table")
}
