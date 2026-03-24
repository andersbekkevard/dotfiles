# Package installation: Homebrew, apt, GitHub releases, Neovim

github_latest_asset_url() {
  local repo="$1"
  local pattern="$2"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" | jq -r --arg pattern "$pattern" '.assets[] | select(.name | test($pattern)) | .browser_download_url' | head -n1
}

ensure_homebrew() {
  if [[ "$OS_FAMILY" != "darwin" ]]; then
    return 0
  fi

  if command_exists brew; then
    return 0
  fi

  run_cmd_allow_failure "Install Homebrew" /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

ensure_linux_command_aliases() {
  if [[ "$OS_FAMILY" != "linux" ]]; then
    return 0
  fi

  mkdir -p "$HOME/.local/bin"

  if [[ -x /usr/bin/batcat && ! -e "$HOME/.local/bin/bat" ]]; then
    ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"
  fi

  if [[ -x /usr/bin/fdfind && ! -e "$HOME/.local/bin/fd" ]]; then
    ln -sf /usr/bin/fdfind "$HOME/.local/bin/fd"
  fi
}

nvim_version_at_least() {
  local required="$1"
  local current
  current="$(nvim --version 2>/dev/null | head -1 | sed 's/^NVIM v//')" || return 1
  [[ -z "$current" ]] && return 1

  local cur_major cur_minor req_major req_minor
  cur_major="${current%%.*}"
  cur_minor="${current#*.}"; cur_minor="${cur_minor%%.*}"
  req_major="${required%%.*}"
  req_minor="${required#*.}"; req_minor="${req_minor%%.*}"

  (( cur_major > req_major )) && return 0
  (( cur_major == req_major && cur_minor >= req_minor )) && return 0
  return 1
}

ensure_neovim_011() {
  local required="0.11"
  local install_dir="$HOME/.local/share/nvim-install"
  local bin_link="$HOME/.local/bin/nvim"

  if command_exists nvim && nvim_version_at_least "$required"; then
    return 0
  fi

  if [[ "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  local arch
  arch="$(uname -m)"
  local tarball_arch
  case "$arch" in
    x86_64)  tarball_arch="x86_64" ;;
    aarch64) tarball_arch="arm64" ;;
    *)
      record_error "Neovim $required: unsupported architecture $arch"
      return 0
      ;;
  esac

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Install Neovim >= $required from GitHub release ($tarball_arch)"
    return 0
  fi

  local release_url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${tarball_arch}.tar.gz"
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  log_info "Install Neovim >= $required from GitHub release ($tarball_arch)"
  curl -fsSL "$release_url" -o "$tmp_dir/nvim.tar.gz"
  local status=$?
  if [[ $status -ne 0 ]]; then
    rm -rf "$tmp_dir"
    record_error "Download Neovim release failed (exit $status)"
    return 0
  fi

  rm -rf "$install_dir"
  mkdir -p "$install_dir"
  tar -xzf "$tmp_dir/nvim.tar.gz" -C "$install_dir" --strip-components=1
  status=$?
  rm -rf "$tmp_dir"
  if [[ $status -ne 0 ]]; then
    record_error "Extract Neovim release failed (exit $status)"
    return 0
  fi

  mkdir -p "$HOME/.local/bin"
  ln -sf "$install_dir/bin/nvim" "$bin_link"

  if "$bin_link" --version >/dev/null 2>&1; then
    log_ok "Neovim $("$bin_link" --version | head -1 | sed 's/^NVIM v//') installed to $bin_link"
  else
    record_error "Neovim binary at $bin_link is not functional"
  fi
}

brew_bundle() {
  local brewfile="$1"
  if [[ "$SKIP_INSTALL" -eq 1 ]]; then
    log_info "Skipping Brewfile $brewfile"
    return 0
  fi

  local brew_args=(bundle --file "$brewfile")
  if brew bundle --help 2>&1 | grep -q -- '--no-lock'; then
    brew_args+=(--no-lock)
  fi

  run_cmd_allow_failure "Apply Brewfile $(basename "$brewfile")" brew "${brew_args[@]}"
}

