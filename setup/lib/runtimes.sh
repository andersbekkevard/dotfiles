_DOTFILES_RUNTIME_PATHS="$DOTFILES_DIR/shell/.local/lib/dotfiles/runtime-paths.sh"
# shellcheck disable=SC1090
source "$_DOTFILES_RUNTIME_PATHS"
unset _DOTFILES_RUNTIME_PATHS

ensure_fnm_available_now() {
  if command_exists fnm; then
    return 0
  fi

  local fnm_bin=""
  if [[ -x "$HOME/.local/share/fnm/fnm" ]]; then
    fnm_bin="$HOME/.local/share/fnm/fnm"
  elif [[ -x "$HOME/.fnm/fnm" ]]; then
    fnm_bin="$HOME/.fnm/fnm"
  fi

  if [[ -n "$fnm_bin" ]]; then
    export PATH="$(dirname "$fnm_bin"):$PATH"
    eval "$("$fnm_bin" env --use-on-cd --shell bash)"
  fi
}

ensure_cargo_available_now() {
  if command_exists cargo; then
    return 0
  fi

  if [[ -f "$HOME/.cargo/env" ]]; then
    # shellcheck disable=SC1090
    source "$HOME/.cargo/env"
  fi
}

ensure_pnpm_global_bin_available_now() {
  command_exists pnpm || return 0

  local configured_pnpm_home pnpm_home
  pnpm_home="${PNPM_HOME:-$(dotfiles_default_pnpm_home)}"
  configured_pnpm_home="$(pnpm config get global-bin-dir 2>/dev/null || true)"

  if [[ "$configured_pnpm_home" != "$pnpm_home" ]]; then
    run_cmd_allow_failure \
      "Configure pnpm global bin directory at $pnpm_home" \
      pnpm config set global-bin-dir "$pnpm_home"
  fi

  if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p "$pnpm_home"
  fi
  export PNPM_HOME="$pnpm_home"
  export PATH="$PNPM_HOME:$PATH"
}

