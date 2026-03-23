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
- Pick the exact target you want: `minimal`, `full`, `macos`, `linux-headless`, or `linux-desktop`.

Typical first-run examples:

```bash
./setup.sh macos
./setup.sh linux-headless
./setup.sh linux-desktop
```

Common maintenance:

```bash
./setup.sh --verify macos
./setup.sh --layer linux-desktop
./setup.sh --stow shell
DOTFILES_ALLOW_PARTIAL=1 ./setup.sh linux-headless
./setup/brew-drift
```

Tmux session picker:

```text
Prefix + s
```

`sp` opens `sesh picker` directly from the shell. `Prefix + s` opens a blog-style `sesh` launcher inside tmux. When `sesh`, `fzf-tmux`, `fd`, and `jq` are available, the launcher mirrors the article workflow with `Ctrl-a` all entries, `Ctrl-t` tmux sessions, `Ctrl-g` configured sessions, `Ctrl-x` zoxide entries, `Ctrl-f` filesystem search, and `Ctrl-d` to kill the highlighted tmux session before reloading. If `fzf-tmux` is unavailable but `gum` is installed, the binding falls back to the article's simpler `gum filter` flow. If only `sesh` is available, it falls back to `sesh picker`. If `sesh` is unavailable, it falls back to the built-in tmux session/window picker with search, preview, and inline actions (`Ctrl-n` new session, `Ctrl-r` rename, `Ctrl-x` kill). `Alt-s` opens the same launcher without a prefix, and `Prefix + S` jumps back to the previous tmux session.

Prefix + e

Opens a new tmux window running `yazi` in the current pane's working directory, which is the most reliable Yazi workflow on this setup because popup mode can trigger tmux terminal-response issues.

Prefix + t

Opens a tmux popup shell running `zsh` in the current pane's working directory, which is useful for quick command work without changing the current layout.

Managed `sesh` defaults live in `~/.config/sesh/sesh.toml`. The baseline includes curated sessions for `Downloads`, dotfiles, tmux config, and notes, a `node_dev` startup script under `~/.config/sesh/scripts/node_dev`, and a default startup command that opens Neovim with `:Telescope find_files`.

Tmux navigation:

```text
Alt-a / Alt-d
Prefix + -
Prefix + _
Prefix + c
```

`Alt-a` and `Alt-d` move to the previous and next window. `Prefix + -`, `Prefix + _`, and `Prefix + c` create splits/windows in the current pane's working directory.

On macOS in Ghostty, left `Option` is reserved for `Alt`/Meta terminal bindings, while right `Option` stays native for macOS symbols and dead keys such as `~`.

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

For unattended Linux bootstrap, pre-authenticate with `sudo -v` before invoking `./setup.sh`. If you intentionally want a rootless pass that skips apt/system setup, make that explicit with `DOTFILES_ALLOW_PARTIAL=1`.

Machine-specific accent color (prompt + tmux):

```bash
# ~/.zshrc.local
export HAL_THEME_COLOR="red"   # linux-desktop
# export HAL_THEME_COLOR="blue"  # macos
# export HAL_THEME_COLOR="green" # headless/minimal

source ~/.zshrc
tmux source-file ~/.tmux.conf
```

`./setup.sh` refreshes `~/.config/zsh/local.example.zsh` on every run so you can diff the latest template guidance without overwriting a customized `~/.zshrc.local`.

Machine-local runtime env and PATH overrides belong in `~/.profile.local`. Use `~/.zshrc.local` only for interactive shell behavior.

Shell bootstrap verification:

```bash
env -i HOME="$HOME" USER="$USER" SHELL=/bin/zsh PATH=/usr/bin:/bin:/usr/sbin:/sbin \
  zsh -lc 'command -v git nvim ngrok delta fnm node pnpm cargo bun tree-sitter'
```

Stable non-login command contract verification:

```bash
env -i HOME="$HOME" USER="$USER" PATH="$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  sh -lc 'command -v git nvim ngrok delta fnm node pnpm cargo bun tree-sitter wt'
```

Use the login-shell check to confirm shared bootstrap does not depend on interactive `~/.zshrc` state. Use the non-login check to confirm agents and scripts can resolve the same commands through the stable `~/.local/bin` contract.

## Architecture handling

Both x86_64 and arm64/aarch64 Linux machines are supported. Architecture is detected automatically via `uname -m` at startup. GitHub release binaries (lazygit, yazi, lsd) and Go use architecture-specific download URLs. No manual configuration is needed.

## One-hit runtime guarantees

After a successful `./setup.sh <profile>` run, all required commands for the active profile are verified in two ways: from a clean login shell and from a non-login shell with `~/.local/bin` plus the base system PATH only. If any required tool is missing in either view, setup exits with a hard error. This keeps human shells and agent/script entrypoints aligned.
