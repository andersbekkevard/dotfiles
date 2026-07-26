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
REQUESTED_PROFILE=""
RUN_LAYER_ONLY=""
STOW_ONLY_PACKAGE=""
VERIFY_PROFILE=""
DRY_RUN=0
SKIP_INSTALL=0
ALLOW_PARTIAL="${DOTFILES_ALLOW_PARTIAL:-0}"
SHOW_HELP=0
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
  "$@"
  local status=$?
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
  "$@"
  local status=$?
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
      printf '#!/bin/sh\nexec %s "$@"\n' "$quoted_resolved" > "$wrapper_path"
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
  log_warn "Setup interrupted."
  if [[ ${#COMPLETED_LAYERS[@]} -gt 0 ]]; then
    printf 'Completed layers: %s\n' "${COMPLETED_LAYERS[*]}"
  fi
  printf 'Re-run ./setup.sh <profile> to resume.\n'
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

print_setup_help() {
  cat <<'EOF'
Usage:
  ./setup.sh <profile> [--dry-run] [--skip-install] [--allow-partial]
  ./setup.sh --verify <profile>
  ./setup.sh --layer <layer>
  ./setup.sh --stow <package>

Profiles:
  minimal         Portable shell-focused environment
  full            Minimal plus shared developer runtimes and tooling
  macos           Full plus macOS-specific packages and config
  linux-desktop   Full plus Linux desktop/window-manager configuration

Examples:
  ./setup.sh macos
  ./setup.sh linux-desktop
  ./setup.sh --verify macos
  ./setup.sh --layer full
  ./setup.sh --stow shell

No profile is chosen automatically. Pick the exact profile you want.
EOF
}

parse_args() {
  if [[ $# -eq 0 ]]; then
    SHOW_HELP=1
    return 0
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        SHOW_HELP=1
        ;;
      --dry-run)
        DRY_RUN=1
        ;;
      --skip-install)
        SKIP_INSTALL=1
        ;;
      --allow-partial|--allow-without-sudo)
        ALLOW_PARTIAL=1
        ;;
      --layer)
        shift
        if [[ $# -eq 0 || "$1" == --* ]]; then
          record_arg_error "--layer requires an explicit layer"
          break
        fi
        if ! valid_profile "$1"; then
          record_arg_error "Unknown layer: $1"
          break
        fi
        RUN_LAYER_ONLY="$1"
        ;;
      --stow)
        shift
        if [[ $# -eq 0 || "$1" == --* ]]; then
          record_arg_error "--stow requires a package name"
          break
        fi
        STOW_ONLY_PACKAGE="$1"
        ;;
      --verify)
        shift
        if [[ $# -eq 0 || "$1" == --* ]]; then
          record_arg_error "--verify requires an explicit profile"
          break
        fi
        if ! valid_profile "$1"; then
          record_arg_error "Unknown verify profile: $1"
          break
        fi
        VERIFY_PROFILE="$1"
        ;;
      minimal|full|macos|linux-desktop)
        REQUESTED_PROFILE="$1"
        ;;
      *)
        record_arg_error "Unknown argument: $1"
        ;;
    esac
    shift
  done

  if [[ "$SHOW_HELP" -eq 1 || "${#ARG_ERRORS[@]}" -gt 0 ]]; then
    return 0
  fi

  if [[ -n "$RUN_LAYER_ONLY" || -n "$STOW_ONLY_PACKAGE" || -n "$VERIFY_PROFILE" ]]; then
    return 0
  fi

  if [[ -z "$REQUESTED_PROFILE" ]]; then
    SHOW_HELP=1
  fi
}

print_profile_banner() {
  local profile="$1"
  shift
  local layers=("$@")
  printf 'dotfiles setup\n'
  printf 'profile: %s\n' "$profile"
  printf 'layers: %s\n' "${layers[*]}"
}

handle_missing_sudo() {
  local reason="$1"

  if [[ "$ALLOW_PARTIAL" == "1" ]]; then
    log_warn "$reason Running in explicit degraded mode; privileged Linux setup will be skipped."
    return 0
  fi

  if [[ -t 0 ]]; then
    log_warn "$reason Privileged operations will be skipped."
    return 0
  fi

  record_error "$reason Non-interactive Linux bootstrap would skip privileged setup. Re-run interactively, run 'sudo -v' first, or set DOTFILES_ALLOW_PARTIAL=1."
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

  for cmd in pnpm codex; do
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
    log_ok "Setup complete."
    exit 0
  fi

  printf 'Setup completed with %d error(s):\n' "${#ERRORS[@]}"
  printf '%s\n' "${ERRORS[@]}"
  exit 1
}
