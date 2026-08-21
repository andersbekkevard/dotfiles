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
  install_remote_script_if_missing \
    fnm "Install fnm" https://fnm.vercel.app/install bash
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

  local update_node=0
  if ! command_exists node; then
    update_node=1
  elif [[ "$UPGRADE_EXISTING" -eq 1 ]]; then
    case "$(resolve_path_chain "$(command -v node)" 2>/dev/null || command -v node)" in
      "$HOME/.local/share/fnm/"*|"$HOME/.fnm/"*) update_node=1 ;;
      *) log_warn "Skipping Node.js update; the active command is not fnm-owned ($(command -v node))." ;;
    esac
  fi
  if [[ "$update_node" -eq 1 ]]; then
    run_cmd_allow_failure "Install Node.js LTS with fnm" fnm install --lts --progress never
    run_cmd_allow_failure "Select Node.js LTS with fnm" fnm default lts-latest
  fi

  # Re-evaluate fnm env so node/npm/corepack land on PATH for the rest of setup
  eval "$(fnm env --use-on-cd --shell bash 2>/dev/null)" || true

  local update_pnpm=0 pnpm_home
  pnpm_home="${PNPM_HOME:-$(dotfiles_default_pnpm_home)}"
  if ! command_exists pnpm; then
    update_pnpm=1
  elif [[ "$UPGRADE_EXISTING" -eq 1 ]]; then
    case "$(resolve_path_chain "$(command -v pnpm)" 2>/dev/null || command -v pnpm)" in
      "$HOME/.local/share/fnm/"*|"$HOME/.fnm/"*|"$pnpm_home/"*) update_pnpm=1 ;;
      *) log_warn "Skipping pnpm update; the active command is not fnm/pnpm-home-owned ($(command -v pnpm))." ;;
    esac
  fi
  if [[ "$update_pnpm" -eq 1 ]]; then
    if command_exists corepack; then
      run_cmd_allow_failure "Enable corepack" corepack enable
      run_cmd_allow_failure "Activate pnpm" corepack prepare pnpm@latest --activate
    elif command_exists npm; then
      run_cmd_allow_failure "Install pnpm via npm (corepack unavailable)" npm install -g pnpm
    else
      record_error "Neither corepack nor npm available; pnpm not installed"
    fi
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

  if [[ "$UPGRADE_EXISTING" -eq 0 ]] && command_exists typescript-language-server && command_exists tsc; then
    return 0
  fi

  if [[ "$UPGRADE_EXISTING" -eq 1 ]] && command_exists typescript-language-server; then
    local tls_path pnpm_home
    tls_path="$(resolve_path_chain "$(command -v typescript-language-server)" 2>/dev/null || command -v typescript-language-server)"
    pnpm_home="${PNPM_HOME:-$(dotfiles_default_pnpm_home)}"
    case "$tls_path" in
      "$pnpm_home/"*) ;;
      *)
        log_warn "Skipping TypeScript language tools update; the active server is not pnpm-owned ($(command -v typescript-language-server))."
        return 0
        ;;
    esac
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

  if [[ "$UPGRADE_EXISTING" -eq 0 ]] && command_exists codex && codex --version >/dev/null 2>&1; then
    return 0
  fi
  if [[ "$UPGRADE_EXISTING" -eq 1 ]] && command_exists codex; then
    case "$(resolve_path_chain "$(command -v codex)" 2>/dev/null || command -v codex)" in
      "$HOME/.codex/packages/standalone/"*) ;;
      *)
        log_warn "Skipping Codex CLI update; the active command is not standalone-installer-owned ($(command -v codex))."
        return 0
        ;;
    esac
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

  if curl -fsSL https://chatgpt.com/codex/install.sh -o "$installer" && [[ -s "$installer" ]]; then
    status=0
  else
    status=$?
    rm -rf "$tmp_dir"
    record_error "Download Codex CLI installer failed (exit $status)"
    return 0
  fi

  log_info "Install Codex CLI with the official standalone installer"
  if PATH="$HOME/.local/bin:$PATH" CODEX_NON_INTERACTIVE=1 NONINTERACTIVE=1 CI=1 sh "$installer"; then
    status=0
  else
    status=$?
  fi
  rm -rf "$tmp_dir"
  if [[ $status -ne 0 ]]; then
    record_error "Install Codex CLI failed (exit $status)"
  fi
}

