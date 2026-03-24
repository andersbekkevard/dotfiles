package_entry_target() {
  local package="$1"
  local package_entry="$2"
  printf '%s/%s\n' "$HOME" "${package_entry#"$DOTFILES_DIR/$package/"}"
}

resolve_symlink_destination() {
  local link_path="$1"
  local link_target

  link_target="$(readlink "$link_path")" || return 1

  if [[ "$link_target" = /* ]]; then
    printf '%s\n' "$link_target"
    return 0
  fi

  (
    cd "$(dirname "$link_path")" || exit 1
    cd "$(dirname "$link_target")" || exit 1
    printf '%s/%s\n' "$(pwd -P)" "$(basename "$link_target")"
  )
}

backup_path() {
  local target="$1"
  local backup_root="$HOME/.dotfiles-backups/$RUN_ID"
  local relative="${target#"$HOME/"}"

  mkdir -p "$backup_root/$(dirname "$relative")"
  mv "$target" "$backup_root/$relative"
}

backup_conflicts_for_package() {
  local package="$1"

  while IFS= read -r entry; do
    [[ "$entry" == "$DOTFILES_DIR/$package" ]] && continue
    local target
    target="$(package_entry_target "$package" "$entry")"

    if [[ -d "$entry" ]]; then
      if [[ -e "$target" && ! -d "$target" ]]; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
          log_info "[dry-run] Backup conflicting path $target"
        else
          backup_path "$target"
        fi
      fi
      continue
    fi

    [[ ! -e "$target" && ! -L "$target" ]] && continue

    if [[ -L "$target" ]]; then
      local resolved
      resolved="$(resolve_symlink_destination "$target")"
      if [[ "$resolved" == "$entry" ]]; then
        continue
      fi
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
      log_info "[dry-run] Backup conflicting path $target"
    else
      backup_path "$target"
    fi
  done < <(find "$DOTFILES_DIR/$package" -mindepth 1 | LC_ALL=C sort)
}

ensure_stow_available() {
  if command_exists stow; then
    return 0
  fi

  record_error "GNU Stow is required but not installed."
  return 1
}

stow_package() {
  local package="$1"

  if [[ ! -d "$DOTFILES_DIR/$package" ]]; then
    record_error "Unknown stow package: $package"
    return 0
  fi

  ensure_stow_available || return 0
  backup_conflicts_for_package "$package"
  run_cmd_allow_failure "Stow package $package" stow --restow --target="$HOME" --dir="$DOTFILES_DIR" --no-folding "$package"
}

stow_packages() {
  local package
  for package in "$@"; do
    stow_package "$package"
  done
}
