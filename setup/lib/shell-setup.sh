git_checkout_is_complete() {
  local target="$1" required_path="$2"
  [[ -d "$target/.git" && -e "$target/$required_path" ]]
}

install_git_checkout_if_incomplete() {
  local name="$1" url="$2" target="$3" required_path="$4"
  local parent staging clone_output

  git_checkout_is_complete "$target" "$required_path" && return 0
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Install $name"
    return 0
  fi

  parent="$(dirname "$target")"
  mkdir -p "$parent"
  staging="$(mktemp -d "$parent/.$(basename "$target").tmp.XXXXXX")"
  if ! clone_output="$(git clone --depth=1 "$url" "$staging/checkout" 2>&1)" ||
     ! git_checkout_is_complete "$staging/checkout" "$required_path"; then
    rm -rf "$staging"
    record_error "Install $name failed: $(tail -n 1 <<< "$clone_output")"
    return 0
  fi

  if [[ -e "$target" || -L "$target" ]]; then
    backup_path "$target"
    log_warn "backed up incomplete $name checkout at $target"
  fi
  if ! mv "$staging/checkout" "$target"; then
    rm -rf "$staging"
    record_error "Could not activate $name at $target"
    return 0
  fi
  rmdir "$staging" 2>/dev/null || true
}

ensure_oh_my_zsh() {
  local target="$HOME/.oh-my-zsh"
  if [[ "$SKIP_INSTALL" -eq 1 ]] ||
     [[ -d "$target/.git" && -f "$target/oh-my-zsh.sh" ]]; then
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Install Oh My Zsh assets"
    return 0
  fi

  local parent staging tmp_dir installer status
  parent="$(dirname "$target")"
  staging="$(mktemp -d "$parent/.oh-my-zsh.tmp.XXXXXX")"
  tmp_dir="$(mktemp -d)"
  installer="$tmp_dir/install.sh"
  if curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$installer" &&
     [[ -s "$installer" ]]; then
    status=0
  else
    status=$?
    rm -rf "$staging" "$tmp_dir"
    record_error "Download Oh My Zsh installer failed (exit $status)"
    return 0
  fi

  log_info "Install Oh My Zsh assets"
  if ZSH="$staging/checkout" RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh "$installer" "" --unattended; then
    status=0
  else
    status=$?
  fi
  rm -rf "$tmp_dir"
  if [[ $status -ne 0 || ! -d "$staging/checkout/.git" || ! -f "$staging/checkout/oh-my-zsh.sh" ]]; then
    rm -rf "$staging"
    record_error "Install Oh My Zsh assets failed (exit $status)"
    return 0
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    backup_path "$target"
    log_warn "backed up incomplete Oh My Zsh checkout at $target"
  fi
  if ! mv "$staging/checkout" "$target"; then
    rm -rf "$staging"
    record_error "Could not activate Oh My Zsh assets"
    return 0
  fi
  rmdir "$staging" 2>/dev/null || true
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
    install_git_checkout_if_incomplete "$name" "$url" "$target" .git
  done
}

