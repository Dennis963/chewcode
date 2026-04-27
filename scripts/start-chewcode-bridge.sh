#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="$HOME/.config/chewcode/chewcode.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing env file: $ENV_FILE" >&2
  exit 1
fi

source "$ENV_FILE"

cd "$CHEWCODE_PROJECT_ROOT/services/bridge"
exec env \
  HOST="$CHEWCODE_BRIDGE_HOST" \
  PORT="$CHEWCODE_BRIDGE_PORT" \
  OPENCODE_BASE_URL="http://$CHEWCODE_OPENCODE_HOST:$CHEWCODE_OPENCODE_PORT" \
  BRIDGE_BEARER_TOKEN="$CHEWCODE_BRIDGE_TOKEN" \
  PROJECT_ALLOWED_ROOTS="$CHEWCODE_PROJECT_ALLOWED_ROOTS" \
  PROJECT_REGISTRY_FILE="$CHEWCODE_PROJECT_REGISTRY_FILE" \
  "$CHEWCODE_NODE_BIN" dist/index.js
