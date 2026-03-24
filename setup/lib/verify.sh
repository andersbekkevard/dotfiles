verify_package_links() {
  local package="$1"
  local failures=0

  while IFS= read -r source_path; do
    local rel target resolved
    rel="${source_path#"$DOTFILES_DIR/$package/"}"
    target="$HOME/$rel"

    if [[ ! -L "$target" ]]; then
      printf 'missing symlink: %s\n' "$target"
      failures=1
      continue
    fi

    resolved="$(resolve_symlink_destination "$target")"
    if [[ "$resolved" != "$source_path" ]]; then
      printf 'wrong target: %s -> %s\n' "$target" "$resolved"
      failures=1
      continue
    fi

    if [[ ! -e "$target" ]]; then
      printf 'broken symlink: %s\n' "$target"
      failures=1
    fi
  done < <(find "$DOTFILES_DIR/$package" -mindepth 1 \( -type f -o -type l \) | LC_ALL=C sort)

  return $failures
}

verify_commands() {
  local profile="$1"
  local failures=0
  local cmd

  while IFS= read -r cmd; do
    [[ -z "$cmd" ]] && continue
    if ! command_exists_in_clean_login_shell "$cmd"; then
      printf 'missing in clean login shell: %s\n' "$cmd"
      failures=1
    fi
    if ! command_exists_in_stable_path_contract "$cmd"; then
      printf 'missing in stable PATH contract: %s\n' "$cmd"
      failures=1
    fi
  done < <(profile_commands "$profile")

  return $failures
}

verify_profile() {
  local profile="$1"
  local failures=0
  local package

  while IFS= read -r package; do
    [[ -z "$package" ]] && continue
    verify_package_links "$package" || failures=1
  done < <(profile_packages "$profile")

  verify_profile_symlink_drift "$profile" || failures=1
  verify_commands "$profile" || failures=1

  if command_exists nvim; then
    if ! nvim_version_at_least "0.11"; then
      printf 'neovim too old: %s (need >= 0.11). Run ./setup.sh <profile> to upgrade.\n' \
        "$(nvim --version 2>/dev/null | head -1 | sed 's/^NVIM v//')"
      failures=1
    fi
  fi

  if [[ $failures -eq 0 ]]; then
    printf 'verify: ok (%s)\n' "$profile"
    return 0
  fi

  printf 'verify: failed (%s)\n' "$profile"
  return 1
}

managed_target_roots() {
  find "$DOTFILES_DIR" \
    -mindepth 2 \
    -maxdepth 3 \
    \( -type f -o -type l \) \
    ! -path "$DOTFILES_DIR/setup/*" \
    ! -path "$DOTFILES_DIR/docs/*" \
    ! -path "$DOTFILES_DIR/archive/*" \
    | while IFS= read -r source_path; do
        local rel
        rel="${source_path#"$DOTFILES_DIR"/}"
        rel="${rel#*/}"
        printf '%s\n' "${rel%%/*}"
      done | LC_ALL=C sort -u
}

verify_profile_symlink_drift() {
  local profile="$1"
  local actual_link actual_target root_path failures=0
  local tmp_expected tmp_roots

  tmp_expected="$(mktemp)"
  tmp_roots="$(mktemp)"

  while IFS= read -r package; do
    [[ -z "$package" ]] && continue
    find "$DOTFILES_DIR/$package" -mindepth 1 \( -type f -o -type l \) | while IFS= read -r source_path; do
      printf '%s\n' "$HOME/${source_path#"$DOTFILES_DIR/$package/"}"
    done
  done < <(profile_packages "$profile") | LC_ALL=C sort -u > "$tmp_expected"

  managed_target_roots > "$tmp_roots"

  while IFS= read -r root_name; do
    root_path="$HOME/$root_name"
    [[ -e "$root_path" || -L "$root_path" ]] || continue

    while IFS= read -r actual_link; do
      actual_target="$(resolve_symlink_destination "$actual_link" 2>/dev/null)" || {
        printf 'broken managed symlink: %s\n' "$actual_link"
        failures=1
        continue
      }

      case "$actual_target" in
        "$DOTFILES_DIR"/*)
          if ! grep -Fxq "$actual_link" "$tmp_expected"; then
            printf 'unexpected managed symlink for profile %s: %s -> %s\n' "$profile" "$actual_link" "$actual_target"
            failures=1
          fi
          ;;
      esac
    done < <(find "$root_path" \( -type l -o -xtype l \) 2>/dev/null | LC_ALL=C sort)
  done < "$tmp_roots"

  rm -f "$tmp_expected" "$tmp_roots"
  return $failures
}
