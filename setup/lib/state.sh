#!/usr/bin/env bash

install_state_path() {
  local profile="$1"
  printf '%s/dotfiles/install-state/%s.tsv\n' "${XDG_STATE_HOME:-$HOME/.local/state}" "$profile"
}

resolve_path_chain() {
  local path="$1" target depth=0
  while [[ -L "$path" && $depth -lt 20 ]]; do
    target="$(readlink "$path")" || return 1
    if [[ "$target" = /* ]]; then
      path="$target"
    else
      path="$(cd "$(dirname "$path")" && cd "$(dirname "$target")" && pwd -P)/$(basename "$target")"
    fi
    depth=$((depth + 1))
  done
  printf '%s\n' "$path"
}

canonical_command_path() {
  local command_name="$1"
  local path

  path="$(resolve_command_from_clean_login_shell_without_stable_path "$command_name")" ||
    path="$(resolve_command_from_clean_login_shell "$command_name")" || return 1
  path="$(stabilize_runtime_entrypoint "$path" "$command_name" 2>/dev/null || printf '%s\n' "$path")"
  resolve_path_chain "$path"
}

install_provider_for_command() {
  local command_name="$1" path="$2"
  case "$path" in
    "$DOTFILES_DIR"/*) printf 'dotfiles-stow' ;;
    "$HOME/.local/bin/.dotfiles-entrypoints/"*) printf 'dotfiles-entrypoint' ;;
    "$HOME/.local/share/fnm/"*|"$HOME/.fnm/"*) printf 'fnm' ;;
    "$HOME/.cargo/"*) printf 'cargo-rustup' ;;
    "$HOME/.bun/"*) printf 'bun' ;;
    "$HOME/.local/share/claude/"*) printf 'claude-standalone' ;;
    "$HOME/.codex/packages/standalone/"*) printf 'codex-standalone' ;;
    "$HOME/.local/share/cliproxyapi/"*) printf 'cliproxyapi-release' ;;
    "$HOME/.local/share/nvim-install/"*) printf 'dotfiles-release' ;;
    "$HOME/.local/bin/"*)
      case "$command_name" in
        fzf|sesh|gum|trufflehog|lazygit|yazi|lsd|lazydocker|greenclip) printf 'dotfiles-release' ;;
        *) printf 'user-local' ;;
      esac
      ;;
    /opt/homebrew/*|/usr/local/Cellar/*|/usr/local/Caskroom/*) printf 'homebrew' ;;
    /usr/bin/*|/bin/*|/usr/sbin/*|/sbin/*) printf 'system-package' ;;
    /usr/local/go/*) printf 'dotfiles-go' ;;
    /usr/local/*) printf 'local-system' ;;
    *) printf 'external' ;;
  esac
}

command_has_safe_version_flag() {
  case "$1" in
    git|zsh|stow|tmux|fzf|rg|fd|bat|zoxide|nvim|htop|btop|jq|ngrok|cloudflared|delta|sesh|gum|trufflehog|fleet|tree-sitter|fnm|node|pnpm|claude|codex|uv|cargo|rustc|bun|lazygit|lazydocker|gh|yazi|git-crypt|psql|typescript-language-server|brew|go|i3|rofi|polybar|alacritty|kitty|picom|xdotool)
      return 0
      ;;
  esac
  return 1
}

installed_command_version() {
  local command_name="$1" path="$2" version
  if ! command_has_safe_version_flag "$command_name"; then
    printf 'unreported\n'
    return 0
  fi

  case "$command_name" in
    go|ngrok)
      version="$("$path" version 2>&1)" || version=""
      ;;
    *)
      version="$("$path" --version 2>&1)" || version=""
      ;;
  esac
  version="${version%%$'\n'*}"
  version="${version//$'\t'/ }"
  version="${version//$'\r'/}"
  [[ -n "$version" ]] || version="unreported"
  printf '%s\n' "$version"
}

render_profile_install_state() {
  local profile="$1" command_name path provider version
  printf '# dotfiles-install-state-v1\tprofile=%s\n' "$profile"
  while IFS= read -r command_name; do
    [[ -n "$command_name" ]] || continue
    path="$(canonical_command_path "$command_name" 2>/dev/null || true)"
    if [[ -z "$path" || ! -x "$path" ]]; then
      printf '%s\tmissing\tmissing\tmissing\n' "$command_name"
      continue
    fi
    provider="$(install_provider_for_command "$command_name" "$path")"
    version="$(installed_command_version "$command_name" "$path")"
    printf '%s\t%s\t%s\t%s\n' "$command_name" "$provider" "$path" "$version"
  done < <(profile_commands "$profile")
}

write_profile_install_state() {
  local profile="$1" target target_dir temporary
  target="$(install_state_path "$profile")"
  target_dir="$(dirname "$target")"
  mkdir -p "$target_dir"
  temporary="$(mktemp "$target_dir/.${profile}.tmp.XXXXXX")" || {
    record_error "Could not create install-state file for $profile"
    return 0
  }
  render_profile_install_state "$profile" > "$temporary"
  if [[ -f "$target" ]] && cmp -s "$temporary" "$target"; then
    rm -f "$temporary"
    log_info "Install state unchanged for $profile"
    return 0
  fi
  if ! chmod 0600 "$temporary" || ! mv -f "$temporary" "$target"; then
    rm -f "$temporary"
    record_error "Could not record install state for $profile"
    return 0
  fi
  log_info "Recorded install state at $target"
}

verify_profile_install_state() {
  local profile="$1" target command_name expected_provider expected_path expected_version
  local actual_path actual_provider actual_version failures=0
  target="$(install_state_path "$profile")"

  if [[ ! -r "$target" ]]; then
    printf 'missing install state: %s\n' "$target"
    printf 'record it with: ./dotfiles.sh install %s\n' "$profile"
    return 1
  fi

  while IFS=$'\t' read -r command_name expected_provider expected_path expected_version; do
    [[ -n "$command_name" && "$command_name" != \#* ]] || continue
    actual_path="$(canonical_command_path "$command_name" 2>/dev/null || true)"
    if [[ -z "$actual_path" || ! -x "$actual_path" ]]; then
      printf 'install-state command missing: %s\n' "$command_name"
      failures=1
      continue
    fi
    actual_provider="$(install_provider_for_command "$command_name" "$actual_path")"
    if [[ "$actual_path" != "$expected_path" || "$actual_provider" != "$expected_provider" ]]; then
      printf 'install-state provider drift: %s is %s at %s; recorded %s at %s\n' \
        "$command_name" "$actual_provider" "$actual_path" "$expected_provider" "$expected_path"
      failures=1
    fi
    if [[ "$expected_version" != "unreported" ]]; then
      actual_version="$(installed_command_version "$command_name" "$actual_path")"
      if [[ "$actual_version" != "$expected_version" ]]; then
        printf 'install-state version drift: %s is %s; recorded %s\n' \
          "$command_name" "$actual_version" "$expected_version"
        failures=1
      fi
    fi
  done < "$target"

  if [[ $failures -eq 0 ]]; then
    printf 'install state: ok (%s)\n' "$profile"
    return 0
  fi
  printf 'install state: failed (%s)\n' "$profile"
  return 1
}
