package httpapi

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/Zhorenty/dvor-chatbot/services/api/internal/bridge"
	"github.com/Zhorenty/dvor-chatbot/services/api/internal/store"
)

const token = "123:abc"

type fakeBot struct {
	scheduleCalls int
	scheduleErr   error
	bookResult    bridge.ActionResult
	lastBook      string
	adminResult   bridge.AdminResult
	roster        bridge.Roster
	adminCalls    []string
	rpcCalls      []string
	rpcErr        error
}

func (f *fakeBot) RPC(_ context.Context, method string, caller bridge.Caller, params json.RawMessage) (json.RawMessage, error) {
	f.rpcCalls = append(f.rpcCalls, method+":"+strconv.FormatInt(caller.ID, 10)+":"+string(params))
	if f.rpcErr != nil {
		return nil, f.rpcErr
	}
	return json.RawMessage(`{"ok":true}`), nil
}

func (f *fakeBot) Schedule(context.Context) (bridge.Schedule, error) {
	f.scheduleCalls++
	if f.scheduleErr != nil {
		return bridge.Schedule{}, f.scheduleErr
	}
	return bridge.Schedule{Events: []bridge.Event{{Key: "k", Title: "Бокс"}}}, nil
}

func (f *fakeBot) Bookings(context.Context, int64) ([]bridge.Booking, error) { return nil, nil }

func (f *fakeBot) Book(_ context.Context, userID int64, username, key string) (bridge.ActionResult, error) {
	f.lastBook = strconv.FormatInt(userID, 10) + ":" + username + ":" + key
	return f.bookResult, nil
}

func (f *fakeBot) Cancel(context.Context, int64, int64) (bridge.ActionResult, error) {
	return bridge.ActionResult{Outcome: "too_late"}, nil
}

func (f *fakeBot) AdminPayments(context.Context) ([]bridge.Payment, error) {
	f.adminCalls = append(f.adminCalls, "payments")
	return nil, nil
}

func (f *fakeBot) ReviewPayment(_ context.Context, adminID int64, adminUsername string, bookingID int64, decision string) (bridge.AdminResult, error) {
	f.adminCalls = append(f.adminCalls, "review:"+strconv.FormatInt(adminID, 10)+":"+adminUsername+":"+strconv.FormatInt(bookingID, 10)+":"+decision)
	return f.adminResult, nil
}

func (f *fakeBot) SendProof(_ context.Context, adminID, bookingID int64) (bridge.AdminResult, error) {
	f.adminCalls = append(f.adminCalls, "proof:"+strconv.FormatInt(bookingID, 10))
	return f.adminResult, nil
}

func (f *fakeBot) AdminSessions(context.Context) ([]bridge.Session, error) {
	f.adminCalls = append(f.adminCalls, "sessions")
	return []bridge.Session{{Key: "k", Title: "Бокс", Participants: 3}}, nil
}

func (f *fakeBot) Participants(_ context.Context, key string) (bridge.Roster, error) {
	f.adminCalls = append(f.adminCalls, "participants:"+key)
	return f.roster, nil
}

func (f *fakeBot) MarkAttendance(_ context.Context, adminID, bookingID int64, attendance string) (bridge.AdminResult, error) {
	f.adminCalls = append(f.adminCalls, "attendance:"+strconv.FormatInt(bookingID, 10)+":"+attendance)
	return f.adminResult, nil
}

type fakeProfiles struct{}

func (fakeProfiles) Profile(context.Context, int64) (store.Profile, error) {
	return store.Profile{Peaks: 120, Visits: 3}, nil
}

func initData(t *testing.T, now time.Time) string {
	t.Helper()
	fields := map[string]string{
		"auth_date": strconv.FormatInt(now.Unix(), 10),
		"user":      `{"id":7,"first_name":"Ваня","username":"vanya"}`,
	}
	pairs := []string{}
	for k, v := range fields {
		pairs = append(pairs, k+"="+v)
	}
	sort.Strings(pairs)
	secret := mac([]byte("WebAppData"), []byte(token))
	values := url.Values{}
	for k, v := range fields {
		values.Set(k, v)
	}
	values.Set("hash", hex.EncodeToString(mac(secret, []byte(strings.Join(pairs, "\n")))))
	return values.Encode()
}