install_claude_cli() {
  if [[ "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if [[ "$UPGRADE_EXISTING" -eq 0 ]] && command_exists claude && claude --version >/dev/null 2>&1; then
    return 0
  fi
  if [[ "$UPGRADE_EXISTING" -eq 1 ]] && command_exists claude; then
    case "$(resolve_path_chain "$(command -v claude)" 2>/dev/null || command -v claude)" in
      "$HOME/.local/share/claude/"*) ;;
      *)
        log_warn "Skipping Claude Code update; the active command is not standalone-installer-owned ($(command -v claude))."
        return 0
        ;;
    esac
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Install Claude Code with the official standalone installer"
    return 0
  fi

  if ! command_exists curl; then
    record_error "curl not available; Claude Code not installed"
    return 0
  fi

  local tmp_dir installer status
  tmp_dir="$(mktemp -d)"
  installer="$tmp_dir/install.sh"

  if curl -fsSL https://claude.ai/install.sh -o "$installer" && [[ -s "$installer" ]]; then
    status=0
  else
    status=$?
    rm -rf "$tmp_dir"
    record_error "Download Claude Code installer failed (exit $status)"
    return 0
  fi

  log_info "Install Claude Code with the official standalone installer"
  if [[ "$ASSUME_YES" -eq 1 || "$NO_INPUT" -eq 1 || ! -t 0 ]]; then
    if PATH="$HOME/.local/bin:$PATH" NONINTERACTIVE=1 CI=1 bash "$installer"; then
      status=0
    else
      status=$?
    fi
  else
    if PATH="$HOME/.local/bin:$PATH" bash "$installer"; then
      status=0
    else
      status=$?
    fi
  fi
  rm -rf "$tmp_dir"
  if [[ $status -ne 0 ]]; then
    record_error "Install Claude Code failed (exit $status)"
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

  if [[ "$UPGRADE_EXISTING" -eq 0 ]] && command_exists cli-proxy-api; then
    return 0
  fi
  if [[ "$UPGRADE_EXISTING" -eq 1 ]] && command_exists cli-proxy-api; then
    case "$(resolve_path_chain "$(command -v cli-proxy-api)" 2>/dev/null || command -v cli-proxy-api)" in
      "$HOME/.local/share/cliproxyapi/"*) ;;
      *)
        log_warn "Skipping CLIProxyAPI update; the active command is not dotfiles-release-owned ($(command -v cli-proxy-api))."
        return 0
        ;;
    esac
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
  local tmp_dir archive checksums expected actual install_dir staging_dir previous_dir status
  if release_json="$(curl -fsSL https://api.github.com/repos/router-for-me/CLIProxyAPI/releases/latest)" &&
     [[ -n "$release_json" ]]; then
    status=0
  else
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
  if curl -fsSL "$download_url" -o "$archive" && [[ -s "$archive" ]]; then
    status=0
  else
    status=$?
    rm -rf "$tmp_dir"
    record_error "Download CLIProxyAPI $version failed (exit $status)"
    return 0
  fi
  if curl -fsSL "https://github.com/router-for-me/CLIProxyAPI/releases/download/$version/checksums.txt" \
    -o "$checksums" && [[ -s "$checksums" ]]; then
    status=0
  else
    status=$?
  fi
  expected="$(awk -v name="$archive_name" '$2 == name {print $1}' "$checksums" 2>/dev/null)"
  actual="$(sha256_file "$archive")"
  if [[ $status -ne 0 || -z "$expected" || "$actual" != "$expected" ]]; then
    rm -rf "$tmp_dir"
    record_error "CLIProxyAPI checksum verification failed for $archive_name"
    return 0
  fi

  mkdir -p "$(dirname "$install_dir")" "$HOME/.local/bin"
  staging_dir="$(mktemp -d "$(dirname "$install_dir")/.cliproxyapi.tmp.XXXXXX")"
  if tar -xzf "$archive" -C "$staging_dir" cli-proxy-api; then
    status=0
  else
    status=$?
  fi
  rm -rf "$tmp_dir"
  if [[ $status -ne 0 || ! -x "$staging_dir/cli-proxy-api" ]] ||
     ! "$staging_dir/cli-proxy-api" --version >/dev/null 2>&1; then
    rm -rf "$staging_dir"
    record_error "Install CLIProxyAPI $version failed (exit $status)"
    return 0
  fi
  previous_dir="$(dirname "$install_dir")/.cliproxyapi.previous.$RUN_ID"
  rm -rf "$previous_dir"
  if [[ -e "$install_dir" ]] && ! mv "$install_dir" "$previous_dir"; then
    rm -rf "$staging_dir"
    record_error "Could not stage the existing CLIProxyAPI $version installation"
    return 0
  fi
  if ! mv "$staging_dir" "$install_dir"; then
    [[ -e "$previous_dir" ]] && mv "$previous_dir" "$install_dir"
    record_error "Could not activate CLIProxyAPI $version"
    return 0
  fi
  rm -rf "$previous_dir"
  ln -sfn "$install_dir/cli-proxy-api" "$HOME/.local/bin/cli-proxy-api"
  log_info "Installed CLIProxyAPI ${version#v}"
}

