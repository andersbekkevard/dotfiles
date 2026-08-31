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

stat_inode() {
  if [[ "$(uname -s)" == Darwin ]]; then
    stat -f '%i' "$1"
  else
    stat -c '%i' "$1"
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

test_no_tty_prompt_contract() {
  local fake_home instant_prompt
  fake_home="$(mktemp -d)"
  instant_prompt="$fake_home/cache/p10k-instant-prompt-$(id -un).zsh"
  mkdir -p "${instant_prompt%/*}" "$fake_home/.scripts"
  printf 'export DOTFILES_TEST_INSTANT_PROMPT_SOURCED=1\n' >"$instant_prompt"
  printf ':\n' >"$fake_home/.scripts/noop.zsh"

  HOME="$fake_home" XDG_CACHE_HOME="$fake_home/cache" \
    zsh -fic 'source "$1"; [[ -z "${DOTFILES_TEST_INSTANT_PROMPT_SOURCED:-}" ]]' \
    zsh "$REPO_ROOT/shell/.zshrc" </dev/null ||
    fail "non-TTY interactive zsh sourced the instant prompt"

  HOME="$fake_home" zsh -fic \
    'source "$1"; [[ -z "$ZSH_THEME" && "$PROMPT" == "%~%# " && -z "$RPROMPT" ]]' \
    zsh "$REPO_ROOT/shell/.zsh/core.zsh" </dev/null ||
    fail "non-TTY interactive zsh enabled a terminal prompt theme"

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
    "$REPO_ROOT/agents/skills/provision-hetzner-dev-server/SKILL.md" \
    "$REPO_ROOT/agents/skills/provision-hetzner-dev-server/scripts/verify-host.sh"; then
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

test_homebrew_install_update_split() {
  local fake_root fake_bin brew_log manifest
  fake_root="$(mktemp -d)"
  fake_bin="$fake_root/bin"
  brew_log="$fake_root/brew.log"
  manifest="$fake_root/Brewfile"
  mkdir -p "$fake_bin"
  printf 'brew "git"\n' > "$manifest"
  cat > "$fake_bin/brew" <<'EOF'
#!/bin/sh
if [ "$1 $2 $3" = "bundle install --help" ]; then
  printf '%s\n' '--no-upgrade --upgrade'
  exit 0
fi
printf 'CI=%s NONINTERACTIVE=%s NO_AUTO_UPDATE=%s args=%s\n' \
  "${CI-}" "${NONINTERACTIVE-}" "${HOMEBREW_NO_AUTO_UPDATE-}" "$*" >> "$BREW_LOG"
EOF
  chmod +x "$fake_bin/brew"

  (
    PATH="$fake_bin:/usr/bin:/bin"
    BREW_LOG="$brew_log"
    export BREW_LOG
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    # shellcheck source=../lib/packages.sh
    source "$REPO_ROOT/setup/lib/packages.sh"
    DRY_RUN=0
    SKIP_INSTALL=0
    UPGRADE_EXISTING=0
    ERRORS=()
    brew_bundle "$manifest"
    [[ ${#ERRORS[@]} -eq 0 ]] || fail "missing-only Brewfile run recorded an error"
  )
  grep -Fq 'NO_AUTO_UPDATE=1 args=bundle install --file' "$brew_log" ||
    fail "install did not suppress Homebrew auto-update"
  grep -Fq -- '--no-upgrade' "$brew_log" || fail "install omitted brew bundle --no-upgrade"

  : > "$brew_log"
  (
    PATH="$fake_bin:/usr/bin:/bin"
    BREW_LOG="$brew_log"
    export BREW_LOG
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    # shellcheck source=../lib/packages.sh
    source "$REPO_ROOT/setup/lib/packages.sh"
    DRY_RUN=0
    SKIP_INSTALL=0
    UPGRADE_EXISTING=1
    ERRORS=()
    brew_bundle "$manifest"
    [[ ${#ERRORS[@]} -eq 0 ]] || fail "Brewfile update recorded an error"
  )
  grep -Fq 'args=update' "$brew_log" || fail "update omitted brew update"
  grep -Fq -- '--upgrade' "$brew_log" || fail "update omitted brew bundle --upgrade"
  if grep -Fq -- '--no-upgrade' "$brew_log"; then
    fail "update retained missing-only Homebrew semantics"
  fi

  rm -rf "$fake_root"
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

test_agent_instruction_composition() {
  local fake_home fake_sources shared_source codex_source claude_source
  local shared_local_source codex_local_source claude_local_source
  fake_home="$(mktemp -d)"
  fake_sources="$(mktemp -d)"
  shared_source="$fake_sources/SHARED.global.md"
  codex_source="$fake_sources/AGENTS.global.md"
  claude_source="$fake_sources/CLAUDE.global.md"
  shared_local_source="$fake_sources/SHARED.md"
  codex_local_source="$fake_sources/AGENTS.md"
  claude_local_source="$fake_sources/CLAUDE.md"
  printf 'shared rule\n' > "$shared_source"
  printf 'codex rule\n' > "$codex_source"
  printf 'claude rule\n' > "$claude_source"
  printf 'shared local rule\n' > "$shared_local_source"
  printf 'codex local rule\n' > "$codex_local_source"
  printf 'claude local rule\n' > "$claude_local_source"
  mkdir -p "$fake_home/.codex" "$fake_home/.claude"

  (
    HOME="$fake_home"
    DOTFILES_DIR="$REPO_ROOT"
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    # shellcheck source=../lib/stow.sh
    source "$REPO_ROOT/setup/lib/stow.sh"
    # shellcheck source=../agents.sh
    source "$REPO_ROOT/setup/agents.sh"
    RUN_ID=test-agent-composition
    DRY_RUN=0
    ERRORS=()

    ln -s "$codex_source" "$HOME/.codex/AGENTS.md"
    printf 'pre-existing Claude instructions\n' > "$HOME/.claude/CLAUDE.md"
    compose_agent_file \
      "$HOME/.codex/AGENTS.md" "$shared_source" "$codex_source" "$codex_source" \
      "$shared_local_source" "$codex_local_source"
    compose_agent_file \
      "$HOME/.claude/CLAUDE.md" "$shared_source" "$claude_source" "$codex_source" \
      "$shared_local_source" "$claude_local_source"

    assert_eq "$(cat "$HOME/.codex/AGENTS.md")" "$(printf '%s\n' \
      '<!-- dotfiles-managed: composed global agent instructions -->' \
      'shared rule' '' 'codex rule' '' 'shared local rule' '' 'codex local rule')"
    assert_eq "$(cat "$HOME/.claude/CLAUDE.md")" "$(printf '%s\n' \
      '<!-- dotfiles-managed: composed global agent instructions -->' \
      'shared rule' '' 'claude rule' '' 'shared local rule' '' 'claude local rule')"
    assert_eq "$(sed -n '2p' "$HOME/.codex/AGENTS.md")" "shared rule"
    assert_eq "$(sed -n '4p' "$HOME/.codex/AGENTS.md")" "codex rule"
    grep -Fxq 'shared rule' "$HOME/.codex/AGENTS.md" || fail "Codex instructions omit shared rules"
    grep -Fxq 'codex rule' "$HOME/.codex/AGENTS.md" || fail "Codex instructions omit Codex rules"
    grep -Fxq 'shared local rule' "$HOME/.codex/AGENTS.md" || fail "Codex instructions omit shared local rules"
    grep -Fxq 'codex local rule' "$HOME/.codex/AGENTS.md" || fail "Codex instructions omit Codex local rules"
    if grep -Fq 'claude rule' "$HOME/.codex/AGENTS.md"; then
      fail "Codex instructions include Claude rules"
    fi
    if grep -Fq 'claude local rule' "$HOME/.codex/AGENTS.md"; then
      fail "Codex instructions include Claude local rules"
    fi
    grep -Fxq 'shared rule' "$HOME/.claude/CLAUDE.md" || fail "Claude instructions omit shared rules"
    grep -Fxq 'claude rule' "$HOME/.claude/CLAUDE.md" || fail "Claude instructions omit Claude rules"
    grep -Fxq 'shared local rule' "$HOME/.claude/CLAUDE.md" || fail "Claude instructions omit shared local rules"
    grep -Fxq 'claude local rule' "$HOME/.claude/CLAUDE.md" || fail "Claude instructions omit Claude local rules"
    if grep -Fq 'codex rule' "$HOME/.claude/CLAUDE.md"; then
      fail "Claude instructions include Codex rules"
    fi
    if grep -Fq 'codex local rule' "$HOME/.claude/CLAUDE.md"; then
      fail "Claude instructions include Codex local rules"
    fi
    grep -Fxq 'pre-existing Claude instructions' \
      "$HOME/.dotfiles-backups/test-agent-composition/.claude/CLAUDE.md" ||
      fail "pre-existing Claude instructions were not backed up"

    printf 'updated codex rule\n' > "$codex_source"
    compose_agent_file \
      "$HOME/.codex/AGENTS.md" "$shared_source" "$codex_source" "$codex_source" \
      "$shared_local_source" "$codex_local_source"
    grep -Fxq 'updated codex rule' "$HOME/.codex/AGENTS.md" || fail "managed Codex instructions did not refresh"
    grep -Fxq 'codex local rule' "$HOME/.codex/AGENTS.md" || fail "Codex local rules did not survive refresh"
    [[ ! -e "$HOME/.dotfiles-backups/test-agent-composition/.codex/AGENTS.md" ]] ||
      fail "managed Codex instructions were backed up during refresh"

    rm "$shared_local_source" "$codex_local_source"
    compose_agent_file \
      "$HOME/.codex/AGENTS.md" "$shared_source" "$codex_source" "$codex_source" \
      "$shared_local_source" "$codex_local_source"
    if grep -Fq 'local rule' "$HOME/.codex/AGENTS.md"; then
      fail "removed local overlays remain in Codex instructions"
    fi
  )

  rm -rf "$fake_home" "$fake_sources"
}

test_dotfiles_cli_contract() {
  (
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    parse_args install minimal --yes
    assert_eq "$CLI_COMMAND" "install"
    assert_eq "$REQUESTED_PROFILE" "minimal"
    assert_eq "$SKIP_INSTALL" "0"
    assert_eq "$ASSUME_YES" "1"
    [[ ${#ARG_ERRORS[@]} -eq 0 ]] || fail "install arguments were rejected"
  )

  (
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    parse_args update full --yes
    assert_eq "$CLI_COMMAND" "update"
    assert_eq "$REQUESTED_PROFILE" "full"
    assert_eq "$UPGRADE_EXISTING" "1"
    assert_eq "$ASSUME_YES" "1"
    [[ ${#ARG_ERRORS[@]} -eq 0 ]] || fail "update arguments were rejected"
  )

  (
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    parse_args refresh
    assert_eq "$CLI_COMMAND" "refresh"
    assert_eq "$REQUESTED_PROFILE" "full"
    assert_eq "$SKIP_INSTALL" "1"
    [[ ${#ARG_ERRORS[@]} -eq 0 ]] || fail "default refresh arguments were rejected"
  )

  (
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    parse_args refresh linux-desktop -n
    assert_eq "$REQUESTED_PROFILE" "linux-desktop"
    assert_eq "$SKIP_INSTALL" "1"
    assert_eq "$DRY_RUN" "1"
    [[ ${#ARG_ERRORS[@]} -eq 0 ]] || fail "explicit refresh profile was rejected"
  )

  (
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    parse_args stow shell nvim --dry-run
    assert_eq "$CLI_COMMAND" "stow"
    assert_eq "${STOW_PACKAGES[*]}" "shell nvim"
    assert_eq "$DRY_RUN" "1"
    [[ ${#ARG_ERRORS[@]} -eq 0 ]] || fail "multi-package stow arguments were rejected"
  )

  (
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    parse_args verify macos
    assert_eq "$CLI_COMMAND" "verify"
    assert_eq "$VERIFY_PROFILE" "macos"
    [[ ${#ARG_ERRORS[@]} -eq 0 ]] || fail "verify arguments were rejected"
  )

  (
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    parse_args minimal
    [[ ${#ARG_ERRORS[@]} -gt 0 ]] || fail "legacy direct-profile syntax was accepted"
  )

  (
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    CLI_COMMAND=install
    NO_INPUT=1
    if confirm_package_mutation >/dev/null 2>&1; then
      fail "unconfirmed non-interactive install was accepted"
    fi
    ASSUME_YES=1
    confirm_package_mutation >/dev/null 2>&1 || fail "--yes did not confirm install"
  )

  local help_output install_output install_status update_output update_status
  help_output="$(bash "$REPO_ROOT/dotfiles.sh" --help)"
  printf '%s\n' "$help_output" | grep -Fq './dotfiles.sh stow <package>...' ||
    fail "dotfiles help omits multi-package stow"
  printf '%s\n' "$help_output" | grep -Fq './dotfiles.sh update <profile>' ||
    fail "dotfiles help omits explicit update"
  printf '%s\n' "$help_output" | grep -Fq 'Working tools are adopted without upgrading them.' ||
    fail "dotfiles help omits missing-only install semantics"
  printf '%s\n' "$help_output" | grep -Fq "We can't prove every third-party installer is idempotent." ||
    fail "dotfiles help omits the unproven-idempotence warning"

  set +e
  install_output="$(bash "$REPO_ROOT/dotfiles.sh" install minimal --no-input 2>&1)"
  install_status=$?
  set -e
  assert_eq "$install_status" "2"
  printf '%s\n' "$install_output" | grep -Fq 'Install may execute third-party installers' ||
    fail "unconfirmed install omitted its mutation warning"

  set +e
  update_output="$(bash "$REPO_ROOT/dotfiles.sh" update minimal --no-input 2>&1)"
  update_status=$?
  set -e
  assert_eq "$update_status" "2"
  printf '%s\n' "$update_output" | grep -Fq 'Update intentionally changes managed package and runtime versions.' ||
    fail "unconfirmed update omitted its mutation warning"
}

test_agents_cli_contract() {
  local fake_home fake_bin python_capture dry_home verify_home help_output real_python
  fake_home="$(mktemp -d)"
  fake_bin="$fake_home/bin"
  python_capture="$fake_home/python-capture"
  real_python="$(command -v python3)"
  mkdir -p "$fake_bin"
  cat > "$fake_bin/python3" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" > "$PYTHON_CAPTURE"
exec "$REAL_PYTHON" "$@"
EOF
  chmod +x "$fake_bin/python3"

  (
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    parse_args agents sync
    assert_eq "$CLI_COMMAND" "agents"
    assert_eq "$AGENTS_ACTION" "sync"
    assert_eq "$SKIP_INSTALL" "1"
    assert_eq "$REQUESTED_PROFILE" ""
    [[ ${#ARG_ERRORS[@]} -eq 0 ]] || fail "agents arguments were rejected"
  )

  HOME="$fake_home" \
    PATH="$fake_bin:/usr/bin:/bin" \
    PYTHON_CAPTURE="$python_capture" \
    REAL_PYTHON="$real_python" \
    bash "$REPO_ROOT/dotfiles.sh" agents sync >/dev/null

  [[ -f "$fake_home/.claude/CLAUDE.md" ]] || fail "agents mode did not compose Claude instructions"
  [[ -f "$fake_home/.codex/AGENTS.md" ]] || fail "agents mode did not compose Codex instructions"
  [[ -L "$fake_home/.claude/skills/unslop" ]] || fail "agents mode did not link Claude skills"
  assert_eq "$(cat "$python_capture")" "$REPO_ROOT/agents/skillpull validate"
  [[ ! -e "$fake_home/.zshrc" ]] || fail "agents mode touched shell dotfiles"
  [[ ! -e "$fake_home/.config/zsh/local.example.zsh" ]] || fail "agents mode refreshed unrelated templates"
  [[ ! -e "$fake_home/.local/bin" ]] || fail "agents mode refreshed stable command entrypoints"

  dry_home="$(mktemp -d)"
  HOME="$dry_home" \
    PATH="$fake_bin:/usr/bin:/bin" \
    PYTHON_CAPTURE="$python_capture" \
    REAL_PYTHON="$real_python" \
    bash "$REPO_ROOT/dotfiles.sh" agents sync --dry-run >/dev/null
  if find "$dry_home" -mindepth 1 -print -quit | grep -q .; then
    fail "agents dry-run mutated HOME"
  fi

  help_output="$(bash "$REPO_ROOT/dotfiles.sh" agents --help)"
  printf '%s\n' "$help_output" | grep -Fq './dotfiles.sh agents sync [-n|--dry-run]' ||
    fail "dotfiles help omits agents mode"

  HOME="$fake_home" PATH="$fake_bin:/usr/bin:/bin" PYTHON_CAPTURE="$python_capture" \
    REAL_PYTHON="$real_python" bash "$REPO_ROOT/dotfiles.sh" agents verify >/dev/null ||
    fail "agents verify rejected a synced isolated HOME"
  HOME="$fake_home" PATH="$fake_bin:/usr/bin:/bin" PYTHON_CAPTURE="$python_capture" \
    REAL_PYTHON="$real_python" bash "$REPO_ROOT/dotfiles.sh" agents status >/dev/null ||
    fail "agents status rejected a synced isolated HOME"

  if bash "$REPO_ROOT/dotfiles.sh" agents minimal >/dev/null 2>&1; then
    fail "agents accepted an unknown action"
  fi
  if bash "$REPO_ROOT/dotfiles.sh" agents sync sync >/dev/null 2>&1; then
    fail "agents sync accepted a duplicate action"
  fi
  if bash "$REPO_ROOT/dotfiles.sh" agents sync --yes >/dev/null 2>&1; then
    fail "agents sync accepted an install-only flag"
  fi

  verify_home="$(mktemp -d)"
  if HOME="$verify_home" PATH="$fake_bin:/usr/bin:/bin" PYTHON_CAPTURE="$python_capture" \
      REAL_PYTHON="$real_python" bash "$REPO_ROOT/dotfiles.sh" agents verify >/dev/null 2>&1; then
    fail "agents verify accepted a missing agent surface"
  fi
  if find "$verify_home" -mindepth 1 -print -quit | grep -q .; then
    fail "agents verify mutated HOME"
  fi

  rm -rf "$fake_home" "$dry_home" "$verify_home"
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

test_install_update_package_selection() {
  local fake_root manifest output
  fake_root="$(mktemp -d)"
  manifest="$fake_root/apt.txt"
  printf '%s\n' git ripgrep jq > "$manifest"

  output="$(
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    # shellcheck source=../lib/packages.sh
    source "$REPO_ROOT/setup/lib/packages.sh"
    OS_FAMILY=linux
    SKIP_INSTALL=0
    DRY_RUN=0
    UPGRADE_EXISTING=0
    dpkg_package_installed() { [[ "$1" == git ]]; }
    apt_package_satisfied_by_command() { [[ "$1" == ripgrep ]]; }
    can_use_root() { return 0; }
    apt_update_once() { printf 'apt-update\n'; }
    run_cmd_allow_failure() { shift; printf 'selected=%s\n' "$*"; }
    apt_install_manifest "$manifest"
  )"
  grep -Fq 'selected=as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y jq' <<<"$output" ||
    fail "install did not limit apt to missing, unprovided packages: $output"

  output="$(
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    # shellcheck source=../lib/packages.sh
    source "$REPO_ROOT/setup/lib/packages.sh"
    OS_FAMILY=linux
    SKIP_INSTALL=0
    DRY_RUN=0
    UPGRADE_EXISTING=1
    dpkg_package_installed() { [[ "$1" == git ]]; }
    apt_package_satisfied_by_command() { [[ "$1" == ripgrep ]]; }
    can_use_root() { return 0; }
    apt_update_once() { printf 'apt-update\n'; }
    run_cmd_allow_failure() { shift; printf 'selected=%s\n' "$*"; }
    apt_install_manifest "$manifest"
  )"
  grep -Fq 'selected=as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y git jq' <<<"$output" ||
    fail "update did not upgrade apt-owned and install truly missing packages: $output"
  if grep -Fq 'ripgrep' <<<"${output##*selected=}"; then
    fail "update replaced an adopted command provider with apt"
  fi

  rm -rf "$fake_root"
}

test_installer_convergence_and_atomicity() {
  local fake_home fake_bin install_count old_target source_file
  fake_home="$(mktemp -d)"
  fake_bin="$fake_home/bin"
  install_count="$fake_home/install-count"
  old_target="$fake_home/managed-tool"
  source_file="$fake_home/new-tool"
  mkdir -p "$fake_bin"

  (
    HOME="$fake_home"
    PATH="$fake_bin:/usr/bin:/bin"
    INSTALL_COUNT="$install_count"
    export INSTALL_COUNT
    curl() {
      local output="${@: -1}"
      cat > "$output" <<'EOF'
#!/bin/sh
count=0
[ ! -f "$INSTALL_COUNT" ] || count="$(cat "$INSTALL_COUNT")"
count=$((count + 1))
printf '%s\n' "$count" > "$INSTALL_COUNT"
cat > "$HOME/bin/probe" <<'INNER'
#!/bin/sh
[ "${1-}" = --version ] && printf 'probe 1.0\n'
INNER
chmod +x "$HOME/bin/probe"
EOF
    }
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    # shellcheck source=../lib/packages.sh
    source "$REPO_ROOT/setup/lib/packages.sh"
    SKIP_INSTALL=0
    DRY_RUN=0
    ASSUME_YES=1
    ERRORS=()
    install_remote_script_if_missing probe "Install probe" https://example.invalid/install.sh sh
    hash -r
    install_remote_script_if_missing probe "Install probe" https://example.invalid/install.sh sh
    assert_eq "$(cat "$INSTALL_COUNT")" "1"
    [[ ${#ERRORS[@]} -eq 0 ]] || fail "convergent remote installer recorded an error"
  )

  printf 'old\n' > "$old_target"
  printf 'new\n' > "$source_file"
  (
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    # shellcheck source=../lib/packages.sh
    source "$REPO_ROOT/setup/lib/packages.sh"
    install() {
      local destination="${@: -1}"
      printf 'partial\n' > "$destination"
      return 9
    }
    if atomic_install_file "$source_file" "$old_target" 0755; then
      fail "atomic install accepted a failed staging write"
    fi
  )
  assert_eq "$(cat "$old_target")" old
  if find "$fake_home" -name '.managed-tool.tmp.*' -print -quit | grep -q .; then
    fail "failed atomic install left a staging file"
  fi

  (
    HOME="$fake_home"
    PATH=/usr/bin:/bin
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    # shellcheck source=../lib/packages.sh
    source "$REPO_ROOT/setup/lib/packages.sh"
    SKIP_INSTALL=0
    DRY_RUN=0
    ASSUME_YES=1
    ERRORS=()
    curl() { return 22; }
    install_remote_script_if_missing missing-probe "Install missing probe" https://example.invalid/fail.sh sh
    [[ ${#ERRORS[@]} -eq 1 ]] || fail "failed installer download was not recorded exactly once"
  )

  rm -rf "$fake_home"
}

test_install_state_receipt() {
  local fake_home fake_bin state_file first_inode second_inode output
  fake_home="$(mktemp -d)"
  fake_bin="$fake_home/.local/bin"
  state_file="$fake_home/state/dotfiles/install-state/minimal.tsv"
  mkdir -p "$fake_bin"
  cat > "$fake_bin/probe" <<'EOF'
#!/bin/sh
printf 'probe 1.0\n'
EOF
  chmod +x "$fake_bin/probe"

  (
    HOME="$fake_home"
    XDG_STATE_HOME="$fake_home/state"
    DOTFILES_DIR="$REPO_ROOT"
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    # shellcheck source=../lib/state.sh
    source "$REPO_ROOT/setup/lib/state.sh"
    profile_commands() { printf 'probe\n'; }
    command_has_safe_version_flag() { return 0; }
    resolve_command_from_clean_login_shell_without_stable_path() { printf '%s\n' "$fake_bin/$1"; }
    resolve_command_from_clean_login_shell() { printf '%s\n' "$fake_bin/$1"; }
    ERRORS=()
    write_profile_install_state minimal
    [[ ${#ERRORS[@]} -eq 0 ]] || fail "install-state write recorded an error"
  )
  first_inode="$(stat_inode "$state_file")"
  assert_eq "$(stat_mode "$state_file")" 600
  grep -Fq $'probe\tuser-local\t' "$state_file" || fail "install state omitted provider/path data"
  grep -Fq $'\tprobe 1.0' "$state_file" || fail "install state omitted version data"

  (
    HOME="$fake_home"
    XDG_STATE_HOME="$fake_home/state"
    DOTFILES_DIR="$REPO_ROOT"
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    # shellcheck source=../lib/state.sh
    source "$REPO_ROOT/setup/lib/state.sh"
    profile_commands() { printf 'probe\n'; }
    command_has_safe_version_flag() { return 0; }
    resolve_command_from_clean_login_shell_without_stable_path() { printf '%s\n' "$fake_bin/$1"; }
    resolve_command_from_clean_login_shell() { printf '%s\n' "$fake_bin/$1"; }
    ERRORS=()
    write_profile_install_state minimal >/dev/null
    verify_profile_install_state minimal >/dev/null
  )
  second_inode="$(stat_inode "$state_file")"
  assert_eq "$second_inode" "$first_inode"

  sed 's/probe 1.0/probe 2.0/' "$fake_bin/probe" > "$fake_bin/probe.new"
  mv "$fake_bin/probe.new" "$fake_bin/probe"
  chmod +x "$fake_bin/probe"
  set +e
  output="$(
    HOME="$fake_home"
    XDG_STATE_HOME="$fake_home/state"
    DOTFILES_DIR="$REPO_ROOT"
    source "$REPO_ROOT/setup/lib/core.sh"
    source "$REPO_ROOT/setup/lib/state.sh"
    profile_commands() { printf 'probe\n'; }
    command_has_safe_version_flag() { return 0; }
    resolve_command_from_clean_login_shell_without_stable_path() { printf '%s\n' "$fake_bin/$1"; }
    resolve_command_from_clean_login_shell() { printf '%s\n' "$fake_bin/$1"; }
    verify_profile_install_state minimal
  )"
  local status=$?
  set -e
  [[ $status -ne 0 ]] || fail "install-state verification accepted version drift"
  grep -Fq 'install-state version drift: probe is probe 2.0; recorded probe 1.0' <<<"$output" ||
    fail "install-state verification did not explain version drift"

  rm -rf "$fake_home"
}

test_privilege_and_manifest_guards() {
  (
    # shellcheck source=../lib/core.sh
    source "$REPO_ROOT/setup/lib/core.sh"
    ERRORS=()
    ALLOW_PARTIAL=0
    if handle_missing_sudo "sudo unavailable." >/dev/null; then
      fail "install silently degraded without --allow-partial"
    fi
    [[ ${#ERRORS[@]} -eq 1 ]] || fail "missing sudo did not become a hard error"
    ALLOW_PARTIAL=1
    handle_missing_sudo "sudo unavailable." >/dev/null || fail "explicit --allow-partial was rejected"
  )

  if grep -Fq '|always' "$REPO_ROOT/setup/packages/linux-binaries.minimal.txt"; then
    fail "minimal Linux binaries still force unconditional downloads"
  fi
  if rg -n 'curl[^|]*\|[[:space:]]*(sh|bash)' "$REPO_ROOT/setup" -g '*.sh' >/dev/null; then
    fail "setup still pipes remote scripts directly into a shell"
  fi
}

test_control_europa_desktop_wrapper() {
  local fake_home fake_bin capture helper_dir wrapper
  fake_home="$(mktemp -d)"
  fake_bin="$fake_home/bin"
  capture="$fake_home/capture"
  helper_dir="$fake_home/dotfiles/agents/skills/control-europa-desktop/scripts"
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

test_fleet_cli() {
  local fake_root fake_home fake_bin config known_hosts wrapper capture output expected_sha
  fake_root="$(mktemp -d)"
  fake_home="$fake_root/home"
  fake_bin="$fake_root/bin"
  config="$fake_root/machines.tsv"
  known_hosts="$fake_root/known_hosts"
  wrapper="$REPO_ROOT/scripts/.local/bin/fleet"
  capture="$fake_root/capture"
  mkdir -p "$fake_home" "$fake_bin"

  printf 'here\tdummy\t%s\t-\n' "$(hostname -s)" >"$config"
  printf 'remote\ttest@example.test\tnowhere\topen\n' >>"$config"
  : >"$known_hosts"
  printf 'fleet fixture\n' >"$fake_root/source.txt"
  if command -v sha256sum >/dev/null 2>&1; then
    expected_sha="$(sha256sum "$fake_root/source.txt" | awk '{print $1}')"
  else
    expected_sha="$(shasum -a 256 "$fake_root/source.txt" | awk '{print $1}')"
  fi

  output="$(FLEET_CONFIG="$config" "$wrapper" list)"
  grep -Fq 'test@example.test' <<<"$output" || fail "fleet list omitted a registered machine"

  output="$(FLEET_CONFIG="$config" "$wrapper" here run -- printf 'fleet-run-ok')"
  assert_eq "$output" fleet-run-ok

  FLEET_CONFIG="$config" HOME="$fake_home" \
    "$wrapper" here put "$fake_root/source.txt" inbox/ >/dev/null
  cmp "$fake_root/source.txt" "$fake_home/inbox/source.txt" ||
    fail "fleet put changed local file bytes"
  if FLEET_CONFIG="$config" HOME="$fake_home" \
      "$wrapper" here put "$fake_root/source.txt" inbox/ >/dev/null 2>&1; then
    fail "fleet put replaced an existing file without --force"
  fi
  FLEET_CONFIG="$config" HOME="$fake_home" \
    "$wrapper" here put --force "$fake_root/source.txt" inbox/ >/dev/null
  FLEET_CONFIG="$config" HOME="$fake_home" \
    "$wrapper" here get inbox/source.txt "$fake_root/download" >/dev/null
  cmp "$fake_root/source.txt" "$fake_root/download/source.txt" ||
    fail "fleet get changed local file bytes"

  cat >"$fake_bin/ssh" <<'EOF'
#!/bin/sh
socket=""
operation=""
master=0
arguments="$*"
printf '%s\n' "$@" >>"$CAPTURE"
while [ "$#" -gt 0 ]; do
  case "$1" in
    -S)
      shift
      socket="$1"
      ;;
    -O)
      shift
      operation="$1"
      ;;
    -M)
      master=1
      ;;
  esac
  shift
done
case "$operation" in
  check) [ -n "$socket" ] && [ -e "$socket" ] ;;
  exit) rm -f -- "$socket" ;;
  *)
    if [ "$master" -eq 1 ]; then
      : >"$socket"
    elif printf '%s\n' "$arguments" | grep -q sha256sum; then
      printf '%s\n' "$EXPECTED_SHA"
    fi
    ;;
esac
EOF
  chmod +x "$fake_bin/ssh"
  cat >"$fake_bin/scp" <<'EOF'
#!/bin/sh
printf 'scp:%s\n' "$*" >>"$CAPTURE"
EOF
  chmod +x "$fake_bin/scp"
  cat >"$fake_bin/curl" <<'EOF'
#!/bin/sh
exit 0
EOF
  chmod +x "$fake_bin/curl"

  FLEET_CONFIG="$config" FLEET_KNOWN_HOSTS="$known_hosts" \
    PATH="$fake_bin:/usr/bin:/bin" CAPTURE="$capture" \
    "$wrapper" remote run -- printf 'remote ok' >/dev/null
  grep -Fq 'test@example.test' "$capture" || fail "fleet run used the wrong SSH target"
  grep -Fq 'printf remote\ ok' "$capture" || fail "fleet run did not preserve remote arguments"
  grep -Fq "UserKnownHostsFile=$known_hosts" "$capture" ||
    fail "fleet SSH did not use its tracked known-hosts file"

  FLEET_CONFIG="$config" FLEET_KNOWN_HOSTS="$known_hosts" \
    PATH="$fake_bin:/usr/bin:/bin" CAPTURE="$capture" EXPECTED_SHA="$expected_sha" \
    "$wrapper" remote put --force "$fake_root/source.txt" inbox/ >/dev/null
  grep -Fq "scp:-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$known_hosts" "$capture" ||
    fail "fleet SCP did not use its tracked known-hosts file"

  FLEET_CONFIG="$config" PATH="$fake_bin:/usr/bin:/bin" CAPTURE="$capture" \
    "$wrapper" remote open https://example.com >/dev/null
  grep -Fq '/usr/bin/open -- https://example.com' "$capture" ||
    fail "fleet open did not use the target open capability"

  output="$(FLEET_CONFIG="$config" HOME="$fake_home" XDG_RUNTIME_DIR="$fake_root/runtime" \
    PATH="$fake_bin:/usr/bin:/bin" CAPTURE="$capture" \
    "$wrapper" remote forward --open 4100 5100)"
  grep -Fq 'http://127.0.0.1:5100/' <<<"$output" ||
    fail "fleet forward omitted the target URL"
  grep -Fq '127.0.0.1:5100:127.0.0.1:4100' "$capture" ||
    fail "fleet forward built the wrong reverse tunnel"
  grep -Fq '/usr/bin/open -- http://127.0.0.1:5100/' "$capture" ||
    fail "fleet forward --open did not open the Mac-loopback URL"
  output="$(FLEET_CONFIG="$config" HOME="$fake_home" XDG_RUNTIME_DIR="$fake_root/runtime" \
    PATH="$fake_bin:/usr/bin:/bin" CAPTURE="$capture" \
    "$wrapper" remote forward-status 5100)"
  grep -Fq 'active machine=remote source_port=4100 target_port=5100' <<<"$output" ||
    fail "fleet forward-status omitted active tunnel state"
  FLEET_CONFIG="$config" HOME="$fake_home" XDG_RUNTIME_DIR="$fake_root/runtime" \
    PATH="$fake_bin:/usr/bin:/bin" CAPTURE="$capture" \
    "$wrapper" remote forward-stop 5100 >/dev/null
  if FLEET_CONFIG="$config" HOME="$fake_home" XDG_RUNTIME_DIR="$fake_root/runtime" \
      PATH="$fake_bin:/usr/bin:/bin" CAPTURE="$capture" \
      "$wrapper" remote forward-status 5100 >/dev/null 2>&1; then
    fail "fleet forward-stop left the tunnel active"
  fi

  if FLEET_CONFIG="$config" "$wrapper" missing check >/dev/null 2>&1; then
    fail "fleet accepted an unregistered machine"
  fi

  [[ ! -e "$REPO_ROOT/scripts/.local/bin/forward-to-me" ]] ||
    fail "standalone forward-to-me should be absorbed by fleet"
  [[ ! -e "$REPO_ROOT/scripts/.local/bin/forward-from-me" ]] ||
    fail "standalone forward-from-me should be absorbed by fleet"

  rm -rf "$fake_root"
}

test_git_clone_subdir_writes_source_url() {
  local fake_root fake_bin destination wrapper
  fake_root="$(mktemp -d)"
  fake_bin="$fake_root/bin"
  destination="$fake_root/copied"
  wrapper="$REPO_ROOT/scripts/.local/bin/git-clone-subdir"
  mkdir -p "$fake_bin"

  cat >"$fake_bin/git" <<'EOF'
#!/bin/sh
if [ "$1" = clone ]; then
  destination=""
  for argument in "$@"; do destination="$argument"; done
  mkdir -p "$destination/tasks/tripletex"
  printf 'fixture\n' > "$destination/tasks/tripletex/example.txt"
  exit 0
fi
if [ "$1" = -C ] && [ "$3" = sparse-checkout ] && [ "$4" = set ]; then
  exit 0
fi
exit 1
EOF
  chmod +x "$fake_bin/git"

  PATH="$fake_bin:/usr/bin:/bin" "$wrapper" \
    'https://github.com/example/repo/tree/main/tasks/tripletex/?download=1#readme' \
    "$destination" >/dev/null

  assert_eq "$(cat "$destination/.url")" \
    'https://github.com/example/repo/tree/main/tasks/tripletex'
  assert_eq "$(cat "$destination/example.txt")" fixture

  rm -rf "$fake_root"
}

test_runtime_path_defaults
test_profile_contract
test_no_tty_prompt_contract
test_no_machine_specific_home_paths
test_canonical_repo_path_contract
test_homebrew_activation
test_homebrew_dry_run
test_homebrew_install_update_split
test_pnpm_setup_contract
test_pnpm_dry_run
test_agent_cli_profile_contract
test_agent_instruction_composition
test_dotfiles_cli_contract
test_agents_cli_contract
test_claude_standalone_installer_contract
test_codex_standalone_installer_contract
test_cliproxyapi_config_contract
test_cliproxyapi_umask_containment
test_fnm_entrypoint_stability
test_dry_run_privileged_plan
test_install_update_package_selection
test_installer_convergence_and_atomicity
test_install_state_receipt
test_privilege_and_manifest_guards
test_dry_run_on_toolless_machine
test_claudex_environment_isolation
test_control_europa_desktop_wrapper
test_fleet_cli
test_git_clone_subdir_writes_source_url
printf 'bootstrap contracts: ok\n'
