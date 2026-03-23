# .dotfiles

Unified cross-platform dotfiles for macOS, Ubuntu desktop, and Ubuntu headless.

## Quick start

```bash
git clone <repo-url> ~/.dotfiles
cd ~/.dotfiles
./setup.sh macos
```

Choose the exact profile you want:

```bash
./setup.sh minimal
./setup.sh full
./setup.sh macos
./setup.sh linux-headless
./setup.sh linux-desktop
```

`./setup.sh` is the only root bootstrap entrypoint.

On Linux, unattended runs now require working root access up front. If stdin is non-interactive and `sudo` is not already cached, `./setup.sh` exits with an error instead of silently skipping apt/system bootstrap. Use `sudo -v` first, or set `DOTFILES_ALLOW_PARTIAL=1` to opt into explicit degraded mode.

The shared base layer installs the same core CLI set on every machine, including `ngrok`.

## Architecture support

Both x86_64 and arm64/aarch64 are supported on Linux. Architecture is auto-detected at runtime; GitHub release binaries (lazygit, yazi, lsd) and Go are fetched for the correct platform automatically. After setup completes, all required commands for the active profile are verified and missing tools reported as hard errors in the summary.

## Repository layout

- `shell/`, `git/`, `nvim/`, `tmux/`, `scripts/`, `terminals/`, `wt/`, `lazygit/`, `btop/`, `fd/`, `macos/`, `linux-desktop/`: GNU Stow packages.
- `setup/`: non-stowed setup and verification scripts plus package manifests.
- `docs/`: architecture, runtime, profile, local-override, secrets, and migration documentation (`docs/index.md` is the map).
- `AGENTS.md`: LLM/coding-agent navigation, read order, and documentation source-of-truth matrix.

## Useful commands

```bash
./setup.sh --verify macos
./setup.sh --layer full
./setup.sh --stow nvim
DOTFILES_ALLOW_PARTIAL=1 ./setup.sh linux-headless
./setup/brew-drift
```

Machine-local login/runtime overrides live in `~/.profile.local`; interactive-only shell tweaks live in `~/.zshrc.local`. `./setup.sh` refreshes `~/.config/zsh/local.example.zsh` as the latest reference template without overwriting a customized local file, and refreshes stable `~/.local/bin` entrypoints for commands installed outside the base system PATH.
