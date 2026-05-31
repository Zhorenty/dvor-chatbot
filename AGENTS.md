# AGENTS.md

This file documents project-specific guidance for AI/code agents working in this repository.

## Project Context

- Project: `dvor-chatbot`
- Stack: Dart (CLI app), long polling against Telegram Bot API
- Current scope (MVP):
  - Private chat: `/start`, `/trainings`
  - Group flow: DM new members with club info, fallback message in group if DM is not possible

## Architecture Snapshot

- Entry point: `bin/dvor_bot.dart`
- Runtime orchestrator: `lib/src/bot/bot_runner.dart`
- Config loading: `lib/src/config/app_config.dart`
- Telegram API adapter: `lib/src/telegram/telegram_client.dart`
- Handlers:
  - `lib/src/bot/handlers/private_handlers.dart`
  - `lib/src/bot/handlers/group_handlers.dart`
- Trainings domain/data:
  - `lib/src/domain/training_info.dart`
  - `lib/src/data/training_schedule_repository.dart`
  - `lib/src/data/static_schedule_repository.dart`
- Message composition: `lib/src/messages/message_templates.dart`

## Coding Rules

- Keep business logic out of Telegram transport layer:
  - API calls in `telegram_client`
  - behavior in handlers/services
  - text formatting in `message_templates`
- Prefer dependency injection via constructors (already used in handlers/runner).
- Keep repository abstraction (`TrainingScheduleRepository`) intact when adding new data sources.
- Use package imports only (`analysis_options.yaml` enforces this).
- Avoid adding experimental APIs unless absolutely necessary.

## Config and Secrets

- Never hardcode secrets.
- Use config priority:
  1. CLI args
  2. Environment variables
  3. `.env`
  4. defaults
- Main variables:
  - `BOT_TOKEN`
  - `TARGET_CHAT_ID`
  - `SEND_GROUP_FALLBACK`
  - `POLL_TIMEOUT_SECONDS`
  - `LOG_LEVEL`
- Do not commit real `.env` credentials.

## Telegram-Specific Behavior

- Process only relevant update types (`message` currently).
- Respect `TARGET_CHAT_ID` filter in group handler.
- DM delivery can fail if user has not started the bot; keep fallback behavior in group.
- Any new command should be added with:
  - handler logic in `private_handlers`
  - text in `message_templates`
  - tests

## Reliability Practices

- Keep retry + timeout behavior in Telegram API calls.
- Handle API failures explicitly with `TelegramApiException`.
- Maintain graceful shutdown handling (`SIGINT`/`SIGTERM` in entry point).

## Tests and Quality Gate

Before finishing any change, run:

```bash
dart format bin lib test
dart analyze --fatal-infos --fatal-warnings
dart test
```

Required test files for current MVP behavior:

- `test/private_handlers_test.dart`
- `test/group_handlers_test.dart`

## Documentation and Deployment

- Keep `README.md` updated when commands/config/behavior change.
- Docker image should continue to build with `Dockerfile`.
- When changing runtime env variables, update both:
  - `.env.example`
  - `README.md` config section

## Safe Change Checklist

When implementing a feature:

1. Add/update domain/data contracts first.
2. Add/update message templates.
3. Add/update handlers.
4. Add/update tests.
5. Run format + analyze + tests.
6. Update docs if behavior/config changed.

## Out of Scope for MVP (unless explicitly requested)

- Webhook mode
- Database-backed schedule storage
- Admin panel/API
- CI/CD pipeline changes
