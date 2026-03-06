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

## `auto`

`./init.sh` uses `auto` when you do not pass an explicit profile.

- On macOS, `auto` resolves to `macos`.
- On Linux, `auto` resolves to `linux-desktop` only when the current shell looks like a local graphical session.
- On Linux, `auto` resolves to `linux-headless` for SSH sessions and other shells without active GUI runtime signals.

Linux desktop detection checks these signals in order:

1. `WAYLAND_DISPLAY` is set.
2. `XDG_SESSION_TYPE` is `wayland` or `x11`.
3. `DISPLAY` is set and the shell is not running under SSH.
4. `systemctl is-active graphical.target` succeeds and the shell is not running under SSH.

Desktop package installation alone does not affect `auto`. A machine with `xserver-xorg` installed still resolves to `linux-headless` unless one of the runtime signals above is present.
