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
