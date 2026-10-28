package httpapi

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"github.com/Zhorenty/dvor-chatbot/services/api/internal/bridge"
)

// admin lets through only ADMIN_USER_IDS from verified initData. The bot
// re-checks the id before writes.
func (s *Server) admin(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if !s.opts.AdminUserIDs[userFrom(r.Context()).ID] {
			writeError(w, http.StatusForbidden, "forbidden", "Раздел только для админов.")
			return
		}
		next(w, r)
	}
}

func (s *Server) routeAdmin(mux *http.ServeMux) {
	mux.Handle("GET /api/v1/admin/payments", s.auth(s.admin(s.handleAdminPayments)))
	mux.Handle("POST /api/v1/admin/payments/{id}/review", s.auth(s.admin(s.limited(s.handleReview))))
	mux.Handle("POST /api/v1/admin/payments/{id}/proof", s.auth(s.admin(s.limited(s.handleProof))))
	mux.Handle("GET /api/v1/admin/sessions", s.auth(s.admin(s.handleSessions)))
	mux.Handle("GET /api/v1/admin/sessions/participants", s.auth(s.admin(s.handleParticipants)))
	mux.Handle("POST /api/v1/admin/bookings/{id}/attendance", s.auth(s.admin(s.limited(s.handleAttendance))))
}

func (s *Server) handleAdminPayments(w http.ResponseWriter, r *http.Request) {
	payments, err := s.opts.Bot.AdminPayments(r.Context())
	if err != nil {
		s.bridgeError(w, err)
		return
	}
	if payments == nil {
		payments = []bridge.Payment{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"payments": payments})
}

func (s *Server) handleReview(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	var body struct {
		Decision string `json:"decision"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4<<10)).Decode(&body); err != nil ||
		(body.Decision != "approve" && body.Decision != "approve_partial" && body.Decision != "reject") {
		writeError(w, http.StatusBadRequest, "bad_request", "Не выбрано решение.")
		return
	}
	user := userFrom(r.Context())
	result, err := s.opts.Bot.ReviewPayment(r.Context(), user.ID, user.Username, id, body.Decision)
	if err != nil {
		s.bridgeError(w, err)
		return
	}
	// Approval and rejection change taken seats.
	s.invalidateSchedule()
	writeAdmin(w, result)
}

func (s *Server) handleProof(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	result, err := s.opts.Bot.SendProof(r.Context(), userFrom(r.Context()).ID, id)
	if err != nil {
		s.bridgeError(w, err)
		return
	}
	writeAdmin(w, result)
}

func (s *Server) handleSessions(w http.ResponseWriter, r *http.Request) {
	sessions, err := s.opts.Bot.AdminSessions(r.Context())
	if err != nil {
		s.bridgeError(w, err)
		return
	}
	if sessions == nil {
		sessions = []bridge.Session{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"sessions": sessions})
}

func (s *Server) handleParticipants(w http.ResponseWriter, r *http.Request) {
	key := strings.TrimSpace(r.URL.Query().Get("key"))
	if key == "" {
		writeError(w, http.StatusBadRequest, "bad_request", "Не выбрано событие.")
		return
	}
	roster, err := s.opts.Bot.Participants(r.Context(), key)
	if err != nil {
		s.bridgeError(w, err)
		return
	}
	if roster.Outcome != "ok" || roster.Session == nil {
		writeError(w, http.StatusNotFound, "not_found", "Событие не найдено.")
		return
	}
	if roster.Participants == nil {
		roster.Participants = []bridge.Participant{}
	}
	writeJSON(w, http.StatusOK, roster)
}

func (s *Server) handleAttendance(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	var body struct {
		Attendance string `json:"attendance"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4<<10)).Decode(&body); err != nil ||
		(body.Attendance != "attended" && body.Attendance != "absent") {
		writeError(w, http.StatusBadRequest, "bad_request", "Не выбрана отметка.")
		return
	}
	result, err := s.opts.Bot.MarkAttendance(r.Context(), userFrom(r.Context()).ID, id, body.Attendance)
	if err != nil {
		s.bridgeError(w, err)
		return
	}
	writeAdmin(w, result)
}

func pathID(w http.ResponseWriter, r *http.Request) (int64, bool) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusBadRequest, "bad_request", "Запись не найдена.")
		return 0, false
	}
	return id, true
}

func writeAdmin(w http.ResponseWriter, result bridge.AdminResult) {
	switch result.Outcome {
	case "reviewed", "sent", "marked":
		writeJSON(w, http.StatusOK, result)
	case "already_reviewed":
		writeError(w, http.StatusConflict, "already_reviewed", "Оплату уже проверили.")
	case "not_allowed":
		msg := "Отметить нельзя."
		if result.Message != nil && *result.Message != "" {
			msg = *result.Message
		}
		writeError(w, http.StatusConflict, "not_allowed", msg)
	case "unavailable":
		writeError(w, http.StatusBadGateway, "unavailable", "Не получилось отправить чек. Открой заявку в чате с ботом.")
	case "forbidden":
		writeError(w, http.StatusForbidden, "forbidden", "Раздел только для админов.")
	default:
		writeError(w, http.StatusNotFound, "not_found", "Запись не найдена.")
	}
}
