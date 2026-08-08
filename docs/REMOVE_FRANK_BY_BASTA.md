# ТЗ: удаление функционала DVOR × FRANK BY BASTA

Краткий чеклист, чтобы после события вычистить спецкнопку/промо/запись и не оставить хвостов в коде, тестах и доках.

Записи в SQLite трогать не нужно: они привязаны к обычному `training_key` (`sessionKey`) строки расписания. Удаляется только shortcut-UX в боте.

## Цель

Убрать:

- кнопку меню `DVOR x FRANK by БАСТА 🟥`
- промо-текст и клавиатуру записи с промо-экрана
- поиск события Frank в расписании и flow `viewingFrankPromo`
- связанные тесты и упоминания в документации

Оставить без изменений:

- общий механизм записи (`✍️ Записаться` / admin participants)
- исторические бронирования Frank в БД (если строка уже ушла из Sheets — это нормально)

## Порядок работ

### 1. Удалить выделенные файлы

- `lib/src/domain/frank_by_basta.dart`
- `test/frank_by_basta_test.dart`
- этот файл: `docs/REMOVE_FRANK_BY_BASTA.md`

### 2. UI / copy / templates

| Файл | Что убрать |
|------|------------|
| `lib/src/messages/copy/message_copy.dart` | `buttonDvorXFrank` |
| `lib/src/messages/message_templates.dart` | `buttonDvorXFrank`, `dvorXFrankPromo()`, `dvorXFrankPromoUnavailable()` |
| `lib/src/messages/templates/private_navigation_templates.dart` | `dvorXFrankPromo()`, `dvorXFrankPromoUnavailable()` |
| `lib/src/messages/keyboards/telegram_keyboards.dart` | кнопка Frank в `privateMenuKeyboard` (user-ветка); метод `dvorXFrankPromoKeyboard()` |
| `lib/src/messages/templates/message_templates_keyboards.part.dart` | фасад `dvorXFrankPromoKeyboard()` |

### 3. Handlers / flow

| Файл | Что убрать |
|------|------------|
| `lib/src/bot/handlers/private/private_flow_store.dart` | enum `viewingFrankPromo` |
| `lib/src/bot/handlers/private/private_static_commands.dart` | `FrankPromoOpener`, параметр `onOpenFrankPromo`, ветка `buttonDvorXFrank` |
| `lib/src/bot/handlers/private/private_handlers_dispatch.part.dart` | передачу `onOpenFrankPromo` / вызов `_openFrankByBastaPromo` |
| `lib/src/bot/handlers/private/private_handlers_booking.part.dart` | метод `_openFrankByBastaPromo` |
| `lib/src/bot/handlers/private/private_handlers_dispatch_user_booking.part.dart` | ветку `viewingFrankPromo` в обработчике `✍️ Записаться` |
| `lib/src/bot/handlers/private/private_handlers_dispatch_back.part.dart` | case `viewingFrankPromo` |
| `lib/src/bot/handlers/private/private_handlers_payment.part.dart` | `viewingFrankPromo` в orphan payment recovery |
| `lib/src/bot/handlers/private_handlers.dart` | import `frank_by_basta.dart` |

### 4. Static schedule (dev fallback)

В `lib/src/data/static_schedule_repository.dart` удалить sample-тренировку:

- title: `🔴 DVORSPORT | FRANK BY BASTA`

Строку в Google Sheets после события можно архивировать/убрать отдельно (операционка, не код).

### 5. Тесты

| Файл | Что убрать |
|------|------------|
| `test/frank_by_basta_test.dart` | файл целиком |
| `test/private_handlers_test.dart` | тесты Frank promo/booking/unavailable; ожидания `buttonDvorXFrank` в меню (что кнопка первая / отсутствует у админа) |
| `test/message_copy_contract_test.dart` | `expect(..., contains(MessageCopy.buttonDvorXFrank))` |

После правок меню пользователя не должно начинаться с Frank-кнопки — обновить/убрать связанные assert’ы.

### 6. Документация

| Файл | Что убрать |
|------|------------|
| `README.md` | пункт про кнопку `DVOR x FRANK by БАСТА` |
| `docs/BUSINESS_CHEATSHEET.md` | пункт про кнопку Frank |
| `docs/REMOVE_FRANK_BY_BASTA.md` | этот чеклист |

### 7. Проверка «ничего не осталось»

По репозиторию не должно остаться совпадений (кроме возможных старых commit message):

```bash
rg -n "frank|Frank|FRANK|BASTA|Баста|dvorXFrank|viewingFrankPromo|FrankByBasta|FrankPromo" bin lib test docs README.md AGENTS.md
```

Ожидание: пусто (или только несвязанные совпадения — их быть не должно).

### 8. Обязательная валидация

```bash
dart format bin lib test
dart analyze --fatal-infos --fatal-warnings
dart test
```

## Что не удалять

- таблицу/записи `bookings` с `training_key` Frank-события
- общий booking/payment/participants flow
- Google Sheets как источник расписания (только саму строку события — по желанию ops)

## Критерий готовности

1. Кнопки Frank нет в пользовательском меню.
2. Нет flow-шага, helper-класса, промо-текстов и спец-клавиатуры.
3. Поиск по репо чистый.
4. `format` / `analyze` / `test` зелёные.
