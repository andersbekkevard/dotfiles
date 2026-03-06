# Usage

Fresh clone:

```bash
git clone <repo-url> ~/.dotfiles
cd ~/.dotfiles
./init.sh
```

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
export HAL_THEME_COLOR="red"   # thinkpad
# export HAL_THEME_COLOR="blue"  # mac
# export HAL_THEME_COLOR="green" # vps

source ~/.zshrc
tmux source-file ~/.tmux.conf
```
