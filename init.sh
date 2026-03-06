#!/usr/bin/env bash

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=setup/lib.sh
source "$DOTFILES_DIR/setup/lib.sh"
# shellcheck source=setup/minimal.sh
source "$DOTFILES_DIR/setup/minimal.sh"
# shellcheck source=setup/full.sh
source "$DOTFILES_DIR/setup/full.sh"
# shellcheck source=setup/linux-headless.sh
source "$DOTFILES_DIR/setup/linux-headless.sh"
# shellcheck source=setup/linux-desktop.sh
source "$DOTFILES_DIR/setup/linux-desktop.sh"
# shellcheck source=setup/macos.sh
source "$DOTFILES_DIR/setup/macos.sh"

init_runtime
parse_args "$@"

if [[ -n "$VERIFY_PROFILE" ]]; then
  verify_profile "$VERIFY_PROFILE"
  exit $?
fi

if [[ -n "$STOW_ONLY_PACKAGE" ]]; then
  note_git_crypt_state
  stow_package "$STOW_ONLY_PACKAGE"
  exit_with_summary
fi

if [[ -n "$RUN_LAYER_ONLY" ]]; then
  ACTIVE_PROFILE="$RUN_LAYER_ONLY"
  ACTIVE_LAYERS=("$RUN_LAYER_ONLY")
else
  ACTIVE_PROFILE="$(resolve_profile "$REQUESTED_PROFILE")"
  ACTIVE_LAYERS=()
  while IFS= read -r layer; do
    [[ -n "$layer" ]] && ACTIVE_LAYERS+=("$layer")
  done < <(profile_layers "$ACTIVE_PROFILE")
fi

configure_interrupt_trap
if ! acquire_sudo_if_needed; then
  exit_with_summary
fi
note_git_crypt_state
print_profile_banner "$ACTIVE_PROFILE" "${ACTIVE_LAYERS[@]}"

for layer in "${ACTIVE_LAYERS[@]}"; do
  run_layer "$layer"
done

exit_with_summary
