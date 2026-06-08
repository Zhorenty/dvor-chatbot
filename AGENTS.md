# AGENTS.md

Project guidance for AI/code agents in this repository.

## Project Overview

- Project: `dvor-chatbot`
- Stack: Dart CLI app, Telegram Bot API (long polling)
- MVP scope:
  - Private chat: `/start`, `/trainings`
  - Group flow: DM new members with club info, post fallback in group if DM is unavailable

## Source of Truth (Key Files)

- Entry point: `bin/dvor_bot.dart`
- App runtime: `lib/src/bot/bot_runner.dart`
- Config: `lib/src/config/app_config.dart`
- Telegram transport: `lib/src/telegram/telegram_client.dart`
- Handlers:
  - `lib/src/bot/handlers/private_handlers.dart`
  - `lib/src/bot/handlers/group_handlers.dart`
- Trainings domain/data:
  - `lib/src/domain/training_info.dart`
  - `lib/src/data/training_schedule_repository.dart`
  - `lib/src/data/static_schedule_repository.dart`
- Message text/templates: `lib/src/messages/message_templates.dart`

## Architecture and Coding Rules

- Keep layers clean:
  - `telegram_client`: raw Telegram API requests/responses only
  - handlers/services: behavior and orchestration
  - `message_templates`: text composition and formatting
- Preserve DI via constructors.
- Preserve repository abstraction (`TrainingScheduleRepository`) when adding/changing schedule sources.
- Use package imports only (`analysis_options.yaml`).
- Avoid experimental APIs unless there is a strong reason.

## Telegram Behavior Contract

- Process only relevant update types (currently `message`).
- Respect `TARGET_CHAT_ID` filtering in group flows.
- DM to new members may fail if the user has not started the bot:
  - keep fallback message logic in group
  - do not treat this as fatal
- Any new command must include:
  - handler update
  - message template update
  - tests

## Config and Secrets

- Never hardcode secrets or commit real credentials.
- Config precedence (highest to lowest):
  1. CLI args
  2. Environment variables
  3. `.env`
  4. defaults
- Core env vars:
  - `BOT_TOKEN`
  - `TARGET_CHAT_ID`
  - `SEND_GROUP_FALLBACK`
  - `POLL_TIMEOUT_SECONDS`
  - `LOG_LEVEL`

## Reliability Baseline

- Keep timeout/retry behavior in Telegram API calls.
- Handle Telegram failures explicitly via `TelegramApiException`.
- Keep graceful shutdown behavior (`SIGINT`/`SIGTERM`) intact.

## Required Validation Before Handoff

Run and pass all checks:

```bash
dart format bin lib test
dart analyze --fatal-infos --fatal-warnings
dart test
```

## Documentation Update Rules

Update docs when behavior/config/operations change:

- `README.md` (commands, config, behavior)
- `.env.example` (if env vars changed)
- deployment docs where relevant (notably `docs/DAILY_OPS_TIMEWEB.md`)

## Production Defaults (Timeweb Cloud)

Use these defaults unless explicitly told otherwise:

- Path: `/opt/dvor-chatbot-project`
- Runtime: Docker Compose (`docker compose`)
- Container: `dvor-chatbot`
- Persistent SQLite: `/opt/dvor-chatbot-project/data/bookings.sqlite`
- Production `.env`: `/opt/dvor-chatbot-project/.env`
- Backup script: `/opt/dvor-chatbot-project/backup.sh`
- Backup dir: `/opt/backups/dvor-chatbot-project`

Operational assumptions:

- Long polling mode (no public webhook endpoint required).
- Persistent volume for SQLite (`./data:/app/data`).
- After `.env` changes, restart compose services.

## Safe Change Flow

For new features and non-trivial changes:

1. Update domain/contracts first.
2. Update templates/messages.
3. Update handlers/services.
4. Add or adjust tests.
5. Run format, analyze, and tests.
6. Update docs if needed.

