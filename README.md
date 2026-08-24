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

`./dotfiles.sh` is the only root management entrypoint. `install` fills missing
prerequisites without upgrading working tools; `update` deliberately moves
dotfiles-managed packages and runtimes; `refresh` reapplies configuration with
all installers disabled.

Install and update ask for confirmation because third-party installers cannot
all be proven idempotent. Use `--dry-run` to inspect the plan. `--yes` means the
entire run must remain noninteractive; on Linux, pre-authenticate with `sudo -v`
or explicitly accept skipped privileged work with `--allow-partial`.

The shared base layer installs the same core CLI set on every machine, including `fleet` for cross-machine commands and verified file transfer against Git-tracked encrypted host identities, `cloudflared`, `ngrok`, `git-delta`, TruffleHog secret scanning, and the `git-loc` remote repository line-count helper. `cloudflared` is the canonical path for publishing local services on Anders' Cloudflare-managed domains; the global `publish-web` skill owns that workflow. TruffleHog is the fail-closed preflight used by the global `autoreview` skill. The full profile adds the Claude Code and Codex CLIs, CLIProxyAPI, the isolated `claudex` Claude-Code-with-Codex entrypoint, `git-crypt`, and developer tools including the PostgreSQL client (`psql`) required by Neovim Dadbod for PostgreSQL connections.

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
./dotfiles.sh update macos
./dotfiles.sh agents sync
./dotfiles.sh agents status
./dotfiles.sh agents verify
./dotfiles.sh verify macos
./dotfiles.sh stow nvim
./dotfiles.sh install full --dry-run
./dotfiles.sh update full --dry-run
./dotfiles.sh install linux-desktop --yes --allow-partial
./setup/brew-drift
```

On an already working machine, `./dotfiles.sh agents sync` refreshes only the global
agent skills and instructions under `~/.claude` and `~/.codex`. It does not
install packages, restow dotfiles, refresh shell templates, or update stable
command entrypoints. The first run also establishes the local skill-usage
telemetry baseline. `./dotfiles.sh agents status` shows the tracked and
machine-local instruction sources and effective invocation modes; use
`agents/skill-usage sync` to publish later usage counts.

A successful install or update records the resolved command path, provider, and
reported version under `${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/install-state/`.
`./dotfiles.sh verify <profile>` checks the live machine against that receipt as
well as the profile's links and command contract.

Machine-local login/runtime overrides live in `~/.profile.local`; interactive-only shell tweaks live in `~/.zshrc.local`. Profile-wide `install`, `update`, and `refresh` operations update `~/.config/zsh/local.example.zsh` without overwriting a customized local file, and refresh stable `~/.local/bin` entrypoints for commands installed outside the base system PATH.