apt_update_once() {
  if [[ "$OS_FAMILY" != "linux" || "$APT_UPDATED" -eq 1 || "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if ! as_root true >/dev/null 2>&1; then
    log_warn "Skipping apt update; sudo/root unavailable."
    return 0
  fi

  run_cmd_allow_failure "Update apt package index" as_root apt-get update
  APT_UPDATED=1
}

apt_install_manifest() {
  local manifest="$1"
  if [[ "$OS_FAMILY" != "linux" || "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if ! as_root true >/dev/null 2>&1; then
    log_warn "Skipping apt install for $(basename "$manifest"); sudo/root unavailable."
    return 0
  fi

  local packages=()
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    packages+=("$line")
  done < "$manifest"

  [[ ${#packages[@]} -eq 0 ]] && return 0
  run_cmd_allow_failure "Install apt packages from $(basename "$manifest")" as_root apt-get install -y "${packages[@]}"
}

ensure_gh_apt_repo() {
  if [[ "$OS_FAMILY" != "linux" || "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if grep -Rq "cli.github.com/packages" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
    return 0
  fi

  if ! as_root true >/dev/null 2>&1; then
    log_warn "Skipping GitHub CLI apt repository setup; sudo/root unavailable."
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Configure GitHub CLI apt repository"
    return 0
  fi

  local keyring="/usr/share/keyrings/githubcli-archive-keyring.gpg"
  local source_file="/etc/apt/sources.list.d/github-cli.list"

  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | as_root tee "$keyring" >/dev/null
  local status=$?
  if [[ $status -ne 0 ]]; then
    record_error "Configure GitHub CLI apt repository failed (exit $status)"
    return 0
  fi

  as_root chmod go+r "$keyring"
  printf 'deb [arch=%s signed-by=%s] https://cli.github.com/packages stable main\n' "$(dpkg --print-architecture)" "$keyring" | as_root tee "$source_file" >/dev/null
  apt_update_once
}

ensure_ngrok_apt_repo() {
  if [[ "$OS_FAMILY" != "linux" || "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if grep -Rq "ngrok-agent.s3.amazonaws.com" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
    return 0
  fi

  if ! as_root true >/dev/null 2>&1; then
    log_warn "Skipping ngrok apt repository setup; sudo/root unavailable."
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Configure ngrok apt repository"
    return 0
  fi

  local keyring="/etc/apt/trusted.gpg.d/ngrok.asc"
  local source_file="/etc/apt/sources.list.d/ngrok.list"

  curl -fsSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | as_root tee "$keyring" >/dev/null
  local status=$?
  if [[ $status -ne 0 ]]; then
    record_error "Configure ngrok apt repository failed (exit $status)"
    return 0
  fi

  printf 'deb https://ngrok-agent.s3.amazonaws.com bookworm main\n' | as_root tee "$source_file" >/dev/null
  status=$?
  if [[ $status -ne 0 ]]; then
    record_error "Write ngrok apt repository source failed (exit $status)"
    return 0
  fi

  apt_update_once
}

install_git_delta_linux() {
  if [[ "$OS_FAMILY" != "linux" || "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if command_exists delta; then
    return 0
  fi

  local package_name="git-delta"
  local repo="dandavison/delta"
  local pattern="git-delta_.*_${ARCH_GO}\\.deb$"
  local apt_has_package=0

  if command_exists apt-cache && apt-cache show "$package_name" >/dev/null 2>&1; then
    apt_has_package=1
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    if [[ "$apt_has_package" -eq 1 ]]; then
      log_info "[dry-run] Install git-delta from apt"
    else
      log_info "[dry-run] Install git-delta from GitHub release (.deb)"
    fi
    return 0
  fi

  if ! as_root true >/dev/null 2>&1; then
    log_warn "Skipping git-delta install; sudo/root unavailable."
    return 0
  fi

  if [[ "$apt_has_package" -eq 1 ]]; then
    run_cmd_allow_failure "Install git-delta from apt" as_root apt-get install -y "$package_name"
    return 0
  fi

  local url
  url="$(github_latest_asset_url "$repo" "$pattern")"
  if [[ -z "$url" ]]; then
    record_error "Could not resolve download URL for git-delta"
    return 0
  fi

  local tmp_dir package_path
  tmp_dir="$(mktemp -d)"
  package_path="$tmp_dir/$(basename "$url")"

  curl -fsSL "$url" -o "$package_path"
  local status=$?
  if [[ $status -ne 0 ]]; then
    rm -rf "$tmp_dir"
    record_error "Download git-delta release failed (exit $status)"
    return 0
  fi

  run_cmd_allow_failure "Install git-delta from GitHub release (.deb)" as_root apt-get install -y "$package_path"
  rm -rf "$tmp_dir"
}

install_script_if_missing() {
  local command_name="$1"
  local description="$2"
  local install_cmd="$3"

  if command_exists "$command_name" || [[ "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] $description"
    return 0
  fi

  log_info "$description"
  bash -lc "$install_cmd"
  local status=$?
  if [[ $status -ne 0 ]]; then
    record_error "$description failed (exit $status)"
  fi
  return 0
}

install_linux_release_binaries() {
  local manifest="${1:-$DOTFILES_DIR/setup/packages/linux-binaries.full.txt}"

  if [[ "$OS_FAMILY" != "linux" || "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  while IFS='|' read -r tool repo pattern binary_name; do
    [[ -z "$tool" || "$tool" =~ ^# ]] && continue
    command_exists "$tool" && continue

    # Substitute architecture placeholders in the asset pattern
    pattern="${pattern//__UNAME_ARCH__/$ARCH_UNAME}"
    pattern="${pattern//__SHORT_ARCH__/$ARCH_SHORT}"

    if [[ "$DRY_RUN" -eq 1 ]]; then
      log_info "[dry-run] Install $tool from GitHub release ($ARCH_UNAME)"
      continue
    fi

    local url
    url="$(github_latest_asset_url "$repo" "$pattern")"
    if [[ -z "$url" ]]; then
      record_error "Could not resolve download URL for $tool"
      continue
    fi

    local tmp_dir archive_path
    tmp_dir="$(mktemp -d)"
    archive_path="$tmp_dir/asset"
    curl -fsSL "$url" -o "$archive_path"
    local status=$?
    if [[ $status -ne 0 ]]; then
      rm -rf "$tmp_dir"
      record_error "Download $tool release failed (exit $status)"
      continue
    fi

    case "$url" in
      *.tar.gz|*.tgz)
        tar -xzf "$archive_path" -C "$tmp_dir"
        ;;
      *.zip)
        unzip -q "$archive_path" -d "$tmp_dir"
        ;;
      *)
        chmod +x "$archive_path"
        mkdir -p "$HOME/.local/bin"
        mv "$archive_path" "$HOME/.local/bin/$binary_name"
        rm -rf "$tmp_dir"
        continue
        ;;
    esac

    local extracted
    extracted="$(find "$tmp_dir" -type f -name "$binary_name" | head -n1)"
    if [[ -z "$extracted" ]]; then
      rm -rf "$tmp_dir"
      record_error "Could not locate binary $binary_name for $tool"
      continue
    fi

    mkdir -p "$HOME/.local/bin"
    install -m 0755 "$extracted" "$HOME/.local/bin/$binary_name"
    rm -rf "$tmp_dir"
  done < "$manifest"
}

install_meslo_font_linux() {
  local font_dir="$HOME/.local/share/fonts"
  local archive_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.tar.xz"

  if [[ "$OS_FAMILY" != "linux" || "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if compgen -G "$font_dir/*Meslo*" >/dev/null 2>&1; then
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Install Meslo Nerd Font"
    return 0
  fi

  local tmp_dir archive
  tmp_dir="$(mktemp -d)"
  archive="$tmp_dir/meslo.tar.xz"
  mkdir -p "$font_dir"

  curl -fsSL "$archive_url" -o "$archive"
  local status=$?
  if [[ $status -ne 0 ]]; then
    rm -rf "$tmp_dir"
    record_error "Download Meslo Nerd Font failed (exit $status)"
    return 0
  fi

  tar -xf "$archive" -C "$font_dir"
  status=$?
  rm -rf "$tmp_dir"
  if [[ $status -ne 0 ]]; then
    record_error "Install Meslo Nerd Font failed (exit $status)"
    return 0
  fi

  command_exists fc-cache && fc-cache -f "$font_dir" >/dev/null 2>&1
}

install_greenclip() {
  local target="$HOME/.local/bin/greenclip"
  local url="https://github.com/erebe/greenclip/releases/download/v4.2/greenclip"

  if [[ "$OS_FAMILY" != "linux" || "$SKIP_INSTALL" -eq 1 || -x "$target" ]]; then
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Install greenclip"
    return 0
  fi

  mkdir -p "$HOME/.local/bin"
  curl -fsSL "$url" -o "$target"
  local status=$?
  if [[ $status -ne 0 ]]; then
    record_error "Install greenclip failed (exit $status)"
    return 0
  fi

  chmod +x "$target"
}

install_ghostty_snap() {
  if [[ "$OS_FAMILY" != "linux" || "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  command_exists ghostty && return 0
  command_exists snap || return 0
  as_root true >/dev/null 2>&1 || return 0

  run_cmd_allow_failure "Install Ghostty snap" as_root snap install ghostty --classic
}
