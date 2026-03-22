# Profiles

## `minimal`

Portable shell-focused environment with zsh, tmux, neovim, and core CLI tools.

## `full`

Adds development runtimes and shared developer tooling on top of `minimal`.
On Linux, this includes `gh`, `git-crypt`, `lazygit`, and `yazi`.

## `macos`

Adds macOS-only packages, keyboard/mouse configuration, and terminal configs on top of `full`.

## `linux-headless`

Selects the Linux non-GUI profile on top of `full`, without desktop/window-manager config.

## `linux-desktop`

Adds desktop packages and window-manager configuration on top of `linux-headless`.

## Selection rule

`./setup.sh` requires an explicit profile. It does not auto-detect one.

There is no second root bootstrap script. Profile choice is part of the operator command, not something the repo guesses.

That keeps first-run bootstrap deterministic and makes the chosen machine contract obvious from the command line:

- `./setup.sh macos`
- `./setup.sh linux-headless`
- `./setup.sh linux-desktop`
- `./setup.sh full`
- `./setup.sh minimal`
