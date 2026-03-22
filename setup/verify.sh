#!/usr/bin/env bash

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=setup/lib.sh
source "$DOTFILES_DIR/setup/lib.sh"

init_runtime

if [[ $# -ne 1 ]] || ! valid_profile "$1"; then
  printf 'usage: ./setup/verify.sh <profile>\n' >&2
  exit 1
fi

verify_profile "$1"
