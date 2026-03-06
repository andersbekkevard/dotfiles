# .dotfiles

Unified cross-platform dotfiles for macOS, Ubuntu desktop, and Ubuntu headless.

## Quick start

```bash
git clone <repo-url> ~/.dotfiles
cd ~/.dotfiles
./init.sh
```

Use an explicit profile to avoid surprises:

```bash
./init.sh minimal
./init.sh full
./init.sh macos
./init.sh linux-headless
./init.sh linux-desktop
```

With no explicit profile, `./init.sh` uses `auto`. On Linux, `auto` only selects `linux-desktop` when it sees runtime evidence of a local graphical session: `WAYLAND_DISPLAY`, `XDG_SESSION_TYPE=x11|wayland`, a non-SSH `DISPLAY`, or an active `graphical.target`. Installed GUI packages alone do not count, and SSH/X11-forwarded shells default to `linux-headless`.

On Linux, unattended runs now require working root access up front. If stdin is non-interactive and `sudo` is not already cached, `./init.sh` exits with an error instead of silently skipping apt/system bootstrap. Use `sudo -v` first, or set `DOTFILES_ALLOW_PARTIAL=1` to opt into explicit degraded mode.

## Architecture support

Both x86_64 and arm64/aarch64 are supported on Linux. Architecture is auto-detected at runtime; GitHub release binaries (lazygit, yazi, lsd) and Go are fetched for the correct platform automatically. After setup completes, all required commands for the active profile are verified and missing tools reported as hard errors in the summary.

## Repository layout

- `shell/`, `git/`, `nvim/`, `tmux/`, `scripts/`, `terminals/`, `wt/`, `lazygit/`, `btop/`, `fd/`, `macos/`, `linux-desktop/`: GNU Stow packages.
- `setup/`: non-stowed setup and verification scripts plus package manifests.
- `docs/`: architecture, runtime, profile, secrets, and migration documentation.

## Useful commands

```bash
./init.sh --verify
./init.sh --layer full
./init.sh --stow nvim
DOTFILES_ALLOW_PARTIAL=1 ./init.sh linux-headless
./setup/brew-drift
```

`setup.sh` remains as a compatibility wrapper for `./init.sh` and now passes arguments through without forcing `linux-desktop`.

Machine-local shell overrides live in `~/.zshrc.local`. `./init.sh` refreshes `~/.config/zsh/local.example.zsh` as the latest reference template without overwriting a customized local file.
