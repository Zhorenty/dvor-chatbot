// Package config loads API settings: CLI flags > environment > .env > defaults.
package config

import (
	"bufio"
	"errors"
	"flag"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Addr          string
	BotToken      string
	BridgeURL     string
	BridgeToken   string
	DBPath        string
	MiniAppURL    string
	MenuButton    string
	AdminUserIDs  map[int64]bool
	InitDataTTL   time.Duration
	ScheduleCache time.Duration
	LogLevel      string
}

func Load(args []string) (Config, error) {
	dotenv := readDotEnv(".env")
	fs := flag.NewFlagSet("api", flag.ContinueOnError)
	flags := map[string]*string{
		"API_ADDR":             fs.String("addr", "", "listen address"),
		"BOT_TOKEN":            fs.String("bot-token", "", "Telegram bot token"),
		"MINIAPP_BRIDGE_URL":   fs.String("bridge-url", "", "bot bridge base URL"),
		"MINIAPP_BRIDGE_TOKEN": fs.String("bridge-token", "", "bot bridge shared secret"),
		"BOOKINGS_DB_PATH":     fs.String("db", "", "SQLite path (read-only)"),
		"MINIAPP_URL":          fs.String("miniapp-url", "", "public Mini App URL"),
		"LOG_LEVEL":            fs.String("log-level", "", "debug|info|warn|error"),
	}
	if err := fs.Parse(args); err != nil {
		return Config{}, err
	}
	get := func(key, fallback string) string {
		if v := strings.TrimSpace(*flags[key]); v != "" {
			return v
		}
		if v := strings.TrimSpace(os.Getenv(key)); v != "" {
			return v
		}
		if v := strings.TrimSpace(dotenv[key]); v != "" {
			return v
		}
		return fallback
	}
	env := func(key, fallback string) string {
		if v := strings.TrimSpace(os.Getenv(key)); v != "" {
			return v
		}
		if v := strings.TrimSpace(dotenv[key]); v != "" {
			return v
		}
		return fallback
	}

	cfg := Config{
		Addr:          get("API_ADDR", ":8080"),
		BotToken:      get("BOT_TOKEN", ""),
		BridgeURL:     strings.TrimRight(get("MINIAPP_BRIDGE_URL", "http://dvor-chatbot:8081"), "/"),
		BridgeToken:   get("MINIAPP_BRIDGE_TOKEN", ""),
		DBPath:        get("BOOKINGS_DB_PATH", "data/bookings.sqlite"),
		MiniAppURL:    get("MINIAPP_URL", ""),
		MenuButton:    env("MINIAPP_MENU_BUTTON_TEXT", "DVOR"),
		AdminUserIDs:  parseIDs(env("ADMIN_USER_IDS", "")),
		InitDataTTL:   24 * time.Hour,
		ScheduleCache: 20 * time.Second,
		LogLevel:      get("LOG_LEVEL", "info"),
	}
	if cfg.BotToken == "" {
		return cfg, errors.New("BOT_TOKEN is required")
	}
	if len(cfg.BridgeToken) < 16 {
		return cfg, errors.New("MINIAPP_BRIDGE_TOKEN (16+ chars) is required")
	}
	return cfg, nil
}

func parseIDs(raw string) map[int64]bool {
	ids := map[int64]bool{}
	for _, part := range strings.Split(raw, ",") {
		if id, err := strconv.ParseInt(strings.TrimSpace(part), 10, 64); err == nil {
			ids[id] = true
		}
	}
	return ids
}

func readDotEnv(path string) map[string]string {
	out := map[string]string{}
	f, err := os.Open(path)
	if err != nil {
		return out
	}
	defer f.Close()
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		out[strings.TrimSpace(key)] = strings.Trim(strings.TrimSpace(value), `"'`)
	}
	return out
}
