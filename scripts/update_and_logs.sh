#!/usr/bin/env bash
set -euo pipefail

cd /opt/dvor-chatbot-project
git pull
docker compose up -d --build
docker logs --tail=200 dvor-chatbot
