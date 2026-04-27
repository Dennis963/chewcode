#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/apps/mobile"
BRIDGE_URL="${BRIDGE_URL:-http://127.0.0.1:8084}"

if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
  printf 'No graphical display detected. Run this script from your Linux desktop session.\n' >&2
  exit 1
fi

printf 'Using bridge: %s\n' "$BRIDGE_URL"

if command -v curl >/dev/null 2>&1; then
  if ! curl -fsS "$BRIDGE_URL/health" >/dev/null 2>&1; then
    printf 'Warning: bridge health check failed at %s\n' "$BRIDGE_URL" >&2
    printf 'The app will still try to start, but it may show connection errors.\n' >&2
  fi
fi

cd "$APP_DIR"
exec flutter run -d linux --dart-define=BRIDGE_URL="$BRIDGE_URL"
