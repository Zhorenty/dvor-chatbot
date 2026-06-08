# DVOR Telegram Bot

MVP-бот для спортивного объединения DVOR на Dart.

## Бизнес-документация

- Полная шпаргалка по пользовательским и админским сценариям, Google Sheets и операционным процессам: `BUSINESS_CHEATSHEET.md`

## Что умеет сейчас

- Личка (пользовательский сценарий):
  - `/start` — приветствие и постоянное кнопочное меню
  - `/trainings` или кнопка `Расписание` — сначала выбор категории (`Тренировки` / `Походы` / `Трейлы`), затем список по выбранной категории
  - `/book` или кнопка `Записаться` — сначала выбор категории, затем запись на конкретное мероприятие
  - после записи отправляет реквизиты/инструкцию оплаты
  - `/my_bookings` или кнопка `Мои записи` — показывает архив, разделенный на актуальные и прошедшие записи
  - после оплаты пользователь отправляет в чат файл с подтверждением (документ/фото), после чего заявка уходит администратору
  - для записей в `pending_payment` автоматически отправляет напоминания об оплате
  - кнопка `Помощь` — краткая справка по доступным действиям
- Личка (админский сценарий):
  - кнопка `Обновить расписание` — принудительная синхронизация расписания + ссылка на Google Sheet
  - кнопка `Список записавшихся` — сначала выбор категории, затем список участников по выбранному разделу
  - кнопка `Управление записями`:
    - `Список записей` -> выбор сегмента (`Активные`/`Архивные`) -> выбор категории -> выбор записи
    - для выбранной записи: редактирование (`оплата`, `username`, `мероприятие`) и мягкое удаление в архив (`cancelled`)
    - `Создать запись` -> выбор категории -> выбор мероприятия из расписания -> username -> статус оплаты -> подтверждение
  - `/payments_queue` — сначала выбор категории, затем очередь оплат на проверку (каждая заявка приходит отдельным сообщением)
  - `/approve_payment <id>` и `/reject_payment <id>` — модерация подтверждений оплаты
  - после модерации бот уведомляет пользователя о результате
  - при заданном `ADMIN_CHAT_ID` дублирует результат модерации в админ-чат
- Групповой сценарий:
  - при входе нового участника бот отправляет welcome-сообщение в группу
  - welcome автоматически удаляется позже (или после `/start` в личке)
- Источники расписания:
  - `static` (по умолчанию) — расписание в коде
  - `google_sheets` — расписание из Google Sheets CSV с периодическим sync и fallback на последний валидный кэш

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
ADMIN_CHAT_ID=-1001234567890
BOOKINGS_DB_PATH=data/bookings.sqlite
PENDING_PAYMENT_TTL_MINUTES=120
LOG_LEVEL=info
```

Можно задавать и через CLI (имеет более высокий приоритет):

```bash
dart run bin/dvor_bot.dart --token=123456:ABCDEF --target-chat-id=-1001234567890 --schedule-source=google_sheets --google-sheets-csv-url="https://docs.google.com/spreadsheets/d/.../export?format=csv&gid=0"
```

### Формат Google Sheets CSV

Тренировки (лист `gid=0`, URL задается через `GOOGLE_SHEETS_CSV_URL`), обязательные колонки:

- `title`
- `starts_at` (например `2026-06-05 19:00` или `05.06.2026 19:00`)
- `location`

Опциональные колонки:

- `coach`
- `notes`

Походы и трейлы загружаются из тех же Google Sheets автоматически:

- Походы: `gid=294119056`
- Трейлы: `gid=1220729038`

Для них используются колонки:

- `title` (обязательно)
- `date_from` (обязательно)
- `date_to` (опционально, для однодневных событий можно оставить пустым)
- `description` (обязательно)
- `price` (опционально)

## Локальный запуск

1. Установите Dart SDK (3.5+).
2. Установите зависимости:
   - `dart pub get`
3. Запустите бота:
   - `make bot` (или `dart run bin/dvor_bot.dart`)
4. Быстрые команды через `Makefile`:
   - `make bot` — запуск бота
   - `make bot-stop` — остановка запущенного процесса бота
   - `make bot-restart` — перезапуск одной командой

## Проверка работоспособности (smoke test)

1. Откройте личку с ботом, нажмите `Start`.
2. Нажмите `Расписание` и `Помощь` — проверьте ответы.
3. Нажмите `Записаться`, затем `Мои записи`, после оплаты отправьте файл с подтверждением (документ/фото).
4. Если ваш user id указан в `ADMIN_USER_IDS`, нажмите `Обновить расписание` и проверьте `/payments_queue`.
5. Добавьте тестового пользователя в группу DVOR.
6. Убедитесь, что бот:
   - отправил welcome в группу,
   - удалил welcome после TTL или после `/start` в личке.

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

- Добавить внешний шлюз оплаты вместо ручного подтверждения.
- Добавить интеграционные тесты с mock Telegram API.
- Настроить CI (analyze + test) в GitHub Actions.
