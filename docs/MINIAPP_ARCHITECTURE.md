# DVOR Mini App

Telegram Mini App на Flutter + Go API поверх существующего бота.
Бот не заменён: он остаётся источником бизнес-логики и всего, что Mini App не умеет.

## Что где живёт

| Функция | Где | Как |
| --- | --- | --- |
| Афиша, места (только когда их меньше 30%, как в посте бота) | **Mini App** | Каталог из бота; Go скрывает число мест, пока их много |
| Запись себя, друзей и гостей (до 5) | **Mini App → бот** | `_createOrContinueBooking`, `_createPartyBookingGroup` |
| Оплата: СБП, чек фото, предоплата, ⛰️, промокод, стартовая | **Mini App → бот** | RPC `payment.*` нажимает те же кнопки, что в чате (`/paid`, `/use_bonus`, `/use_loyalty`, `/enter_promo`); чек загружается в чат с ботом и уходит админам как обычно |
| Мои записи: отмена, перенос | **Mini App → бот** | `miniAppCancel`, RPC `booking.reschedule` через `/reschedule_booking` |
| BOXING CARD: тарифы, оформление, продление с чеком или ⛰️ | **Mini App → бот** | RPC `card.*` через кнопки «Оформить» → тариф → чек |
| Профиль, история ⛰️ и дата сгорания, рефералка, команда, правила | **Mini App** | Go читает SQLite (`loyalty_ledger`), команда — лист «Тренерский штаб» |
| Админы | **Только админка в Mini App** | Отдельный роутер: оплаты и BOXING CARD, явка, расписание (CRUD в Sheets), записи, инструменты (отчёты, поиск, ⛰️, рассылки) |
| Уведомления, напоминания, ответ по чеку, отзыв после тренировки | **Бот** | Пишет первым |
| Группа: велкомы, антиспам, анонсы мест | **Бот** | Mini App не видит группу |
| Фоновые задачи, Google Sheets, сводки | **Бот** | `JobScheduler` + `job_dedupe_log` |
| Онбординг-видео, чат админов | **Бот** | Загрузка видео-кружков остаётся в чате |

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
- **Админский раздел** (`private_handlers_miniapp_admin.part.dart`, вкладка «Админка» во Flutter): видна, если `/api/v1/me` вернул `isAdmin`.
  API пускает только `ADMIN_USER_IDS` из проверенного `initData` (403 остальным), бот перед записью ещё раз сверяет `adminUserId` со своим `ADMIN_USER_IDS`.
  Подтверждение/отклонение оплаты — `_applyPaymentReview` (карточка пользователю, заметка в админ-чат, пост о местах в группу);
  явка — `_applyAttendance` (правила чата, синхронизация ⛰️, уведомление участнику). Чек Mini App показать не может: кнопка «Прислать чек в чат» копирует фото чека в личку админа с ботом.

### API

Все запросы: `Authorization: tma <Telegram.WebApp.initData>`.

| Метод | Путь | Ответ |
| --- | --- | --- |
| GET | `/api/v1/me` | пользователь, `isAdmin`, `profile{peaks,visits,invited,bookings}`, `botUsername`, `referralLink` |
| GET | `/api/v1/events` | `events[]`: key, category, title, startsAt/endsAt (UTC), location, price, prepayPercent, limit, taken, coach, notes, description, equipment, itinerary |
| GET | `/api/v1/bookings` | `bookings[]`: id, key, status, canCancel, boxingCard, participant, attendance |
| POST | `/api/v1/bookings` `{key}` | 200 `created`/`exists`, 409 `full`, 404 `not_found` |
| POST | `/api/v1/bookings/{id}/cancel` | 200 `cancelled` (+`refundPeaks`), 409 `too_late`, 404 |
| POST | `/api/v1/rpc/{method}` | любое другое действие бота; 422 `{error}` с текстом для пользователя. `admin.*` — только `ADMIN_USER_IDS` |

RPC-методы (`lib/src/bot/handlers/private/private_handlers_miniapp_rpc.part.dart`):
`payment.options|choose|receipt|bonus|peaks|promo`, `booking.party|rescheduleOptions|reschedule`,
`card.overview|buy`, `team.list`, `admin.report|cards.pending|cards.review|peaks.grant|user|broadcast`,
`admin.schedule.list|save|delete`, `admin.bookings.list|create|status|archive` (`notify: true` — бот пишет участнику, как в чате),
`admin.contact` (ссылка `tg://user?id=` на участника без username — в чат админа).

События из `FeaturedTrainings` приходят с `featured: true` и стоят на главной блоком «Главное» над расписанием.

Многошаговые сценарии чата бот проходит сам: мост подаёт в `handle()` те же команды, что шлют кнопки,
помечая обновление `_miniapp`, и перехватывает ответ бота (`MiniAppEchoSender`) — приложение показывает
тот же текст, что пришёл в чат.

Админские (403 `forbidden`, если пользователя нет в `ADMIN_USER_IDS`):

