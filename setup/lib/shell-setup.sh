ensure_oh_my_zsh() {
  if [[ "$SKIP_INSTALL" -eq 1 || -d "$HOME/.oh-my-zsh" ]]; then
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Install Oh My Zsh assets"
    return 0
  fi

  log_info "Install Oh My Zsh assets"
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  local status=$?
  if [[ $status -ne 0 ]]; then
    record_error "Install Oh My Zsh assets failed (exit $status)"
  fi
}

ensure_zsh_plugins() {
  local custom_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  local specs=(
    "powerlevel10k|themes/powerlevel10k|https://github.com/romkatv/powerlevel10k.git"
    "zsh-autosuggestions|plugins/zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions"
    "zsh-syntax-highlighting|plugins/zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting.git"
  )

  if [[ "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  for spec in "${specs[@]}"; do
    IFS='|' read -r name rel url <<< "$spec"
    local target="$custom_dir/$rel"
    if [[ -d "$target" ]]; then
      continue
    fi
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log_info "[dry-run] Install $name"
      continue
    fi
    mkdir -p "$(dirname "$target")"
    git clone --depth=1 "$url" "$target" >/dev/null 2>&1
    local status=$?
    if [[ $status -ne 0 ]]; then
      record_error "Install $name failed (exit $status)"
    fi
  done
}

ensure_tpm() {
  local target="$HOME/.tmux/plugins/tpm"

  if [[ "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if [[ ! -d "$target" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log_info "[dry-run] Install tmux plugin manager"
    else
      git clone --depth=1 https://github.com/tmux-plugins/tpm "$target" >/dev/null 2>&1
      local status=$?
      if [[ $status -ne 0 ]]; then
        record_error "Install tmux plugin manager failed (exit $status)"
      fi
    fi
  fi

  if [[ -x "$target/bin/install_plugins" ]]; then
    run_cmd_allow_failure "Install tmux plugins with TPM" "$target/bin/install_plugins"
  fi
}

ensure_default_shell_zsh() {
  if ! command_exists zsh; then
    record_error "zsh is not installed; cannot set default shell"
    return 0
  fi

  local zsh_path
  zsh_path="$(command -v zsh)"
  if [[ "${SHELL:-}" == "$zsh_path" || "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Change default shell to $zsh_path"
    return 0
  fi

  log_info "Changing default shell to $zsh_path"
  if [[ $EUID -eq 0 ]]; then
    chsh -s "$zsh_path"
  elif [[ "$HAS_SUDO" -eq 1 ]]; then
    sudo chsh -s "$zsh_path" "$USER"
  else
    log_warn "chsh will prompt for your password."
    chsh -s "$zsh_path"
  fi
  local status=$?
  if [[ $status -ne 0 ]]; then
    record_error "Change default shell to zsh failed (exit $status)"
  fi
}

note_git_crypt_state() {
  local secrets_path
  secrets_path="$(secrets_source_path)"

  if [[ ! -e "$secrets_path" ]]; then
    log_info "No .secrets file present; git-crypt unlock not required."
    return 0
  fi

  if LC_ALL=C grep -Iq . "$secrets_path" 2>/dev/null; then
    log_info "Tracked shell/.secrets is readable."
  else
    log_warn "Tracked shell/.secrets appears locked or binary. Run: git-crypt unlock <keyfile>"
  fi
}

write_local_overrides_template() {
  local profile="$1"
  local target="$HOME/.zshrc.local"
  local source_template="$DOTFILES_DIR/shell/.zshrc.local.example"
  local local_config_dir="$HOME/.config/zsh"
  local reference_template="$local_config_dir/local.example.zsh"
  local backup_target
  local managed_state=""
  local managed_version=""
  local managed_profile=""

  render_current_local_overrides() {
    cat "$source_template"
    printf '\n# Profile scaffold for %s\n' "$1"

    case "$1" in
      linux-desktop)
        cat <<'EOF'
export THEME_COLOR="blue"

if [[ -f /etc/tlp.d/01-server-mode.conf && -o interactive ]]; then
  _threshold="$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null)"
  if [[ "$_threshold" != "80" ]]; then
    printf '\033[0;31m[!] TLP battery threshold not enforced (reads %s%%)\033[0m\n' "${_threshold:-?}"
  fi
  unset _threshold
fi

if [[ -f "$HOME/.openclaw/completions/openclaw.zsh" ]]; then
  source "$HOME/.openclaw/completions/openclaw.zsh"
fi

command -v openclaw >/dev/null 2>&1 && alias tui="openclaw tui"
EOF
        ;;
      macos)
        cat <<'EOF'
export THEME_COLOR="blue"
EOF
        ;;
      *)
        cat <<'EOF'
export THEME_COLOR="blue"
EOF
        ;;
    esac
  }

  render_previous_current_local_overrides() {
    # Snapshot of the previous managed template so untouched ~/.zshrc.local
    # files can be migrated from HAL_THEME_COLOR to THEME_COLOR in place.
    cat <<'EOF'
# Machine-local shell overrides live here.
# This file is user-owned. Keep host-specific settings here instead of tracked
# dotfiles, and compare against ~/.config/zsh/local.example.zsh after running
# ./setup.sh to review the latest template changes safely.
#
# Good candidates:
# - prompt/tmux accent
# - host-specific aliases or completions
# - laptop-only checks
#
# For env vars or PATH entries that automation and services must see, use
# ~/.profile.local instead.
EOF
    printf '\n# Profile scaffold for %s\n' "$1"

    case "$1" in
      linux-desktop)
        cat <<'EOF'
export HAL_THEME_COLOR="red"

if [[ -f /etc/tlp.d/01-server-mode.conf && -o interactive ]]; then
  _threshold="$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null)"
  if [[ "$_threshold" != "80" ]]; then
    printf '\033[0;31m[!] TLP battery threshold not enforced (reads %s%%)\033[0m\n' "${_threshold:-?}"
  fi
  unset _threshold
fi

if [[ -f "$HOME/.openclaw/completions/openclaw.zsh" ]]; then
  source "$HOME/.openclaw/completions/openclaw.zsh"
fi

command -v openclaw >/dev/null 2>&1 && alias tui="openclaw tui"
EOF
        ;;
      macos)
        cat <<'EOF'
export HAL_THEME_COLOR="blue"
EOF
        ;;
      *)
        cat <<'EOF'
export HAL_THEME_COLOR="green"
EOF
        ;;
    esac
  }

  render_legacy_local_overrides() {
    local legacy_profile_name="$1"

    # Keep the historical template verbatim so we can safely detect untouched
    # legacy ~/.zshrc.local files before refreshing them in place.
    cat <<'EOF'
# Machine-specific overrides live here.
# This file is intentionally not tracked once copied to ~/.zshrc.local.
#
# Use it for:
# - host-specific PATH additions
# - laptop-only battery checks
# - local aliases that should not propagate
# - optional shell completions for tools installed outside dotfiles
#
# Prompt/tmux machine identity color.
# Recommended defaults:
#   ThinkPad / linux-desktop -> red
#   MacBook / macos          -> blue
#   VPS / linux-headless     -> green
# export HAL_THEME_COLOR="red"

# Example machine-local model paths:
# export LLAMA_APRILIA_MODEL_PATH="$HOME/.ollama/models/blobs/<blob>"
# export LLAMA_GLM_MODEL_PATH="$HOME/.ollama/models/blobs/<blob>"
EOF
    printf '\n# Profile-specific additions for %s\n' "$legacy_profile_name"

    case "$legacy_profile_name" in
      linux-desktop)
        cat <<'EOF'
export HAL_THEME_COLOR="red"

if [[ -f /etc/tlp.d/01-server-mode.conf && -o interactive ]]; then
  _threshold="$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null)"
  if [[ "$_threshold" != "80" ]]; then
    printf '\033[0;31m[!] TLP battery threshold not enforced (reads %s%%)\033[0m\n' "${_threshold:-?}"
  fi
  unset _threshold
fi

if [[ -f "$HOME/.openclaw/completions/openclaw.zsh" ]]; then
  source "$HOME/.openclaw/completions/openclaw.zsh"
fi

command -v openclaw >/dev/null 2>&1 && alias tui="openclaw tui"
EOF
        ;;
      macos)
        cat <<'EOF'
