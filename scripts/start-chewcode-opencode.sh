#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="$HOME/.config/chewcode/chewcode.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing env file: $ENV_FILE" >&2
  exit 1
fi

source "$ENV_FILE"

cd "$CHEWCODE_PROJECT_ROOT"
exec "$CHEWCODE_OPENCODE_BIN" serve --port "$CHEWCODE_OPENCODE_PORT" --hostname "$CHEWCODE_OPENCODE_HOST"
