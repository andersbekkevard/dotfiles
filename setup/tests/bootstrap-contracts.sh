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

stat_mode() {
  if [[ "$(uname -s)" == Darwin ]]; then
    stat -f '%OLp' "$1"
  else
    stat -c '%a' "$1"
  fi
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

  rm -rf "$fake_home"
}

# Every tracked file that a login or interactive shell sources must address the
# user's home through $HOME. A literal /Users/<name> or /home/<name> works on
# exactly one machine and fails silently everywhere else. /home/linuxbrew is the
# one legitimate exception: it is Homebrew's fixed Linux prefix, not a home dir.
test_no_machine_specific_home_paths() {
  local startup_files=(
    "$REPO_ROOT/shell/.profile"
    "$REPO_ROOT/shell/.zprofile"
    "$REPO_ROOT/shell/.zshenv"
    "$REPO_ROOT/shell/.zshrc"
  )
  local zsh_module
  for zsh_module in "$REPO_ROOT"/shell/.zsh/*.zsh; do
    startup_files+=("$zsh_module")
  done

  local offenders
  offenders="$(
    grep -nE '/(Users|home)/[A-Za-z0-9._-]+' "${startup_files[@]}" |
      grep -v '/home/linuxbrew' || true
  )"

  if [[ -n "$offenders" ]]; then
    printf '%s\n' "$offenders" >&2
    fail "tracked startup files contain a machine-specific home path"
  fi
}

test_canonical_repo_path_contract() {
  grep -Fqx 'alias zrc="nvim ~/dotfiles/shell/.zshrc"' \
    "$REPO_ROOT/shell/.zsh/aliases.zsh" ||
    fail "zrc does not use the canonical ~/dotfiles path"
  grep -Fq -- '--dir="$HOME/dotfiles"' \
    "$REPO_ROOT/shell/.zsh/aliases.zsh" ||
    fail "dstow does not use the canonical ~/dotfiles path"
  grep -Fqx 'path = "~/dotfiles"' \
    "$REPO_ROOT/shell/.config/sesh/sesh.toml" ||
    fail "sesh does not use the canonical ~/dotfiles path"

  if grep -Fq '~/.dotfiles' \
    "$REPO_ROOT/README.md" \
    "$REPO_ROOT/docs/usage.md" \
    "$REPO_ROOT/shell/.zsh/aliases.zsh" \
    "$REPO_ROOT/shell/.config/sesh/sesh.toml" \
    "$REPO_ROOT/agents/skills/fleet/provision-hetzner-dev-server/SKILL.md" \
    "$REPO_ROOT/agents/skills/fleet/provision-hetzner-dev-server/scripts/verify-host.sh"; then
    fail "canonical operator surfaces still reference ~/.dotfiles"
  fi
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

test_claude_standalone_installer_contract() {
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
#!/bin/bash
[[ -n "${BASH_VERSION:-}" ]] || exit 8
case ":$PATH:" in
  *":$HOME/.local/bin:"*) printf '%s\n' path-ok > "$INSTALL_LOG" ;;
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
    install_claude_cli
    assert_eq "$(sed -n '1p' "$INSTALL_LOG")" "path-ok"
    [[ ${#ERRORS[@]} -eq 0 ]] || fail "Claude standalone install recorded an error"
  )
  rm -rf "$fake_home"
}

test_agent_cli_profile_contract() {
  # shellcheck source=../lib/profiles.sh
  source "$REPO_ROOT/setup/lib/profiles.sh"

  profile_commands full | grep -Fxq claude ||
    fail "full profile does not require Claude Code"
  profile_commands full | grep -Fxq codex ||
    fail "full profile does not require Codex"
  if profile_commands minimal | grep -Fxq claude; then
    fail "minimal profile unexpectedly requires Claude Code"
  fi
}

test_restow_cli_contract() {
  (
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    parse_args restow
    assert_eq "$REQUESTED_PROFILE" "full"
    assert_eq "$SKIP_INSTALL" "1"
    assert_eq "$RESTOW_MODE" "1"
    [[ ${#ARG_ERRORS[@]} -eq 0 ]] || fail "default restow arguments were rejected"
  )

  (
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    parse_args restow linux-desktop
    assert_eq "$REQUESTED_PROFILE" "linux-desktop"
    assert_eq "$SKIP_INSTALL" "1"
    assert_eq "$RESTOW_MODE" "1"
    [[ ${#ARG_ERRORS[@]} -eq 0 ]] || fail "explicit restow profile was rejected"
  )
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
  printf 'context_window=%s\n' "$CLAUDE_CODE_AUTO_COMPACT_WINDOW"
  printf 'compact_pct=%s\n' "$CLAUDE_AUTOCOMPACT_PCT_OVERRIDE"
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
  grep -Fxq 'subagent=gpt-5.6-luna' "$capture" || fail "claudex subagent model is wrong"
  grep -Fxq 'context_window=272000' "$capture" || fail "claudex context window is wrong"
  grep -Fxq 'compact_pct=88' "$capture" || fail "claudex compaction threshold is wrong"
  grep -Fxq 'args=--model gpt-5.6-sol --effort high --safe-mode' "$capture" ||
    fail "claudex arguments are wrong"

  rm -rf "$fake_home"
}

test_cliproxyapi_umask_containment() {
  local fake_home config_dir
  fake_home="$(mktemp -d)"
  config_dir="$fake_home/.config/cliproxyapi"

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
    umask 022
    previous_umask="$(umask)"
    ensure_cliproxyapi_config
    [[ ${#ERRORS[@]} -eq 0 ]] || fail "CLIProxyAPI config generation recorded an error"
    assert_eq "$(umask)" "$previous_umask"
    mkdir -p "$fake_home/later-in-the-run"
    assert_eq "$(stat_mode "$fake_home/later-in-the-run")" "755"
  )

  assert_eq "$(stat_mode "$config_dir/config.yaml")" "600"
  assert_eq "$(stat_mode "$config_dir/claudex.env")" "600"

  rm -rf "$fake_home"
}

test_fnm_entrypoint_stability() {
  local fake_home alias_bin multishell_bin
  fake_home="$(mktemp -d)"
  alias_bin="$fake_home/.local/share/fnm/aliases/default/bin"
  multishell_bin="$fake_home/.local/state/fnm_multishells/4242_1700000000000/bin"
  mkdir -p "$alias_bin" "$multishell_bin"
  # Stand in for the real node binary: not a '#!' script, so the entrypoint is a
  # direct symlink rather than a generated exec wrapper.
  printf 'not-a-script\n' >"$alias_bin/node"
  chmod +x "$alias_bin/node"
  ln -s "$alias_bin/node" "$multishell_bin/node"

  (
    HOME="$fake_home"
    DOTFILES_DIR="$REPO_ROOT"
    unset FNM_DIR
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    profile_commands() { printf '%s\n' node; }
    resolve_command_from_clean_login_shell_without_stable_path() {
      printf '%s\n' "$multishell_bin/$1"
    }
    resolve_command_from_clean_login_shell() {
      printf '%s\n' "$multishell_bin/$1"
    }
    DRY_RUN=0
    refresh_local_bin_entrypoints full
  )

  assert_eq "$(readlink "$fake_home/.local/bin/node")" "$alias_bin/node"

  # With no default alias there is nothing stable to pin, so no dangling link.
  rm -rf "$fake_home/.local/share/fnm/aliases" "$fake_home/.local/bin/node"
  (
    HOME="$fake_home"
    DOTFILES_DIR="$REPO_ROOT"
    unset FNM_DIR
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    profile_commands() { printf '%s\n' node; }
    resolve_command_from_clean_login_shell_without_stable_path() {
      printf '%s\n' "$multishell_bin/$1"
    }
    resolve_command_from_clean_login_shell() {
      printf '%s\n' "$multishell_bin/$1"
    }
    DRY_RUN=0
    refresh_local_bin_entrypoints full
  )

  [[ ! -L "$fake_home/.local/bin/node" ]] ||
    fail "entrypoint refresh pinned an ephemeral fnm multishell path"

  rm -rf "$fake_home"
}

# A dry run on a machine that has none of the tools yet is the case --dry-run
# exists for. Steps whose tool the same run would install must report intent,
# not error. Regression guard: this once exited 1 with 13 errors on a bare
# Ubuntu image because stow and zsh were checked before the dry-run branch.
test_dry_run_on_toolless_machine() {
  local fake_home
  fake_home="$(mktemp -d)"

  local output
  output="$(
    HOME="$fake_home"
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    # shellcheck source=../lib/stow.sh
    source "$REPO_ROOT/setup/lib/stow.sh"
    # shellcheck source=../lib/shell-setup.sh
    source "$REPO_ROOT/setup/lib/shell-setup.sh"
    DOTFILES_DIR="$REPO_ROOT"
    RUN_ID=test
    DRY_RUN=1
    SKIP_INSTALL=0
    ERRORS=()
    # Stand in for a machine where the package step has not run yet.
    command_exists() {
      [[ "$1" == stow || "$1" == zsh ]] && return 1
      command -v "$1" >/dev/null 2>&1
    }
    stow_package btop
    ensure_default_shell_zsh
    printf 'errors=%d\n' "${#ERRORS[@]}"
    if [[ ${#ERRORS[@]} -gt 0 ]]; then printf '%s\n' "${ERRORS[@]}"; fi
  )"

  grep -Fxq 'errors=0' <<<"$output" ||
    fail "dry run on a toolless machine recorded errors: $output"

  # The guard must not weaken the real run: with no installer step to follow,
  # missing stow and zsh are still hard errors.
  local real_output
  real_output="$(
    HOME="$fake_home"
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    # shellcheck source=../lib/stow.sh
    source "$REPO_ROOT/setup/lib/stow.sh"
    # shellcheck source=../lib/shell-setup.sh
    source "$REPO_ROOT/setup/lib/shell-setup.sh"
    DOTFILES_DIR="$REPO_ROOT"
    RUN_ID=test
    DRY_RUN=0
    SKIP_INSTALL=1
    ERRORS=()
    command_exists() {
      [[ "$1" == stow || "$1" == zsh ]] && return 1
      command -v "$1" >/dev/null 2>&1
    }
    stow_package btop
    ensure_default_shell_zsh
    if [[ ${#ERRORS[@]} -gt 0 ]]; then printf '%s\n' "${ERRORS[@]}"; fi
  )"

  grep -Fq 'GNU Stow is required but not installed.' <<<"$real_output" ||
    fail "real run stopped reporting missing stow"
  grep -Fq 'zsh is not installed; cannot set default shell' <<<"$real_output" ||
    fail "real run stopped reporting missing zsh"

  rm -rf "$fake_home"
}

test_dry_run_privileged_plan() {
  local output
  output="$(
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    # shellcheck source=../lib/packages.sh
    source "$REPO_ROOT/setup/lib/packages.sh"
    OS_FAMILY=linux
    DRY_RUN=1
    SKIP_INSTALL=0
    APT_UPDATED=0
    HAS_SUDO=0
    ERRORS=()
    apt_update_once
  )"

  grep -Fq 'Update apt package index' <<<"$output" ||
    fail "dry run does not report the apt update it would perform"
  grep -Fq 'sudo/root unavailable' <<<"$output" &&
    fail "dry run reports privileged steps as skipped"

  return 0
}

test_control_europa_desktop_wrapper() {
  local fake_home fake_bin capture helper_dir wrapper
  fake_home="$(mktemp -d)"
  fake_bin="$fake_home/bin"
  capture="$fake_home/capture"
  helper_dir="$fake_home/dotfiles/agents/skills/desk/control-europa-desktop/scripts"
  wrapper="$REPO_ROOT/scripts/.local/bin/control-europa-desktop"
  mkdir -p "$fake_bin" "$helper_dir"

  cat >"$fake_bin/hostname" <<'EOF'
#!/bin/sh
printf 'mac-test\n'
EOF
  cat >"$fake_bin/ssh" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >"$CAPTURE"
EOF
  chmod +x "$fake_bin/hostname" "$fake_bin/ssh"

  HOME="$fake_home" PATH="$fake_bin:/usr/bin:/bin" CAPTURE="$capture" \
    "$wrapper"
  assert_eq "$(cat "$capture")" "$(printf '%s\n' \
    -T \
    -o BatchMode=yes \
    -o ConnectTimeout=10 \
    -o StrictHostKeyChecking=yes \
    europa \
    '/home/anders/.local/bin/control-europa-desktop open ')"

  cat >"$fake_bin/hostname" <<'EOF'
#!/bin/sh
printf 'europa\n'
EOF
  cat >"$helper_dir/control-europa-desktop" <<'EOF'
#!/bin/sh
printf '%s\n' "$1" >"$HELPER_CAPTURE"
EOF
  chmod +x "$fake_bin/hostname" "$helper_dir/control-europa-desktop"

  HOME="$fake_home" PATH="$fake_bin:/usr/bin:/bin" HELPER_CAPTURE="$capture" \
    "$wrapper" close
  assert_eq "$(cat "$capture")" close

  if HOME="$fake_home" PATH="$fake_bin:/usr/bin:/bin" \
      "$wrapper" invalid >/dev/null 2>&1; then
    fail "control-europa-desktop accepted an invalid operation"
  fi

  rm -rf "$fake_home"
}

test_runtime_path_defaults
test_profile_contract
test_no_machine_specific_home_paths
test_canonical_repo_path_contract
test_homebrew_activation
test_homebrew_dry_run
test_pnpm_setup_contract
test_pnpm_dry_run
test_agent_cli_profile_contract
test_restow_cli_contract
test_claude_standalone_installer_contract
test_codex_standalone_installer_contract
test_cliproxyapi_config_contract
test_cliproxyapi_umask_containment
test_fnm_entrypoint_stability
test_dry_run_privileged_plan
test_dry_run_on_toolless_machine
test_claudex_environment_isolation
test_control_europa_desktop_wrapper
printf 'bootstrap contracts: ok\n'
