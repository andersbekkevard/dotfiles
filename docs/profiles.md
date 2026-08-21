# Profiles

## `minimal`

Portable shell-focused environment. Stows `shell`, `git`, `nvim`, `tmux`, `scripts`, `fd`, and `btop`, links the global agent surface (`agents/` — skills + instructions for Claude Code and Codex; see `docs/architecture.md`), and establishes the base command contract (`git`, `zsh`, `stow`, `tmux`, `fzf`, `rg`, `fd`, `bat`, `zoxide`, `nvim`, `htop`, `btop`, `jq`, `ngrok`, `cloudflared`, `delta`, `sesh`, `gum`, `trufflehog`, `fleet`, `control-europa-desktop`, `forward-to-me`, `forward-from-me`, `git-clone-subdir`, `git-credential-gh-safe`, and `git-loc`).

## `full`

Adds shared development runtimes and tooling on top of `minimal`. This layer installs the managed runtime stack (`tree-sitter`, `uv`, `rustup`/`cargo`, `fnm`, `node`, `pnpm`, `bun`, the Claude Code and Codex CLIs, CLIProxyAPI plus the isolated `claudex` entrypoint, and the TypeScript language server tools), stows `lazygit`, `wt`, and `lsd`, and installs shared developer CLIs such as `gh`, `git-crypt`, `yazi`, `lazydocker`, and the PostgreSQL client (`psql`) used by Neovim Dadbod.

## `macos`

Adds macOS-only packages and config on top of `full`. This includes the `terminals` and `macos` stow packages plus Homebrew-managed extras such as Go and the macOS terminal/application setup.

## `linux-desktop`

Adds Linux desktop packages and window-manager config on top of `full`. This includes the `terminals` and `linux-desktop` stow packages plus the verified desktop command set (`i3`, `rofi`, `polybar`, `alacritty`, `kitty`, `dex`, `feh`, `greenclip`, `i3lock`, `maim`, `nm-applet`, `pactl`, `picom`, `setxkbmap`, `xclip`, `xdotool`, `xinput`, `xrandr`, `xss-lock`, and `xcape`).

## Selection rule

`./dotfiles.sh install`, `./dotfiles.sh update`, and `./dotfiles.sh verify`
require an explicit profile; none auto-detects one. `./dotfiles.sh refresh` has a fixed `full` default;
pass `macos` or `linux-desktop` explicitly when platform configuration belongs
in the refresh.

There is no second root bootstrap script. Profile choice is part of the operator command, not something the repo guesses.

That keeps first-run bootstrap deterministic and makes the chosen machine contract obvious from the command line:

- `./dotfiles.sh install macos`
- `./dotfiles.sh install linux-desktop`
- `./dotfiles.sh install full`
- `./dotfiles.sh install minimal`

Deliberate managed upgrades use the same profile boundaries:

- `./dotfiles.sh update macos`
- `./dotfiles.sh update linux-desktop`
- `./dotfiles.sh update full`
- `./dotfiles.sh update minimal`

Idempotent repo-managed repair without package or runtime installation:

- `./dotfiles.sh refresh` (defaults to `full`)
- `./dotfiles.sh refresh macos`
- `./dotfiles.sh refresh linux-desktop`

Agent-only repair on an already working machine:

- `./dotfiles.sh agents sync`

This maintenance mode refreshes the global skills and instructions under
`~/.claude` and `~/.codex`. It does not run a profile layer or touch unrelated
dotfiles.

Individual layers are internal implementation details. The public CLI always
expands a profile through its complete additive chain so dependency ordering is
not bypassed.