ensure_tpm() {
  local target="$HOME/.tmux/plugins/tpm"

  if [[ "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  install_git_checkout_if_incomplete \
    "tmux plugin manager" https://github.com/tmux-plugins/tpm "$target" bin/install_plugins

  if [[ -x "$target/bin/install_plugins" ]]; then
    run_cmd_allow_failure "Install tmux plugins with TPM" "$target/bin/install_plugins"
  fi
}

ensure_default_shell_zsh() {
  if ! command_exists zsh; then
    # Same reasoning as ensure_stow_available: the package step that installs
    # zsh is part of the plan a dry run is printing, so report the intent rather
    # than an error. The path is unknown until zsh exists, so name the command.
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log_info "[dry-run] Change default shell to zsh"
      return 0
    fi
    record_error "zsh is not installed; cannot set default shell"
    return 0
  fi

  local zsh_path current_shell
  zsh_path="$(command -v zsh)"
  if command_exists getent; then
    current_shell="$(getent passwd "${USER:-$(id -un)}" | awk -F: '{print $7}')"
  elif command_exists dscl; then
    current_shell="$(dscl . -read "/Users/${USER:-$(id -un)}" UserShell 2>/dev/null | awk '{print $2}')"
  else
    current_shell="${SHELL:-}"
  fi
  if [[ "$current_shell" == "$zsh_path" || "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Change default shell to $zsh_path"
    return 0
  fi

  log_info "Changing default shell to $zsh_path"
  local status
  if [[ $EUID -eq 0 ]]; then
    if chsh -s "$zsh_path"; then status=0; else status=$?; fi
  elif [[ "$HAS_SUDO" -eq 1 ]]; then
    if sudo chsh -s "$zsh_path" "$USER"; then status=0; else status=$?; fi
  elif [[ "$ASSUME_YES" -eq 1 || "$NO_INPUT" -eq 1 || ! -t 0 ]]; then
    record_error "Changing the default shell requires interactive authentication or working sudo"
    return 0
  else
    log_warn "chsh will prompt for your password."
    if chsh -s "$zsh_path"; then status=0; else status=$?; fi
  fi
  if [[ $status -ne 0 ]]; then
    record_error "Change default shell to zsh failed (exit $status)"
  fi
}

note_git_crypt_state() {
  local secrets_path private_probe private_prefix
  secrets_path="$(secrets_source_path)"
  private_probe="$DOTFILES_DIR/agents/skills/application-email/SKILL.md"

  if [[ -f "$private_probe" ]]; then
    private_prefix="$(LC_ALL=C od -An -tx1 -N10 "$private_probe" 2>/dev/null | tr -d '[:space:]')"
    if [[ "$private_prefix" == "00474954435259505400" ]]; then
      log_warn "Private repository content is locked. Run: git-crypt unlock <keyfile>"
      return 0
    fi
  fi

  if [[ ! -e "$secrets_path" ]]; then
    log_info "Private repository content is readable; no .secrets file is present."
    return 0
  fi

  if LC_ALL=C grep -Iq . "$secrets_path" 2>/dev/null; then
    log_info "Tracked shell/.secrets is readable."
  else
    log_warn "Tracked shell/.secrets appears locked or binary. Run: git-crypt unlock <keyfile>"
  fi
}

# ~/.zshrc.local is user-owned once edited. Setup writes it with a first-line
# marker carrying the profile and a sha256 of the body; a file whose body still
# hashes to its marker is untouched and safe to refresh in place. This replaces
# keeping verbatim snapshots of every historical template.
write_local_overrides_template() {
  local profile="$1"
  local target="$HOME/.zshrc.local"
  local source_template="$DOTFILES_DIR/shell/.zshrc.local.example"
  local local_config_dir="$HOME/.config/zsh"
  local reference_template="$local_config_dir/local.example.zsh"
  local backup_target managed_profile=""

  render_local_overrides_body() {
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
EOF
        ;;
      *)
        cat <<'EOF'
export THEME_COLOR="blue"
EOF
        ;;
    esac
  }

  render_managed_local_overrides() {
    printf '# dotfiles-managed: profile=%s sha256=%s\n' \
      "$1" "$(render_local_overrides_body "$1" | sha256_stdin)"
    render_local_overrides_body "$1"
  }

  # Prints the profile of an untouched managed file; fails if the file was
  # edited by the user (marker hash no longer matches) or is not managed.
  detect_managed_profile() {
    local candidate="$1"
    local first_line marker_rest marker_profile marker_sha candidate_profile

    IFS= read -r first_line < "$candidate" || return 1

    case "$first_line" in
      '# dotfiles-managed: profile='*' sha256='*)
        marker_rest="${first_line#"# dotfiles-managed: profile="}"
        marker_profile="${marker_rest%% *}"
        marker_sha="${marker_rest##* sha256=}"
        [[ "$(tail -n +2 "$candidate" | sha256_stdin)" == "$marker_sha" ]] || return 1
        printf '%s\n' "$marker_profile"
        return 0
        ;;
    esac

    # Transitional: adopt marker-less files that still exactly match the live
    # template render, from before the marker existed.
    for candidate_profile in minimal full macos linux-desktop; do
      if diff -q "$candidate" <(render_local_overrides_body "$candidate_profile") >/dev/null 2>&1; then
        printf '%s\n' "$candidate_profile"
        return 0
      fi
    done
    return 1
  }

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Refresh ~/.config/zsh/local.example.zsh"
  else
    mkdir -p "$local_config_dir"
    render_managed_local_overrides "$profile" > "$reference_template"
  fi

  if [[ ! -e "$target" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log_info "[dry-run] Create ~/.zshrc.local from managed template"
      return 0
    fi
    render_managed_local_overrides "$profile" > "$target"
    return 0
  fi

  managed_profile="$(detect_managed_profile "$target" || true)"

  if [[ -z "$managed_profile" ]]; then
    log_info "Preserving existing ~/.zshrc.local; compare with $reference_template for template updates."
    return 0
  fi

  if [[ "$managed_profile" == "$profile" ]] && \
     diff -q "$target" <(render_managed_local_overrides "$profile") >/dev/null 2>&1; then
    return 0
  fi

  backup_target="$target.pre-locality-migration-$RUN_ID.bak"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Refresh untouched ~/.zshrc.local from managed template"
    return 0
  fi

  cp "$target" "$backup_target"
  render_managed_local_overrides "$profile" > "$target"
  log_info "Refreshed untouched ~/.zshrc.local from the latest managed template"
  log_info "Backup saved to $backup_target"
}
