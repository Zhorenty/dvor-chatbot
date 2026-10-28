#!/usr/bin/env bash
# Build the Flutter Mini App locally and upload it to prod, then rebuild
# the API/Caddy containers. Flutter is not installed on the 1 GB server.
#
#   scripts/deploy_miniapp.sh            # build + upload + restart miniapp services
#   SKIP_BUILD=1 scripts/deploy_miniapp.sh
set -euo pipefail

HOST="${DEPLOY_HOST:-dvor}"
REMOTE_DIR="${REMOTE_DIR:-/opt/dvor-chatbot-project}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/apps/miniapp"

if [ -z "${SKIP_BUILD:-}" ]; then
  (cd "$APP" && flutter pub get && flutter build web --release \
    --no-web-resources-cdn --no-source-maps --no-wasm-dry-run)
fi

rsync -az --delete "$APP/build/web/" "$HOST:$REMOTE_DIR/miniapp-dist/"

ssh "$HOST" "cd $REMOTE_DIR && git pull --ff-only && COMPOSE_PROFILES=miniapp docker compose up -d --build --no-deps dvor-api caddy && docker compose ps"
