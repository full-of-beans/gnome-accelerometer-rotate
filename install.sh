#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
UNIT_DIR="${HOME}/.config/systemd/user"
NAME='gnome-accelerometer-rotate'

for command in gdctl gsettings monitor-sensor systemctl udevadm; do
    if ! command -v "$command" >/dev/null 2>&1; then
        printf 'Missing required command: %s\n' "$command" >&2
        exit 1
    fi
done

install -d "$BIN_DIR" "$UNIT_DIR"
install -m 0755 "$ROOT_DIR/$NAME" "$BIN_DIR/$NAME"
install -m 0644 "$ROOT_DIR/$NAME.service" "$UNIT_DIR/$NAME.service"

systemctl --user daemon-reload
systemctl --user enable --now "$NAME.service"

printf 'Installed and started %s.service\n' "$NAME"
printf 'Check status with: systemctl --user status %s.service\n' "$NAME"
