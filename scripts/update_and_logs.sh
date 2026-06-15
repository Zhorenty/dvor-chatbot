#!/usr/bin/env bash
set -euo pipefail

cd /opt/dvor-chatbot-project
git pull
docker compose up -d --build

# Keep disk usage stable: drop old build cache and dangling images
# while preserving recently used cache for faster incremental builds.
docker builder prune -af --filter "until=168h"
docker image prune -f

docker logs --tail=200 dvor-chatbot
