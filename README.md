# DVOR Telegram Bot

MVP-бот для спортивного объединения DVOR на Dart.

## Что умеет сейчас

- В личке отвечает на:
  - `/start` — приветствие и подсказка по командам
  - `/trainings` — ближайшие тренировки (статично в коде)
- В группе:
  - при входе нового участника пытается отправить ЛС с инфо о клубе
  - если ЛС недоступно, отправляет fallback-сообщение в группу (опционально)

## Структура проекта

- `bin/dvor_bot.dart` — entrypoint и запуск бота
- `lib/src/config/app_config.dart` — конфигурация из CLI/env/.env
- `lib/src/telegram/telegram_client.dart` — Telegram Bot API клиент
- `lib/src/bot/handlers/private_handlers.dart` — логика `/start` и `/trainings`
- `lib/src/bot/handlers/group_handlers.dart` — welcome flow для новых участников
- `lib/src/data/static_schedule_repository.dart` — статичное расписание тренировок
- `lib/src/messages/message_templates.dart` — шаблоны сообщений
- `test/` — unit-тесты

## Конфигурация

Создайте `.env` рядом с `pubspec.yaml`:

```env
BOT_TOKEN=123456:ABCDEF
TARGET_CHAT_ID=-1001234567890
SEND_GROUP_FALLBACK=true
POLL_TIMEOUT_SECONDS=25
LOG_LEVEL=info
```

Можно задавать и через CLI (имеет более высокий приоритет):

```bash
dart run bin/dvor_bot.dart --token=123456:ABCDEF --target-chat-id=-1001234567890
```

## Локальный запуск

1. Установите Dart SDK (3.5+).
2. Установите зависимости:
   - `dart pub get`
3. Запустите бота:
   - `dart run bin/dvor_bot.dart`

## Проверка работоспособности (smoke test)

1. Откройте личку с ботом, нажмите `Start`.
2. Отправьте `/start` и `/trainings` — проверьте ответы.
3. Добавьте тестового пользователя в группу DVOR.
4. Убедитесь, что бот:
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

- Вынести расписание из кода в JSON/Google Sheets/БД.
- Добавить админ-команду обновления расписания.
- Добавить интеграционные тесты с mock Telegram API.
- Настроить CI (analyze + test) в GitHub Actions.
