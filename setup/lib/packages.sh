# Package installation: Homebrew, apt, GitHub releases, Neovim

atomic_install_file() {
  local source="$1" target="$2" mode="${3:-0755}"
  local target_dir staging

  target_dir="$(dirname "$target")"
  mkdir -p "$target_dir"
  staging="$(mktemp "$target_dir/.$(basename "$target").tmp.XXXXXX")" || return 1
  if ! install -m "$mode" "$source" "$staging"; then
    rm -f "$staging"
    return 1
  fi
  if ! mv -f "$staging" "$target"; then
    rm -f "$staging"
    return 1
  fi
}

atomic_install_file_as_root() {
  local source="$1" target="$2" mode="${3:-0644}"
  local staging="${target}.dotfiles-tmp.${RUN_ID:-run}.$$"

  if ! as_root install -m "$mode" "$source" "$staging"; then
    as_root rm -f "$staging"
    return 1
  fi
  if ! as_root mv -f "$staging" "$target"; then
    as_root rm -f "$staging"
    return 1
  fi
}

download_nonempty_file() {
  local url="$1" target="$2"
  curl -fsSL "$url" -o "$target" && [[ -s "$target" ]]
}

command_owned_at() {
  local command_name="$1" target="$2"
  local resolved

  resolved="$(command -v "$command_name" 2>/dev/null || true)"
  [[ "$resolved" == "$target" ]]
}

should_install_managed_command() {
  local command_name="$1" target="$2"

  if ! command_exists "$command_name"; then
    return 0
  fi
  [[ "$UPGRADE_EXISTING" -eq 1 ]] || return 1
  if command_owned_at "$command_name" "$target"; then
    return 0
  fi
  log_warn "Skipping update for $command_name; current command is not dotfiles-owned ($(command -v "$command_name"))."
  return 1
}

github_latest_asset_url() {
  local repo="$1"
  local pattern="$2"
  local release_json
  if ! release_json="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest")"; then
    return 0
  fi
  jq -r --arg pattern "$pattern" \
    '.assets[] | select(.name | test($pattern)) | .browser_download_url' \
    <<<"$release_json" 2>/dev/null | head -n1 || true
}

homebrew_executable() {
  if command_exists brew; then
    command -v brew
    return 0
  fi

  case "$(uname -m)" in
    arm64|aarch64)
      [[ -x /opt/homebrew/bin/brew ]] && {
        printf '%s\n' /opt/homebrew/bin/brew
        return 0
      }
      [[ -x /usr/local/bin/brew ]] && {
        printf '%s\n' /usr/local/bin/brew
        return 0
      }
      ;;
    *)
      [[ -x /usr/local/bin/brew ]] && {
        printf '%s\n' /usr/local/bin/brew
        return 0
      }
      [[ -x /opt/homebrew/bin/brew ]] && {
        printf '%s\n' /opt/homebrew/bin/brew
        return 0
      }
      ;;
  esac

  return 1
}

