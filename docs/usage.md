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
./setup/brew-drift
```

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
