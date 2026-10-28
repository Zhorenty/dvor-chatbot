package bridge

import (
	"context"
	"net/http"
	"net/url"
	"strconv"
	"time"
)

// Person is a club member as the admin sees them: @username or "id N".
type Person struct {
	UserID int64  `json:"userId"`
	Name   string `json:"name"`
}

// Payment is one submitted payment awaiting review (one per payment group).
type Payment struct {
	ID            int64     `json:"id"`
	Key           string    `json:"key"`
	Category      string    `json:"category"`
	Title         string    `json:"title"`
	StartsAt      time.Time `json:"startsAt"`
	Location      string    `json:"location"`
	Price         *int      `json:"price,omitempty"`
	PrepayPercent *int      `json:"prepayPercent,omitempty"`
	Total         int       `json:"total"`
	PaymentType   *string   `json:"paymentType,omitempty"`
	Comment       *string   `json:"comment,omitempty"`
	PromoCode     *string   `json:"promoCode,omitempty"`
	Organizer     Person    `json:"organizer"`
	Participants  []string  `json:"participants"`
	HasProof      bool      `json:"hasProof"`
}

// Session is an event with its roster summary.
type Session struct {
	Key            string    `json:"key"`
	Category       string    `json:"category"`
	Title          string    `json:"title"`
	StartsAt       time.Time `json:"startsAt"`
	Location       string    `json:"location"`
	Limit          *int      `json:"limit,omitempty"`
	Participants   int       `json:"participants"`
	AttendanceOpen bool      `json:"attendanceOpen"`
	Unmarked       int       `json:"unmarked"`
}

// Participant is one booking on a session roster.
type Participant struct {
	BookingID  int64   `json:"bookingId"`
	Name       string  `json:"name"`
	Guest      bool    `json:"guest"`
	ManagedBy  *string `json:"managedBy,omitempty"`
	Status     string  `json:"status"`
	BoxingCard bool    `json:"boxingCard"`
	Attendance *string `json:"attendance,omitempty"`
	CanMark    bool    `json:"canMark"`
}

// Roster is a session with its participants. Outcome: ok | not_found.
type Roster struct {
	Outcome      string        `json:"outcome"`
	Session      *Session      `json:"session,omitempty"`
	Participants []Participant `json:"participants"`
}

// AdminResult is the outcome of an admin write.
// Outcome: reviewed | already_reviewed | sent | unavailable | marked |
// not_allowed | not_found | forbidden.
type AdminResult struct {
	Outcome     string       `json:"outcome"`
	Message     *string      `json:"message,omitempty"`
	BookingID   *int64       `json:"bookingId,omitempty"`
	Status      *string      `json:"status,omitempty"`
	PeaksDelta  *int         `json:"peaksDelta,omitempty"`
	Participant *Participant `json:"participant,omitempty"`
}

func (c *Client) AdminPayments(ctx context.Context) ([]Payment, error) {
	var out struct {
		Payments []Payment `json:"payments"`
	}
	err := c.do(ctx, http.MethodGet, "/internal/admin/payments", nil, &out)
	return out.Payments, err
}

func (c *Client) ReviewPayment(ctx context.Context, adminID int64, adminUsername string, bookingID int64, decision string) (AdminResult, error) {
	payload := map[string]any{"adminUserId": adminID, "decision": decision}
	if adminUsername != "" {
		payload["adminUsername"] = adminUsername
	}
	var out AdminResult
	err := c.do(ctx, http.MethodPost,
		"/internal/admin/payments/"+strconv.FormatInt(bookingID, 10)+"/review", payload, &out)
	return out, err
}

func (c *Client) SendProof(ctx context.Context, adminID, bookingID int64) (AdminResult, error) {
	var out AdminResult
	err := c.do(ctx, http.MethodPost,
		"/internal/admin/payments/"+strconv.FormatInt(bookingID, 10)+"/proof",
		map[string]any{"adminUserId": adminID}, &out)
	return out, err
}

func (c *Client) AdminSessions(ctx context.Context) ([]Session, error) {
	var out struct {
		Sessions []Session `json:"sessions"`
	}
	err := c.do(ctx, http.MethodGet, "/internal/admin/sessions", nil, &out)
	return out.Sessions, err
}

func (c *Client) Participants(ctx context.Context, key string) (Roster, error) {
	var out Roster
	err := c.do(ctx, http.MethodGet, "/internal/admin/participants?key="+url.QueryEscape(key), nil, &out)
	return out, err
}

func (c *Client) MarkAttendance(ctx context.Context, adminID, bookingID int64, attendance string) (AdminResult, error) {
	var out AdminResult
	err := c.do(ctx, http.MethodPost,
		"/internal/admin/bookings/"+strconv.FormatInt(bookingID, 10)+"/attendance",
		map[string]any{"adminUserId": adminID, "attendance": attendance}, &out)
	return out, err
}
