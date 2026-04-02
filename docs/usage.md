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

Setup flags:

- `--dry-run` prints the install/stow plan without changing the machine.
- `--skip-install` skips package/runtime installers and only applies repo-managed setup work such as stow and local-template refreshes.
- `--allow-partial` is the CLI equivalent of `DOTFILES_ALLOW_PARTIAL=1`; use it when you intentionally want Linux setup to continue without privileged apt/system steps.

For unattended Linux bootstrap, pre-authenticate with `sudo -v` before invoking `./setup.sh`. If you intentionally want a rootless pass that skips apt/system setup, make that explicit with `--allow-partial` or `DOTFILES_ALLOW_PARTIAL=1`.

Scope:

- This page documents how to operate the dotfiles repo itself: bootstrap, verify, stow, local overrides, and repo-managed customization points.
- It does not document general usage of installed tools such as tmux, Neovim, `wt`, or other bundled CLIs.

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
