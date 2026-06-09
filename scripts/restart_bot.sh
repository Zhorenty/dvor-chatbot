#!/usr/bin/env bash
set -euo pipefail

cd /opt/dvor-chatbot-project
docker compose restart
docker compose ps
