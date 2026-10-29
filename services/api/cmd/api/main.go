// Command api serves the DVOR Telegram Mini App backend.
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/Zhorenty/dvor-chatbot/services/api/internal/bridge"
	"github.com/Zhorenty/dvor-chatbot/services/api/internal/config"
	"github.com/Zhorenty/dvor-chatbot/services/api/internal/httpapi"
	"github.com/Zhorenty/dvor-chatbot/services/api/internal/store"
	"github.com/Zhorenty/dvor-chatbot/services/api/internal/telegram"
)

func main() {
	if err := run(); err != nil {
		slog.Error("api stopped", "err", err)
		os.Exit(1)
	}
}

func run() error {
	cfg, err := config.Load(os.Args[1:])
	if err != nil {
		return err
	}
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: parseLevel(cfg.LogLevel)}))
	slog.SetDefault(logger)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	db, err := store.Open(cfg.DBPath)
	if err != nil {
		return err
	}
	defer db.Close()

	botAPI := telegram.NewBotAPI(cfg.BotToken)
	var botUsername atomic.Value
	botUsername.Store("")
	go resolveBot(ctx, botAPI, cfg, &botUsername, logger)

	server := httpapi.New(httpapi.Options{
		Bot:           bridge.NewClient(cfg.BridgeURL, cfg.BridgeToken),
		Profiles:      db,
		BotToken:      cfg.BotToken,
		BotUsername:   func() string { return botUsername.Load().(string) },
		AdminUserIDs:  cfg.AdminUserIDs,
		InitDataTTL:   cfg.InitDataTTL,
		ScheduleCache: cfg.ScheduleCache,
		Logger:        logger,
	})

	httpServer := &http.Server{
		Addr:              cfg.Addr,
		Handler:           server.Handler(),
		ReadHeaderTimeout: 5 * time.Second,
		// Receipt uploads over mobile networks and chat-driven RPCs are slow.
		ReadTimeout:  90 * time.Second,
		WriteTimeout: 90 * time.Second,
		IdleTimeout:  90 * time.Second,
	}
	errCh := make(chan error, 1)
	go func() {
		logger.Info("api listening", "addr", cfg.Addr, "bridge", cfg.BridgeURL)
		errCh <- httpServer.ListenAndServe()
	}()

	select {
	case err := <-errCh:
		if !errors.Is(err, http.ErrServerClosed) {
			return err
		}
	case <-ctx.Done():
		logger.Info("shutting down")
	}
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	return httpServer.Shutdown(shutdownCtx)
}

// resolveBot reads the bot username and installs the menu button, retrying
// while Telegram is unreachable.
func resolveBot(ctx context.Context, api *telegram.BotAPI, cfg config.Config, username *atomic.Value, logger *slog.Logger) {
	for attempt := 0; ; attempt++ {
		callCtx, cancel := context.WithTimeout(ctx, 15*time.Second)
		name, err := api.Username(callCtx)
		if err == nil && cfg.MiniAppURL != "" {
			err = api.SetMenuButton(callCtx, cfg.MenuButton, cfg.MiniAppURL)
		}
		cancel()
		if err == nil {
			username.Store(name)
			logger.Info("bot resolved", "username", name, "menuButton", cfg.MiniAppURL != "")
			return
		}
		logger.Warn("bot setup failed, retrying", "attempt", attempt, "err", err)
		select {
		case <-ctx.Done():
			return
		case <-time.After(min(time.Duration(attempt+1)*5*time.Second, time.Minute)):
		}
	}
}

func parseLevel(raw string) slog.Level {
	switch strings.ToLower(raw) {
	case "debug":
		return slog.LevelDebug
	case "warn", "warning":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}
