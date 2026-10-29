// Package bridge talks to the bot's internal HTTP bridge. Booking writes go
// through the bot so chat cards, admin notifications and capacity rules stay
// in one place.
package bridge

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"time"
)

// Event is one bookable training, hike or trail.
type Event struct {
	Key             string     `json:"key"`
	Category        string     `json:"category"`
	Featured        bool       `json:"featured"`
	Title           string     `json:"title"`
	StartsAt        time.Time  `json:"startsAt"`
	EndsAt          *time.Time `json:"endsAt,omitempty"`
	Location        string     `json:"location"`
	LocationURL     *string    `json:"locationUrl,omitempty"`
	Price           *int       `json:"price,omitempty"`
	PrepayPercent   *int       `json:"prepayPercent,omitempty"`
	Limit           *int       `json:"limit,omitempty"`
	Taken           *int       `json:"taken,omitempty"`
	Coach           *string    `json:"coach,omitempty"`
	Notes           *string    `json:"notes,omitempty"`
	Description     *string    `json:"description,omitempty"`
	Equipment       *string    `json:"equipment,omitempty"`
	Itinerary       *string    `json:"itinerary,omitempty"`
	PromoRestricted bool       `json:"promoRestricted"`
}

// Schedule is the bot's current bookable catalog.
type Schedule struct {
	Events      []Event   `json:"events"`
	GeneratedAt time.Time `json:"generatedAt"`
}

// Booking is one booking owned (managed) by the user.
type Booking struct {
	ID            int64     `json:"id"`
	Key           string    `json:"key"`
	Category      string    `json:"category"`
	Title         string    `json:"title"`
	StartsAt      time.Time `json:"startsAt"`
	Location      string    `json:"location"`
	LocationURL   *string   `json:"locationUrl,omitempty"`
	Status        string    `json:"status"`
	Price         *int      `json:"price,omitempty"`
	PrepayPercent *int      `json:"prepayPercent,omitempty"`
	Participant   *string   `json:"participant,omitempty"`
	CanCancel     bool      `json:"canCancel"`
	BoxingCard    bool      `json:"boxingCard"`
	Attendance    *string   `json:"attendance,omitempty"`
}

// ActionResult is the outcome of a book or cancel call.
// Outcome: created | exists | full | not_found | cancelled | too_late.
type ActionResult struct {
	Outcome     string   `json:"outcome"`
	Message     *string  `json:"message,omitempty"`
	RefundPeaks *int     `json:"refundPeaks,omitempty"`
	Booking     *Booking `json:"booking,omitempty"`
}

var ErrUnavailable = errors.New("bot bridge unavailable")

type Client struct {
	baseURL string
	token   string
	http    *http.Client
	rpcHTTP *http.Client
}

func NewClient(baseURL, token string) *Client {
	return &Client{
		baseURL: baseURL,
		token:   token,
		// Booking runs the chat flow (several Bot API calls), so allow time.
		http: &http.Client{Timeout: 25 * time.Second},
		// RPC deadlines come from the request context (see RPC).
		rpcHTTP: &http.Client{},
	}
}

func (c *Client) Schedule(ctx context.Context) (Schedule, error) {
	var out Schedule
	err := c.do(ctx, http.MethodGet, "/internal/schedule", nil, &out)
	return out, err
}

func (c *Client) Bookings(ctx context.Context, userID int64) ([]Booking, error) {
	var out struct {
		Bookings []Booking `json:"bookings"`
	}
	err := c.do(ctx, http.MethodGet, "/internal/users/"+strconv.FormatInt(userID, 10)+"/bookings", nil, &out)
	return out.Bookings, err
}

func (c *Client) Book(ctx context.Context, userID int64, username, key string) (ActionResult, error) {
	payload := map[string]any{"userId": userID, "key": key}
	if username != "" {
		payload["username"] = username
	}
	var out ActionResult
	err := c.do(ctx, http.MethodPost, "/internal/bookings", payload, &out)
	return out, err
}

func (c *Client) Cancel(ctx context.Context, userID, bookingID int64) (ActionResult, error) {
	var out ActionResult
	err := c.do(ctx, http.MethodPost,
		"/internal/bookings/"+strconv.FormatInt(bookingID, 10)+"/cancel",
		map[string]any{"userId": userID}, &out)
	return out, err
}

func (c *Client) do(ctx context.Context, method, path string, payload, out any) error {
	var body *bytes.Reader
	if payload != nil {
		raw, err := json.Marshal(payload)
		if err != nil {
			return err
		}
		body = bytes.NewReader(raw)
	} else {
		body = bytes.NewReader(nil)
	}
	req, err := http.NewRequestWithContext(ctx, method, c.baseURL+path, body)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+c.token)
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("%w: %v", ErrUnavailable, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("%w: %s %s -> %d", ErrUnavailable, method, path, resp.StatusCode)
	}
	return json.NewDecoder(resp.Body).Decode(out)
}
