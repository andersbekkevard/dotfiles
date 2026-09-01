#!/usr/bin/env bash

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=setup/lib.sh
source "$DOTFILES_DIR/setup/lib.sh"
# shellcheck source=setup/minimal.sh
source "$DOTFILES_DIR/setup/minimal.sh"
# shellcheck source=setup/full.sh
source "$DOTFILES_DIR/setup/full.sh"
# shellcheck source=setup/linux-desktop.sh
source "$DOTFILES_DIR/setup/linux-desktop.sh"
# shellcheck source=setup/macos.sh
source "$DOTFILES_DIR/setup/macos.sh"
# shellcheck source=setup/agents.sh
source "$DOTFILES_DIR/setup/agents.sh"

parse_args "$@"
configure_output_style
configure_mutation_environment

if [[ "$SHOW_HELP" -eq 1 ]]; then
  print_dotfiles_help
  exit 0
fi

if [[ "$SHOW_VERSION" -eq 1 ]]; then
  print_dotfiles_version
  exit 0
fi

if [[ "${#ARG_ERRORS[@]}" -gt 0 ]]; then
  print_dotfiles_help >&2
  printf '\n' >&2
  printf 'error: %s\n' "${ARG_ERRORS[@]}" >&2
  exit 2
fi

init_runtime

case "$CLI_COMMAND" in
  verify)
    failures=0
    verify_profile "$VERIFY_PROFILE" || failures=1
    verify_agent_surface || failures=1
    exit "$failures"
    ;;
  stow)
    note_git_crypt_state
    stow_packages "${STOW_PACKAGES[@]}"
    exit_with_summary
    ;;
  agents)
    case "$AGENTS_ACTION" in
      sync)
        configure_interrupt_trap
        printf 'dotfiles agents sync\n'
        ensure_agent_surface
        if [[ "$DRY_RUN" -eq 0 ]] && ! verify_agent_surface; then
          record_error "Agent surface verification failed after sync"
        fi
        exit_with_summary
        ;;
      status)
        status_agent_surface
        exit $?
        ;;
      verify)
        verify_agent_surface
        exit $?
        ;;
    esac
    ;;
esac

if [[ "$CLI_COMMAND" == "install" || "$CLI_COMMAND" == "update" ]]; then
  confirm_package_mutation || exit $?
fi

ACTIVE_PROFILE="$REQUESTED_PROFILE"
ACTIVE_LAYERS=()
while IFS= read -r layer; do
  [[ -n "$layer" ]] && ACTIVE_LAYERS+=("$layer")
done < <(profile_layers "$ACTIVE_PROFILE")

configure_interrupt_trap
if ! acquire_sudo_if_needed; then
  exit_with_summary
fi
note_git_crypt_state
print_profile_banner "$ACTIVE_PROFILE" "${ACTIVE_LAYERS[@]}"

for layer in "${ACTIVE_LAYERS[@]}"; do
  run_layer "$layer"
done

if [[ "$DRY_RUN" -eq 0 ]]; then
  refresh_local_bin_entrypoints "$ACTIVE_PROFILE"
fi

if [[ "$OS_FAMILY" == "linux" && "$ACTIVE_PROFILE" == "linux-desktop" ]]; then
  configure_agent_browser_mcp
fi

if [[ "$DRY_RUN" -eq 0 && "$SKIP_INSTALL" -eq 0 ]]; then
  check_required_commands "$ACTIVE_PROFILE"
fi

if [[ "$DRY_RUN" -eq 0 ]] && ! verify_agent_surface; then
  record_error "Agent surface verification failed after $CLI_COMMAND"
fi

if [[ "$DRY_RUN" -eq 0 && "$SKIP_INSTALL" -eq 0 && ${#ERRORS[@]} -eq 0 ]]; then
  write_profile_install_state "$ACTIVE_PROFILE"
fi

exit_with_summary
