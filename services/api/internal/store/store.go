// Package store reads profile aggregates from the bot's SQLite database.
// It never writes: the bot owns the schema and all mutations.
package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"

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
	// PeaksExpireAt is when the balance burns without new activity
	// (45 days after the last loyalty activity, same rule as the bot).
	PeaksExpireAt *time.Time    `json:"peaksExpireAt,omitempty"`
	PeaksHistory  []PeaksChange `json:"peaksHistory"`
}

// PeaksChange is one loyalty ledger row; Reason is the bot's db value
// (start, training, spend, refund, ...).
type PeaksChange struct {
	Amount    int       `json:"amount"`
	Reason    string    `json:"reason"`
	CreatedAt time.Time `json:"createdAt"`
}

// peaksLifetime mirrors LoyaltyMath.lifetime in the bot.
const peaksLifetime = 45 * 24 * time.Hour

const peaksHistoryLimit = 8

func (s *Store) Profile(ctx context.Context, userID int64) (Profile, error) {
	p := Profile{PeaksHistory: []PeaksChange{}}
	var lastActivity sql.NullString
	err := s.db.QueryRowContext(ctx,
		`SELECT remaining, last_loyalty_activity_at FROM loyalty_accounts WHERE user_id = ?`,
		userID).Scan(&p.Peaks, &lastActivity)
	if err != nil && !errors.Is(err, sql.ErrNoRows) && !isMissingTable(err) {
		return p, fmt.Errorf("loyalty: %w", err)
	}
	if last, ok := parseTime(lastActivity.String); ok && p.Peaks > 0 {
		expires := last.Add(peaksLifetime)
		p.PeaksExpireAt = &expires
	}
	if p.PeaksHistory, err = s.peaksHistory(ctx, userID); err != nil {
		return p, err
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

func (s *Store) peaksHistory(ctx context.Context, userID int64) ([]PeaksChange, error) {
	history := []PeaksChange{}
	rows, err := s.db.QueryContext(ctx, `
		SELECT amount, reason, created_at FROM loyalty_ledger
		WHERE user_id = ? AND amount != 0
		ORDER BY created_at DESC, id DESC
		LIMIT ?`, userID, peaksHistoryLimit)
	if err != nil {
		if isMissingTable(err) {
			return history, nil
		}
		return history, fmt.Errorf("ledger: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var change PeaksChange
		var created string
		if err := rows.Scan(&change.Amount, &change.Reason, &created); err != nil {
			return history, fmt.Errorf("ledger: %w", err)
		}
		change.CreatedAt, _ = parseTime(created)
		history = append(history, change)
	}
	return history, rows.Err()
}

// parseTime reads the bot's ISO-8601 timestamps (UTC with or without "Z").
func parseTime(raw string) (time.Time, bool) {
	if raw == "" {
		return time.Time{}, false
	}
	for _, layout := range []string{time.RFC3339Nano, "2006-01-02T15:04:05.999999999"} {
		if t, err := time.Parse(layout, raw); err == nil {
			return t.UTC(), true
		}
	}
	return time.Time{}, false
}

func isMissingTable(err error) bool {
	return err != nil && strings.Contains(err.Error(), "no such table")
}
