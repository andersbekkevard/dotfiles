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

install_shared_runtimes() {
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
  install_typescript_language_tools
}

install_go_linux() {
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

  local version
  version="$(curl -fsSL 'https://go.dev/dl/?mode=json' | jq -r '.[0].version' | sed 's/^go//')"
  if [[ -z "$version" ]]; then
    record_error "Could not determine latest stable Go version"
    return 0
  fi

  local archive="go${version}.linux-${ARCH_GO}.tar.gz"
  local url="https://go.dev/dl/${archive}"

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
