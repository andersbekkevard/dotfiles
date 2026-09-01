#!/usr/bin/env bash

COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

RUN_ID=""
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OS_FAMILY=""
ARCH_UNAME=""   # raw uname -m: x86_64 or aarch64
ARCH_SHORT=""   # normalized: x86_64 or arm64
ARCH_GO=""      # Go convention: amd64 or arm64
ERRORS=()
COMPLETED_LAYERS=()
APT_UPDATED=0
HAS_SUDO=0
SUDO_KEEPALIVE_PID=""
ACTIVE_PROFILE=""
ACTIVE_LAYERS=()
CLI_COMMAND=""
AGENTS_ACTION=""
REQUESTED_PROFILE=""
STOW_PACKAGES=()
VERIFY_PROFILE=""
DRY_RUN=0
SKIP_INSTALL=0
UPGRADE_EXISTING=0
ASSUME_YES=0
NO_INPUT=0
ALLOW_PARTIAL="${DOTFILES_ALLOW_PARTIAL:-0}"
SHOW_HELP=0
SHOW_VERSION=0
NO_COLOR_REQUESTED=0
ARG_ERRORS=()

secrets_source_path() {
  printf '%s\n' "$DOTFILES_DIR/shell/.secrets"
}

log_line() {
  printf '%b%s%b\n' "$1" "$2" "$COLOR_RESET"
}

log_info() {
  log_line "$COLOR_BLUE" "$1"
}

log_ok() {
  log_line "$COLOR_GREEN" "$1"
}

log_warn() {
  log_line "$COLOR_YELLOW" "$1"
}

log_error() {
  log_line "$COLOR_RED" "$1"
}

record_arg_error() {
  ARG_ERRORS+=("$1")
}

record_error() {
  ERRORS+=("$1")
  log_error "$1"
}

run_cmd() {
  local description="$1"
  shift

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] $description"
    return 0
  fi

  log_info "$description"
  local status
  if "$@"; then
    status=0
  else
    status=$?
  fi
  if [[ $status -ne 0 ]]; then
    record_error "$description failed (exit $status)"
    return $status
  fi

  return 0
}

run_cmd_allow_failure() {
  local description="$1"
  shift

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] $description"
    return 0
  fi

  log_info "$description"
  local status
  if "$@"; then
    status=0
  else
    status=$?
  fi
  if [[ $status -ne 0 ]]; then
    record_error "$description failed (exit $status)"
  fi
  return 0
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

base_system_path() {
  printf '%s\n' "/usr/local/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
}

resolve_command_from_clean_login_shell() {
  local cmd="$1"
  local zsh_bin user_name

  zsh_bin="$(command -v zsh 2>/dev/null || printf '/bin/zsh')"
  [[ -x "$zsh_bin" ]] || return 1

  user_name="${USER:-$(id -un)}"
  env -i \
    HOME="$HOME" \
    USER="$user_name" \
    SHELL="$zsh_bin" \
    PATH="$(base_system_path)" \
    "$zsh_bin" -lc "command -v '$cmd'" 2>/dev/null | tail -n 1
}

resolve_command_from_clean_login_shell_without_stable_path() {
  local cmd="$1"
  local user_name zsh_bin

  user_name="${USER:-$(id -un)}"
  zsh_bin="$(command -v zsh 2>/dev/null || printf '/bin/zsh')"
  [[ -x "$zsh_bin" ]] || return 1

  env -i \
    HOME="$HOME" \
    USER="$user_name" \
    SHELL="$zsh_bin" \
    PATH="$(base_system_path)" \
    "$zsh_bin" -lc \
      'path=(${path:#$HOME/.local/bin}); command -v "$1"' -- "$cmd" \
      2>/dev/null | tail -n 1
}