install_fnm_node_stack() {
  install_script_if_missing fnm "Install fnm" "curl -fsSL https://fnm.vercel.app/install | bash"
  ensure_fnm_available_now

  if [[ "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if ! command_exists fnm; then
    if [[ "$DRY_RUN" -eq 0 ]]; then
      record_error "fnm not available after install; node/pnpm stack skipped"
    fi
    return 0
  fi

  run_cmd_allow_failure "Install Node.js LTS with fnm" fnm install --lts
  run_cmd_allow_failure "Select Node.js LTS with fnm" fnm default lts-latest

  # Re-evaluate fnm env so node/npm/corepack land on PATH for the rest of setup
  eval "$(fnm env --use-on-cd --shell bash 2>/dev/null)" || true

  if command_exists corepack; then
    run_cmd_allow_failure "Enable corepack" corepack enable
    run_cmd_allow_failure "Activate pnpm" corepack prepare pnpm@latest --activate
  elif command_exists npm; then
    run_cmd_allow_failure "Install pnpm via npm (corepack unavailable)" npm install -g pnpm
  else
    record_error "Neither corepack nor npm available; pnpm not installed"
  fi

  ensure_pnpm_global_bin_available_now

  # Final check: node and pnpm should be reachable now
  if ! command_exists node; then
    record_error "node not on PATH after fnm install"
  fi
  if ! command_exists pnpm; then
    record_error "pnpm not on PATH after activation"
  fi
}

install_typescript_language_tools() {
  if [[ "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if command_exists pnpm; then
    run_cmd_allow_failure \
      "Install TypeScript language tools with pnpm" \
      pnpm add -g typescript typescript-language-server
  elif command_exists npm; then
    run_cmd_allow_failure \
      "Install TypeScript language tools with npm (pnpm unavailable)" \
      npm install -g typescript typescript-language-server
  elif [[ "$DRY_RUN" -eq 0 ]]; then
    record_error "Neither pnpm nor npm available; TypeScript language tools not installed"
    return 0
  fi
}

install_codex_cli() {
  if [[ "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Install Codex CLI with the official standalone installer"
    return 0
  fi

  if ! command_exists curl; then
    record_error "curl not available; Codex CLI not installed"
    return 0
  fi

  local tmp_dir installer status
  tmp_dir="$(mktemp -d)"
  installer="$tmp_dir/install.sh"

  curl -fsSL https://chatgpt.com/codex/install.sh -o "$installer"
  status=$?
  if [[ $status -ne 0 || ! -s "$installer" ]]; then
    rm -rf "$tmp_dir"
    record_error "Download Codex CLI installer failed (exit $status)"
    return 0
  fi

  log_info "Install Codex CLI with the official standalone installer"
  PATH="$HOME/.local/bin:$PATH" CODEX_NON_INTERACTIVE=1 sh "$installer"
  status=$?
  rm -rf "$tmp_dir"
  if [[ $status -ne 0 ]]; then
    record_error "Install Codex CLI failed (exit $status)"
  fi
}

sha256_file() {
  if command_exists sha256sum; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

sha256_stdin() {
  if command_exists sha256sum; then
    sha256sum | awk '{print $1}'
  else
    shasum -a 256 | awk '{print $1}'
  fi
}

ensure_cliproxyapi_config() {
  local config_dir config_file env_file api_key previous_umask
  config_dir="${XDG_CONFIG_HOME:-"$HOME/.config"}/cliproxyapi"
  config_file="$config_dir/config.yaml"
  env_file="$config_dir/claudex.env"

  if [[ -e "$config_file" || -e "$env_file" ]]; then
    if [[ -r "$config_file" && -r "$env_file" ]]; then
      return 0
    fi
    record_error "CLIProxyAPI configuration is incomplete under $config_dir"
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Create localhost-only CLIProxyAPI configuration in $config_dir"
    return 0
  fi

  # The private umask covers the window between creating the config files and
  # chmod'ing them. It is process-global, so it must be restored on every exit
  # path; otherwise the rest of the run (pnpm home, global installs, stow) keeps
  # creating 0700 directories.
  previous_umask="$(umask)"
  umask 077
  mkdir -p "$config_dir"
  api_key="$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')"
  if [[ -z "$api_key" ]]; then
    umask "$previous_umask"
    record_error "Could not generate CLIProxyAPI local API key"
    return 0
  fi

  cat >"$config_file" <<EOF
host: "127.0.0.1"
port: 8317
tls:
  enable: false
remote-management:
  allow-remote: false
  secret-key: ""
  disable-control-panel: true
auth-dir: "~/.cli-proxy-api"
api-keys:
  - "$api_key"
debug: false
EOF
  cat >"$env_file" <<EOF
CLIPROXY_BASE_URL='http://127.0.0.1:8317'
CLIPROXY_API_KEY='$api_key'
EOF
  umask "$previous_umask"
  chmod 0600 "$config_file" "$env_file"
  log_info "Created localhost-only CLIProxyAPI configuration in $config_dir"
}

install_cliproxyapi() {
  ensure_cliproxyapi_config

  if [[ "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Install latest CLIProxyAPI release for $OS_FAMILY/$ARCH_GO"
    return 0
  fi

  if ! command_exists curl || ! command_exists jq; then
    record_error "curl and jq are required to install CLIProxyAPI"
    return 0
  fi

  local release_json version platform release_arch archive_name download_url
  local tmp_dir archive checksums expected actual install_dir status
  release_json="$(curl -fsSL https://api.github.com/repos/router-for-me/CLIProxyAPI/releases/latest)"
  status=$?
  if [[ $status -ne 0 || -z "$release_json" ]]; then
    record_error "Could not resolve latest CLIProxyAPI release"
    return 0
  fi

  version="$(jq -r '.tag_name // empty' <<<"$release_json")"
  case "$OS_FAMILY" in
    darwin) platform="darwin" ;;
    linux) platform="linux" ;;
    *)
      record_error "CLIProxyAPI is unsupported on $OS_FAMILY"
      return 0
      ;;
  esac
  case "$ARCH_GO" in
    amd64) release_arch="amd64" ;;
    arm64) release_arch="aarch64" ;;
    *)
      record_error "CLIProxyAPI is unsupported on architecture $ARCH_GO"
      return 0
      ;;
  esac
  archive_name="CLIProxyAPI_${version#v}_${platform}_${release_arch}.tar.gz"
  download_url="$(jq -r --arg name "$archive_name" \
    '.assets[] | select(.name == $name) | .browser_download_url' <<<"$release_json")"
  if [[ -z "$version" || -z "$download_url" ]]; then
    record_error "No CLIProxyAPI release asset for $platform/$release_arch"
    return 0
  fi

  install_dir="$HOME/.local/share/cliproxyapi/$version"
  if [[ -x "$install_dir/cli-proxy-api" ]]; then
    mkdir -p "$HOME/.local/bin"
    ln -sfn "$install_dir/cli-proxy-api" "$HOME/.local/bin/cli-proxy-api"
    return 0
  fi

  tmp_dir="$(mktemp -d)"
  archive="$tmp_dir/$archive_name"
  checksums="$tmp_dir/checksums.txt"
  curl -fsSL "$download_url" -o "$archive"
  status=$?
  if [[ $status -ne 0 || ! -s "$archive" ]]; then
    rm -rf "$tmp_dir"
    record_error "Download CLIProxyAPI $version failed (exit $status)"
    return 0
  fi
  curl -fsSL "https://github.com/router-for-me/CLIProxyAPI/releases/download/$version/checksums.txt" \
    -o "$checksums"
  status=$?
  expected="$(awk -v name="$archive_name" '$2 == name {print $1}' "$checksums" 2>/dev/null)"
  actual="$(sha256_file "$archive")"
  if [[ $status -ne 0 || -z "$expected" || "$actual" != "$expected" ]]; then
    rm -rf "$tmp_dir"
    record_error "CLIProxyAPI checksum verification failed for $archive_name"
    return 0
  fi

  mkdir -p "$install_dir" "$HOME/.local/bin"
  tar -xzf "$archive" -C "$install_dir" cli-proxy-api
  status=$?
  rm -rf "$tmp_dir"
  if [[ $status -ne 0 || ! -x "$install_dir/cli-proxy-api" ]]; then
    record_error "Install CLIProxyAPI $version failed (exit $status)"
    return 0
  fi
  ln -sfn "$install_dir/cli-proxy-api" "$HOME/.local/bin/cli-proxy-api"
  log_info "Installed CLIProxyAPI ${version#v}"
}

install_shared_runtimes() {
  if [[ "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  install_script_if_missing uv "Install uv" "curl -LsSf https://astral.sh/uv/install.sh | sh"
  install_script_if_missing rustup "Install rustup" "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"
  install_script_if_missing bun "Install bun" "curl -fsSL https://bun.sh/install | bash"
  install_script_if_missing zoxide "Install zoxide" "curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash"
  ensure_cargo_available_now
  if command_exists cargo; then
    run_cmd_allow_failure "Install tree-sitter CLI with cargo" cargo install tree-sitter-cli --locked
  elif [[ "$DRY_RUN" -eq 0 ]]; then
    record_error "cargo not on PATH after rustup install; tree-sitter CLI skipped"
  fi
  install_fnm_node_stack
  install_codex_cli
  install_cliproxyapi
  install_typescript_language_tools
}

install_go_linux() {
  if [[ "$OS_FAMILY" != "linux" || "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if command_exists go; then
    return 0
  fi

  if ! can_use_root; then
    log_warn "Skipping Go install; sudo/root unavailable."
    return 0
  fi

  # Resolve the version only for real runs; a dry run must not depend on the
  # network or record an error when go.dev is unreachable.
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Install latest stable Go (linux-${ARCH_GO})"
    return 0
  fi

  local version
  version="$(curl -fsSL 'https://go.dev/dl/?mode=json' | jq -r '.[0].version' | sed 's/^go//')"
  if [[ -z "$version" ]]; then
    record_error "Could not determine latest stable Go version"
    return 0
  fi

  local archive="go${version}.linux-${ARCH_GO}.tar.gz"
  local url="https://go.dev/dl/${archive}"

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
