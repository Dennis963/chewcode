#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-status}"

case "$ACTION" in
  start)
    systemctl --user start chewcode-opencode chewcode-bridge
    ;;
  stop)
    systemctl --user stop chewcode-bridge chewcode-opencode
    ;;
  restart)
    systemctl --user restart chewcode-opencode chewcode-bridge
    ;;
  status)
    systemctl --user status chewcode-opencode chewcode-bridge --no-pager
    ;;
  logs)
    journalctl --user -u chewcode-opencode -u chewcode-bridge -n 200 --no-pager
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|logs}"
    exit 1
    ;;
esac
