# AGENTS.md

Project guidance for AI/code agents in this repository.

## Project Overview

- Project: `dvor-chatbot`
- Stack: Dart CLI app, Telegram Bot API (long polling)
- MVP scope:
  - Private chat: `/start`, `/trainings`
  - Group flow: DM new members with club info, post fallback in group if DM is unavailable

## Source of Truth (Key Files)

- Entry point: `bin/dvor_bot.dart` (shared SQLite handle for booking/onboarding/subscription)
- App runtime: `lib/src/bot/bot_runner.dart` + `lib/src/jobs/job_scheduler.dart`
- Config: `lib/src/config/app_config.dart`
- Telegram transport: `lib/src/telegram/telegram_client.dart`
- Handlers:
 - `lib/src/bot/handlers/private_handlers.dart` (facade + DI, ≪200 LOC)
 - `lib/src/bot/handlers/private/private_handlers_dispatch*.part.dart` (update routing by domain)
 - `lib/src/bot/handlers/private/*.part.dart` (booking/payment/admin/onboarding/bonuses/schedule ops)
 - `lib/src/application/admin_analytics_service.dart` (admin analytics aggregates)
 - `lib/src/bot/handlers/group_handlers.dart`
- Jobs: `lib/src/jobs/` (promo/broadcast jobs use persistent `job_dedupe_log`)
- Anti-spam:
  - `lib/src/application/group_spam_detector.dart`
- Trainings domain/data:
  - `lib/src/domain/training_info.dart`
 - `lib/src/data/training_schedule_repository.dart`
 - `lib/src/data/static_schedule_repository.dart`
 - `lib/src/data/dvor_team_repository.dart` (+ Google Sheets gid `2001400867`)
 - `lib/src/data/sqlite/sqlite_database_handle.dart`
- Conversation log: `lib/src/data/sqlite_conversation_log_repository.dart` (+ `LoggingMessageSender`)
- Message text/templates: `lib/src/messages/message_templates.dart` (+ `templates/*.part.dart`)
- HTML escaping: `lib/src/messages/html_escaper.dart`
- Club voice / copy: `docs/VOICE.md` (read before generating or editing user-facing text)

## Architecture and Coding Rules

- Keep layers clean:
  - `telegram_client`: raw Telegram API requests/responses only
  - handlers/services: behavior and orchestration
  - `message_templates`: text composition and formatting
- Preserve DI via constructors.
- Preserve repository abstraction (`TrainingScheduleRepository`) when adding/changing schedule sources.
- Use package imports only (`analysis_options.yaml`).
- Avoid experimental APIs unless there is a strong reason.

## Voice and Copy

When asked to write or edit user-facing text (group posts, broadcasts, congratulations, onboarding, templates), follow `docs/VOICE.md`. Do not invent a new tone. Do not rewrite existing `message_templates` copy to match the milestone example unless the task is explicitly about copy.

- DVOR is a sports club people train *with*, not a gym brand or a sales funnel. Brand spelling: `DVOR`.
- Address one person (DM, named welcome) as «ты»; the group as a whole as «вы». Do not mix in one text.
- Meaning before hype. Concrete life of the club over abstract «сообщество». Name only the activities the text is about.
- Short sentences, 1–3 line paragraphs, air between blocks. One emoji as a headline anchor, not a shower of emoji.
- Pick a genre first (milestone, welcome, schedule/promo, referral/payment, bot UX, onboarding, admin). The milestone skeleton is for community posts only.
- Community posts have no hard sell and close physically (`До встречи на площадке. DVOR 🤝`). CTA only when the message is about an action; then one CTA, factual scarcity OK, FOMO is not.
- Bot UX: fact → status → one next step. No club signature. Onboarding: one question or one step, not the whole club.
- Do not invent dates, coaches, prices, address, or headcount. Escape user-provided strings. HTML, `<b>` on headline/key words only.

Avoid: «дорогие друзья», «от лица команды», «администрация», «не упусти шанс», «эксклюзив», walls of text, `!!!`, mixing English slang except product terms already in use (`Start`, `PRO`).

## Telegram Behavior Contract

- Process only relevant update types (currently `message`).
- Respect `TARGET_CHAT_ID` filtering in group flows.
- For new bot-facing message UX, prefer Telegram rich formatting first (`sendRichMessage`/rich entities when available; otherwise `HTML` parse mode with safe escaping).
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
  - `ADMIN_USER_IDS` / `ADMIN_CHAT_ID`
  - `ANTISPAM_ENABLED`
  - `LOG_LEVEL`

## Reliability Baseline

- Keep timeout/retry behavior in Telegram API calls.
- Handle Telegram failures explicitly via `TelegramApiException`.
- Keep graceful shutdown behavior (`SIGINT`/`SIGTERM`) intact.
- Capacity checks for bookings run inside `BEGIN IMMEDIATE` transactions.
- Background jobs use `JobScheduler` in-flight guards; group announcements are serialized.
- Scheduled promo/broadcast jobs claim keys via `job_dedupe_log` so restarts do not double-send.

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
- `docs/VOICE.md` (if club voice, copy rhythm, or user-facing tone changes; keep the AGENTS.md Voice and Copy section in sync)

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

