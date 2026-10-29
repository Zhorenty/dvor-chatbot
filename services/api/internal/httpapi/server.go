// Package httpapi exposes the Mini App REST API.
package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/Zhorenty/dvor-chatbot/services/api/internal/bridge"
	"github.com/Zhorenty/dvor-chatbot/services/api/internal/store"
	"github.com/Zhorenty/dvor-chatbot/services/api/internal/telegram"
)

// Bot is the subset of the bot bridge the API uses.
type Bot interface {
	Schedule(ctx context.Context) (bridge.Schedule, error)
	Bookings(ctx context.Context, userID int64) ([]bridge.Booking, error)
	Book(ctx context.Context, userID int64, username, key string) (bridge.ActionResult, error)
	Cancel(ctx context.Context, userID, bookingID int64) (bridge.ActionResult, error)
	AdminPayments(ctx context.Context) ([]bridge.Payment, error)
	ReviewPayment(ctx context.Context, adminID int64, adminUsername string, bookingID int64, decision string) (bridge.AdminResult, error)
	SendProof(ctx context.Context, adminID, bookingID int64) (bridge.AdminResult, error)
	AdminSessions(ctx context.Context) ([]bridge.Session, error)
	Participants(ctx context.Context, key string) (bridge.Roster, error)
	MarkAttendance(ctx context.Context, adminID, bookingID int64, attendance string) (bridge.AdminResult, error)
	RPC(ctx context.Context, method string, caller bridge.Caller, params json.RawMessage) (json.RawMessage, error)
}

// Profiles reads profile aggregates.
type Profiles interface {
	Profile(ctx context.Context, userID int64) (store.Profile, error)
}

type Options struct {
	Bot           Bot
	Profiles      Profiles
	BotToken      string
	BotUsername   func() string
	AdminUserIDs  map[int64]bool
	InitDataTTL   time.Duration
	ScheduleCache time.Duration
	Logger        *slog.Logger
	Now           func() time.Time
}

type Server struct {
	opts    Options
	limiter *limiter

	scheduleMu      sync.Mutex
	schedule        *bridge.Schedule
	scheduleFetched time.Time
}

func New(opts Options) *Server {
	if opts.Now == nil {
		opts.Now = time.Now
	}
	if opts.Logger == nil {
		opts.Logger = slog.Default()
	}
	if opts.BotUsername == nil {
		opts.BotUsername = func() string { return "" }
	}
	return &Server{opts: opts, limiter: newLimiter(5, time.Second)}
}

func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
	})
	mux.Handle("GET /api/v1/me", s.auth(s.handleMe))
	mux.Handle("GET /api/v1/events", s.auth(s.handleEvents))
	mux.Handle("GET /api/v1/bookings", s.auth(s.handleBookings))
	mux.Handle("POST /api/v1/bookings", s.auth(s.limited(s.handleBook)))
	mux.Handle("POST /api/v1/bookings/{id}/cancel", s.auth(s.limited(s.handleCancel)))
	s.routeAdmin(mux)
	mux.Handle("POST /api/v1/rpc/{method}", s.auth(s.limited(s.handleRPC)))
	return s.recover(s.logRequests(mux))
}

type userKey struct{}

func userFrom(ctx context.Context) telegram.User {
	user, _ := ctx.Value(userKey{}).(telegram.User)
	return user
}

// auth accepts "Authorization: tma <initData>" as recommended by Telegram.
func (s *Server) auth(next http.HandlerFunc) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw, ok := strings.CutPrefix(r.Header.Get("Authorization"), "tma ")
		if !ok || raw == "" {
			writeError(w, http.StatusUnauthorized, "unauthorized", "Открой приложение из Telegram.")
			return
		}
		data, err := telegram.ValidateInitData(raw, s.opts.BotToken, s.opts.InitDataTTL, s.opts.Now())
		if err != nil {
			writeError(w, http.StatusUnauthorized, "unauthorized", "Сессия устарела. Перезапусти приложение.")
			return
		}
		next(w, r.WithContext(context.WithValue(r.Context(), userKey{}, data.User)))
	})
}

func (s *Server) limited(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if !s.limiter.allow(userFrom(r.Context()).ID, s.opts.Now()) {
			writeError(w, http.StatusTooManyRequests, "rate_limited", "Слишком часто. Попробуй через пару секунд.")
			return
		}
		next(w, r)
	}
}

type meResponse struct {
	User         telegram.User `json:"user"`
	IsAdmin      bool          `json:"isAdmin"`
	Profile      store.Profile `json:"profile"`
	BotUsername  string        `json:"botUsername"`
	ReferralLink string        `json:"referralLink,omitempty"`
}

func (s *Server) handleMe(w http.ResponseWriter, r *http.Request) {
	user := userFrom(r.Context())
	profile, err := s.opts.Profiles.Profile(r.Context(), user.ID)
	if err != nil {
		s.opts.Logger.Warn("profile read failed", "user", user.ID, "err", err)
	}
	resp := meResponse{
		User:        user,
		IsAdmin:     s.opts.AdminUserIDs[user.ID],
		Profile:     profile,
		BotUsername: s.opts.BotUsername(),
	}
	if resp.BotUsername != "" {
		resp.ReferralLink = "https://t.me/" + resp.BotUsername + "?start=ref_" + strconv.FormatInt(user.ID, 10)
	}
	writeJSON(w, http.StatusOK, resp)
}

func (s *Server) handleEvents(w http.ResponseWriter, r *http.Request) {
	schedule, err := s.cachedSchedule(r.Context())
	if err != nil {
		s.bridgeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, publicSchedule(schedule))
}

