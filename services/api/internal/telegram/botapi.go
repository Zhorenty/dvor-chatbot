package telegram

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

// BotAPI is a minimal Bot API client. The bot process owns getUpdates;
// the API only reads identity and configures the menu button.
type BotAPI struct {
	token string
	http  *http.Client
	base  string
}

func NewBotAPI(token string) *BotAPI {
	return &BotAPI{
		token: token,
		http:  &http.Client{Timeout: 10 * time.Second},
		base:  "https://api.telegram.org",
	}
}

type apiResponse struct {
	OK          bool            `json:"ok"`
	Result      json.RawMessage `json:"result"`
	Description string          `json:"description"`
}

func (b *BotAPI) call(ctx context.Context, method string, payload any, out any) error {
	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		fmt.Sprintf("%s/bot%s/%s", b.base, b.token, method), bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := b.http.Do(req)
	if err != nil {
		return fmt.Errorf("telegram %s: %w", method, err)
	}
	defer resp.Body.Close()
	var decoded apiResponse
	if err := json.NewDecoder(resp.Body).Decode(&decoded); err != nil {
		return fmt.Errorf("telegram %s: decode: %w", method, err)
	}
	if !decoded.OK {
		return fmt.Errorf("telegram %s: %s", method, decoded.Description)
	}
	if out != nil {
		return json.Unmarshal(decoded.Result, out)
	}
	return nil
}

// Username returns the bot's @username without the @.
func (b *BotAPI) Username(ctx context.Context) (string, error) {
	var me struct {
		Username string `json:"username"`
	}
	if err := b.call(ctx, "getMe", map[string]any{}, &me); err != nil {
		return "", err
	}
	return me.Username, nil
}

// SetMenuButton points the default chat menu button at the Mini App.
func (b *BotAPI) SetMenuButton(ctx context.Context, text, appURL string) error {
	return b.call(ctx, "setChatMenuButton", map[string]any{
		"menu_button": map[string]any{
			"type":    "web_app",
			"text":    text,
			"web_app": map[string]string{"url": appURL},
		},
	}, nil)
}
