# Profiles

## `minimal`

Portable shell-focused environment with zsh, tmux, neovim, and core CLI tools.

## `full`

Adds development runtimes and shared developer tooling on top of `minimal`.
Includes `gh`, `git-crypt`, `lazygit`, `yazi`, `lsd`, and `lazydocker`.

## `macos`

Adds macOS-only packages, keyboard/mouse configuration, and terminal configs on top of `full`.

## `linux-desktop`

Adds Linux desktop packages and window-manager configuration on top of `full`.

## Selection rule

`./setup.sh` requires an explicit profile. It does not auto-detect one.

There is no second root bootstrap script. Profile choice is part of the operator command, not something the repo guesses.

That keeps first-run bootstrap deterministic and makes the chosen machine contract obvious from the command line:

- `./setup.sh macos`
- `./setup.sh linux-desktop`
- `./setup.sh full`
- `./setup.sh minimal`
