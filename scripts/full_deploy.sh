#!/usr/bin/env bash
# Full production deploy: pull, rebuild the image without Docker cache, recreate
# the container (picks up .env), then print logs.
#
# Use this after new Dart packages, Dockerfile/compose changes, or when
# `scripts/update_and_logs.sh` left a stale cached image.
#
# From Mac (after commit + push):
#   ./scripts/full_deploy.sh
#
# Already on the VPS:
#   bash /opt/dvor-chatbot-project/scripts/full_deploy.sh
#
# Override SSH target: DVOR_SSH=root@193.124.57.201 ./scripts/full_deploy.sh
set -euo pipefail

REMOTE_DIR="/opt/dvor-chatbot-project"
DVOR_SSH="${DVOR_SSH:-root@193.124.57.201}"

is_production_checkout() {
  [[ -d "${REMOTE_DIR}/.git" && -f "${REMOTE_DIR}/compose.yaml" ]]
}

ensure_origin_is_pushed() {
  local root
  root="$(cd "$(dirname "$0")/.." && pwd)"
  cd "$root"

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 0
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Есть незакоммиченные изменения. Сначала commit + push, потом снова ./scripts/full_deploy.sh" >&2
    git status --short >&2
    exit 1
  fi

  if ! git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    echo "Ветка не следит за origin. Сделай git push -u origin HEAD и повтори деплой." >&2
    exit 1
  fi

  git fetch origin
  local local_sha remote_sha
  local_sha="$(git rev-parse HEAD)"
  remote_sha="$(git rev-parse '@{u}')"
  if [[ "$local_sha" != "$remote_sha" ]]; then
    echo "Локальный git не совпадает с origin. Push (или pull), затем повтори деплой." >&2
    git status -sb >&2
    exit 1
  fi
}

deploy_on_server() {
  cd "$REMOTE_DIR"
  echo "==> git pull --ff-only"
  git pull --ff-only

  mkdir -p data secrets

  if [[ ! -f data/bookings.sqlite ]]; then
    if docker container inspect dvor-chatbot >/dev/null 2>&1; then
      docker cp dvor-chatbot:/app/data/bookings.sqlite data/bookings.sqlite 2>/dev/null || true
    fi
  fi

  if grep -q '^GOOGLE_SHEETS_WRITE_ENABLED=true' .env 2>/dev/null; then
    if [[ ! -f secrets/google-sheets.json ]]; then
      echo "GOOGLE_SHEETS_WRITE_ENABLED=true, но нет ${REMOTE_DIR}/secrets/google-sheets.json" >&2
      exit 1
    fi
  fi

  echo "==> docker compose build --no-cache --pull"
  docker compose build --no-cache --pull

  echo "==> docker compose up -d --force-recreate --remove-orphans"
  docker compose up -d --force-recreate --remove-orphans

  docker builder prune -af --filter "until=168h"
  docker image prune -f

  echo "==> status"
  docker compose ps
  echo "==> logs"
  sleep 2
  docker logs --tail=200 dvor-chatbot
}

if is_production_checkout; then
  deploy_on_server
  exit 0
fi

ensure_origin_is_pushed

echo "==> SSH ${DVOR_SSH}: pull + full rebuild"
exec ssh -t "$DVOR_SSH" "cd ${REMOTE_DIR} && git pull --ff-only && bash scripts/full_deploy.sh"
