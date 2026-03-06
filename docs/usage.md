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