command_exists_in_clean_login_shell() {
  local resolved
  resolved="$(resolve_command_from_clean_login_shell "$1")" || return 1
  [[ "$resolved" = /* && -x "$resolved" ]]
}

command_exists_in_stable_path_contract() {
  local cmd="$1"
  local user_name

  user_name="${USER:-$(id -un)}"
  env -i \
    HOME="$HOME" \
    USER="$user_name" \
    PATH="$HOME/.local/bin:$(base_system_path)" \
    /bin/sh -lc "command -v '$cmd' >/dev/null 2>&1"
}

command_reports_version_in_stable_path_contract() {
  local cmd="$1"
  local user_name

  user_name="${USER:-$(id -un)}"
  env -i \
    HOME="$HOME" \
    USER="$user_name" \
    PATH="$HOME/.local/bin:$(base_system_path)" \
    "$cmd" --version >/dev/null 2>&1
}

path_is_in_base_system() {
  case "$1" in
    /usr/bin/*|/bin/*|/usr/sbin/*|/sbin/*|/usr/local/bin/*|/usr/local/sbin/*)
      return 0
      ;;
  esac
  return 1
}

fnm_default_alias_bin_dir() {
  printf '%s\n' "${FNM_DIR:-$HOME/.local/share/fnm}/aliases/default/bin"
}

# fnm activates Node through a per-shell directory under fnm_multishells/ that
# belongs to the shell that created it. The clean-login probe therefore resolves
# node/npm/npx inside a scratch directory owned by a subshell that exits
# immediately after. Re-point those at the stable default-alias path so the
# ~/.local/bin entrypoint follows `fnm default` instead of a dead shell.
# Anything else passes through untouched.
stabilize_runtime_entrypoint() {
  local resolved="$1"
  local cmd="$2"
  local stable

  case "$resolved" in
    */fnm_multishells/*)
      stable="$(fnm_default_alias_bin_dir)/$cmd"
      # No default alias means there is nothing stable to pin. Skip rather than
      # create a dangling entrypoint; the command contract check reports it.
      [[ -x "$stable" ]] || return 1
      printf '%s\n' "$stable"
      ;;
    *)
      printf '%s\n' "$resolved"
      ;;
  esac
}

refresh_local_bin_entrypoints() {
  local profile="$1"
  local cmd resolved link_path wrapper_dir wrapper_path quoted_resolved

  mkdir -p "$HOME/.local/bin"
  wrapper_dir="$HOME/.local/bin/.dotfiles-entrypoints"
  mkdir -p "$wrapper_dir"

  while IFS= read -r cmd; do
    [[ -z "$cmd" ]] && continue
    link_path="$HOME/.local/bin/$cmd"

    if [[ -e "$link_path" && ! -L "$link_path" ]]; then
      continue
    fi

    resolved="$(resolve_command_from_clean_login_shell_without_stable_path "$cmd")" || \
      resolved="$(resolve_command_from_clean_login_shell "$cmd")" || continue
    [[ "$resolved" = /* && -x "$resolved" ]] || continue
    resolved="$(stabilize_runtime_entrypoint "$resolved" "$cmd")" || continue
    [[ "$resolved" == "$link_path" ]] && continue
    path_is_in_base_system "$resolved" && continue

    if [[ "$(head -c 2 "$resolved" 2>/dev/null || true)" == "#!" ]]; then
      wrapper_path="$wrapper_dir/$cmd"
      printf -v quoted_resolved '%q' "$resolved"
      if [[ "$cmd" == "agent-browser" ]]; then
        printf '%s\n' \
          '#!/bin/sh' \
          'if [ -z "${AGENT_BROWSER_SOCKET_DIR:-}" ]; then' \
          '  AGENT_BROWSER_SOCKET_DIR="/tmp/agent-browser-$(id -u)"' \
          '  export AGENT_BROWSER_SOCKET_DIR' \
          'fi' \
          "exec $quoted_resolved \"\$@\"" > "$wrapper_path"
      else
        printf '#!/bin/sh\nexec %s "$@"\n' "$quoted_resolved" > "$wrapper_path"
      fi
      chmod 0755 "$wrapper_path"
      resolved="$wrapper_path"
    fi

    ln -sfn "$resolved" "$link_path"
  done < <(profile_commands "$profile")
}

detect_os() {
  case "$OSTYPE" in
    darwin*) OS_FAMILY="darwin" ;;
    linux*) OS_FAMILY="linux" ;;
    *)
      record_error "Unsupported OS: $OSTYPE"
      OS_FAMILY="unknown"
      ;;
  esac
}

detect_arch() {
  ARCH_UNAME="$(uname -m)"
  case "$ARCH_UNAME" in
    x86_64)
      ARCH_SHORT="x86_64"
      ARCH_GO="amd64"
      ;;
    aarch64|arm64)
      ARCH_UNAME="aarch64"
      ARCH_SHORT="arm64"
      ARCH_GO="arm64"
      ;;
    *)
      record_error "Unsupported architecture: $ARCH_UNAME"
      ARCH_SHORT="$ARCH_UNAME"
      ARCH_GO="$ARCH_UNAME"
      ;;
  esac
}

init_runtime() {
  RUN_ID="$(date +%Y%m%d-%H%M%S)"
  detect_os
  detect_arch
  seed_path
}

seed_path() {
  local dirs=(
    "$HOME/.local/bin"
    "$HOME/.local/share/fnm"
    "$HOME/.fnm"
    "$HOME/.cargo/bin"
    "$HOME/.bun/bin"
  )
  local d
  for d in "${dirs[@]}"; do
    [[ -d "$d" ]] && [[ ":$PATH:" != *":$d:"* ]] && export PATH="$d:$PATH"
  done
}

cleanup_runtime() {
  if [[ -n "$SUDO_KEEPALIVE_PID" ]]; then
    kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1
  fi
}

handle_interrupt() {
  cleanup_runtime
  log_warn "Dotfiles operation interrupted."
  if [[ ${#COMPLETED_LAYERS[@]} -gt 0 ]]; then
    printf 'Completed layers: %s\n' "${COMPLETED_LAYERS[*]}"
  fi
  if [[ "$CLI_COMMAND" == "install" || "$CLI_COMMAND" == "update" ]]; then
    printf 'Re-run ./dotfiles.sh %s %s to resume.\n' "$CLI_COMMAND" "$REQUESTED_PROFILE"
  fi
  exit 130
}

configure_interrupt_trap() {
  trap handle_interrupt INT TERM
}

valid_profile() {
  case "$1" in
    minimal|full|macos|linux-desktop)
      return 0
      ;;
  esac
  return 1
}

configure_output_style() {
  if [[ "$NO_COLOR_REQUESTED" -eq 1 || -n "${NO_COLOR:-}" || "${TERM:-}" == "dumb" || ! -t 1 ]]; then
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_RED=""
    COLOR_BLUE=""
    COLOR_RESET=""
  fi
}

configure_mutation_environment() {
  case "$CLI_COMMAND" in
    install|update) ;;
    *) return 0 ;;
  esac

  if [[ "$ASSUME_YES" -eq 1 || "$NO_INPUT" -eq 1 ]]; then
    export CI=1
    export NONINTERACTIVE=1
    export GIT_TERMINAL_PROMPT=0
    export DEBIAN_FRONTEND=noninteractive
  fi
}

print_dotfiles_version() {
  local revision="unknown"
  if command -v git >/dev/null 2>&1; then
    revision="$(git -C "$DOTFILES_DIR" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
  fi
  printf 'dotfiles %s\n' "$revision"
}

print_dotfiles_help() {
  cat <<'EOF'
Usage:
  ./dotfiles.sh install <profile> [options]
  ./dotfiles.sh update <profile> [options]
  ./dotfiles.sh refresh [profile] [-n|--dry-run]
  ./dotfiles.sh stow <package>... [-n|--dry-run]
  ./dotfiles.sh agents sync [-n|--dry-run]
  ./dotfiles.sh agents status
  ./dotfiles.sh agents verify
  ./dotfiles.sh verify <profile>

Profiles:
  minimal         Portable shell-focused environment
  full            Minimal plus shared developer runtimes and tooling
  macos           Full plus macOS-specific packages and config
  linux-desktop   Full plus Linux desktop/window-manager configuration

Examples:
  ./dotfiles.sh install macos
  ./dotfiles.sh update macos
  ./dotfiles.sh install linux-desktop --yes
  ./dotfiles.sh install full --dry-run
  ./dotfiles.sh refresh
  ./dotfiles.sh refresh macos
  ./dotfiles.sh stow shell nvim
  ./dotfiles.sh agents sync
  ./dotfiles.sh agents verify
  ./dotfiles.sh verify macos

Commands:
  install    Install missing prerequisites and apply repo-managed configuration.
             Working tools are adopted without upgrading them.
  update     Deliberately update managed packages/runtimes, then apply configuration.
  refresh    Apply repo-managed configuration without package/runtime installers.
             Defaults to the additive full profile.
  stow       Apply only the named Stow packages. Accepts more than one package.
  agents     Sync, inspect, or verify global skills and agent instructions only.
  verify     Read-only verification of a profile and the global agent surface.

Mutation safety:
  Install may execute third-party installers for missing tools. Update intentionally
  changes tool versions. We can't prove every third-party installer is idempotent.
  Both ask before starting unless --yes is supplied.
  Non-interactive install/update requires --yes. --dry-run never prompts or mutates.

Options:
  -n, --dry-run       Print planned work without changing the machine.
  -y, --yes           Confirm install/update without prompting anywhere in the run.
      --no-input      Never prompt; fails unless --yes or --dry-run is also used.
      --allow-partial Allow install/update to continue without privileged Linux steps.
      --no-color      Disable colored output. NO_COLOR is also respected.
  -h, --help          Show this help.
      --version       Show the repository revision.

Install, update, and verify require an explicit profile; no profile is auto-detected.
EOF
}

parse_args() {
  if [[ $# -eq 0 ]]; then
    SHOW_HELP=1
    return 0
  fi

  local arg
  for arg in "$@"; do
    case "$arg" in
      --help|-h|help) SHOW_HELP=1; return 0 ;;
      --version) SHOW_VERSION=1; return 0 ;;
    esac
  done

  CLI_COMMAND="$1"
  shift

  case "$CLI_COMMAND" in
    install|update)
      if [[ "$CLI_COMMAND" == "update" ]]; then
        UPGRADE_EXISTING=1
      fi
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -n|--dry-run) DRY_RUN=1 ;;
          -y|--yes) ASSUME_YES=1 ;;
          --no-input) NO_INPUT=1 ;;
          --allow-partial|--allow-without-sudo) ALLOW_PARTIAL=1 ;;
          --no-color) NO_COLOR_REQUESTED=1 ;;
          --*) record_arg_error "Unknown $CLI_COMMAND option: $1" ;;
          *)
            if [[ -n "$REQUESTED_PROFILE" ]]; then
              record_arg_error "$CLI_COMMAND accepts exactly one profile"
            elif valid_profile "$1"; then
              REQUESTED_PROFILE="$1"
            else
              record_arg_error "Unknown profile: $1"
            fi
            ;;
        esac
        shift
      done
      [[ -n "$REQUESTED_PROFILE" ]] || record_arg_error "$CLI_COMMAND requires an explicit profile"
      ;;
    refresh)
      SKIP_INSTALL=1
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -n|--dry-run) DRY_RUN=1 ;;
          --no-color) NO_COLOR_REQUESTED=1 ;;
          --*) record_arg_error "Unknown refresh option: $1" ;;
          *)
            if [[ -n "$REQUESTED_PROFILE" ]]; then
              record_arg_error "refresh accepts at most one profile"
            elif valid_profile "$1"; then
              REQUESTED_PROFILE="$1"
            else
              record_arg_error "Unknown profile: $1"
            fi
            ;;
        esac
        shift
      done
      REQUESTED_PROFILE="${REQUESTED_PROFILE:-full}"
      ;;
    stow)
      SKIP_INSTALL=1
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -n|--dry-run) DRY_RUN=1 ;;
          --no-color) NO_COLOR_REQUESTED=1 ;;
          --*) record_arg_error "Unknown stow option: $1" ;;
          *) STOW_PACKAGES+=("$1") ;;
        esac
        shift
      done
      [[ ${#STOW_PACKAGES[@]} -gt 0 ]] || record_arg_error "stow requires at least one package"
      ;;
    agents)
      SKIP_INSTALL=1
      if [[ $# -gt 0 && "$1" != --* ]]; then
        AGENTS_ACTION="$1"
        shift
      fi
      case "$AGENTS_ACTION" in
        sync|status|verify) ;;
        "") record_arg_error "agents requires one of: sync, status, verify" ;;
        *) record_arg_error "Unknown agents action: $AGENTS_ACTION" ;;
      esac
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -n|--dry-run)
            if [[ "$AGENTS_ACTION" == "sync" ]]; then
              DRY_RUN=1
            else
              record_arg_error "agents $AGENTS_ACTION does not accept --dry-run"
            fi
            ;;
          --no-color) NO_COLOR_REQUESTED=1 ;;
          *) record_arg_error "Unknown agents option: $1" ;;
        esac
        shift
      done
      ;;
    verify)
      SKIP_INSTALL=1
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --no-color) NO_COLOR_REQUESTED=1 ;;
          --*) record_arg_error "Unknown verify option: $1" ;;
          *)
            if [[ -n "$VERIFY_PROFILE" ]]; then
              record_arg_error "verify accepts exactly one profile"
            elif valid_profile "$1"; then
              VERIFY_PROFILE="$1"
            else
              record_arg_error "Unknown profile: $1"
            fi
            ;;
        esac
        shift
      done
      [[ -n "$VERIFY_PROFILE" ]] || record_arg_error "verify requires an explicit profile"
      ;;
    minimal|full|macos|linux-desktop|restow)
      record_arg_error "Legacy syntax '$CLI_COMMAND' is no longer supported; run ./dotfiles.sh --help"
      ;;
    *)
      record_arg_error "Unknown command: $CLI_COMMAND"
      ;;
  esac

  if [[ "${#ARG_ERRORS[@]}" -gt 0 ]]; then
    return 0
  fi
}

confirm_package_mutation() {
  [[ "$DRY_RUN" -eq 1 ]] && return 0
  [[ "$ASSUME_YES" -eq 1 ]] && return 0

  if [[ "$CLI_COMMAND" == "update" ]]; then
    log_warn "Update intentionally changes managed package and runtime versions."
  else
    log_warn "Install may execute third-party installers for missing prerequisites."
  fi
  log_warn "We can't prove every third-party installer is idempotent."
  if [[ "$NO_INPUT" -eq 1 || ! -t 0 ]]; then
    log_error "$CLI_COMMAND requires confirmation. Re-run with --yes, or inspect it first with --dry-run."
    return 2
  fi

  local reply
  read -r -p "Continue with dotfiles $CLI_COMMAND? [y/N] " reply || return 2
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
  esac
  log_warn "$CLI_COMMAND cancelled."
  return 1
}

print_profile_banner() {
  local profile="$1"
  shift
  local layers=("$@")
  printf 'dotfiles %s\n' "$CLI_COMMAND"
  printf 'profile: %s\n' "$profile"
  printf 'layers: %s\n' "${layers[*]}"
}

handle_missing_sudo() {
  local reason="$1"

  if [[ "$ALLOW_PARTIAL" == "1" ]]; then
    log_warn "$reason Running in explicit degraded mode; privileged Linux setup will be skipped."
    return 0
  fi

  record_error "$reason Installation requires privileged Linux setup. Re-run with working sudo, or explicitly pass --allow-partial."
  return 1
}

acquire_sudo_if_needed() {
  if [[ "$SKIP_INSTALL" -eq 1 || "$DRY_RUN" -eq 1 || "$OS_FAMILY" != "linux" ]]; then
    return 0
  fi

  if [[ $EUID -eq 0 ]]; then
    return 0
  fi

  if ! command_exists sudo; then
    handle_missing_sudo "sudo not available."
    return $?
  fi

  if sudo -n true >/dev/null 2>&1; then
    HAS_SUDO=1
  elif [[ "$ASSUME_YES" -eq 1 || "$NO_INPUT" -eq 1 ]]; then
    handle_missing_sudo "No cached sudo for a no-prompt run."
    return $?
  elif [[ -t 0 ]]; then
    log_info "Requesting sudo access up front."
    if sudo -v; then
      HAS_SUDO=1
    else
      handle_missing_sudo "sudo authentication failed."
      return $?
    fi
  else
    handle_missing_sudo "No cached sudo in non-interactive mode."
    return $?
  fi

  (
    while true; do
      sudo -n true >/dev/null 2>&1 || exit 0
      sleep 45
    done
  ) &
  SUDO_KEEPALIVE_PID=$!
}

as_root() {
  if [[ "$OS_FAMILY" != "linux" ]]; then
    "$@"
    return $?
  fi

  if [[ $EUID -eq 0 ]]; then
    "$@"
  elif [[ "$HAS_SUDO" -eq 1 ]]; then
    sudo "$@"
  else
    return 1
  fi
}

# Guard predicate for privileged steps: "would this step be able to run?"
# Dry runs never acquire sudo, so probing with `as_root true` would report every
# apt/system step as skipped and print a plan the real run does not follow.
# Answer from capability instead, without prompting for a password.
can_use_root() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    [[ $EUID -eq 0 ]] && return 0
    command_exists sudo
    return $?
  fi

  as_root true >/dev/null 2>&1
}

run_layer() {
  local layer="$1"

  case "$layer" in
    minimal)
      run_minimal_layer
      ;;
    full)
      run_full_layer
      ;;
    linux-desktop)
      run_linux_desktop_layer
      ;;
    macos)
      run_macos_layer
      ;;
    *)
      record_error "Unknown layer: $layer"
      ;;
  esac

  COMPLETED_LAYERS+=("$layer")
}

# Emits one "<kind> <command>" line per failed check: kind is "login"
# (missing in a clean login shell), "stable" (missing from the stable PATH
# contract), or "exec" (present but does not execute). Both the end-of-setup
# check and `--verify` consume this so the two can never drift apart.
profile_command_failures() {
  local profile="$1"
  local cmd

  while IFS= read -r cmd; do
    [[ -z "$cmd" ]] && continue
    command_exists_in_clean_login_shell "$cmd" || printf 'login %s\n' "$cmd"
    command_exists_in_stable_path_contract "$cmd" || printf 'stable %s\n' "$cmd"
  done < <(profile_commands "$profile")

  for cmd in pnpm claude codex; do
    if profile_commands "$profile" | grep -Fxq "$cmd" && \
       ! command_reports_version_in_stable_path_contract "$cmd"; then
      printf 'exec %s\n' "$cmd"
    fi
  done
}

check_required_commands() {
  local profile="$1"
  local kind cmd missing_login=() missing_stable=()

  while read -r kind cmd; do
    case "$kind" in
      login) missing_login+=("$cmd") ;;
      stable) missing_stable+=("$cmd") ;;
      exec)
        record_error "Required command does not execute from stable PATH contract for profile $profile: $cmd"
        ;;
    esac
  done < <(profile_command_failures "$profile")

  if [[ ${#missing_login[@]} -gt 0 ]]; then
    record_error "Required commands missing in clean login shell for profile $profile: ${missing_login[*]}"
  fi
  if [[ ${#missing_stable[@]} -gt 0 ]]; then
    record_error "Required commands missing from stable PATH contract for profile $profile: ${missing_stable[*]}"
  fi
}

exit_with_summary() {
  cleanup_runtime
  if [[ ${#ERRORS[@]} -eq 0 ]]; then
    log_ok "Dotfiles operation complete."
    exit 0
  fi

  printf 'Dotfiles operation completed with %d error(s):\n' "${#ERRORS[@]}"
  printf '%s\n' "${ERRORS[@]}"
  exit 1
}
