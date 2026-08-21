#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd "$script_dir/.." && pwd)"
runtime_dir="$HOME/.local/lib/personal-edge"
unit_dir="$HOME/.config/systemd/user"

install -d -m 700 "$runtime_dir" "$HOME/.local/state/personal-edge"
install -d -m 755 "$unit_dir"
install -m 755 "$script_dir/publication_expiry.py" "$runtime_dir/publication_expiry.py"
install -m 644 "$skill_dir/assets/systemd/personal-edge-expiry.service" "$unit_dir/personal-edge-expiry.service"
install -m 644 "$skill_dir/assets/systemd/personal-edge-expiry.timer" "$unit_dir/personal-edge-expiry.timer"

systemctl --user daemon-reload
systemctl --user enable --now personal-edge-expiry.timer
systemctl --user is-enabled personal-edge-expiry.timer
systemctl --user is-active personal-edge-expiry.timer
