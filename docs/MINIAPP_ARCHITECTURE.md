# DVOR Mini App

Telegram Mini App на Flutter + Go API поверх существующего бота.
Бот не заменён: он остаётся источником бизнес-логики и всего, что Mini App не умеет.

## Аудит бота: что куда

| Функция | Где живёт | Почему |
| --- | --- | --- |
| Афиша: тренировки, походы, трейлы/кэмпы, места | **Mini App** (данные из бота) | Каталог и подсчёт мест — `ActivityCatalogService`, `countActiveParticipants` |
| Запись на себя | **Mini App → бот** | Создание брони идёт через `_createOrContinueBooking`: бесплатные, тренеры, команда DVOR, BOXING CARD, бонусы, уведомления админам и группе |
| Мои записи, статусы, отмена | **Mini App → бот** | Политика отмены (`BookingPolicyService`), возврат ⛰️, BOXING CARD late cancel |
| Профиль: вершинки, посещения, рефералы | **Mini App** (Go читает SQLite) | Только чтение агрегатов |
| Реферальная ссылка | **Mini App** | Тот же формат `?start=ref_<id>` |
| Оплата: СБП, чек, предоплата, ⛰️, промокоды, стартовый бонус | **Бот** | Карточка оплаты приходит в чат сразу после записи из Mini App; чек — фото в чат, ревью админом |
| Запись друга / гостя, перенос | **Бот** | Многошаговые диалоги, редко используются |
| Онбординг-квиз, фидбек после тренировки | **Бот** | Бот пишет первым |
| Группа: велкомы, антиспам, напоминания вступить | **Бот** | Mini App не видит группу |
| Фоновые задачи: напоминания об оплате, промо, рассылки, начисления, Sheets | **Бот** | `JobScheduler` + `job_dedupe_log` |
| Админка: оплаты, списки, посещаемость, CRUD расписания, рассылки, аналитика | **Бот** | Админский раздел Mini App — следующий этап |

## Архитектура

```
Telegram ─┬─ чат ───────────── dvor-chatbot (Dart, long polling)
          │                       ▲  внутренний HTTP-мост :8081 (Bearer)
          └─ Mini App ── Caddy ──┤  /api/* → dvor-api (Go)
             (Flutter web)  TLS   └─ статика Flutter
                                      dvor-api читает data/bookings.sqlite (query_only)
```

- **Flutter** (`apps/miniapp`): Riverpod, go_router, `dart:js_interop` к Telegram WebApp SDK.
  Нативные MainButton/BackButton, haptics, `showConfirm`, тема и safe area из Telegram, splash в стиле DVOR.
  Вне Telegram показывает «Открой в Telegram»; демо-режим — `--dart-define=DVOR_DEMO=true`.
- **Go API** (`services/api`): `net/http` + `slog`. Проверяет `initData` (HMAC-SHA256, TTL 24 ч),
  rate limit на запись, кэш афиши 20 с (отдаёт последний снимок, если бот перезапускается),
  ставит menu button бота на Mini App.
- **Мост в боте** (`lib/src/miniapp/miniapp_bridge_server.dart`, `private_handlers_miniapp.part.dart`):
  слушает только внутри Docker-сети, порт не публикуется. Запись и отмена идут через те же методы, что и кнопки в чате.

### API

Все запросы: `Authorization: tma <Telegram.WebApp.initData>`.

| Метод | Путь | Ответ |
| --- | --- | --- |
| GET | `/api/v1/me` | пользователь, `isAdmin`, `profile{peaks,visits,invited,bookings}`, `botUsername`, `referralLink` |
| GET | `/api/v1/events` | `events[]`: key, category, title, startsAt/endsAt (UTC), location, price, prepayPercent, limit, taken, coach, notes, description, equipment, itinerary |
| GET | `/api/v1/bookings` | `bookings[]`: id, key, status, canCancel, boxingCard, participant, attendance |
| POST | `/api/v1/bookings` `{key}` | 200 `created`/`exists`, 409 `full`, 404 `not_found` |
| POST | `/api/v1/bookings/{id}/cancel` | 200 `cancelled` (+`refundPeaks`), 409 `too_late`, 404 |

Ошибки: `{"error":{"code","message"}}`, `message` — готовый текст для пользователя.

### Deep links

`https://t.me/<bot>?startapp=bookings | profile | hikes | trails | trainings`.

## Конфиг

| Переменная | Кто читает | Назначение |
| --- | --- | --- |
| `MINIAPP_BRIDGE_PORT` | бот | порт моста (пусто — мост выключен) |
| `MINIAPP_BRIDGE_TOKEN` | бот, API | общий секрет моста, 16+ символов |
| `MINIAPP_URL` | API | публичный URL Mini App для menu button |
| `MINIAPP_MENU_BUTTON_TEXT` | API | текст кнопки меню (по умолчанию `DVOR`) |
| `MINIAPP_DOMAIN` | Caddy | домен для TLS |
| `COMPOSE_PROFILES=miniapp` | docker compose | включает `dvor-api` и `caddy` |

## Деплой

Flutter собирается локально (на сервере 1 ГБ RAM и нет Flutter), статика уезжает rsync-ом:

```bash
scripts/deploy_miniapp.sh
```

Бот и API обновляются обычными `scripts/update_and_logs.sh` / `scripts/full_deploy.sh`: с `COMPOSE_PROFILES=miniapp` в `.env` compose поднимает все три сервиса.

## Проверки

```bash
dart format bin lib test && dart analyze --fatal-infos --fatal-warnings && dart test
(cd services/api && gofmt -l . && go vet ./... && go test ./...)
(cd apps/miniapp && flutter analyze && flutter test)
```

## Дальше

- Админский раздел Mini App (оплаты на проверке, списки участников, посещаемость).
- Запись друга/гостя и перенос в Mini App.
- Загрузка чека прямо из Mini App вместо чата.
