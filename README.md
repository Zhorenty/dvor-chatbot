# DVOR Telegram Bot

MVP-бот для спортивного объединения DVOR на Dart.

## Что умеет сейчас

- В личке отвечает на:
  - `/start` — приветствие и кнопочное меню
  - `/trainings` и кнопка `Расписание` — ближайшие тренировки
  - `/book` и кнопка `Записаться` — запись на ближайшую тренировку
  - `/my_bookings` и кнопка `Мои записи` — просмотр статусов записей
  - `/paid` и кнопка `Я оплатил` — отправка подтверждения оплаты
  - кнопка `Помощь` — краткая справка по боту
  - кнопка `Обновить расписание` — принудительный sync расписания (только для админов)
  - `/payments_queue`, `/approve_payment <id>`, `/reject_payment <id>` — админ-флоу оплаты
- В группе:
  - при входе нового участника пытается отправить ЛС с инфо о клубе
  - если ЛС недоступно, отправляет fallback-сообщение в группу (опционально)
- Расписание:
  - `static` (по умолчанию) — расписание в коде
  - `google_sheets` — расписание из Google Sheets CSV с периодическим sync

## Структура проекта

- `bin/dvor_bot.dart` — entrypoint и запуск бота
- `lib/src/config/app_config.dart` — конфигурация из CLI/env/.env
- `lib/src/telegram/telegram_client.dart` — Telegram Bot API клиент
- `lib/src/bot/handlers/private_handlers.dart` — логика private-сценариев и кнопочного меню
- `lib/src/bot/handlers/group_handlers.dart` — welcome flow для новых участников
- `lib/src/data/static_schedule_repository.dart` — статичное расписание тренировок
- `lib/src/data/google_sheets_schedule_repository.dart` — расписание из Google Sheets CSV
- `lib/src/data/sqlite_booking_repository.dart` — SQLite-хранилище записей и оплат
- `lib/src/messages/message_templates.dart` — шаблоны сообщений
- `test/` — unit-тесты

## Конфигурация

Создайте `.env` рядом с `pubspec.yaml`:

```env
BOT_TOKEN=123456:ABCDEF
TARGET_CHAT_ID=-1001234567890
SEND_GROUP_FALLBACK=true
POLL_TIMEOUT_SECONDS=25
SCHEDULE_SOURCE=static
GOOGLE_SHEETS_CSV_URL=
SCHEDULE_SYNC_INTERVAL_SECONDS=300
ADMIN_USER_IDS=123456789
BOOKINGS_DB_PATH=data/bookings.sqlite
PENDING_PAYMENT_TTL_MINUTES=120
LOG_LEVEL=info
```

Можно задавать и через CLI (имеет более высокий приоритет):

```bash
dart run bin/dvor_bot.dart --token=123456:ABCDEF --target-chat-id=-1001234567890 --schedule-source=google_sheets --google-sheets-csv-url="https://docs.google.com/spreadsheets/d/.../export?format=csv&gid=0"
```

### Формат Google Sheets CSV

Обязательные колонки:

- `title`
- `starts_at` (например `2026-06-05 19:00` или `05.06.2026 19:00`)
- `location`

Опциональные колонки:

- `coach`
- `notes`

## Локальный запуск

1. Установите Dart SDK (3.5+).
2. Установите зависимости:
   - `dart pub get`
3. Запустите бота:
   - `dart run bin/dvor_bot.dart`

## Проверка работоспособности (smoke test)

1. Откройте личку с ботом, нажмите `Start`.
2. Нажмите `Расписание` и `Помощь` — проверьте ответы.
3. Нажмите `Записаться`, затем `Мои записи` и `Я оплатил`.
4. Если ваш user id указан в `ADMIN_USER_IDS`, нажмите `Обновить расписание` и проверьте `/payments_queue`.
5. Добавьте тестового пользователя в группу DVOR.
6. Убедитесь, что бот:
   - попытался отправить ЛС пользователю,
   - при недоступной личке отправил fallback-сообщение в группу.

## Настройки в BotFather и группе

- Отключите privacy mode (`/setprivacy`) при необходимости обрабатывать service-сообщения о новых участниках.
- Дайте боту право отправлять сообщения в группе.
- Убедитесь, что бот добавлен в нужную группу.

## Качество и тесты

- Анализ:
  - `dart analyze --fatal-infos --fatal-warnings`
- Тесты:
  - `dart test`

## Деплой

### Вариант 1: Docker

1. Соберите образ:
   - `docker build -t dvor-chatbot:latest .`
2. Запустите контейнер:
   - `docker run --name dvor-chatbot --restart unless-stopped --env-file .env dvor-chatbot:latest`
3. Проверьте логи:
   - `docker logs -f dvor-chatbot`

### Вариант 2: systemd (Linux)

1. Скомпилируйте бинарник:
   - `dart compile exe bin/dvor_bot.dart -o dvor_bot.run`
2. Создайте unit-файл `dvor-bot.service` с `Restart=always`.
3. Передайте `EnvironmentFile=/path/to/.env`.
4. Запустите:
   - `sudo systemctl daemon-reload`
   - `sudo systemctl enable --now dvor-bot`
   - `sudo systemctl status dvor-bot`

## Дальнейшие шаги

- Добавить callback-flow с inline-кнопками.
- Добавить внешний шлюз оплаты вместо ручного подтверждения.
- Добавить интеграционные тесты с mock Telegram API.
- Настроить CI (analyze + test) в GitHub Actions.