func mac(key, data []byte) []byte {
	h := hmac.New(sha256.New, key)
	h.Write(data)
	return h.Sum(nil)
}

func newTestServer(bot *fakeBot, now *time.Time) http.Handler {
	return newTestServerWithAdmins(bot, now, map[int64]bool{})
}

func newTestServerWithAdmins(bot *fakeBot, now *time.Time, admins map[int64]bool) http.Handler {
	return New(Options{
		Bot:           bot,
		Profiles:      fakeProfiles{},
		BotToken:      token,
		BotUsername:   func() string { return "dvor_bot" },
		AdminUserIDs:  admins,
		InitDataTTL:   time.Hour,
		ScheduleCache: 20 * time.Second,
		Logger:        slog.New(slog.NewTextHandler(io.Discard, nil)),
		Now:           func() time.Time { return *now },
	}).Handler()
}

func do(t *testing.T, h http.Handler, method, path, auth, body string) (int, map[string]any) {
	t.Helper()
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	if auth != "" {
		req.Header.Set("Authorization", "tma "+auth)
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	var out map[string]any
	_ = json.Unmarshal(rec.Body.Bytes(), &out)
	return rec.Code, out
}

func TestAuthRequired(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	h := newTestServer(&fakeBot{}, &now)
	if code, _ := do(t, h, "GET", "/api/v1/me", "", ""); code != http.StatusUnauthorized {
		t.Fatalf("code = %d", code)
	}
	if code, _ := do(t, h, "GET", "/api/v1/me", "auth_date=1&hash=00", ""); code != http.StatusUnauthorized {
		t.Fatalf("code = %d", code)
	}
}

func TestMe(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	h := newTestServer(&fakeBot{}, &now)
	code, body := do(t, h, "GET", "/api/v1/me", initData(t, now), "")
	if code != http.StatusOK {
		t.Fatalf("code = %d body=%v", code, body)
	}
	if body["referralLink"] != "https://t.me/dvor_bot?start=ref_7" {
		t.Fatalf("referral = %v", body["referralLink"])
	}
	if body["profile"].(map[string]any)["peaks"].(float64) != 120 {
		t.Fatalf("profile = %v", body["profile"])
	}
}

func TestScheduleIsCachedAndServedStale(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	bot := &fakeBot{}
	h := newTestServer(bot, &now)
	auth := initData(t, now)
	do(t, h, "GET", "/api/v1/events", auth, "")
	do(t, h, "GET", "/api/v1/events", auth, "")
	if bot.scheduleCalls != 1 {
		t.Fatalf("calls = %d, want cached", bot.scheduleCalls)
	}
	now = now.Add(time.Minute)
	bot.scheduleErr = errors.New("down")
	code, body := do(t, h, "GET", "/api/v1/events", initData(t, now), "")
	if code != http.StatusOK || len(body["events"].([]any)) != 1 {
		t.Fatalf("stale schedule not served: %d %v", code, body)
	}
}

func TestBookOutcomes(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	tests := []struct {
		outcome string
		want    int
	}{
		{"created", http.StatusOK},
		{"exists", http.StatusOK},
		{"full", http.StatusConflict},
		{"not_found", http.StatusNotFound},
	}
	for _, tt := range tests {
		t.Run(tt.outcome, func(t *testing.T) {
			bot := &fakeBot{bookResult: bridge.ActionResult{Outcome: tt.outcome}}
			h := newTestServer(bot, &now)
			code, _ := do(t, h, "POST", "/api/v1/bookings", initData(t, now), `{"key":"k"}`)
			if code != tt.want {
				t.Fatalf("code = %d, want %d", code, tt.want)
			}
			if bot.lastBook != "7:vanya:k" {
				t.Fatalf("book call = %q", bot.lastBook)
			}
		})
	}
}

func TestBookValidatesBody(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	h := newTestServer(&fakeBot{}, &now)
	if code, _ := do(t, h, "POST", "/api/v1/bookings", initData(t, now), `{}`); code != http.StatusBadRequest {
		t.Fatalf("code = %d", code)
	}
}

func TestCancelTooLate(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	h := newTestServer(&fakeBot{}, &now)
	code, body := do(t, h, "POST", "/api/v1/bookings/5/cancel", initData(t, now), "")
	if code != http.StatusConflict || body["error"].(map[string]any)["code"] != "too_late" {
		t.Fatalf("code = %d body = %v", code, body)
	}
}

func TestRateLimit(t *testing.T) {
	l := newLimiter(2, time.Second)
	now := time.Unix(0, 0)
	if !l.allow(1, now) || !l.allow(1, now) {
		t.Fatal("burst should pass")
	}
	if l.allow(1, now) {
		t.Fatal("third call should be limited")
	}
	if !l.allow(1, now.Add(time.Second)) {
		t.Fatal("refill should allow")
	}
}

func TestAdminRoutesRequireAdmin(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	bot := &fakeBot{adminResult: bridge.AdminResult{Outcome: "reviewed"}}
	h := newTestServer(bot, &now)
	auth := initData(t, now)
	for _, tt := range []struct{ method, path, body string }{
		{"GET", "/api/v1/admin/payments", ""},
		{"POST", "/api/v1/admin/payments/3/review", `{"decision":"approve"}`},
		{"POST", "/api/v1/admin/payments/3/proof", ""},
		{"GET", "/api/v1/admin/sessions", ""},
		{"GET", "/api/v1/admin/sessions/participants?key=k", ""},
		{"POST", "/api/v1/admin/bookings/3/attendance", `{"attendance":"attended"}`},
	} {
		if code, _ := do(t, h, tt.method, tt.path, auth, tt.body); code != http.StatusForbidden {
			t.Fatalf("%s %s: code = %d, want 403", tt.method, tt.path, code)
		}
	}
	if len(bot.adminCalls) != 0 {
		t.Fatalf("bridge called for non-admin: %v", bot.adminCalls)
	}
}

func TestAdminReview(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	tests := []struct {
		outcome string
		want    int
	}{
		{"reviewed", http.StatusOK},
		{"already_reviewed", http.StatusConflict},
		{"not_found", http.StatusNotFound},
		{"forbidden", http.StatusForbidden},
	}
	for _, tt := range tests {
		t.Run(tt.outcome, func(t *testing.T) {
			bot := &fakeBot{adminResult: bridge.AdminResult{Outcome: tt.outcome}}
			h := newTestServerWithAdmins(bot, &now, map[int64]bool{7: true})
			code, _ := do(t, h, "POST", "/api/v1/admin/payments/3/review", initData(t, now), `{"decision":"approve_partial"}`)
			if code != tt.want {
				t.Fatalf("code = %d, want %d", code, tt.want)
			}
			if len(bot.adminCalls) != 1 || bot.adminCalls[0] != "review:7:vanya:3:approve_partial" {
				t.Fatalf("calls = %v", bot.adminCalls)
			}
		})
	}
	bot := &fakeBot{}
	h := newTestServerWithAdmins(bot, &now, map[int64]bool{7: true})
	if code, _ := do(t, h, "POST", "/api/v1/admin/payments/3/review", initData(t, now), `{"decision":"maybe"}`); code != http.StatusBadRequest {
		t.Fatalf("code = %d", code)
	}
}

func TestAdminSessionsAndAttendance(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	msg := "Отметить явку можно после старта."
	bot := &fakeBot{
		adminResult: bridge.AdminResult{Outcome: "not_allowed", Message: &msg},
		roster:      bridge.Roster{Outcome: "ok", Session: &bridge.Session{Key: "a|b c"}},
	}
	h := newTestServerWithAdmins(bot, &now, map[int64]bool{7: true})
	auth := initData(t, now)
	code, body := do(t, h, "GET", "/api/v1/admin/sessions", auth, "")
	if code != http.StatusOK || len(body["sessions"].([]any)) != 1 {
		t.Fatalf("sessions: %d %v", code, body)
	}
	code, body = do(t, h, "GET", "/api/v1/admin/sessions/participants?key="+url.QueryEscape("a|b c"), auth, "")
	if code != http.StatusOK || body["participants"] == nil {
		t.Fatalf("participants: %d %v", code, body)
	}
	code, body = do(t, h, "POST", "/api/v1/admin/bookings/4/attendance", auth, `{"attendance":"absent"}`)
	if code != http.StatusConflict || body["error"].(map[string]any)["message"] != msg {
		t.Fatalf("attendance: %d %v", code, body)
	}
	want := []string{"sessions", "participants:a|b c", "attendance:4:absent"}
	if strings.Join(bot.adminCalls, ",") != strings.Join(want, ",") {
		t.Fatalf("calls = %v", bot.adminCalls)
	}
	bot.roster = bridge.Roster{Outcome: "not_found"}
	if code, _ := do(t, h, "GET", "/api/v1/admin/sessions/participants?key=x", auth, ""); code != http.StatusNotFound {
		t.Fatalf("missing roster code = %d", code)
	}
}

func TestRPC(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	bot := &fakeBot{}
	h := newTestServer(bot, &now)
	auth := initData(t, now)

	code, body := do(t, h, "POST", "/api/v1/rpc/payment.options", auth, `{"bookingId":5}`)
	if code != http.StatusOK || body["ok"] != true {
		t.Fatalf("code = %d body = %v", code, body)
	}
	if len(bot.rpcCalls) != 1 || bot.rpcCalls[0] != `payment.options:7:{"bookingId":5}` {
		t.Fatalf("calls = %v", bot.rpcCalls)
	}

	if code, _ := do(t, h, "POST", "/api/v1/rpc/admin.report", auth, `{}`); code != http.StatusForbidden {
		t.Fatalf("admin rpc for member: code = %d", code)
	}
	if code, _ := do(t, h, "POST", "/api/v1/rpc/bad%20name", auth, `{}`); code != http.StatusNotFound {
		t.Fatalf("bad method: code = %d", code)
	}
	if code, _ := do(t, h, "POST", "/api/v1/rpc/payment.options", auth, `{nope`); code != http.StatusBadRequest {
		t.Fatalf("bad json: code = %d", code)
	}

	bot.rpcErr = &bridge.RPCError{Code: "too_late", Message: "Поздно."}
	code, body = do(t, h, "POST", "/api/v1/rpc/payment.peaks", auth, `{"bookingId":5}`)
	if code != http.StatusUnprocessableEntity || body["error"].(map[string]any)["message"] != "Поздно." {
		t.Fatalf("refusal: code = %d body = %v", code, body)
	}
}

func TestPublicScheduleHidesSeatsUntilLow(t *testing.T) {
	ptr := func(v int) *int { return &v }
	in := bridge.Schedule{Events: []bridge.Event{
		{Key: "many", Limit: ptr(30), Taken: ptr(3)},
		{Key: "low", Limit: ptr(10), Taken: ptr(8)},
		{Key: "full", Limit: ptr(10), Taken: ptr(10)},
		{Key: "open"},
	}}
	out := publicSchedule(in)
	if out.Events[0].Limit != nil || out.Events[0].Taken != nil {
		t.Fatalf("plenty of seats must stay hidden: %+v", out.Events[0])
	}
	if *out.Events[1].Taken != 8 || *out.Events[2].Taken != 10 {
		t.Fatalf("low and full must stay visible: %+v %+v", out.Events[1], out.Events[2])
	}
	if in.Events[0].Limit == nil {
		t.Fatal("cached schedule must not change")
	}
}
