#!/usr/bin/env bash
set -euo pipefail

cd /opt/dvor-chatbot-project
git pull
mkdir -p data

# One-time migration: if DB is still inside container filesystem,
# copy it to persistent host storage before recreate.
if [ ! -f data/bookings.sqlite ]; then
  docker cp dvor-chatbot:/app/data/bookings.sqlite data/bookings.sqlite 2>/dev/null || true
fi

docker compose up -d --build

# Keep disk usage stable: drop old build cache and dangling images
# while preserving recently used cache for faster incremental builds.
docker builder prune -af --filter "until=168h"
docker image prune -f

docker logs --tail=200 dvor-chatbot
