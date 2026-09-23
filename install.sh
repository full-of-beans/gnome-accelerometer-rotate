#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
UNIT_DIR="${HOME}/.config/systemd/user"

for command in gdctl gsettings monitor-sensor systemctl; do
    if ! command -v "$command" >/dev/null 2>&1; then
        printf 'Missing required command: %s\n' "$command" >&2
        exit 1
    fi
done

install -d "$BIN_DIR" "$UNIT_DIR"
install -m 0755 "$ROOT_DIR/yoga-auto-rotate" "$BIN_DIR/yoga-auto-rotate"
install -m 0644 "$ROOT_DIR/yoga-auto-rotate.service" "$UNIT_DIR/yoga-auto-rotate.service"

systemctl --user daemon-reload
systemctl --user enable --now yoga-auto-rotate.service

printf 'Installed and started yoga-auto-rotate.service\n'
printf 'Check status with: systemctl --user status yoga-auto-rotate.service\n'
