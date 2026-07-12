#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_eq() {
  [[ "$1" == "$2" ]] || fail "expected '$2', got '$1'"
}

test_runtime_path_defaults() {
  (
    HOME=/tmp/personal-edge-darwin
    uname() { [[ "${1:-}" == "-s" ]] && printf 'Darwin\n'; }
    # shellcheck source=../../shell/.local/lib/dotfiles/runtime-paths.sh
    source "$REPO_ROOT/shell/.local/lib/dotfiles/runtime-paths.sh"
    assert_eq "$(dotfiles_default_pnpm_home)" "$HOME/Library/pnpm"
  )

  (
    HOME=/tmp/personal-edge-linux
    uname() { [[ "${1:-}" == "-s" ]] && printf 'Linux\n'; }
    # shellcheck source=../../shell/.local/lib/dotfiles/runtime-paths.sh
    source "$REPO_ROOT/shell/.local/lib/dotfiles/runtime-paths.sh"
    assert_eq "$(dotfiles_default_pnpm_home)" "$HOME/.local/share/pnpm"
  )
}

test_profile_contract() {
  local fake_home
  fake_home="$(mktemp -d)"
  mkdir -p \
    "$fake_home/.local/bin" \
    "$fake_home/.local/lib/dotfiles" \
    "$fake_home/Library/pnpm"
  cp "$REPO_ROOT/shell/.local/lib/dotfiles/runtime-paths.sh" \
    "$fake_home/.local/lib/dotfiles/runtime-paths.sh"

  (
    HOME="$fake_home"
    PATH=/usr/bin:/bin
    unset PNPM_HOME
    uname() { [[ "${1:-}" == "-s" ]] && printf 'Darwin\n'; }
    # shellcheck source=../../shell/.profile
    source "$REPO_ROOT/shell/.profile"
    assert_eq "$PNPM_HOME" "$HOME/Library/pnpm"
    assert_eq "${PATH%%:*}" "$HOME/.local/bin"
  )

  mkdir -p "$fake_home/.local/share/pnpm"
  printf '#!/bin/sh\nexit 0\n' > "$fake_home/.local/bin/local-probe"
  chmod +x "$fake_home/.local/bin/local-probe"
  (
    HOME="$fake_home"
    PATH=/usr/bin:/bin
    unset PNPM_HOME
    uname() { [[ "${1:-}" == "-s" ]] && printf 'Linux\n'; }
    # shellcheck source=../../shell/.profile
    source "$REPO_ROOT/shell/.profile"
    assert_eq "$PNPM_HOME" "$HOME/.local/share/pnpm"
    assert_eq "$(command -v local-probe)" "$HOME/.local/bin/local-probe"
  )

  if grep -q '/Users/andersbekkevard' \
    "$REPO_ROOT/shell/.profile" "$REPO_ROOT/shell/.zprofile"; then
    fail "tracked startup files contain a machine-specific home path"
  fi
  rm -rf "$fake_home"
}