ensure_homebrew() {
  if [[ "$OS_FAMILY" != "darwin" ]]; then
    return 0
  fi

  local brew_bin=""
  brew_bin="$(homebrew_executable 2>/dev/null || true)"

  if [[ -z "$brew_bin" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log_info "[dry-run] Install Homebrew"
      log_info "[dry-run] Activate Homebrew in the setup process"
      return 0
    fi

    local tmp_dir installer status
    tmp_dir="$(mktemp -d)"
    installer="$tmp_dir/install.sh"
    if download_nonempty_file https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh "$installer"; then
      status=0
    else
      status=$?
      rm -rf "$tmp_dir"
      record_error "Download Homebrew installer failed (exit $status)"
      return 1
    fi
    if [[ "$ASSUME_YES" -eq 1 || "$NO_INPUT" -eq 1 || ! -t 0 ]]; then
      run_cmd_allow_failure "Install Homebrew" env NONINTERACTIVE=1 CI=1 /bin/bash "$installer"
    else
      run_cmd_allow_failure "Install Homebrew" /bin/bash "$installer"
    fi
    rm -rf "$tmp_dir"
    brew_bin="$(homebrew_executable 2>/dev/null || true)"
  fi

  if [[ -z "$brew_bin" || ! -x "$brew_bin" ]]; then
    record_error "Homebrew is unavailable after installation"
    return 1
  fi

  local brew_env
  brew_env="$("$brew_bin" shellenv 2>/dev/null)" || {
    record_error "Homebrew shell environment could not be loaded from $brew_bin"
    return 1
  }
  eval "$brew_env"
  hash -r

  if ! command_exists brew; then
    record_error "Homebrew is not on PATH after loading $brew_bin shellenv"
    return 1
  fi
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

ensure_postgresql_client_entrypoints() {
  if [[ "$OS_FAMILY" != "darwin" ]]; then
    return 0
  fi

  if ! command_exists brew; then
    return 0
  fi

  local libpq_prefix psql_bin target
  libpq_prefix="$(brew --prefix libpq 2>/dev/null)" || return 0
  psql_bin="$libpq_prefix/bin/psql"
  target="$HOME/.local/bin/psql"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Expose Homebrew libpq psql at $target"
    return 0
  fi

  if [[ -x "$psql_bin" ]]; then
    mkdir -p "$HOME/.local/bin"
    ln -sfn "$psql_bin" "$target"
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

  if command_exists nvim && nvim_version_at_least "$required" && [[ "$UPGRADE_EXISTING" -eq 0 ]]; then
    return 0
  fi

  if [[ "$UPGRADE_EXISTING" -eq 1 ]] && command_exists nvim && ! command_owned_at nvim "$bin_link"; then
    log_warn "Skipping Neovim update; current command is not dotfiles-owned ($(command -v nvim))."
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
  local tmp_dir staging_dir previous_dir
  tmp_dir="$(mktemp -d)"

  log_info "Install Neovim >= $required from GitHub release ($tarball_arch)"
  local status
  if download_nonempty_file "$release_url" "$tmp_dir/nvim.tar.gz"; then
    status=0
  else
    status=$?
    rm -rf "$tmp_dir"
    record_error "Download Neovim release failed (exit $status)"
    return 0
  fi

  mkdir -p "$(dirname "$install_dir")"
  staging_dir="$(mktemp -d "$(dirname "$install_dir")/.nvim-install.tmp.XXXXXX")"
  if tar -xzf "$tmp_dir/nvim.tar.gz" -C "$staging_dir" --strip-components=1; then
    status=0
  else
    status=$?
  fi
  rm -rf "$tmp_dir"
  if [[ $status -ne 0 || ! -x "$staging_dir/bin/nvim" ]] ||
     ! "$staging_dir/bin/nvim" --version >/dev/null 2>&1; then
    rm -rf "$staging_dir"
    record_error "Extract Neovim release failed (exit $status)"
    return 0
  fi

  previous_dir="$(dirname "$install_dir")/.nvim-install.previous.$RUN_ID"
  rm -rf "$previous_dir"
  if [[ -e "$install_dir" ]] && ! mv "$install_dir" "$previous_dir"; then
    rm -rf "$staging_dir"
    record_error "Could not stage the existing Neovim installation"
    return 0
  fi
  if ! mv "$staging_dir" "$install_dir"; then
    [[ -e "$previous_dir" ]] && mv "$previous_dir" "$install_dir"
    record_error "Could not activate the new Neovim installation"
    return 0
  fi
  rm -rf "$previous_dir"

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

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Apply Brewfile $(basename "$brewfile")"
    return 0
  fi

  if ! command_exists brew; then
    record_error "Cannot apply $(basename "$brewfile"): Homebrew is not on PATH"
    return 0
  fi

  local brew_args=(bundle install --file "$brewfile")

  if [[ "$UPGRADE_EXISTING" -eq 1 ]]; then
    if ! brew bundle install --help 2>&1 | grep -q -- '--upgrade'; then
      record_error "This Homebrew version cannot update a Brewfile with --upgrade"
      return 0
    fi
    brew_args+=(--upgrade)
    run_cmd_allow_failure "Update Homebrew metadata" env NONINTERACTIVE=1 CI=1 brew update
    run_cmd_allow_failure "Update Brewfile $(basename "$brewfile")" env NONINTERACTIVE=1 CI=1 brew "${brew_args[@]}"
  else
    if ! brew bundle install --help 2>&1 | grep -q -- '--no-upgrade'; then
      record_error "This Homebrew version cannot install a Brewfile without upgrading existing entries"
      return 0
    fi
    brew_args+=(--no-upgrade)
    run_cmd_allow_failure \
      "Install missing entries from Brewfile $(basename "$brewfile")" \
      env HOMEBREW_NO_AUTO_UPDATE=1 NONINTERACTIVE=1 CI=1 brew "${brew_args[@]}"
  fi
}

apt_package_commands() {
  case "$1" in
    bat) printf '%s\n' bat batcat ;;
    fd-find) printf '%s\n' fd fdfind ;;
    ripgrep) printf '%s\n' rg ;;
    git-delta) printf '%s\n' delta ;;
    postgresql-client) printf '%s\n' psql ;;
    network-manager-gnome) printf '%s\n' nm-applet ;;
    pulseaudio-utils) printf '%s\n' pactl ;;
    x11-xkb-utils) printf '%s\n' setxkbmap ;;
    x11-xserver-utils) printf '%s\n' xrandr ;;
    *) printf '%s\n' "$1" ;;
  esac
}

