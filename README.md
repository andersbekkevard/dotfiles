# dotfiles

Unified cross-platform dotfiles for macOS, Ubuntu desktop, and Ubuntu headless.

## Quick start

```bash
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
./dotfiles.sh install macos
```

Choose the exact profile you want:

```bash
./dotfiles.sh install minimal
./dotfiles.sh install full
./dotfiles.sh install macos
./dotfiles.sh install linux-desktop
```

`./dotfiles.sh` is the only root management entrypoint. It separates installing
software from refreshing, stowing, and verifying repo-managed state.

An install asks for confirmation because third-party package and runtime
installers cannot all be proven idempotent. Use `--yes` for unattended runs or
`--dry-run` to inspect the plan without changing the machine. On Linux,
unattended installs also require working root access up front; use `sudo -v`
first, or explicitly opt into degraded mode with `--allow-partial`.

The shared base layer installs the same core CLI set on every machine, including `cloudflared`, `ngrok`, `git-delta`, TruffleHog secret scanning, and the `git-loc` remote repository line-count helper. `cloudflared` is the canonical path for publishing local services on Anders' Cloudflare-managed domains; the global `personal-edge` skill owns the agent workflow. TruffleHog is the fail-closed preflight used by the global `autoreview` skill. The full profile adds the Claude Code and Codex CLIs, CLIProxyAPI, the isolated `claudex` Claude-Code-with-Codex entrypoint, `git-crypt`, and developer tools including the PostgreSQL client (`psql`) required by Neovim Dadbod for PostgreSQL connections.

## Architecture support

Both x86_64 and arm64/aarch64 are supported on Linux. Architecture is auto-detected at runtime; GitHub release binaries such as `fzf`, `sesh`, `gum`, `lazygit`, `yazi`, and `lsd`, plus Go, are fetched for the correct platform automatically. After setup completes, all required commands for the active profile are verified and missing tools reported as hard errors in the summary.

## Repository layout

- `shell/`, `git/`, `nvim/`, `tmux/`, `scripts/`, `terminals/`, `wt/`, `lazygit/`, `btop/`, `fd/`, `lsd/`, `macos/`, `linux-desktop/`: GNU Stow packages.
- `setup/`: non-stowed setup and verification scripts plus package manifests.
- `docs/`: architecture, runtime, profile, local-override, secrets, and migration documentation (`docs/index.md` is the map).
- `agents/`: flat active global skills, in-progress candidates, retired skills, and shared agent instructions.
- `AGENTS.md`: LLM/coding-agent navigation, read order, and documentation source-of-truth matrix.

## Useful commands

```bash
./dotfiles.sh refresh
./dotfiles.sh agents sync
./dotfiles.sh agents status
./dotfiles.sh agents verify
./dotfiles.sh verify macos
./dotfiles.sh stow nvim
./dotfiles.sh install full --dry-run
./dotfiles.sh install linux-desktop --yes --allow-partial
./setup/brew-drift
```

On an already working machine, `./dotfiles.sh agents sync` refreshes only the global
agent skills and instructions under `~/.claude` and `~/.codex`. It does not
install packages, restow dotfiles, refresh shell templates, or update stable
command entrypoints. `./dotfiles.sh agents status` shows the tracked and
machine-local instruction sources and effective invocation modes.

Machine-local login/runtime overrides live in `~/.profile.local`; interactive-only shell tweaks live in `~/.zshrc.local`. Profile-wide `install` and `refresh` operations update `~/.config/zsh/local.example.zsh` without overwriting a customized local file, and refresh stable `~/.local/bin` entrypoints for commands installed outside the base system PATH.
