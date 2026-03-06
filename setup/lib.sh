#!/usr/bin/env bash

COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

RUN_ID=""
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OS_FAMILY=""
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

init_runtime() {
  RUN_ID="$(date +%Y%m%d-%H%M%S)"
  detect_os
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
  printf 'Re-run ./init.sh to resume.\n'
  exit 130
}

configure_interrupt_trap() {
  trap handle_interrupt INT TERM
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
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
        RUN_LAYER_ONLY="$1"
        ;;
      --stow)
        shift
        STOW_ONLY_PACKAGE="$1"
        ;;
      --verify)
        shift
        if [[ $# -gt 0 && "$1" != --* ]]; then
          VERIFY_PROFILE="$1"
        else
          VERIFY_PROFILE="auto"
          continue
        fi
        ;;
      minimal|full|macos|linux-headless|linux-desktop|auto)
        REQUESTED_PROFILE="$1"
        ;;
      *)
        record_error "Unknown argument: $1"
        ;;
    esac
    shift
  done

  if [[ -n "$VERIFY_PROFILE" && "$VERIFY_PROFILE" == "auto" ]]; then
    VERIFY_PROFILE="$(resolve_profile auto)"
  fi
}

has_display_server() {
  if [[ "$OS_FAMILY" != "linux" ]]; then
    return 1
  fi

  dpkg -s xserver-xorg >/dev/null 2>&1 && return 0
  systemctl list-units --type=target 2>/dev/null | grep -q graphical && return 0
  [[ -n "${DISPLAY:-}" ]] && return 0
  [[ -n "${WAYLAND_DISPLAY:-}" ]] && return 0
  return 1
}

resolve_profile() {
  local requested="${1:-auto}"

  if [[ "$requested" != "auto" && -n "$requested" ]]; then
    printf '%s\n' "$requested"
    return 0
  fi

  case "$OS_FAMILY" in
    darwin)
      printf '%s\n' "macos"
      ;;
    linux)
      if has_display_server; then
        printf '%s\n' "linux-desktop"
      else
        printf '%s\n' "linux-headless"
      fi
      ;;
    *)
      printf '%s\n' "minimal"
      ;;
  esac
}

profile_layers() {
  case "$1" in
    minimal)
      printf '%s\n' minimal
      ;;
    full)
      printf '%s\n' minimal full
      ;;
    macos)
      printf '%s\n' minimal full macos
      ;;
    linux-headless)
      printf '%s\n' minimal full linux-headless
      ;;
    linux-desktop)
      printf '%s\n' minimal full linux-headless linux-desktop
      ;;
  esac
}

profile_packages() {
  local profile="$1"

  case "$profile" in
    minimal)
      printf '%s\n' shell git nvim tmux scripts fd btop
      ;;
    full)
      printf '%s\n' shell git nvim tmux scripts fd btop lazygit wt
      ;;
    macos)
      printf '%s\n' shell git nvim tmux scripts fd btop lazygit wt terminals macos
      ;;
    linux-headless)
      printf '%s\n' shell git nvim tmux scripts fd btop lazygit wt
      ;;
    linux-desktop)
      printf '%s\n' shell git nvim tmux scripts fd btop lazygit wt terminals linux-desktop
      ;;
  esac
}

profile_commands() {
  case "$1" in
    minimal)
      printf '%s\n' git zsh stow tmux fzf rg fd bat zoxide nvim htop btop jq
      ;;
    full)
      printf '%s\n' git zsh stow tmux fzf rg fd bat zoxide nvim htop btop jq fnm node pnpm uv cargo rustc bun lazygit gh yazi git-crypt
      ;;
    macos)
      printf '%s\n' git zsh stow tmux fzf rg fd bat zoxide nvim htop btop jq fnm node pnpm uv cargo rustc bun lazygit gh yazi git-crypt brew
      ;;
    linux-headless)
      printf '%s\n' git zsh stow tmux fzf rg fd bat zoxide nvim htop btop jq fnm node pnpm uv cargo rustc bun lazygit gh yazi git-crypt
      ;;
    linux-desktop)
      printf '%s\n' git zsh stow tmux fzf rg fd bat zoxide nvim htop btop jq fnm node pnpm uv cargo rustc bun lazygit gh yazi git-crypt i3 rofi polybar alacritty dex feh greenclip i3lock killall maim nm-applet pactl picom setxkbmap xclip xdotool xinput xrandr xss-lock xcape
      ;;
  esac
}