apt_package_satisfied_by_command() {
  local package="$1" command_name
  while IFS= read -r command_name; do
    command_exists "$command_name" && return 0
  done < <(apt_package_commands "$package")
  return 1
}

dpkg_package_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -Fqx 'install ok installed'
}

apt_update_once() {
  if [[ "$OS_FAMILY" != "linux" || "$APT_UPDATED" -eq 1 || "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if ! can_use_root; then
    log_warn "Skipping apt update; sudo/root unavailable."
    return 0
  fi

  if run_cmd "Update apt package index" as_root apt-get update; then
    APT_UPDATED=1
    return 0
  fi
  return 1
}

apt_update_after_repo_change() {
  local description="$1"
  if run_cmd "$description" as_root apt-get update; then
    APT_UPDATED=1
    return 0
  fi
  return 1
}

apt_install_manifest() {
  local manifest="$1"
  if [[ "$OS_FAMILY" != "linux" || "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if ! can_use_root; then
    log_warn "Skipping apt install for $(basename "$manifest"); sudo/root unavailable."
    return 0
  fi

  local packages=() selected=() package
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    packages+=("$line")
  done < "$manifest"

  [[ ${#packages[@]} -eq 0 ]] && return 0
  for package in "${packages[@]}"; do
    if dpkg_package_installed "$package"; then
      [[ "$UPGRADE_EXISTING" -eq 1 ]] && selected+=("$package")
    elif apt_package_satisfied_by_command "$package"; then
      log_info "Adopting existing command provider instead of apt package: $package"
    else
      selected+=("$package")
    fi
  done

  [[ ${#selected[@]} -eq 0 ]] && return 0
  apt_update_once || return 0
  run_cmd_allow_failure \
    "$([[ "$UPGRADE_EXISTING" -eq 1 ]] && printf 'Update' || printf 'Install missing') apt packages from $(basename "$manifest")" \
    as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "${selected[@]}"
}

ensure_gh_apt_repo() {
  if [[ "$OS_FAMILY" != "linux" || "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if [[ "$UPGRADE_EXISTING" -eq 0 ]] && command_exists gh; then
    return 0
  fi
  if [[ "$UPGRADE_EXISTING" -eq 1 ]] && command_exists gh && ! dpkg_package_installed gh; then
    log_warn "Skipping GitHub CLI update; the active command is not apt-owned ($(command -v gh))."
    return 0
  fi

  if grep -Rq "cli.github.com/packages" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
    return 0
  fi

  if ! can_use_root; then
    log_warn "Skipping GitHub CLI apt repository setup; sudo/root unavailable."
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Configure GitHub CLI apt repository"
    return 0
  fi

  local keyring="/usr/share/keyrings/githubcli-archive-keyring.gpg"
  local source_file="/etc/apt/sources.list.d/github-cli.list"

  local tmp_dir downloaded source_staging
  tmp_dir="$(mktemp -d)"
  downloaded="$tmp_dir/githubcli-archive-keyring.gpg"
  source_staging="$tmp_dir/github-cli.list"
  printf 'deb [arch=%s signed-by=%s] https://cli.github.com/packages stable main\n' \
    "$(dpkg --print-architecture)" "$keyring" > "$source_staging"
  if ! download_nonempty_file https://cli.github.com/packages/githubcli-archive-keyring.gpg "$downloaded" ||
     ! atomic_install_file_as_root "$downloaded" "$keyring" 0644 ||
     ! atomic_install_file_as_root "$source_staging" "$source_file" 0644; then
    rm -rf "$tmp_dir"
    record_error "Configure GitHub CLI apt repository failed (empty or missing keyring)"
    return 0
  fi
  rm -rf "$tmp_dir"
  apt_update_after_repo_change "Update apt for GitHub CLI repository"
}

ensure_ngrok_apt_repo() {
  if [[ "$OS_FAMILY" != "linux" || "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if [[ "$UPGRADE_EXISTING" -eq 0 ]] && command_exists ngrok; then
    return 0
  fi
  if [[ "$UPGRADE_EXISTING" -eq 1 ]] && command_exists ngrok && ! dpkg_package_installed ngrok; then
    log_warn "Skipping ngrok update; the active command is not apt-owned ($(command -v ngrok))."
    return 0
  fi

  local keyring="/etc/apt/trusted.gpg.d/ngrok.asc"
  local source_file="/etc/apt/sources.list.d/ngrok.list"
  local source_line
  source_line="deb [arch=$(dpkg --print-architecture) signed-by=$keyring] https://ngrok-agent.s3.amazonaws.com bookworm main"

  if ! can_use_root; then
    log_warn "Skipping ngrok apt repository setup; sudo/root unavailable."
    return 0
  fi

  if [[ -s "$keyring" && -f "$source_file" ]] && grep -Fxq "$source_line" "$source_file"; then
    apt_update_once || return 0
    run_cmd_allow_failure "$([[ "$UPGRADE_EXISTING" -eq 1 ]] && printf 'Update' || printf 'Install') ngrok" \
      as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y ngrok
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Configure ngrok apt repository and install ngrok"
    return 0
  fi

  local tmp_dir downloaded source_staging
  tmp_dir="$(mktemp -d)"
  downloaded="$tmp_dir/ngrok.asc"
  source_staging="$tmp_dir/ngrok.list"
  printf '%s\n' "$source_line" > "$source_staging"
  if ! download_nonempty_file https://ngrok-agent.s3.amazonaws.com/ngrok.asc "$downloaded" ||
     ! atomic_install_file_as_root "$downloaded" "$keyring" 0644 ||
     ! atomic_install_file_as_root "$source_staging" "$source_file" 0644; then
    rm -rf "$tmp_dir"
    record_error "Configure ngrok apt repository failed (empty or missing keyring)"
    return 0
  fi
  rm -rf "$tmp_dir"
  apt_update_after_repo_change "Update apt for ngrok repository" || return 0
  run_cmd_allow_failure "Install ngrok" as_root apt-get install -y ngrok
}

ensure_cloudflared_apt_repo() {
  if [[ "$OS_FAMILY" != "linux" || "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if [[ "$UPGRADE_EXISTING" -eq 0 ]] && command_exists cloudflared; then
    return 0
  fi
  if [[ "$UPGRADE_EXISTING" -eq 1 ]] && command_exists cloudflared && ! dpkg_package_installed cloudflared; then
    log_warn "Skipping cloudflared update; the active command is not apt-owned ($(command -v cloudflared))."
    return 0
  fi

  local keyring="/usr/share/keyrings/cloudflare-main.gpg"
  local source_file="/etc/apt/sources.list.d/cloudflared.list"
  local source_line="deb [signed-by=$keyring] https://pkg.cloudflare.com/cloudflared any main"

  if ! can_use_root; then
    log_warn "Skipping Cloudflare package repository setup; sudo/root unavailable."
    return 0
  fi

  if [[ -s "$keyring" && -f "$source_file" ]] && grep -Fxq "$source_line" "$source_file"; then
    apt_update_once || return 0
    run_cmd_allow_failure "$([[ "$UPGRADE_EXISTING" -eq 1 ]] && printf 'Update' || printf 'Install') cloudflared" \
      as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y cloudflared
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Configure Cloudflare package repository and install cloudflared"
    return 0
  fi

  as_root mkdir -p --mode=0755 /usr/share/keyrings
  local tmp_dir downloaded source_staging
  tmp_dir="$(mktemp -d)"
  downloaded="$tmp_dir/cloudflare-main.gpg"
  source_staging="$tmp_dir/cloudflared.list"
  printf '%s\n' "$source_line" > "$source_staging"
  if ! download_nonempty_file https://pkg.cloudflare.com/cloudflare-main.gpg "$downloaded" ||
     ! atomic_install_file_as_root "$downloaded" "$keyring" 0644 ||
     ! atomic_install_file_as_root "$source_staging" "$source_file" 0644; then
    rm -rf "$tmp_dir"
    record_error "Configure Cloudflare package repository failed (empty or missing keyring)"
    return 0
  fi
  rm -rf "$tmp_dir"
  apt_update_after_repo_change "Update apt for Cloudflare repository" || return 0
  run_cmd_allow_failure "Install cloudflared" as_root apt-get install -y cloudflared
}

install_git_delta_linux() {
  if [[ "$OS_FAMILY" != "linux" || "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if command_exists delta && [[ "$UPGRADE_EXISTING" -eq 0 ]]; then
    return 0
  fi

  if [[ "$UPGRADE_EXISTING" -eq 1 ]] && command_exists delta; then
    if ! dpkg-query -W -f='${Status}' git-delta 2>/dev/null | grep -Fqx 'install ok installed'; then
      log_warn "Skipping git-delta update; current command is not dotfiles-owned ($(command -v delta))."
      return 0
    fi
  fi

  local package_name="git-delta"
  local repo="dandavison/delta"
  local pattern="git-delta_.*_${ARCH_GO}\\.deb$"
  local apt_has_package=0

  if command_exists apt-cache; then
    local apt_candidate
    apt_candidate="$(apt-cache policy "$package_name" 2>/dev/null | awk '/Candidate:/ {print $2; exit}')"
    if [[ -n "$apt_candidate" && "$apt_candidate" != "(none)" ]]; then
      apt_has_package=1
    fi
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    if [[ "$apt_has_package" -eq 1 ]]; then
      log_info "[dry-run] Install git-delta from apt"
    else
      log_info "[dry-run] Install git-delta from GitHub release (.deb)"
    fi
    return 0
  fi

  if ! can_use_root; then
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

  local status
  if download_nonempty_file "$url" "$package_path"; then
    status=0
  else
    status=$?
    rm -rf "$tmp_dir"
    record_error "Download git-delta release failed (exit $status)"
    return 0
  fi

  run_cmd_allow_failure "Install git-delta from GitHub release (.deb)" as_root apt-get install -y "$package_path"
  rm -rf "$tmp_dir"
}

run_remote_installer() {
  local description="$1" url="$2" interpreter="$3"
  shift 3
  local tmp_dir installer status
  tmp_dir="$(mktemp -d)"
  installer="$tmp_dir/install.sh"
  if download_nonempty_file "$url" "$installer"; then
    status=0
  else
    status=$?
    rm -rf "$tmp_dir"
    record_error "$description download failed (exit $status)"
    return 0
  fi

  log_info "$description"
  if [[ "$ASSUME_YES" -eq 1 || "$NO_INPUT" -eq 1 || ! -t 0 ]]; then
    if env NONINTERACTIVE=1 CI=1 "$interpreter" "$installer" "$@"; then
      status=0
    else
      status=$?
    fi
  else
    if "$interpreter" "$installer" "$@"; then
      status=0
    else
      status=$?
    fi
  fi
  rm -rf "$tmp_dir"
  if [[ $status -ne 0 ]]; then
    record_error "$description failed (exit $status)"
  fi
  return 0
}

install_remote_script_if_missing() {
  local command_name="$1" description="$2" url="$3" interpreter="$4"
  shift 4

  if [[ "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if command_exists "$command_name" && "$command_name" --version >/dev/null 2>&1; then
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] $description"
    return 0
  fi

  run_remote_installer "$description" "$url" "$interpreter" "$@"
}

install_linux_release_binaries() {
  local manifest="${1:-$DOTFILES_DIR/setup/packages/linux-binaries.full.txt}"

  if [[ "$OS_FAMILY" != "linux" || "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  while IFS='|' read -r tool repo pattern binary_name policy; do
    [[ -z "$tool" || "$tool" =~ ^# ]] && continue
    local target="$HOME/.local/bin/$binary_name"
    should_install_managed_command "$tool" "$target" || continue

    # Substitute architecture placeholders in the asset pattern
    pattern="${pattern//__UNAME_ARCH__/$ARCH_UNAME}"
    pattern="${pattern//__SHORT_ARCH__/$ARCH_SHORT}"
    pattern="${pattern//__GO_ARCH__/$ARCH_GO}"

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
    local status
    if download_nonempty_file "$url" "$archive_path"; then
      status=0
    else
      status=$?
      rm -rf "$tmp_dir"
      record_error "Download $tool release failed (exit $status)"
      continue
    fi

    case "$url" in
      *.tar.gz|*.tgz)
        if ! tar -xzf "$archive_path" -C "$tmp_dir"; then
          rm -rf "$tmp_dir"
          record_error "Extract $tool release failed"
          continue
        fi
        ;;
      *.zip)
        if ! unzip -q "$archive_path" -d "$tmp_dir"; then
          rm -rf "$tmp_dir"
          record_error "Extract $tool release failed"
          continue
        fi
        ;;
      *)
        chmod +x "$archive_path"
        if ! atomic_install_file "$archive_path" "$target" 0755; then
          record_error "Could not atomically install $tool at $target"
        fi
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

    if ! atomic_install_file "$extracted" "$target" 0755; then
      rm -rf "$tmp_dir"
      record_error "Could not atomically install $tool at $target"
      continue
    fi
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

  local status
  if download_nonempty_file "$archive_url" "$archive"; then
    status=0
  else
    status=$?
    rm -rf "$tmp_dir"
    record_error "Download Meslo Nerd Font failed (exit $status)"
    return 0
  fi

  if tar -xf "$archive" -C "$font_dir"; then
    status=0
  else
    status=$?
  fi
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

  if [[ "$OS_FAMILY" != "linux" || "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  should_install_managed_command greenclip "$target" || return 0

  # greenclip publishes a single x86_64 binary; there is no aarch64 release.
  if [[ "$ARCH_SHORT" != "x86_64" ]]; then
    record_error "greenclip has no upstream release for $ARCH_UNAME (x86_64 only)"
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Install greenclip"
    return 0
  fi

  local tmp_dir downloaded
  tmp_dir="$(mktemp -d)"
  downloaded="$tmp_dir/greenclip"
  local status
  if download_nonempty_file "$url" "$downloaded"; then
    status=0
  else
    status=$?
    rm -rf "$tmp_dir"
    record_error "Install greenclip failed (exit $status)"
    return 0
  fi
  if ! atomic_install_file "$downloaded" "$target" 0755; then
    rm -rf "$tmp_dir"
    record_error "Could not atomically install greenclip at $target"
    return 0
  fi
  rm -rf "$tmp_dir"
}

install_ghostty_snap() {
  if [[ "$OS_FAMILY" != "linux" || "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if command_exists ghostty; then
    if [[ "$UPGRADE_EXISTING" -eq 1 ]] && command_exists snap; then
      if can_use_root && snap list ghostty >/dev/null 2>&1; then
        run_cmd_allow_failure "Update Ghostty snap" as_root snap refresh ghostty
      else
        log_warn "Skipping Ghostty update; the active command is not an installed snap or root is unavailable."
      fi
    fi
    return 0
  fi
  command_exists snap || return 0
  can_use_root || return 0

  run_cmd_allow_failure "Install Ghostty snap" as_root snap install ghostty --classic
}
