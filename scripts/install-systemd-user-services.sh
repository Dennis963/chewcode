#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SYSTEMD_DIR="$HOME/.config/systemd/user"
CONFIG_DIR="$HOME/.config/chewcode"

mkdir -p "$SYSTEMD_DIR" "$CONFIG_DIR"

cp "$REPO_ROOT/deploy/systemd/chewcode-opencode.service" "$SYSTEMD_DIR/"
cp "$REPO_ROOT/deploy/systemd/chewcode-bridge.service" "$SYSTEMD_DIR/"
cp "$REPO_ROOT/scripts/start-chewcode-opencode.sh" "$CONFIG_DIR/"
cp "$REPO_ROOT/scripts/start-chewcode-bridge.sh" "$CONFIG_DIR/"

chmod +x "$REPO_ROOT/scripts/manage-chewcode-services.sh"
chmod +x "$CONFIG_DIR/start-chewcode-opencode.sh" "$CONFIG_DIR/start-chewcode-bridge.sh"

if [[ ! -f "$CONFIG_DIR/chewcode.env" ]]; then
  cp "$REPO_ROOT/deploy/systemd/chewcode.env.example" "$CONFIG_DIR/chewcode.env"
  REPO_ROOT="$REPO_ROOT" python - <<'PY'
import os
from pathlib import Path
import shutil
env_path = Path.home() / '.config' / 'chewcode' / 'chewcode.env'
text = env_path.read_text()
text = text.replace('CHEWCODE_PROJECT_ROOT=/path/to/chewcode', f"CHEWCODE_PROJECT_ROOT={os.environ['REPO_ROOT']}")
opencode_path = shutil.which('opencode') or 'opencode'
node_path = shutil.which('node') or 'node'
text = text.replace('CHEWCODE_OPENCODE_BIN=opencode', f'CHEWCODE_OPENCODE_BIN={opencode_path}')
text = text.replace('CHEWCODE_NODE_BIN=node', f'CHEWCODE_NODE_BIN={node_path}')
env_path.write_text(text)
PY
  echo "Created $CONFIG_DIR/chewcode.env. Review and update CHEWCODE_BRIDGE_TOKEN before starting services."
fi

systemctl --user daemon-reload
echo "Installed user services: chewcode-opencode.service and chewcode-bridge.service"
echo "Start with: systemctl --user start chewcode-opencode chewcode-bridge"
