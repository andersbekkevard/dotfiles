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

`Prefix + s` opens a tmux popup session/window picker with search, preview, and inline actions (`Ctrl-n` new session, `Ctrl-r` rename, `Ctrl-x` kill). `Alt-s` opens the same popup without a prefix, and `Prefix + S` jumps back to the previous tmux session.

Tmux navigation:

```text
Alt-a / Alt-d
Prefix + -
Prefix + _
Prefix + c
```

`Alt-a` and `Alt-d` move to the previous and next window. `Prefix + -`, `Prefix + _`, and `Prefix + c` create splits/windows in the current pane's working directory.

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
  zsh -lc 'command -v git nvim fnm node pnpm cargo bun tree-sitter'
```

Stable non-login command contract verification:

```bash
env -i HOME="$HOME" USER="$USER" PATH="$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  sh -lc 'command -v git nvim fnm node pnpm cargo bun tree-sitter wt'
```

Use the login-shell check to confirm shared bootstrap does not depend on interactive `~/.zshrc` state. Use the non-login check to confirm agents and scripts can resolve the same commands through the stable `~/.local/bin` contract.

## Architecture handling

Both x86_64 and arm64/aarch64 Linux machines are supported. Architecture is detected automatically via `uname -m` at startup. GitHub release binaries (lazygit, yazi, lsd) and Go use architecture-specific download URLs. No manual configuration is needed.

## One-hit runtime guarantees

After a successful `./setup.sh <profile>` run, all required commands for the active profile are verified in two ways: from a clean login shell and from a non-login shell with `~/.local/bin` plus the base system PATH only. If any required tool is missing in either view, setup exits with a hard error. This keeps human shells and agent/script entrypoints aligned.
