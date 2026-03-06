#!/usr/bin/env bash

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=setup/lib.sh
source "$DOTFILES_DIR/setup/lib.sh"

init_runtime
verify_profile "$(resolve_profile "${1:-auto}")"
