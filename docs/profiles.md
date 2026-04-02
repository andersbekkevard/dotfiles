# Profiles

## `minimal`

Portable shell-focused environment. Stows `shell`, `git`, `nvim`, `tmux`, `scripts`, `fd`, and `btop`, and establishes the base command contract (`git`, `zsh`, `stow`, `tmux`, `fzf`, `rg`, `fd`, `bat`, `zoxide`, `nvim`, `htop`, `btop`, `jq`, `ngrok`, `delta`, `sesh`, and `gum`).

## `full`

Adds shared development runtimes and tooling on top of `minimal`. This layer installs the managed runtime stack (`tree-sitter`, `uv`, `rustup`/`cargo`, `fnm`, `node`, `pnpm`, `bun`, and the TypeScript language server tools), stows `lazygit`, `wt`, and `lsd`, and installs shared developer CLIs such as `gh`, `git-crypt`, `yazi`, and `lazydocker`.

## `macos`

Adds macOS-only packages and config on top of `full`. This includes the `terminals` and `macos` stow packages plus Homebrew-managed extras such as Go and the macOS terminal/application setup.

## `linux-desktop`

Adds Linux desktop packages and window-manager config on top of `full`. This includes the `terminals` and `linux-desktop` stow packages plus the verified desktop command set (`i3`, `rofi`, `polybar`, `alacritty`, `dex`, `feh`, `greenclip`, `i3lock`, `maim`, `nm-applet`, `pactl`, `picom`, `setxkbmap`, `xclip`, `xdotool`, `xinput`, `xrandr`, `xss-lock`, and `xcape`).

## Selection rule

`./setup.sh` requires an explicit profile. It does not auto-detect one.

There is no second root bootstrap script. Profile choice is part of the operator command, not something the repo guesses.

That keeps first-run bootstrap deterministic and makes the chosen machine contract obvious from the command line:

- `./setup.sh macos`
- `./setup.sh linux-desktop`
- `./setup.sh full`
- `./setup.sh minimal`

`--layer <name>` is a maintenance mode that runs one layer in isolation; it does not expand to the full additive profile chain.