// lowSeatsShare mirrors the bot's group post rule: seat counts are public
// only when under 30% of places are free.
const lowSeatsShare = 0.3

// publicSchedule hides seat counts unless they are running out. The cached
// schedule is not modified.
func publicSchedule(schedule bridge.Schedule) bridge.Schedule {
	events := make([]bridge.Event, len(schedule.Events))
	for i, e := range schedule.Events {
		if e.Limit != nil && *e.Limit > 0 {
			taken := 0
			if e.Taken != nil {
				taken = *e.Taken
			}
			free := max(*e.Limit-taken, 0)
			if float64(free)/float64(*e.Limit) >= lowSeatsShare {
				e.Limit, e.Taken = nil, nil
			}
		}
		events[i] = e
	}
	schedule.Events = events
	return schedule
}

// cachedSchedule keeps the catalog for a short time and serves the last good
// copy while the bot restarts.
func (s *Server) cachedSchedule(ctx context.Context) (bridge.Schedule, error) {
	s.scheduleMu.Lock()
	defer s.scheduleMu.Unlock()
	now := s.opts.Now()
	if s.schedule != nil && now.Sub(s.scheduleFetched) < s.opts.ScheduleCache {
		return *s.schedule, nil
	}
	fresh, err := s.opts.Bot.Schedule(ctx)
	if err != nil {
		if s.schedule != nil {
			s.opts.Logger.Warn("serving stale schedule", "err", err)
			return *s.schedule, nil
		}
		return bridge.Schedule{}, err
	}
	s.schedule = &fresh
	s.scheduleFetched = now
	return fresh, nil
}

func (s *Server) invalidateSchedule() {
	s.scheduleMu.Lock()
	s.scheduleFetched = time.Time{}
	s.scheduleMu.Unlock()
}

func (s *Server) handleBookings(w http.ResponseWriter, r *http.Request) {
	bookings, err := s.opts.Bot.Bookings(r.Context(), userFrom(r.Context()).ID)
	if err != nil {
		s.bridgeError(w, err)
		return
	}
	if bookings == nil {
		bookings = []bridge.Booking{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"bookings": bookings})
}

func (s *Server) handleBook(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Key string `json:"key"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4<<10)).Decode(&body); err != nil ||
		strings.TrimSpace(body.Key) == "" {
		writeError(w, http.StatusBadRequest, "bad_request", "Не выбрано событие.")
		return
	}
	user := userFrom(r.Context())
	result, err := s.opts.Bot.Book(r.Context(), user.ID, user.Username, body.Key)
	if err != nil {
		s.bridgeError(w, err)
		return
	}
	s.invalidateSchedule()
	writeAction(w, result)
}

func (s *Server) handleCancel(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusBadRequest, "bad_request", "Запись не найдена.")
		return
	}
	result, err := s.opts.Bot.Cancel(r.Context(), userFrom(r.Context()).ID, id)
	if err != nil {
		s.bridgeError(w, err)
		return
	}
	s.invalidateSchedule()
	writeAction(w, result)
}

func writeAction(w http.ResponseWriter, result bridge.ActionResult) {
	switch result.Outcome {
	case "created", "exists", "cancelled":
		writeJSON(w, http.StatusOK, result)
	case "full":
		writeError(w, http.StatusConflict, "full", "Мест уже нет.")
	case "too_late":
		msg := "Отменить уже нельзя."
		if result.Message != nil && *result.Message != "" {
			msg = *result.Message
		}
		writeError(w, http.StatusConflict, "too_late", msg)
	default:
		writeError(w, http.StatusNotFound, "not_found", "Событие или запись не найдены.")
	}
}

func (s *Server) bridgeError(w http.ResponseWriter, err error) {
	s.opts.Logger.Error("bridge call failed", "err", err)
	if errors.Is(err, context.Canceled) {
		return
	}
	writeError(w, http.StatusServiceUnavailable, "unavailable", "Бот сейчас перезапускается. Попробуй через минуту.")
}

type apiError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func writeError(w http.ResponseWriter, status int, code, message string) {
	writeJSON(w, status, map[string]apiError{"error": {Code: code, Message: message}})
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(status int) {
	r.status = status
	r.ResponseWriter.WriteHeader(status)
}

func (s *Server) logRequests(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		started := time.Now()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r)
		s.opts.Logger.Info("http", "method", r.Method, "path", r.URL.Path,
			"status", rec.status, "dur_ms", time.Since(started).Milliseconds())
	})
}

func (s *Server) recover(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if v := recover(); v != nil {
				s.opts.Logger.Error("panic", "path", r.URL.Path, "value", v)
				writeError(w, http.StatusInternalServerError, "internal", "Что-то пошло не так.")
			}
		}()
		next.ServeHTTP(w, r)
	})
}

// limiter is a per-user token bucket for write endpoints.
type limiter struct {
	mu      sync.Mutex
	burst   float64
	refill  time.Duration
	buckets map[int64]*bucket
}

type bucket struct {
	tokens float64
	last   time.Time
}

func newLimiter(burst int, refill time.Duration) *limiter {
	return &limiter{burst: float64(burst), refill: refill, buckets: map[int64]*bucket{}}
}

func (l *limiter) allow(userID int64, now time.Time) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	b, ok := l.buckets[userID]
	if !ok {
		b = &bucket{tokens: l.burst, last: now}
		l.buckets[userID] = b
	}
	b.tokens = min(l.burst, b.tokens+float64(now.Sub(b.last))/float64(l.refill))
	b.last = now
	if b.tokens < 1 {
		return false
	}
	b.tokens--
	return true
}