| Метод | Путь | Ответ |
| --- | --- | --- |
| GET | `/api/v1/admin/payments` | `payments[]`: id, title, startsAt, organizer{userId,name,username}, participants[], total, prepayPercent, paymentType, comment, promoCode, hasProof — одна запись на группу оплаты |
| POST | `/api/v1/admin/payments/{id}/review` `{decision: approve\|approve_partial\|reject}` | 200 `reviewed` (+status), 409 `already_reviewed`, 404 |
| POST | `/api/v1/admin/payments/{id}/proof` | 200 `sent` — бот копирует чек в чат админа; 404 нет чека, 502 Telegram не принял |
| GET | `/api/v1/admin/sessions` | `sessions[]`: ближайшие события каталога + тренировки за 7 дней; participants, limit, attendanceOpen, unmarked |
| GET | `/api/v1/admin/sessions/participants?key=` | `session`, `participants[]`: bookingId, name, guest, managedBy, status, attendance, canMark |
| POST | `/api/v1/admin/bookings/{id}/attendance` `{attendance: attended\|absent}` | 200 `marked` (+participant, peaksDelta), 409 `not_allowed` с причиной, 404 |

Ошибки: `{"error":{"code","message"}}`, `message` — готовый текст для пользователя.

### Deep links

`https://t.me/<bot>?startapp=bookings | profile | admin | hikes | trails | trainings | fps` (работает после настройки Main Mini App в @BotFather).

## Производительность

- Сборка `flutter build web --wasm` (skwasm), старые WebView без WasmGC получают JS-версию автоматически.
- Без `BackdropFilter`: навбар и фильтры афиши на плотной подложке. Без `Opacity`, `ClipRRect` и `IntrinsicHeight` в списках.
- Тема перестраивается только при смене темы Telegram (`brightnessListenable`), отступы безопасной зоны — через `safeAreaProvider`. События `viewportChanged` приложение не перестраивают.
- Заглушки загрузки делят один тикер, он работает только пока заглушки на экране.
- Шрифты Montserrat урезаны до латиницы и кириллицы (`fontTools.subset`, ~52 КБ на начертание). Оригиналы — в `scripts/assets/week_stories`.
- Админка — отдельный отложенный чанк (`features/admin/admin.dart`, `deferred as admin`).
- Замер в Telegram: `https://t.me/<bot>?startapp=fps` показывает fps, самый долгий кадр и число кадров дольше 25 мс.

## Конфиг

| Переменная | Кто читает | Назначение |
| --- | --- | --- |
| `MINIAPP_BRIDGE_PORT` | бот | порт моста (пусто — мост выключен) |
| `MINIAPP_BRIDGE_TOKEN` | бот, API | общий секрет моста, 16+ символов |
| `MINIAPP_URL` | API, бот | публичный URL Mini App: menu button и кнопки «Открыть DVOR» |
| `MINIAPP_ONLY` | бот | `true` — участники пользуются приложением, чат только для уведомлений (см. ниже) |
| `MINIAPP_MENU_BUTTON_TEXT` | API | текст кнопки меню (по умолчанию `DVOR`) |
| `MINIAPP_DOMAIN` | Caddy | домен для TLS |
| `COMPOSE_PROFILES=miniapp` | docker compose | включает `dvor-api` и `caddy` |

## Деплой

Flutter собирается локально (на сервере 1 ГБ RAM и нет Flutter), статика уезжает rsync-ом:

```bash
scripts/deploy_miniapp.sh
```

Бот и API обновляются обычными `scripts/update_and_logs.sh` / `scripts/full_deploy.sh`: с `COMPOSE_PROFILES=miniapp` в `.env` compose поднимает все три сервиса.

## Режим «только приложение» (`MINIAPP_ONLY=true`)

- `/start` (и `?start=ref_…`, `?start=book`) — одно сообщение с кнопкой «Открыть DVOR»; реферал, стартовые ⛰️ и онбординг-состояние сохраняются.
- Любой другой текст участника — подсказка про приложение, старое нижнее меню убирается (`remove_keyboard`).
- Работает как раньше: кнопки под уведомлениями и карточкой оплаты, чек фото в чат, ввод промокода и ответ на отзыв (открытый сценарий чата).
- Админы и тренеры (списки записавшихся) сохраняют полный чат.
- Вместе с флагом выключаем `ONBOARDING_DRIP_ENABLED`: квиз в чате больше не нужен.
- Откат: `MINIAPP_ONLY=false` и перезапуск бота.

## Проверки

```bash
dart format bin lib test && dart analyze --fatal-infos --fatal-warnings && dart test
(cd services/api && gofmt -l . && go vet ./... && go test ./...)
(cd apps/miniapp && flutter analyze && flutter test)
```

## Дальше

- Через две недели спокойной работы в режиме `MINIAPP_ONLY` — удалить из бота меню и диалоги, которые перехватывает режим.
- Онбординг-квиз в приложении (сейчас в режиме `MINIAPP_ONLY` квиз не задаётся).
