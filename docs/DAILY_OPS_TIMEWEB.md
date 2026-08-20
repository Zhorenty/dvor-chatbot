# Daily ops · Timeweb

Production path: `/opt/dvor-chatbot-project`  
Host: `root@193.124.57.201`  
Container: `dvor-chatbot`  
SQLite: `/opt/dvor-chatbot-project/data/bookings.sqlite`

## Какой скрипт

| Скрипт | Когда |
| --- | --- |
| `scripts/restart_bot.sh` | Процесс завис, код не менялся |
| `scripts/update_and_logs.sh` | Обычный патч: текст, хендлер, шаблон. На сервере: `git pull` + сборка **с кэшем Docker** |
| `scripts/full_deploy.sh` | Новые пакеты (`pubspec.yaml`), Dockerfile/compose, `.env`, ключ Sheets, или кэш оставил старый бинарник |

`update_and_logs` для воронки в Sheets **недостаточно**, если менялись зависимости или нужно гарантированно пересобрать `dvor_bot.run`. Тогда `full_deploy.sh`.

## Полный деплой с Mac

1. Commit + push в `origin`.
2. Из корня репозитория:

```bash
./scripts/full_deploy.sh
```

Скрипт проверит, что рабочее дерево чистое и origin совпадает с HEAD, затем по SSH: `git pull`, `docker compose build --no-cache --pull`, recreate контейнера, логи.

Другой хост:

```bash
DVOR_SSH=root@193.124.57.201 ./scripts/full_deploy.sh
```

Уже в SSH на VPS:

```bash
cd /opt/dvor-chatbot-project
bash scripts/full_deploy.sh
```

Первый запуск нового скрипта: сначала push, на сервере один раз `git pull`, дальше можно вызывать с Mac.

## Google Sheets (FUNNEL)

На сервере в `.env`:

```env
GOOGLE_SHEETS_WRITE_ENABLED=true
GOOGLE_SHEETS_CREDENTIALS_PATH=/app/secrets/google-sheets.json
GOOGLE_SHEETS_SPREADSHEET_ID=<id из URL таблицы>
GOOGLE_SHEETS_WRITE_SHEET_TITLE=FUNNEL
```

JSON сервис-аккаунта: `/opt/dvor-chatbot-project/secrets/google-sheets.json` (не в git). После смены `.env` — полный деплой или хотя бы `docker compose up -d --force-recreate`.

Тот же service account пишет входные листы `Тренировки` / `Походы` / `Трейлы` из админ-кнопки `📅 Расписание` и раз в час удаляет события старше 2 дней. Лист `FUNNEL` по-прежнему пересоздаётся отдельно; входные вкладки бот не wipe.
