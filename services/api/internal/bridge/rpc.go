package bridge

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"time"
)

// Caller is the verified Telegram user an RPC runs as.
type Caller struct {
	ID        int64  `json:"id"`
	Username  string `json:"username,omitempty"`
	FirstName string `json:"firstName,omitempty"`
}

// RPCError is a refusal with a message meant for the user.
type RPCError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func (e *RPCError) Error() string { return e.Code + ": " + e.Message }

var methodName = regexp.MustCompile(`^[a-zA-Z]+(\.[a-zA-Z]+)*$`)

// ValidMethod reports whether name looks like an RPC method ("payment.options").
func ValidMethod(name string) bool { return len(name) <= 64 && methodName.MatchString(name) }

// RPC calls a bot action (payment, BOXING CARD, admin tools). The result is
// returned as raw JSON; a refusal comes back as *RPCError.
func (c *Client) RPC(ctx context.Context, method string, caller Caller, params json.RawMessage) (json.RawMessage, error) {
	if len(params) == 0 {
		params = json.RawMessage("{}")
	}
	body, err := json.Marshal(map[string]any{"user": caller, "params": params})
	if err != nil {
		return nil, err
	}
	// Receipts and multi-step chat flows can take a while.
	ctx, cancel := context.WithTimeout(ctx, 60*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/internal/rpc/"+method, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+c.token)
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.rpcHTTP.Do(req)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrUnavailable, err)
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrUnavailable, err)
	}
	switch resp.StatusCode {
	case http.StatusOK:
		return raw, nil
	case http.StatusUnprocessableEntity:
		var payload struct {
			Error RPCError `json:"error"`
		}
		if json.Unmarshal(raw, &payload) == nil && payload.Error.Message != "" {
			return nil, &payload.Error
		}
	}
	return nil, fmt.Errorf("%w: rpc %s -> %d", ErrUnavailable, method, resp.StatusCode)
}
