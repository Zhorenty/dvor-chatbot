package httpapi

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"

	"github.com/Zhorenty/dvor-chatbot/services/api/internal/bridge"
)

// maxRPCBody fits a base64 photo of a receipt (8 MB raw) plus fields.
const maxRPCBody = 12 << 20

// readOnlyRPC never changes bookings, so the schedule cache stays valid.
var readOnlyRPC = map[string]bool{
	"payment.options":           true,
	"booking.rescheduleOptions": true,
	"card.overview":             true,
	"team.list":                 true,
	"admin.report":              true,
	"admin.cards.pending":       true,
	"admin.user":                true,
	"admin.schedule.list":       true,
	"admin.bookings.list":       true,
}

// handleRPC forwards one bot action as the verified user. Admin methods
// ("admin.*") require ADMIN_USER_IDS here; the bot re-checks them.
func (s *Server) handleRPC(w http.ResponseWriter, r *http.Request) {
	method := r.PathValue("method")
	if !bridge.ValidMethod(method) {
		writeError(w, http.StatusNotFound, "not_found", "Это действие недоступно.")
		return
	}
	user := userFrom(r.Context())
	if strings.HasPrefix(method, "admin.") && !s.opts.AdminUserIDs[user.ID] {
		writeError(w, http.StatusForbidden, "forbidden", "Раздел только для админов.")
		return
	}
	raw, err := io.ReadAll(http.MaxBytesReader(w, r.Body, maxRPCBody))
	if err != nil {
		writeError(w, http.StatusRequestEntityTooLarge, "too_large", "Файл слишком большой. Сожми фото или сделай скриншот.")
		return
	}
	if len(raw) == 0 {
		raw = []byte("{}")
	}
	if !json.Valid(raw) {
		writeError(w, http.StatusBadRequest, "bad_request", "Не получилось прочитать запрос.")
		return
	}
	out, err := s.opts.Bot.RPC(r.Context(), method, bridge.Caller{
		ID:        user.ID,
		Username:  user.Username,
		FirstName: user.FirstName,
	}, raw)
	var refused *bridge.RPCError
	switch {
	case errors.As(err, &refused):
		writeError(w, http.StatusUnprocessableEntity, refused.Code, refused.Message)
		return
	case err != nil:
		s.bridgeError(w, err)
		return
	}
	if !readOnlyRPC[method] {
		s.invalidateSchedule()
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(out)
}