install_shared_runtimes() {
  if [[ "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  install_remote_script_if_missing uv "Install uv" https://astral.sh/uv/install.sh sh
  install_remote_script_if_missing rustup "Install rustup" https://sh.rustup.rs sh -y
  install_remote_script_if_missing bun "Install bun" https://bun.sh/install bash
  install_remote_script_if_missing \
    zoxide "Install zoxide" https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh bash

  if [[ "$UPGRADE_EXISTING" -eq 1 ]]; then
    case "$(resolve_path_chain "$(command -v fnm 2>/dev/null || true)" 2>/dev/null || true)" in
      "$HOME/.local/share/fnm/"*|"$HOME/.fnm/"*)
        if [[ "$DRY_RUN" -eq 1 ]]; then
          log_info "[dry-run] Update fnm"
        else
          run_remote_installer "Update fnm" https://fnm.vercel.app/install bash
          ensure_fnm_available_now
        fi
        ;;
    esac
    case "$(resolve_path_chain "$(command -v uv 2>/dev/null || true)" 2>/dev/null || true)" in
      "$HOME/.local/bin/"*|"$HOME/.local/share/uv/"*) run_cmd_allow_failure "Update uv" uv self update ;;
    esac
    case "$(resolve_path_chain "$(command -v rustup 2>/dev/null || true)" 2>/dev/null || true)" in
      "$HOME/.cargo/"*) run_cmd_allow_failure "Update Rust toolchains" rustup update ;;
    esac
    case "$(resolve_path_chain "$(command -v bun 2>/dev/null || true)" 2>/dev/null || true)" in
      "$HOME/.bun/"*) run_cmd_allow_failure "Update Bun" bun upgrade ;;
    esac
  fi

  ensure_cargo_available_now
  if command_exists cargo && ! command_exists tree-sitter; then
    run_cmd_allow_failure "Install tree-sitter CLI with cargo" cargo install tree-sitter-cli --locked
  elif command_exists cargo && [[ "$UPGRADE_EXISTING" -eq 1 ]]; then
    case "$(resolve_path_chain "$(command -v tree-sitter)" 2>/dev/null || command -v tree-sitter)" in
      "$HOME/.cargo/"*) run_cmd_allow_failure "Update tree-sitter CLI with cargo" cargo install tree-sitter-cli --locked ;;
      *) log_warn "Skipping tree-sitter update; the active command is not Cargo-owned ($(command -v tree-sitter))." ;;
    esac
  elif [[ "$DRY_RUN" -eq 0 ]]; then
    record_error "cargo not on PATH after rustup install; tree-sitter CLI skipped"
  fi
  install_fnm_node_stack
  install_claude_cli
  install_codex_cli
  install_cliproxyapi
  install_typescript_language_tools
}

install_go_linux() {
  if [[ "$OS_FAMILY" != "linux" || "$SKIP_INSTALL" -eq 1 ]]; then
    return 0
  fi

  if command_exists go && [[ "$UPGRADE_EXISTING" -eq 0 ]]; then
    return 0
  fi

  if [[ "$UPGRADE_EXISTING" -eq 1 ]] && command_exists go &&
     [[ "$(command -v go)" != "/usr/local/go/bin/go" ]]; then
    log_warn "Skipping Go update; current command is not dotfiles-owned ($(command -v go))."
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
  if ! version="$(curl -fsSL 'https://go.dev/dl/?mode=json' | jq -r '.[0].version' | sed 's/^go//')"; then
    version=""
  fi
  if [[ -z "$version" ]]; then
    record_error "Could not determine latest stable Go version"
    return 0
  fi

  local archive="go${version}.linux-${ARCH_GO}.tar.gz"
  local url="https://go.dev/dl/${archive}"

  local tmp_dir staging_dir previous_dir
  tmp_dir="$(mktemp -d)"
  local status
  if curl -fsSL "$url" -o "$tmp_dir/$archive" && [[ -s "$tmp_dir/$archive" ]]; then
    status=0
  else
    status=$?
    rm -rf "$tmp_dir"
    record_error "Download Go ${version} failed (exit $status)"
    return 0
  fi

  staging_dir="/usr/local/.go.dotfiles-stage-$RUN_ID-$$"
  previous_dir="/usr/local/.go.dotfiles-previous-$RUN_ID-$$"
  as_root rm -rf "$staging_dir" "$previous_dir"
  as_root mkdir -p "$staging_dir"
  if as_root tar -C "$staging_dir" -xzf "$tmp_dir/$archive" --strip-components=1; then
    status=0
  else
    status=$?
  fi
  rm -rf "$tmp_dir"
  if [[ $status -ne 0 ]] || ! as_root "$staging_dir/bin/go" version >/dev/null 2>&1; then
    as_root rm -rf "$staging_dir"
    record_error "Install Go ${version} failed (exit $status)"
    return 0
  fi
  if [[ -e /usr/local/go ]] && ! as_root mv /usr/local/go "$previous_dir"; then
    as_root rm -rf "$staging_dir"
    record_error "Could not stage the existing Go installation"
    return 0
  fi
  if ! as_root mv "$staging_dir" /usr/local/go; then
    [[ -e "$previous_dir" ]] && as_root mv "$previous_dir" /usr/local/go
    record_error "Could not activate Go ${version}"
    return 0
  fi
  as_root rm -rf "$previous_dir"
  return 0
}
