# Daily Ops (Timeweb Cloud)

This is an operational cheat sheet for the production bot on Timeweb Cloud.

## Production Context

- Server path: `/opt/dvor-chatbot-project`
- Runtime: Docker Compose
- Container name: `dvor-chatbot`
- SQLite DB: `/opt/dvor-chatbot-project/data/bookings.sqlite`
- Backups: `/opt/backups/dvor-chatbot-project`

## 1) Daily Health Check

```bash
cd /opt/dvor-chatbot-project
docker compose ps
docker logs --tail=200 dvor-chatbot
ls -la /opt/dvor-chatbot-project/data
```

## 2) Restart Bot

```bash
cd /opt/dvor-chatbot-project
docker compose restart
docker compose ps
```

## 3) Update Bot from Git

```bash
cd /opt/dvor-chatbot-project
git pull
docker compose up -d --build
docker logs --tail=200 dvor-chatbot
```

## 4) Stop / Start Bot

```bash
cd /opt/dvor-chatbot-project
docker compose down
docker compose up -d
```

## 5) Live Logs

```bash
docker logs -f dvor-chatbot
```

## 6) Check SQLite

```bash
sqlite3 /opt/dvor-chatbot-project/data/bookings.sqlite ".tables"
sqlite3 /opt/dvor-chatbot-project/data/bookings.sqlite "PRAGMA integrity_check;"
```

## 7) Manual Backup

```bash
/opt/dvor-chatbot-project/backup.sh
ls -lah /opt/backups/dvor-chatbot-project
```

## 8) Edit `.env` Safely

### Option A (manual editor)

```bash
nano /opt/dvor-chatbot-project/.env
```

After editing:

```bash
cd /opt/dvor-chatbot-project
docker compose up -d
docker compose restart
docker logs --tail=100 dvor-chatbot
```

### Option B (change one key by command)

Example: change `LOG_LEVEL` to `debug`:

```bash
sed -i 's/^LOG_LEVEL=.*/LOG_LEVEL=debug/' /opt/dvor-chatbot-project/.env
```

If key does not exist, append it:

```bash
echo 'LOG_LEVEL=debug' >> /opt/dvor-chatbot-project/.env
```

Then apply changes:

```bash
cd /opt/dvor-chatbot-project
docker compose up -d
docker compose restart
```

## 9) Verify Important Env Values (hide token)

```bash
grep -E '^(BOT_TOKEN|BOOKINGS_DB_PATH|SCHEDULE_SOURCE|GOOGLE_SHEETS_CSV_URL|ADMIN_USER_IDS|TARGET_CHAT_ID)=' /opt/dvor-chatbot-project/.env | sed 's/BOT_TOKEN=.*/BOT_TOKEN=***hidden***/'
```


## 10) Troubleshooting Quick Commands

```bash
cd /opt/dvor-chatbot-project
docker compose ps -a
docker logs dvor-chatbot
df -h
free -h
```

## 11) Smoke Test After Deploy

```bash
cd /opt/dvor-chatbot-project
docker compose ps
docker logs --tail=120 dvor-chatbot
```

Then verify in Telegram:

- Private chat: `/start` returns welcome.
- Admin chat: `📊 Оперативная сводка` returns metrics.
- Admin chat: `🔄 Обновить расписание` returns success message.

## 12) Incident: Bot Not Responding

```bash
cd /opt/dvor-chatbot-project
docker compose ps -a
docker logs --tail=300 dvor-chatbot
docker logs dvor-chatbot | rg "409|Conflict|Telegram API error"
```

If `409 Conflict` appears:

1. Ensure only one instance of the bot is running.
2. Restart compose stack.
3. Re-check logs for stable polling.

## 13) Incident: Schedule Looks Outdated

```bash
cd /opt/dvor-chatbot-project
docker logs --tail=200 dvor-chatbot | rg "Google Sheets|schedule"
```

Then in Telegram:

1. Press `🔄 Обновить расписание`.
2. Verify that schedule in `📅 Расписание` is refreshed.

## 14) Restore from Backup

```bash
cd /opt/dvor-chatbot-project
docker compose down
cp /opt/backups/dvor-chatbot-project/bookings.sqlite.<timestamp> /opt/dvor-chatbot-project/data/bookings.sqlite
sqlite3 /opt/dvor-chatbot-project/data/bookings.sqlite "PRAGMA integrity_check;"
docker compose up -d
docker logs --tail=100 dvor-chatbot
```

## 15) Onboarding New Admin

1. Get Telegram user id (for example via @userinfobot).
2. Add user id to `ADMIN_USER_IDS` in `/opt/dvor-chatbot-project/.env`.
3. Restart services: `docker compose restart`.
4. In private chat with bot run `/start` and verify admin buttons are visible.
