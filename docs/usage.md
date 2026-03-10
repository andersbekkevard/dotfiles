# Usage

Fresh clone:

```bash
git clone <repo-url> ~/.dotfiles
cd ~/.dotfiles
./init.sh
```

Auto profile selection:

- `./init.sh` without a profile uses `auto`.
- On Linux, `auto` prefers `linux-headless` unless the current shell has local GUI runtime signals.
- SSH sessions, including shells with only X11 forwarding via `DISPLAY`, stay on `linux-headless` by default.
- Pass `linux-desktop` explicitly when you want desktop setup regardless of auto-detection.

Common maintenance:

```bash
./init.sh --verify
./init.sh --layer linux-desktop
./init.sh --stow shell
DOTFILES_ALLOW_PARTIAL=1 ./init.sh linux-headless
./setup/brew-drift
```

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

For unattended Linux bootstrap, pre-authenticate with `sudo -v` before invoking `./init.sh`. If you intentionally want a rootless pass that skips apt/system setup, make that explicit with `DOTFILES_ALLOW_PARTIAL=1`.

Compatibility wrapper:

```bash
./setup.sh
```

Machine-specific accent color (prompt + tmux):

```bash
# ~/.zshrc.local
export HAL_THEME_COLOR="red"   # linux-desktop
# export HAL_THEME_COLOR="blue"  # macos
# export HAL_THEME_COLOR="green" # headless/minimal

source ~/.zshrc
tmux source-file ~/.tmux.conf
```

`./init.sh` refreshes `~/.config/zsh/local.example.zsh` on every run so you can diff the latest template guidance without overwriting a customized `~/.zshrc.local`.

Shell bootstrap verification:

```bash
env -i HOME="$HOME" USER="$USER" SHELL=/bin/zsh PATH=/usr/bin:/bin:/usr/sbin:/sbin \
  zsh -lc 'command -v fnm node pnpm openclaw qmd'
```

Use that clean login-shell check when you need to confirm runtime bootstrap does not depend on interactive `~/.zshrc` state.

## Architecture handling

Both x86_64 and arm64/aarch64 Linux machines are supported. Architecture is detected automatically via `uname -m` at startup. GitHub release binaries (lazygit, yazi, lsd) and Go use architecture-specific download URLs. No manual configuration is needed.

## One-hit runtime guarantees

After a successful `./init.sh` run, all required commands for the active profile are verified. If any required tool (including `node`, `pnpm`, and other runtimes) is missing, the setup exits with a hard error listing the missing commands. This ensures that a green exit always means a fully functional environment.
