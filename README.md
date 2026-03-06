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

## Repository layout

- `shell/`, `git/`, `nvim/`, `tmux/`, `scripts/`, `terminals/`, `wt/`, `lazygit/`, `btop/`, `fd/`, `macos/`, `linux-desktop/`: GNU Stow packages.
- `setup/`: non-stowed setup and verification scripts plus package manifests.
- `docs/`: architecture, runtime, profile, secrets, and migration documentation.

## Useful commands

```bash
./init.sh --verify
./init.sh --layer full
./init.sh --stow nvim
./setup/brew-drift
```

`setup.sh` remains as a compatibility wrapper for `./init.sh linux-desktop`.