test_homebrew_activation() {
  local fake_bin
  fake_bin="$(mktemp -d)"
  mkdir -p "$fake_bin/activated/bin"
  cat > "$fake_bin/brew" <<EOF
#!/bin/sh
if [ "\${1:-}" = shellenv ]; then
  printf '%s\n' 'export HOMEBREW_PREFIX="$fake_bin/activated"'
  printf '%s\n' 'export PATH="$fake_bin/activated/bin:$fake_bin:\$PATH"'
  exit 0
fi
exit 0
EOF
  chmod +x "$fake_bin/brew"
  ln -s "$fake_bin/brew" "$fake_bin/activated/bin/brew"

  (
    PATH="$fake_bin:/usr/bin:/bin"
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    # shellcheck source=../lib/packages.sh
    source "$REPO_ROOT/setup/lib/packages.sh"
    OS_FAMILY=darwin
    DRY_RUN=0
    SKIP_INSTALL=0
    ERRORS=()
    ensure_homebrew
    assert_eq "$HOMEBREW_PREFIX" "$fake_bin/activated"
    assert_eq "$(command -v brew)" "$fake_bin/activated/bin/brew"
    [[ ${#ERRORS[@]} -eq 0 ]] || fail "Homebrew activation recorded an error"
  )
  rm -rf "$fake_bin"
}

test_homebrew_dry_run() {
  (
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    # shellcheck source=../lib/packages.sh
    source "$REPO_ROOT/setup/lib/packages.sh"
    homebrew_executable() { return 1; }
    curl() { fail "Homebrew dry-run attempted a download"; }
    OS_FAMILY=darwin
    DRY_RUN=1
    SKIP_INSTALL=0
    ERRORS=()
    ensure_homebrew
    brew_bundle "$REPO_ROOT/setup/packages/Brewfile.minimal"
    [[ ${#ERRORS[@]} -eq 0 ]] || fail "Homebrew dry-run recorded an error"
  )
}

test_pnpm_setup_contract() {
  local fake_home pnpm_log
  fake_home="$(mktemp -d)"
  pnpm_log="$fake_home/pnpm.log"

  (
    HOME="$fake_home"
    PATH=/usr/bin:/bin
    DOTFILES_DIR="$REPO_ROOT"
    unset XDG_CONFIG_HOME
    unset PNPM_HOME
    PNPM_LOG="$pnpm_log"
    uname() { [[ "${1:-}" == "-s" ]] && printf 'Darwin\n'; }
    pnpm() {
      if [[ "$1 $2 $3" == "config get global-bin-dir" ]]; then
        printf 'null\n'
      elif [[ "$1 $2 $3" == "config set global-bin-dir" ]]; then
        printf '%s\n' "$4" > "$PNPM_LOG"
      fi
    }
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    # shellcheck source=../lib/runtimes.sh
    source "$REPO_ROOT/setup/lib/runtimes.sh"
    DRY_RUN=0
    ERRORS=()
    ensure_pnpm_global_bin_available_now
    assert_eq "$PNPM_HOME" "$HOME/Library/pnpm"
    assert_eq "$(cat "$PNPM_LOG")" "$HOME/Library/pnpm"
    [[ -d "$HOME/Library/pnpm" ]] || fail "pnpm global bin directory was not created"
  )
  rm -rf "$fake_home"
}

test_pnpm_dry_run() {
  local fake_home
  fake_home="$(mktemp -d)"

  (
    HOME="$fake_home"
    PATH=/usr/bin:/bin
    DOTFILES_DIR="$REPO_ROOT"
    unset PNPM_HOME
    uname() { [[ "${1:-}" == "-s" ]] && printf 'Darwin\n'; }
    pnpm() {
      [[ "$1 $2 $3" == "config get global-bin-dir" ]] && printf 'null\n'
    }
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    # shellcheck source=../lib/runtimes.sh
    source "$REPO_ROOT/setup/lib/runtimes.sh"
    DRY_RUN=1
    ERRORS=()
    ensure_pnpm_global_bin_available_now
    assert_eq "$PNPM_HOME" "$HOME/Library/pnpm"
    [[ ! -e "$HOME/Library/pnpm" ]] || fail "pnpm dry-run created the global bin directory"
  )
  rm -rf "$fake_home"
}

test_codex_standalone_installer_contract() {
  local fake_home install_log
  fake_home="$(mktemp -d)"
  install_log="$fake_home/install.log"

  (
    HOME="$fake_home"
    PATH=/usr/bin:/bin
    DOTFILES_DIR="$REPO_ROOT"
    INSTALL_LOG="$install_log"
    export INSTALL_LOG
    curl() {
      local output="${@: -1}"
      cat > "$output" <<'EOF'
#!/bin/sh
printf '%s\n' "$CODEX_NON_INTERACTIVE" > "$INSTALL_LOG"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) printf '%s\n' path-ok >> "$INSTALL_LOG" ;;
  *) exit 9 ;;
esac
EOF
    }
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    # shellcheck source=../lib/runtimes.sh
    source "$REPO_ROOT/setup/lib/runtimes.sh"
    DRY_RUN=0
    SKIP_INSTALL=0
    ERRORS=()
    install_codex_cli
    assert_eq "$(sed -n '1p' "$INSTALL_LOG")" "1"
    assert_eq "$(sed -n '2p' "$INSTALL_LOG")" "path-ok"
    [[ ${#ERRORS[@]} -eq 0 ]] || fail "Codex standalone install recorded an error"
  )
  rm -rf "$fake_home"
}

test_cliproxyapi_config_contract() {
  local fake_home config_file env_file config_key env_key
  fake_home="$(mktemp -d)"
  config_file="$fake_home/.config/cliproxyapi/config.yaml"
  env_file="$fake_home/.config/cliproxyapi/claudex.env"

  (
    HOME="$fake_home"
    PATH=/usr/bin:/bin
    DOTFILES_DIR="$REPO_ROOT"
    unset XDG_CONFIG_HOME
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    # shellcheck source=../lib/runtimes.sh
    source "$REPO_ROOT/setup/lib/runtimes.sh"
    DRY_RUN=0
    ERRORS=()
    ensure_cliproxyapi_config
    [[ ${#ERRORS[@]} -eq 0 ]] || fail "CLIProxyAPI config generation recorded an error"
  )

  [[ -r "$config_file" ]] || fail "CLIProxyAPI config was not created"
  [[ -r "$env_file" ]] || fail "CLIProxyAPI env file was not created"
  grep -Fxq 'host: "127.0.0.1"' "$config_file" || fail "CLIProxyAPI is not localhost-only"
  grep -Fxq '  disable-control-panel: true' "$config_file" || fail "CLIProxyAPI control panel is enabled"
  config_key="$(awk -F'"' '/^  - "/ {print $2}' "$config_file")"
  env_key="$(sed -n "s/^CLIPROXY_API_KEY='\(.*\)'$/\1/p" "$env_file")"
  [[ -n "$config_key" ]] || fail "CLIProxyAPI config key is empty"
  assert_eq "$env_key" "$config_key"

  rm -rf "$fake_home"
}

test_claudex_environment_isolation() {
  local fake_home fake_bin capture
  fake_home="$(mktemp -d)"
  fake_bin="$fake_home/bin"
  capture="$fake_home/capture"
  mkdir -p "$fake_bin" "$fake_home/.config/cliproxyapi"
  cat >"$fake_home/.config/cliproxyapi/claudex.env" <<'EOF'
CLIPROXY_BASE_URL='http://127.0.0.1:8317'
CLIPROXY_API_KEY='local-test-key'
EOF
cat >"$fake_bin/claudex-proxy" <<'EOF'
#!/bin/sh
[ "$1" = start ]
EOF
  cat >"$fake_bin/claude" <<'EOF'
#!/bin/sh
{
  printf 'api_key=%s\n' "${ANTHROPIC_API_KEY-unset}"
  printf 'base_url=%s\n' "$ANTHROPIC_BASE_URL"
  printf 'auth_token=%s\n' "$ANTHROPIC_AUTH_TOKEN"
  printf 'subagent=%s\n' "$CLAUDE_CODE_SUBAGENT_MODEL"
  printf 'args=%s\n' "$*"
} >"$CAPTURE"
EOF
  chmod +x "$fake_bin/claudex-proxy" "$fake_bin/claude"

  env -u XDG_CONFIG_HOME \
    HOME="$fake_home" PATH="$fake_bin:/usr/bin:/bin" CAPTURE="$capture" \
    ANTHROPIC_API_KEY=must-not-pass \
    "$REPO_ROOT/scripts/.local/bin/claudex" --safe-mode

  grep -Fxq 'api_key=unset' "$capture" || fail "claudex leaked ANTHROPIC_API_KEY"
  grep -Fxq 'base_url=http://127.0.0.1:8317' "$capture" || fail "claudex base URL is wrong"
  grep -Fxq 'auth_token=local-test-key' "$capture" || fail "claudex auth token is wrong"
  grep -Fxq 'subagent=gpt-5.6-sol' "$capture" || fail "claudex subagent model is wrong"
  grep -Fxq 'args=--model gpt-5.6-sol --effort medium --safe-mode' "$capture" ||
    fail "claudex arguments are wrong"

  rm -rf "$fake_home"
}

test_runtime_path_defaults
test_profile_contract
test_homebrew_activation
test_homebrew_dry_run
test_pnpm_setup_contract
test_pnpm_dry_run
test_codex_standalone_installer_contract
test_cliproxyapi_config_contract
test_claudex_environment_isolation
printf 'bootstrap contracts: ok\n'