print_profile_banner() {
  local profile="$1"
  shift
  local layers=("$@")
  printf 'dotfiles init\n'
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

brew_bundle() {
  local brewfile="$1"
  if [[ "$SKIP_INSTALL" -eq 1 ]]; then
    log_info "Skipping Brewfile $brewfile"
    return 0
  fi
  run_cmd_allow_failure "Apply Brewfile $(basename "$brewfile")" brew bundle --file "$brewfile" --no-lock
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

ensure_fnm_available_now() {
  if command_exists fnm; then
    return 0
  fi

  if [[ -x "$HOME/.local/share/fnm/fnm" ]]; then
    eval "$("$HOME/.local/share/fnm/fnm" env --use-on-cd --shell bash)"
  fi
}

install_fnm_node_stack() {
  install_script_if_missing fnm "Install fnm" "curl -fsSL https://fnm.vercel.app/install | bash"
  ensure_fnm_available_now

  if [[ "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if command_exists fnm; then
    run_cmd_allow_failure "Install Node.js LTS with fnm" fnm install --lts
    run_cmd_allow_failure "Select Node.js LTS with fnm" fnm default lts-latest
    if command_exists corepack; then
      run_cmd_allow_failure "Enable corepack" corepack enable
      run_cmd_allow_failure "Activate pnpm" corepack prepare pnpm@latest --activate
    fi
  fi
}

install_shared_runtimes() {
  install_script_if_missing uv "Install uv" "curl -LsSf https://astral.sh/uv/install.sh | sh"
  install_script_if_missing rustup "Install rustup" "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"
  install_script_if_missing bun "Install bun" "curl -fsSL https://bun.sh/install | bash"
  install_script_if_missing zoxide "Install zoxide" "curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash"
  install_fnm_node_stack
}

install_go_linux() {
  local version="1.24.1"
  local archive="go${version}.linux-amd64.tar.gz"
  local url="https://go.dev/dl/${archive}"

  if [[ "$OS_FAMILY" != "linux" || "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if command_exists go; then
    return 0
  fi

  if ! as_root true >/dev/null 2>&1; then
    log_warn "Skipping Go install; sudo/root unavailable."
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Install Go ${version}"
    return 0
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmp_dir/$archive"
  local status=$?
  if [[ $status -ne 0 ]]; then
    rm -rf "$tmp_dir"
    record_error "Download Go ${version} failed (exit $status)"
    return 0
  fi

  as_root rm -rf /usr/local/go
  as_root tar -C /usr/local -xzf "$tmp_dir/$archive"
  status=$?
  rm -rf "$tmp_dir"
  if [[ $status -ne 0 ]]; then
    record_error "Install Go ${version} failed (exit $status)"
  fi
  return 0
}

github_latest_asset_url() {
  local repo="$1"
  local pattern="$2"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" | jq -r --arg pattern "$pattern" '.assets[] | select(.name | test($pattern)) | .browser_download_url' | head -n1
}

install_linux_release_binaries() {
  local manifest="$DOTFILES_DIR/setup/packages/linux-binaries.full.txt"

  if [[ "$OS_FAMILY" != "linux" || "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  while IFS='|' read -r tool repo pattern binary_name; do
    [[ -z "$tool" || "$tool" =~ ^# ]] && continue
    command_exists "$tool" && continue

    if [[ "$DRY_RUN" -eq 1 ]]; then
      log_info "[dry-run] Install $tool from GitHub release"
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

  chsh -s "$zsh_path" >/dev/null 2>&1
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

    for candidate_version in current legacy; do
      for candidate_profile in minimal full macos linux-headless linux-desktop; do
        if [[ "$candidate_version" == "current" ]]; then
          if diff -q "$candidate" <(render_current_local_overrides "$candidate_profile") >/dev/null 2>&1; then
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

  if [[ "$managed_version" == "legacy" || ( "$managed_version" == "current" && "$managed_profile" != "$profile" ) ]]; then
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
    if ! command_exists "$cmd"; then
      printf 'missing command: %s\n' "$cmd"
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

run_layer() {
  local layer="$1"

  case "$layer" in
    minimal)
      run_minimal_layer
      ;;
    full)
      run_full_layer
      ;;
    linux-headless)
      run_linux_headless_layer
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