export HAL_THEME_COLOR="blue"

# Add machine-only PATH or aliases here.
EOF
        ;;
      *)
        cat <<'EOF'
export HAL_THEME_COLOR="green"

# Add machine-only PATH or aliases here.
EOF
        ;;
    esac
  }

  detect_managed_template_state() {
    local candidate="$1"
    local candidate_profile
    local candidate_version

    for candidate_version in current previous legacy; do
      for candidate_profile in minimal full macos linux-headless linux-desktop; do
        if [[ "$candidate_version" == "current" ]]; then
          if diff -q "$candidate" <(render_current_local_overrides "$candidate_profile") >/dev/null 2>&1; then
            printf '%s|%s\n' "$candidate_version" "$candidate_profile"
            return 0
          fi
        elif [[ "$candidate_version" == "previous" ]]; then
          if diff -q "$candidate" <(render_previous_current_local_overrides "$candidate_profile") >/dev/null 2>&1; then
            printf '%s|%s\n' "$candidate_version" "$candidate_profile"
            return 0
          fi
        else
          if diff -q "$candidate" <(render_legacy_local_overrides "$candidate_profile") >/dev/null 2>&1; then
            printf '%s|%s\n' "$candidate_version" "$candidate_profile"
            return 0
          fi
        fi
      done
    done

    return 1
  }

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Refresh ~/.config/zsh/local.example.zsh"
  else
    mkdir -p "$local_config_dir"
    render_current_local_overrides "$profile" > "$reference_template"
  fi

  if [[ -e "$target" ]]; then
    managed_state="$(detect_managed_template_state "$target" || true)"
    if [[ -n "$managed_state" ]]; then
      managed_version="${managed_state%%|*}"
      managed_profile="${managed_state#*|}"
    fi
  fi

  if [[ "$managed_version" == "legacy" || "$managed_version" == "previous" || ( "$managed_version" == "current" && "$managed_profile" != "$profile" ) ]]; then
    backup_target="$target.pre-locality-migration-$RUN_ID.bak"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log_info "[dry-run] Refresh untouched ~/.zshrc.local from managed template"
      return 0
    fi

    cp "$target" "$backup_target"
    render_current_local_overrides "$profile" > "$target"
    log_info "Refreshed untouched ~/.zshrc.local from the latest managed template"
    log_info "Backup saved to $backup_target"
    return 0
  fi

  if [[ "$managed_version" == "current" && "$managed_profile" == "$profile" ]]; then
    return 0
  fi

  if [[ -e "$target" ]]; then
    log_info "Preserving existing ~/.zshrc.local; compare with $reference_template for template updates."
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Create ~/.zshrc.local from managed template"
    return 0
  fi

  render_current_local_overrides "$profile" > "$target"
}
