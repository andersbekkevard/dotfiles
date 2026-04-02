# Usage

Fresh clone:

```bash
git clone <repo-url> ~/.dotfiles
cd ~/.dotfiles
./setup.sh macos
```

Explicit profile selection:

- `./setup.sh` is the only root bootstrap entrypoint.
- Files under `setup/` are support scripts, not alternate install entrypoints.
- `./setup.sh` never auto-detects a profile.
- Running `./setup.sh` with no profile prints the available profiles and maintenance modes.
- Pick the exact target you want: `minimal`, `full`, `macos`, or `linux-desktop`.

Typical first-run examples:

```bash
./setup.sh macos
./setup.sh linux-desktop
```

Common maintenance:

```bash
./setup.sh --verify macos
./setup.sh --layer linux-desktop
./setup.sh --stow shell
./setup.sh full --dry-run
./setup.sh full --skip-install
./setup.sh linux-desktop --allow-partial
DOTFILES_ALLOW_PARTIAL=1 ./setup.sh linux-desktop
./setup/brew-drift
```

Tmux session picker:

```text
Prefix + s
```

`Prefix + s` opens the repo-managed `tmux-session-picker` popup. It uses `fzf` to show sessions and windows together, keeps an always-visible preview on the right, and supports inline actions: `Enter` switches, `Ctrl-s` toggles between sessions-only and sessions-plus-windows, `Ctrl-n` creates a new session, `Ctrl-r` renames the current selection, and `Ctrl-x` kills the selected session or window. In the new-session flow, `Tab` opens a `zoxide` path picker when `zoxide` is available; otherwise the new session starts at `~/`. `Alt-s` opens the same picker without a prefix, and `Prefix + S` jumps back to the previous tmux session.

Quick tmux session targets:

```bash
td
tn
```

`td` jumps to the `dev` tmux session, creating it if needed. `tn` uses the current directory name as the tmux session name: if that session already exists it attaches or switches to it, otherwise it creates a new session rooted at the current working directory.

Prefix + e

Opens a new tmux window running `yazi` in the current pane's working directory, which is the most reliable Yazi workflow on this setup because popup mode can trigger tmux terminal-response issues.

Prefix + g

Opens a tmux popup running `lazygit` in the current pane's working directory.

Prefix + t

Opens a tmux popup shell running `zsh` in the current pane's working directory, which is useful for quick command work without changing the current layout.

Tmux navigation:

```text
Alt-a / Alt-d
Prefix + -
Prefix + _
Prefix + c
```

`Alt-a` and `Alt-d` move to the previous and next window. `Prefix + -`, `Prefix + _`, and `Prefix + c` create splits/windows in the current pane's working directory.

On macOS in Ghostty, `Option` stays native for macOS symbols and dead keys such as `~`; Ghostty does not reserve it for terminal `Alt`/Meta bindings.

`Prefix + Ctrl-c` is mapped to the same action as `Prefix + c`, so it opens a new tmux window in the current pane's working directory.

`Prefix + x` keeps the confirmation prompt before killing the current pane. `Prefix + X` and `Prefix + Ctrl-x` kill the current pane immediately when you want the faster version.

Tmux fingers:

```text
Prefix + F
Prefix + J
```

`Prefix + F` opens `tmux-fingers` hint mode for quickly selecting paths, SHAs, URLs, numbers, and other detected text in the current pane. `Prefix + J` opens `tmux-fingers` jump mode, which moves the cursor to the selected match instead of only copying it. The first TPM install may require completing the plugin's one-time installation wizard.

Tmux state persistence:

`tmux-resurrect` is available for manual save/restore on `Prefix + Ctrl-s` and `Prefix + Ctrl-r`. `tmux-continuum` is also installed and runs periodic background saves, but automatic restore is not enabled by default, so a fresh tmux server will not restore itself unless you opt into that later.

Rapid tmux session cleanup:

```bash
tk
```

`tk` opens an `fzf` picker for tmux sessions, previews the session windows, and asks for confirmation before killing the selected session.

Worktree workflow:

```bash
wt new my-branch
wt config
```

`wt new` creates the worktree, runs any repo-defined setup hooks, and `cd`s into the new path. It does not auto-launch Claude Code or any other follow-up command unless `~/.config/wt/config.json` explicitly opts in with `"autoLaunch": true` alongside a non-empty `"command"` value.

Setup flags:

- `--dry-run` prints the install/stow plan without changing the machine.
- `--skip-install` skips package/runtime installers and only applies repo-managed setup work such as stow and local-template refreshes.
- `--allow-partial` is the CLI equivalent of `DOTFILES_ALLOW_PARTIAL=1`; use it when you intentionally want Linux setup to continue without privileged apt/system steps.

For unattended Linux bootstrap, pre-authenticate with `sudo -v` before invoking `./setup.sh`. If you intentionally want a rootless pass that skips apt/system setup, make that explicit with `--allow-partial` or `DOTFILES_ALLOW_PARTIAL=1`.

Machine-specific accent color (prompt + tmux):

```bash
# ~/.zshrc.local
export THEME_COLOR="blue"     # system default
# export THEME_COLOR="red"     # alternate palette
# export THEME_COLOR="green"   # alternate palette
# export THEME_COLOR="purple"  # alternate palette
# export THEME_COLOR="yellow"  # alternate palette
# export THEME_COLOR="orange"  # alternate palette
# export THEME_COLOR="teal"    # alternate palette

source ~/.zshrc
tmux source-file ~/.tmux.conf
```

`THEME_COLOR` is normalized through one shared palette map, so prompt, tmux, and tmux helper UIs all stay in sync. `./setup.sh` refreshes `~/.config/zsh/local.example.zsh` on every run so you can diff the latest template guidance without overwriting a customized `~/.zshrc.local`.

Machine-local runtime env and PATH overrides belong in `~/.profile.local`. Use `~/.zshrc.local` only for interactive shell behavior.

Shell bootstrap verification:

```bash
env -i HOME="$HOME" USER="$USER" SHELL=/bin/zsh PATH=/usr/bin:/bin:/usr/sbin:/sbin \
  zsh -lc 'command -v git nvim ngrok delta fnm node pnpm cargo bun tree-sitter typescript-language-server'
```

Stable non-login command contract verification:

```bash
env -i HOME="$HOME" USER="$USER" PATH="$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  sh -lc 'command -v git nvim ngrok delta fnm node pnpm cargo bun tree-sitter typescript-language-server wt'
```

Use the login-shell check to confirm shared bootstrap does not depend on interactive `~/.zshrc` state. Use the non-login check to confirm agents and scripts can resolve the same commands through the stable `~/.local/bin` contract.

## Architecture handling

Both x86_64 and arm64/aarch64 Linux machines are supported. Architecture is detected automatically via `uname -m` at startup. GitHub release binaries (lazygit, yazi, lsd) and Go use architecture-specific download URLs. No manual configuration is needed.

## One-hit runtime guarantees

After a successful `./setup.sh <profile>` run, all required commands for the active profile are verified in two ways: from a clean login shell and from a non-login shell with `~/.local/bin` plus the base system PATH only. If any required tool is missing in either view, setup exits with a hard error. This keeps human shells and agent/script entrypoints aligned.
