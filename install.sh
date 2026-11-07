#!/usr/bin/env bash
# Install / remove the launchd agent that runs orca-widget-sync every few seconds.
#   ./install.sh            install (or reinstall) and start
#   ./install.sh uninstall  stop and remove
#   ./install.sh status     show launchd state and recent log lines
set -euo pipefail

LABEL="dev.orca.widget-sync"
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/orca-widget-sync"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/orca-widget-sync.log"
INTERVAL="${ORCA_TW_INTERVAL:-5}"
DOMAIN="gui/$(id -u)"

case "${1:-install}" in
  install)
    chmod +x "$SCRIPT"
    mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs" "$HOME/bin"
    ln -sf "$SCRIPT" "$HOME/bin/orca-widget-sync"
    # Carry any ORCA_TW_* settings from this shell into the launchd job, e.g.
    #   ORCA_TW_STYLE=flap ./install.sh
    ENV_XML=""
    while IFS='=' read -r k v; do
      [[ "$k" == ORCA_TW_INTERVAL ]] && continue
      v="${v//&/&amp;}"; v="${v//</&lt;}"; v="${v//>/&gt;}"
      ENV_XML+="    <key>$k</key><string>$v</string>"$'\n'
    done < <(env | grep -E '^ORCA_TW_[A-Z_]+=' | sort)
    export ENV_XML
    sed -e "s|__LABEL__|$LABEL|g" -e "s|__SCRIPT__|$SCRIPT|g" \
        -e "s|__LOG__|$LOG|g" -e "s|__INTERVAL__|$INTERVAL|g" \
        -e "s|__HOME__|$HOME|g" \
        "$HERE/launchd/dev.orca.widget-sync.plist.template" \
      | /usr/bin/python3 -c 'import os,sys; sys.stdout.write(sys.stdin.read().replace("__ENV__\n", os.environ["ENV_XML"]))' \
      > "$PLIST"
    plutil -lint "$PLIST" >/dev/null
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    launchctl bootstrap "$DOMAIN" "$PLIST"
    launchctl kickstart -k "$DOMAIN/$LABEL"
    echo "Installed $LABEL (every ${INTERVAL}s). Log: $LOG"
    [[ -n "$ENV_XML" ]] && env | grep -E '^ORCA_TW_[A-Z_]+=' | sed 's/^/  /'
    true
    ;;
  uninstall)
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    rm -f "$PLIST" "$HOME/bin/orca-widget-sync"
    echo "Removed $LABEL"
    ;;
  status)
    launchctl print "$DOMAIN/$LABEL" 2>/dev/null | grep -E 'state|last exit|runs' || echo "not loaded"
    [[ -f "$LOG" ]] && tail -5 "$LOG" || true
    ;;
  *) echo "usage: $0 [install|uninstall|status]" >&2; exit 2 ;;
esac
