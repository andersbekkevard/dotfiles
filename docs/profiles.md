# Profiles

## `minimal`

Portable shell-focused environment. Stows `shell`, `git`, `nvim`, `tmux`, `scripts`, `fd`, and `btop`, links the global agent surface (`agents/` — skills + instructions for Claude Code and Codex; see `docs/architecture.md`), and establishes the base command contract (`git`, `zsh`, `stow`, `tmux`, `fzf`, `rg`, `fd`, `bat`, `zoxide`, `nvim`, `htop`, `btop`, `jq`, `ngrok`, `cloudflared`, `delta`, `sesh`, `gum`, `trufflehog`, `forward-to-me`, `forward-from-me`, `git-clone-subdir`, `git-credential-gh-safe`, and `git-loc`).

## `full`

Adds shared development runtimes and tooling on top of `minimal`. This layer installs the managed runtime stack (`tree-sitter`, `uv`, `rustup`/`cargo`, `fnm`, `node`, `pnpm`, `bun`, the Claude Code and Codex CLIs, CLIProxyAPI plus the isolated `claudex` entrypoint, and the TypeScript language server tools), stows `lazygit`, `wt`, and `lsd`, and installs shared developer CLIs such as `gh`, `git-crypt`, `yazi`, `lazydocker`, and the PostgreSQL client (`psql`) used by Neovim Dadbod.

## `macos`

Adds macOS-only packages and config on top of `full`. This includes the `terminals` and `macos` stow packages plus Homebrew-managed extras such as Go and the macOS terminal/application setup.

## `linux-desktop`

Adds Linux desktop packages and window-manager config on top of `full`. This includes the `terminals` and `linux-desktop` stow packages plus the verified desktop command set (`i3`, `rofi`, `polybar`, `alacritty`, `kitty`, `dex`, `feh`, `greenclip`, `i3lock`, `maim`, `nm-applet`, `pactl`, `picom`, `setxkbmap`, `xclip`, `xdotool`, `xinput`, `xrandr`, `xss-lock`, and `xcape`).

## Selection rule

Normal bootstrap with `./setup.sh` requires an explicit profile. It does not auto-detect one. The maintenance shortcut `./setup.sh restow` has a fixed `full` default; pass `macos` or `linux-desktop` explicitly when restowing a platform layer.

There is no second root bootstrap script. Profile choice is part of the operator command, not something the repo guesses.

That keeps first-run bootstrap deterministic and makes the chosen machine contract obvious from the command line:

- `./setup.sh macos`
- `./setup.sh linux-desktop`
- `./setup.sh full`
- `./setup.sh minimal`

Idempotent repo-managed repair without package or runtime installation:

- `./setup.sh restow` (defaults to `full`)
- `./setup.sh restow macos`
- `./setup.sh restow linux-desktop`

`--layer <name>` is a maintenance mode that runs one layer in isolation; it does not expand to the full additive profile chain.
